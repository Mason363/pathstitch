import CoreGraphics
import Foundation
import simd

// MARK: - STEP B-rep mesh (foxtrot) — MAS-157

/// A triangle mesh tessellated from a STEP file by the bundled foxtrot
/// tessellator (`step_mesh` Rust FFI). Positions + per-vertex normals are
/// interleaved (6 floats per vertex); `indices` are triangle indices.
public struct StepMeshData {
    public var interleaved: [Float]   // px,py,pz,nx,ny,nz per vertex
    public var indices: [UInt32]
    public var vertexCount: Int
}

/// Tessellates a STEP file into a real triangle mesh, or nil when foxtrot can't
/// (bad file, or a fully-closed primitive surface it won't flatten) — callers
/// then fall back to the lightweight point cloud. This replaces the old
/// CARTESIAN_POINT scraping, which couldn't tell surface points from stray
/// origin/axis/reference points and so rendered a noisy cloud (MAS-157).
public func loadStepMesh(url: URL) -> StepMeshData? {
    return url.path.withCString { cstr -> StepMeshData? in
        guard let mp = step_mesh_load(cstr) else { return nil }
        defer { step_mesh_free(mp) }
        let m = mp.pointee
        guard let vptr = m.verts, let iptr = m.indices,
              m.vertex_count > 0, m.index_count > 0 else { return nil }
        let interleaved = Array(UnsafeBufferPointer(start: vptr, count: m.vertex_count * 6))
        let indices = Array(UnsafeBufferPointer(start: iptr, count: m.index_count))
        return StepMeshData(interleaved: interleaved, indices: indices, vertexCount: m.vertex_count)
    }
}

/// Renders a tessellated STEP mesh as a flat-shaded isometric bitmap — used for
/// Finder thumbnails and as the still fallback when SceneKit isn't available
/// (MAS-157). Painter's algorithm, soft directional light, dark-on-white.
public func renderStepMeshToImage(_ mesh: StepMeshData, size: CGSize) -> CGImage? {
    let triCount = mesh.indices.count / 3
    guard triCount > 0 else { return nil }
    let w = Int(size.width), h = Int(size.height)
    guard w > 0, h > 0,
          let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
    ctx.fill(CGRect(origin: .zero, size: size))

    let v = mesh.interleaved
    func pos(_ i: Int) -> (Double, Double, Double) {
        let b = i * 6; return (Double(v[b]), Double(v[b+1]), Double(v[b+2]))
    }
    let c30 = cos(Double.pi / 6), s30 = sin(Double.pi / 6)
    func iso(_ p: (Double, Double, Double)) -> (Double, Double) {
        ((p.0 - p.1) * c30, (p.0 + p.1) * s30 - p.2)
    }

    // Bounds in iso space.
    var minX = Double.greatestFiniteMagnitude, minY = Double.greatestFiniteMagnitude
    var maxX = -Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
    for vi in 0..<mesh.vertexCount {
        let s = iso(pos(vi))
        minX = min(minX, s.0); maxX = max(maxX, s.0)
        minY = min(minY, s.1); maxY = max(maxY, s.1)
    }
    let span = max(max(maxX - minX, maxY - minY), 1e-6)
    let margin = 0.08 * min(size.width, size.height)
    let scale = (min(size.width, size.height) - 2 * margin) / span
    let ox = size.width / 2 - (minX + maxX) / 2 * scale
    let oy = size.height / 2 + (minY + maxY) / 2 * scale

    // Painter's algorithm: sort triangles back-to-front along the view diagonal.
    var order = Array(0..<triCount)
    func depth(_ t: Int) -> Double {
        let a = Int(mesh.indices[t*3]), b = Int(mesh.indices[t*3+1]), c = Int(mesh.indices[t*3+2])
        let pa = pos(a), pb = pos(b), pc = pos(c)
        return (pa.0+pb.0+pc.0) + (pa.1+pb.1+pc.1) + (pa.2+pb.2+pc.2)
    }
    order.sort { depth($0) < depth($1) }

    let lx = 0.3, ly = 0.4, lz = 0.85
    let ll = (lx*lx + ly*ly + lz*lz).squareRoot()
    for t in order {
        let ia = Int(mesh.indices[t*3]), ib = Int(mesh.indices[t*3+1]), ic = Int(mesh.indices[t*3+2])
        let a = pos(ia), b = pos(ib), c = pos(ic)
        // Face normal for flat shading.
        let ux = b.0-a.0, uy = b.1-a.1, uz = b.2-a.2
        let wx = c.0-a.0, wy = c.1-a.1, wz = c.2-a.2
        var nx = uy*wz - uz*wy, ny = uz*wx - ux*wz, nz = ux*wy - uy*wx
        let nl = (nx*nx + ny*ny + nz*nz).squareRoot()
        if nl > 0 { nx /= nl; ny /= nl; nz /= nl }
        let shade = abs((nx*lx + ny*ly + nz*lz) / ll)
        let g = CGFloat(0.30 + shade * 0.62)
        ctx.setFillColor(CGColor(red: g, green: g, blue: min(1.0, g + 0.03), alpha: 1.0))
        let pa = iso(a), pb = iso(b), pc = iso(c)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: ox + pa.0 * scale, y: oy - pa.1 * scale))
        ctx.addLine(to: CGPoint(x: ox + pb.0 * scale, y: oy - pb.1 * scale))
        ctx.addLine(to: CGPoint(x: ox + pc.0 * scale, y: oy - pc.1 * scale))
        ctx.closePath()
        ctx.fillPath()
    }
    return ctx.makeImage()
}

