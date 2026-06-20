import Foundation

/// Native, synchronous parallel-offset used for the Offset tool's live preview.
///
/// The committed geometry still comes from the Python/Shapely op (`offset_lines`),
/// which is robust for every entity type. This is *only* the on-canvas ghost: it
/// runs as pure Swift math on the main thread so the preview tracks the drag
/// handle in real time, instead of the old approach that round-tripped through
/// the Python worker (write a DXF + read it back) on every drag frame — which was
/// slow, queued requests faster than they could drain, and showed a stale,
/// lagging outline.
enum OffsetGeometry {
    typealias P = SIMD2<Double>

    /// A flattened curve: a list of points plus whether it forms a closed loop.
    private struct Polyline {
        var pts: [P]
        var closed: Bool
    }

    /// Dashed-preview entities (LWPOLYLINE / CIRCLE on the `PREVIEW` layer) for
    /// offsetting `selected` by `distance` toward `side` ("left" / "right" /
    /// "outer" / "inner" / "both"). The side semantics mirror `get_offset_geometry`
    /// in `dxf_ops.py` so the ghost matches what the commit produces.
    static func preview(selected: [DXFEntity], distance: Double, side: String) -> [DXFEntity] {
        guard distance > 1e-6 else { return [] }

        let sides: [String] = (side == "both") ? ["outer", "inner"] : [side]
        var out: [DXFEntity] = []
        var counter = 0
        func nextKey() -> String { counter += 1; return "preview_offset_\(counter)" }

        // Circles offset by simply growing / shrinking the radius.
        for c in selected where c.type.uppercased() == "CIRCLE" {
            guard let center = c.center, center.count >= 2, let r = c.radius else { continue }
            for s in sides {
                let rr = (s == "left" || s == "outer") ? r + distance : r - distance
                if rr > 1e-6 {
                    out.append(makeCircle(center: center, radius: rr, key: nextKey()))
                }
            }
        }

        // Everything else: flatten to polylines, snap-merge touching segments into
        // chains (so a profile built from many lines/arcs offsets as one loop),
        // then offset each chain.
        let polys = selected.compactMap { flatten($0) }
        for chain in mergeChains(polys) {
            for s in sides {
                let pts = offsetPolyline(chain, distance: distance, side: s)
                if pts.count >= 2 {
                    out.append(makePolyline(pts, closed: chain.closed, key: nextKey()))
                }
            }
        }
        return out
    }

    // MARK: - Flattening

    private static func flatten(_ ent: DXFEntity) -> Polyline? {
        switch ent.type.uppercased() {
        case "LINE":
            guard let s = ent.start, let e = ent.end, s.count >= 2, e.count >= 2 else { return nil }
            return Polyline(pts: [P(s[0], s[1]), P(e[0], e[1])], closed: false)
        case "ARC":
            guard let c = ent.center, c.count >= 2, let r = ent.radius,
                  let sa = ent.start_angle, let ea = ent.end_angle else { return nil }
            var sweep = ea - sa
            if sweep <= 0 { sweep += 360 }
            let steps = max(6, Int(sweep / 4))
            var pts: [P] = []
            for k in 0...steps {
                let ang = (sa + sweep * Double(k) / Double(steps)) * .pi / 180
                pts.append(P(c[0] + r * cos(ang), c[1] + r * sin(ang)))
            }
            return Polyline(pts: pts, closed: false)
        case "LWPOLYLINE", "POLYLINE":
            guard let verts = ent.vertices, verts.count >= 2 else { return nil }
            var pts = verts.compactMap { $0.count >= 2 ? P($0[0], $0[1]) : nil }
            let closed = ent.closed ?? false
            // Drop a redundant closing vertex so the offset routine sees a clean ring.
            if closed, pts.count >= 2, dist(pts.first!, pts.last!) < 1e-7 {
                pts.removeLast()
            }
            return pts.count >= 2 ? Polyline(pts: pts, closed: closed) : nil
        default:
            return nil
        }
    }

    // MARK: - Chain merging (snap shared endpoints, like Python's snap + linemerge)

    private static func mergeChains(_ input: [Polyline]) -> [Polyline] {
        let tol = 0.05
        var result = input.filter { $0.closed && $0.pts.count >= 3 }
        var open = input.filter { !$0.closed && $0.pts.count >= 2 }

        var didMerge = true
        while didMerge {
            didMerge = false
            outer: for i in 0..<open.count {
                for j in (i + 1)..<open.count {
                    if let joined = join(open[i], open[j], tol: tol) {
                        open.remove(at: j)
                        if joined.closed {
                            open.remove(at: i)
                            result.append(joined)
                        } else {
                            open[i] = joined
                        }
                        didMerge = true
                        break outer
                    }
                }
            }
        }

        // An open chain whose own ends meet is really a closed loop.
        for var p in open {
            if let f = p.pts.first, let l = p.pts.last, p.pts.count >= 3, dist(f, l) < tol {
                p.pts.removeLast()
                p.closed = true
            }
            result.append(p)
        }
        return result
    }

