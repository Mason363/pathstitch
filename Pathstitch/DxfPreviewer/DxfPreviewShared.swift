import Foundation
import CoreGraphics
import ZIPFoundation

// MARK: - Parsed geometry

public enum PreviewEntity {
    case line(start: CGPoint, end: CGPoint)
    case circle(center: CGPoint, radius: CGFloat)
    case arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat)
    case polyline(points: [CGPoint], closed: Bool)
}

public struct DXFParser {
    public static func parse(url: URL) -> [PreviewEntity] {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            return parse(content: content)
        }
        if let content = try? String(contentsOf: url, encoding: .ascii) {
            return parse(content: content)
        }
        if let data = try? Data(contentsOf: url),
           let content = String(data: data, encoding: .ascii) {
            return parse(content: content)
        }
        return []
    }

    public static func parse(content: String) -> [PreviewEntity] {
        var entities: [PreviewEntity] = []

        var lines: [Substring] = []
        content.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                lines.append(Substring(trimmed))
            }
        }

        var pairs: [(code: Int, value: Substring)] = []
        pairs.reserveCapacity(lines.count / 2)

        var i = 0
        while i < lines.count - 1 {
            let line1 = lines[i]
            let line2 = lines[i+1]
            if let code = Int(line1) {
                pairs.append((code: code, value: line2))
            }
            i += 2
        }

        var index = 0
        let count = pairs.count

        while index < count {
            let pair = pairs[index]
            if pair.code == 0 {
                let entType = pair.value.uppercased()
                index += 1

                var props: [Int: Substring] = [:]
                while index < count && pairs[index].code != 0 {
                    let p = pairs[index]
                    props[p.code] = p.value
                    index += 1
                }

                switch entType {
                case "LINE":
                    if let x1Str = props[10], let y1Str = props[20],
                       let x2Str = props[11], let y2Str = props[21],
                       let x1 = Double(x1Str), let y1 = Double(y1Str),
                       let x2 = Double(x2Str), let y2 = Double(y2Str) {
                        // Ignore degenerate/zero-length line
                        if abs(x1 - x2) > 1e-5 || abs(y1 - y2) > 1e-5 {
                            entities.append(.line(start: CGPoint(x: x1, y: y1), end: CGPoint(x: x2, y: y2)))
                        }
                    }
                case "CIRCLE":
                    if let cxStr = props[10], let cyStr = props[20], let rStr = props[40],
                       let cx = Double(cxStr), let cy = Double(cyStr), let r = Double(rStr) {
                        if r > 1e-5 {
                            entities.append(.circle(center: CGPoint(x: cx, y: cy), radius: CGFloat(r)))
                        }
                    }
                case "ARC":
                    if let cxStr = props[10], let cyStr = props[20], let rStr = props[40],
                       let startStr = props[50], let endStr = props[51],
                       let cx = Double(cxStr), let cy = Double(cyStr), let r = Double(rStr),
                       let startAngle = Double(startStr), let endAngle = Double(endStr) {
                        if r > 1e-5 {
                            entities.append(.arc(center: CGPoint(x: cx, y: cy), radius: CGFloat(r),
                                                 startAngle: CGFloat(startAngle), endAngle: CGFloat(endAngle)))
                        }
                    }
                case "LWPOLYLINE":
                    var pts: [CGPoint] = []
                    var closedFlag = 0
                    if let cfStr = props[70], let cf = Int(cfStr) {
                        closedFlag = cf
                    }
                    let isClosed = (closedFlag & 1) != 0

                    var entIndex = index - props.count - 1
                    while entIndex < index {
                        let p = pairs[entIndex]
                        if p.code == 10 {
                            var yVal: Double? = nil
                            var scanIndex = entIndex + 1
                            while scanIndex < index {
                                if pairs[scanIndex].code == 20 {
                                    yVal = Double(pairs[scanIndex].value)
                                    break
                                } else if pairs[scanIndex].code == 10 || pairs[scanIndex].code == 0 {
                                    break
                                }
                                scanIndex += 1
                            }
                            if let xVal = Double(p.value), let yVal = yVal {
                                pts.append(CGPoint(x: xVal, y: yVal))
                            }
                        }
                        entIndex += 1
                    }
                    if !pts.isEmpty {
                        // Check if degenerate (all points identical)
                        let first = pts[0]
                        let isDegenerate = pts.allSatisfy { abs($0.x - first.x) < 1e-5 && abs($0.y - first.y) < 1e-5 }
                        if !isDegenerate {
                            entities.append(.polyline(points: pts, closed: isClosed))
                        }
                    }
                case "POLYLINE":
                    var pts: [CGPoint] = []
                    var closedFlag = 0
                    if let cfStr = props[70], let cf = Int(cfStr) {
                        closedFlag = cf
                    }
                    let isClosed = (closedFlag & 1) != 0

                    while index < count {
                        let subPair = pairs[index]
                        if subPair.code == 0 {
                            let subType = subPair.value.uppercased()
                            if subType == "SEQEND" {
                                index += 1
                                break
                            } else if subType == "VERTEX" {
                                index += 1
                                var vProps: [Int: Substring] = [:]
                                while index < count && pairs[index].code != 0 {
                                    let vp = pairs[index]
                                    vProps[vp.code] = vp.value
                                    index += 1
                                }
                                if let vxStr = vProps[10], let vyStr = vProps[20],
                                   let vx = Double(vxStr), let vy = Double(vyStr) {
                                    pts.append(CGPoint(x: vx, y: vy))
                                }
                            } else {
                                break
                            }
                        } else {
                            index += 1
                        }
                    }
                    if !pts.isEmpty {
                        // Check if degenerate (all points identical)
                        let first = pts[0]
                        let isDegenerate = pts.allSatisfy { abs($0.x - first.x) < 1e-5 && abs($0.y - first.y) < 1e-5 }
                        if !isDegenerate {
                            entities.append(.polyline(points: pts, closed: isClosed))
                        }
                    }
                case "SPLINE":
                    var pts: [CGPoint] = []
                    var entIndex = index - props.count - 1
                    while entIndex < index {
                        let p = pairs[entIndex]
                        if p.code == 10 {
                            var yVal: Double? = nil
                            var scanIndex = entIndex + 1
                            while scanIndex < index {
                                if pairs[scanIndex].code == 20 {
                                    yVal = Double(pairs[scanIndex].value)
                                    break
                                } else if pairs[scanIndex].code == 10 || pairs[scanIndex].code == 0 {
                                    break
                                }
                                scanIndex += 1
                            }
                            if let xVal = Double(p.value), let yVal = yVal {
                                pts.append(CGPoint(x: xVal, y: yVal))
                            }
                        }
                        entIndex += 1
                    }
                    // If control points are empty, try fit points (11/21)
                    if pts.isEmpty {
                        entIndex = index - props.count - 1
                        while entIndex < index {
                            let p = pairs[entIndex]
                            if p.code == 11 {
                                var yVal: Double? = nil
                                var scanIndex = entIndex + 1
                                while scanIndex < index {
                                    if pairs[scanIndex].code == 21 {
                                        yVal = Double(pairs[scanIndex].value)
                                        break
                                    } else if pairs[scanIndex].code == 11 || pairs[scanIndex].code == 0 {
                                        break
                                    }
                                    scanIndex += 1
                                }
                                if let xVal = Double(p.value), let yVal = yVal {
                                    pts.append(CGPoint(x: xVal, y: yVal))
                                }
                            }
                            entIndex += 1
                        }
                    }
                    if !pts.isEmpty {
                        // Check if degenerate (all points identical)
                        let first = pts[0]
                        let isDegenerate = pts.allSatisfy { abs($0.x - first.x) < 1e-5 && abs($0.y - first.y) < 1e-5 }
                        if !isDegenerate {
                            var isClosed = false
                            if let flagsStr = props[70], let flags = Int(flagsStr) {
                                isClosed = (flags & 1) != 0
                            }
                            entities.append(.polyline(points: pts, closed: isClosed))
                        }
                    }
                case "ELLIPSE":
                    if let cxStr = props[10], let cyStr = props[20],
                       let mxStr = props[11], let myStr = props[21],
                       let ratioStr = props[40],
                       let cx = Double(cxStr), let cy = Double(cyStr),
                       let mx = Double(mxStr), let my = Double(myStr),
                       let ratio = Double(ratioStr) {

                        let startParam = Double(props[41] ?? "0.0") ?? 0.0
                        let endParam = Double(props[42] ?? "6.283185307179586") ?? 6.283185307179586

                        let rMajor = hypot(mx, my)
                        if rMajor > 1e-5 {
                            let ux = mx / rMajor
                            let uy = my / rMajor

                            let wx = -uy
                            let wy = ux
                            let rMinor = ratio * rMajor

                            var pts: [CGPoint] = []
                            let steps = 36
                            for step in 0...steps {
                                let t = startParam + (Double(step) / Double(steps)) * (endParam - startParam)
                                let px = cx + rMajor * cos(t) * ux + rMinor * sin(t) * wx
                                let py = cy + rMajor * cos(t) * uy + rMinor * sin(t) * wy
                                pts.append(CGPoint(x: px, y: py))
                            }

                            let isClosed = abs(endParam - startParam - 2.0 * .pi) < 0.05
                            entities.append(.polyline(points: pts, closed: isClosed))
                        }
                    }
                case "POINT":
                    // Standalone point entities are deliberately ignored in bounds framing
                    break
                default:
                    break
                }
            } else {
                index += 1
            }
        }

        return entities
    }
}