/// Reads every CARTESIAN_POINT from a STEP file as a 3D point cloud, for the
/// interactive SceneKit preview (MAS-124). Returns model-space coordinates;
/// the view controller handles centering/scaling.
public func parseStepPointCloud(url: URL) -> [SIMD3<Float>] {
    guard let text = try? String(contentsOf: url, encoding: .utf8) ?? String(contentsOf: url, encoding: .isoLatin1) else {
        return []
    }
    return parseStepCartesianPoints(text).map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
}

/// Lightweight STEP (.step/.stp) preview for QuickLook (MAS-63). A full B-rep
/// tessellation needs OpenCASCADE, which can't run inside a QuickLook app
/// extension. Instead we parse the ISO-10303-21 text for every CARTESIAN_POINT
/// and render an isometric point cloud — fast, allocation-light, and enough to
/// recognize the part at a glance. Dark points on white, aspect-fit to `size`.
func renderStepToImage(url: URL, size: CGSize) -> CGImage? {
    guard let text = try? String(contentsOf: url, encoding: .utf8) ?? String(contentsOf: url, encoding: .isoLatin1) else {
        return nil
    }

    let points = parseStepCartesianPoints(text)
    guard points.count >= 2 else { return nil }

    // Isometric projection of each 3D point to 2D.
    let c30 = cos(Double.pi / 6), s30 = sin(Double.pi / 6)
    var projected: [(x: Double, y: Double)] = []
    projected.reserveCapacity(points.count)
    for p in points {
        let sx = (p.x - p.y) * c30
        let sy = (p.x + p.y) * s30 - p.z
        projected.append((sx, sy))
    }
    // Frame on robust (percentile) bounds so a few stray reference/origin points
    // in the STEP file don't blow up the extent and shrink the real part into a
    // corner (the old min/max framing did exactly that) — MAS-157.
    let (minX, maxX) = robustRange(projected.map { $0.x })
    let (minY, maxY) = robustRange(projected.map { $0.y })

    let w = Int(size.width), h = Int(size.height)
    guard w > 0, h > 0,
          let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

    let spanX = max(maxX - minX, 1e-6), spanY = max(maxY - minY, 1e-6)
    let margin = 0.1 * min(size.width, size.height)
    let scale = min((size.width - 2 * margin) / spanX, (size.height - 2 * margin) / spanY)
    let offX = (size.width - spanX * scale) / 2.0
    let offY = (size.height - spanY * scale) / 2.0

    ctx.setFillColor(CGColor(red: 0.12, green: 0.14, blue: 0.2, alpha: 0.95))
    // Larger dots so a sparse control-point cloud still reads as a solid form.
    let r: CGFloat = max(2.0, CGFloat(min(w, h)) / 260.0)
    for pt in projected {
        let px = offX + (pt.x - minX) * scale
        let py = offY + (pt.y - minY) * scale
        ctx.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
    }

    return ctx.makeImage()
}

/// Robust [min, max] of `values` using the 2nd–98th percentile, so a handful of
/// outlier coordinates (stray origin/reference points common in STEP files)
/// don't dominate the framing (MAS-157). Falls back to the true range when there
/// are too few points to clip.
private func robustRange(_ values: [Double]) -> (Double, Double) {
    guard values.count >= 12 else {
        return (values.min() ?? 0, values.max() ?? 1)
    }
    let sorted = values.sorted()
    let lo = sorted[Int(0.02 * Double(sorted.count - 1))]
    let hi = sorted[Int(0.98 * Double(sorted.count - 1))]
    return hi > lo ? (lo, hi) : (sorted.first!, sorted.last!)
}

/// Extracts the (x, y, z) of every CARTESIAN_POINT in a STEP file. Tolerant of
/// scientific notation, whitespace, and the leading label string.
private func parseStepCartesianPoints(_ text: String) -> [(x: Double, y: Double, z: Double)] {
    var result: [(Double, Double, Double)] = []
    // Match: CARTESIAN_POINT ( 'label' , ( 1.0, 2.0, 3.0 ) )
    let pattern = "CARTESIAN_POINT\\s*\\(\\s*'[^']*'\\s*,\\s*\\(([^)]*)\\)"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return result
    }
    let ns = text as NSString
    regex.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
        guard let match = match, match.numberOfRanges >= 2 else { return }
        let nums = ns.substring(with: match.range(at: 1))
        let parts = nums.split(separator: ",").map {
            Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
        }
        // Only keep true 3D model points. 2-coordinate CARTESIAN_POINTs are
        // surface parameter-space (pcurve) points living in an unrelated
        // coordinate range; including them as (x, y, 0) dumped a sheet of noise at
        // z = 0 over the part and made the STEP preview unreadable (MAS-155).
        if parts.count >= 3 {
            result.append((parts[0], parts[1], parts[2]))
        }
    }
    return result
}
