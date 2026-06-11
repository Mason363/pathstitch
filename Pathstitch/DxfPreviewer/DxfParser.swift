import Foundation
import CoreGraphics

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