// MARK: - Loading from .dxf / .stch

/// A `.stch` project bundle is a ZIP holding `project.json` (with the working DXF
/// as base64) plus a pre-rendered `preview.png`. We prefer the embedded PNG: it
/// was rendered by the app with layer-visibility honoured, so hidden geometry is
/// already excluded — something we can't know from the raw DXF alone.
public func stchEmbeddedPreview(url: URL) -> CGImage? {
    guard let archive = Archive(url: url, accessMode: .read),
          let entry = archive["preview.png"] else { return nil }
    var data = Data()
    do {
        _ = try archive.extract(entry) { data.append($0) }
    } catch {
        return nil
    }
    guard let provider = CGDataProvider(data: data as CFData) else { return nil }
    return CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
}

/// Extracts the working DXF text embedded in a `.stch` bundle (fallback path when
/// the bundle predates embedded previews).
public func stchEmbeddedDXF(url: URL) -> [PreviewEntity] {
    guard let archive = Archive(url: url, accessMode: .read),
          let entry = archive["project.json"] else { return [] }
    var data = Data()
    do {
        _ = try archive.extract(entry) { data.append($0) }
    } catch {
        return []
    }
    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let b64 = obj["dxfDataBase64"] as? String,
          let dxfData = Data(base64Encoded: b64) else { return [] }
    let content = String(data: dxfData, encoding: .utf8) ?? String(data: dxfData, encoding: .ascii)
    guard let content else { return [] }
    return DXFParser.parse(content: content)
}