    /// Joins two open polylines if any of their endpoints coincide. Returns the
    /// merged polyline (marked `closed` when the join also seals both free ends).
    private static func join(_ a: Polyline, _ b: Polyline, tol: Double) -> Polyline? {
        guard let af = a.pts.first, let al = a.pts.last,
              let bf = b.pts.first, let bl = b.pts.last else { return nil }

        var merged: [P]?
        if dist(al, bf) < tol {
            merged = a.pts + b.pts.dropFirst()
        } else if dist(al, bl) < tol {
            merged = a.pts + b.pts.reversed().dropFirst()
        } else if dist(af, bf) < tol {
            merged = Array(a.pts.reversed()) + b.pts.dropFirst()
        } else if dist(af, bl) < tol {
            merged = b.pts + a.pts.dropFirst()
        }
        guard var pts = merged else { return nil }

        var closed = false
        if let f = pts.first, let l = pts.last, pts.count >= 3, dist(f, l) < tol {
            pts.removeLast()
            closed = true
        }
        return Polyline(pts: pts, closed: closed)
    }

    // MARK: - Offsetting

    private static func offsetPolyline(_ chain: Polyline, distance: Double, side: String) -> [P] {
        let pts = chain.pts
        guard pts.count >= 2 else { return [] }

        if chain.closed {
            let ccw = signedArea(pts) > 0
            let d: Double
            switch side {
            case "outer": d = distance
            case "inner": d = -distance
            default:
                // "left" / "right" are handle-relative; the left normal points
                // inward exactly when the ring is CCW (matches dxf_ops.py).
                let towardInside = (side == "left") == ccw
                d = towardInside ? -distance : distance
            }
            // `d > 0` must grow the loop regardless of winding.
            let leftAmount = ccw ? -d : d
            return offsetVerts(pts, closed: true, amount: leftAmount)
        } else {
            // offset_curve: positive distance offsets to the left of the directed line.
            let leftAmount = (side == "left" || side == "outer") ? distance : -distance
            return offsetVerts(pts, closed: false, amount: leftAmount)
        }
    }

    /// Miter-joined parallel offset of a vertex list. `amount` is the signed
    /// distance to move along each edge's left normal.
    private static func offsetVerts(_ input: [P], closed: Bool, amount: Double) -> [P] {
        // Drop consecutive duplicates so edge directions are well defined.
        var v: [P] = []
        for p in input where v.last == nil || dist(v.last!, p) > 1e-9 { v.append(p) }
        if closed, v.count > 1, dist(v.first!, v.last!) < 1e-9 { v.removeLast() }
        let m = v.count
        guard m >= 2 else { return [] }

        let edgeCount = closed ? m : m - 1

        func leftNormal(_ edge: Int) -> P? {
            let a = v[edge], b = v[(edge + 1) % m]
            let d = b - a
            let len = (d.x * d.x + d.y * d.y).squareRoot()
            return len < 1e-12 ? nil : P(-d.y / len, d.x / len)
        }
        func dir(_ edge: Int) -> P {
            let a = v[edge], b = v[(edge + 1) % m]
            let d = b - a
            let len = (d.x * d.x + d.y * d.y).squareRoot()
            return len < 1e-12 ? P(0, 0) : P(d.x / len, d.y / len)
        }

        var result: [P] = []
        for i in 0..<m {
            // Open endpoints just follow their single adjacent edge.
            if !closed && i == 0 {
                if let n = leftNormal(0) { result.append(v[0] + n * amount) }
                continue
            }
            if !closed && i == m - 1 {
                if let n = leftNormal(m - 2) { result.append(v[m - 1] + n * amount) }
                continue
            }
            let eIn = (i - 1 + edgeCount) % edgeCount
            let eOut = i % edgeCount
            guard let nIn = leftNormal(eIn), let nOut = leftNormal(eOut) else {
                result.append(v[i]); continue
            }
            let pIn = v[eIn] + nIn * amount
            let pOut = v[i] + nOut * amount
            if let x = intersect(pIn, dir(eIn), pOut, dir(eOut)) {
                result.append(x)
            } else {
                // Collinear edges — straight continuation.
                result.append(pOut)
            }
        }
        return result
    }

    /// Intersection of lines (p1 + t·d1) and (p2 + s·d2); nil when near-parallel.
    private static func intersect(_ p1: P, _ d1: P, _ p2: P, _ d2: P) -> P? {
        let denom = d1.x * d2.y - d1.y * d2.x
        if abs(denom) < 1e-9 { return nil }
        let dp = p2 - p1
        let t = (dp.x * d2.y - dp.y * d2.x) / denom
        return p1 + d1 * t
    }

    private static func signedArea(_ pts: [P]) -> Double {
        let m = pts.count
        guard m >= 3 else { return 0 }
        var a = 0.0
        for i in 0..<m {
            let p = pts[i], q = pts[(i + 1) % m]
            a += p.x * q.y - q.x * p.y
        }
        return a / 2
    }

    private static func dist(_ a: P, _ b: P) -> Double {
        let d = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    // MARK: - Entity builders

    private static func makeCircle(center: [Double], radius: Double, key: String) -> DXFEntity {
        DXFEntity(handle: key, type: "CIRCLE", layer: "PREVIEW", color: 3,
                  start: nil, end: nil, center: center, radius: radius,
                  start_angle: nil, end_angle: nil, vertices: nil, closed: nil,
                  text: nil, height: nil)
    }

    private static func makePolyline(_ pts: [P], closed: Bool, key: String) -> DXFEntity {
        DXFEntity(handle: key, type: "LWPOLYLINE", layer: "PREVIEW", color: 3,
                  start: nil, end: nil, center: nil, radius: nil,
                  start_angle: nil, end_angle: nil,
                  vertices: pts.map { [$0.x, $0.y] }, closed: closed,
                  text: nil, height: nil)
    }
}