// MARK: - Rendering

/// Renders a supported file (`.stch` or `.dxf`) to a framed black-on-white bitmap.
/// For `.stch`, returns the embedded preview verbatim when present (it is already
/// framed); otherwise falls back to rendering the embedded/standalone DXF.
public func renderFileToImage(url: URL, size: CGSize) -> CGImage? {
    if url.pathExtension.lowercased() == "stch" {
        if let embedded = stchEmbeddedPreview(url: url) {
            return embedded
        }
        return renderEntitiesToImage(stchEmbeddedDXF(url: url), size: size)
    }
    return renderEntitiesToImage(DXFParser.parse(url: url), size: size)
}

/// Rasterises parsed entities centred and scaled-to-fit with a small margin —
/// black line art on opaque white, sized to fill with minimal blank space.
public func renderEntitiesToImage(_ entities: [PreviewEntity], size: CGSize) -> CGImage? {
    let width = Int(size.width)
    let height = Int(size.height)
    guard width > 0, height > 0,
          let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else { return nil }

    ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
    ctx.fill(CGRect(origin: .zero, size: size))

    guard !entities.isEmpty else { return ctx.makeImage() }

    var minX = Double.infinity, minY = Double.infinity
    var maxX = -Double.infinity, maxY = -Double.infinity
    func acc(_ x: CGFloat, _ y: CGFloat) {
        minX = min(minX, Double(x)); maxX = max(maxX, Double(x))
        minY = min(minY, Double(y)); maxY = max(maxY, Double(y))
    }
    for e in entities {
        switch e {
        case .line(let s, let en): acc(s.x, s.y); acc(en.x, en.y)
        case .circle(let c, let r): acc(c.x - r, c.y - r); acc(c.x + r, c.y + r)
        case .arc(let c, let r, _, _): acc(c.x - r, c.y - r); acc(c.x + r, c.y + r)
        case .polyline(let pts, _): for p in pts { acc(p.x, p.y) }
        }
    }
    guard minX.isFinite, maxX >= minX, maxY >= minY else { return ctx.makeImage() }

    let bw = max(maxX - minX, 1e-6)
    let bh = max(maxY - minY, 1e-6)
    let bounds = CGRect(x: minX, y: minY, width: bw, height: bh)

    // Tight margin (≈6%, min 8pt) so geometry fills the frame, adapting to bounds.
    let margin = max(min(size.width, size.height) * 0.06, 8.0)
    let fitW = size.width - margin * 2
    let fitH = size.height - margin * 2
    let scale = min(fitW / bounds.width, fitH / bounds.height)
    let offsetX = size.width / 2 - bounds.midX * scale
    let offsetY = size.height / 2 - bounds.midY * scale

    ctx.saveGState()
    ctx.translateBy(x: offsetX, y: offsetY)
    ctx.scaleBy(x: scale, y: scale)
    ctx.setStrokeColor(CGColor(gray: 0.0, alpha: 1.0))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    // Counteract the scale so strokes land at a consistent on-screen weight.
    let onScreenWidth = max(1.5, min(size.width, size.height) / 240.0)
    ctx.setLineWidth(onScreenWidth / scale)

    for e in entities {
        switch e {
        case .line(let s, let en):
            ctx.beginPath(); ctx.move(to: s); ctx.addLine(to: en); ctx.strokePath()
        case .circle(let c, let r):
            ctx.beginPath()
            ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.strokePath()
        case .arc(let c, let r, let sa, let ea):
            ctx.beginPath()
            ctx.addArc(center: c, radius: r,
                       startAngle: sa * .pi / 180.0, endAngle: ea * .pi / 180.0,
                       clockwise: false)
            ctx.strokePath()
        case .polyline(let pts, let closed):
            guard !pts.isEmpty else { continue }
            ctx.beginPath(); ctx.move(to: pts[0])
            for p in pts.dropFirst() { ctx.addLine(to: p) }
            if closed { ctx.closePath() }
            ctx.strokePath()
        }
    }
    ctx.restoreGState()
    return ctx.makeImage()
}
