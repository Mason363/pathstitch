import Foundation
import Observation

/// One primitive a hardware part cuts into the leather, in the part's local frame
/// (mm), relative to its placement point. A `hole` is a drilled post hole; a `slot`
/// is a rounded stadium (e.g. a magnetic-snap prong). Decoded straight from
/// `hardware.json`; the optional fields are per-kind so missing keys are fine.
struct FootprintPrimitive: Codable, Equatable {
    var kind: String        // "hole" | "slot"
    var dx: Double
    var dy: Double
    var dia: Double?        // hole diameter
    var length: Double?     // slot length (end-to-end)
    var width: Double?      // slot width (across)
    var angle: Double?      // slot rotation in the local frame (degrees)

    /// JSON-able dict for `dxf_ops.place_hardware`.
    var payload: [String: Any] {
        var d: [String: Any] = ["kind": kind, "dx": dx, "dy": dy]
        if let v = dia { d["dia"] = v }
        if let v = length { d["length"] = v }
        if let v = width { d["width"] = v }
        if let v = angle { d["angle"] = v }
        return d
    }
}

/// A parametric hardware part: the footprint it stamps (Phase 2), its clamp range
/// (post length vs. stacked thickness → "will it close" validation), the keep-out
/// clearance its cap occupies, and the part-number / vendor for the eventual BOM.
/// `capDiameterMm` is the visible cap size, kept for the future 3D mockup.
struct HardwareItem: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var category: String        // Snaps | Rivets | Closures | Eyelets | …
    var partNumber: String
    var vendor: String
    var footprint: [FootprintPrimitive]
    var clampMinMm: Double
    var clampMaxMm: Double
    var clearanceMm: Double      // keep-out radius around the part (cap + margin)
    var capDiameterMm: Double    // visible cap (for the 3D mockup, later)
    var builtin: Bool

    init(id: String, name: String, category: String, partNumber: String, vendor: String,
         footprint: [FootprintPrimitive], clampMinMm: Double, clampMaxMm: Double,
         clearanceMm: Double, capDiameterMm: Double, builtin: Bool = false) {
        self.id = id; self.name = name; self.category = category
        self.partNumber = partNumber; self.vendor = vendor; self.footprint = footprint
        self.clampMinMm = clampMinMm; self.clampMaxMm = clampMaxMm
        self.clearanceMm = clearanceMm; self.capDiameterMm = capDiameterMm
        self.builtin = builtin
    }

    /// "0.8–2.5 mm stack" — the closable thickness range.
    var clampLabel: String { String(format: "%.1f–%.1f mm stack", clampMinMm, clampMaxMm) }

    /// True when a stacked thickness `stackMm` is inside this part's clamp range —
    /// i.e. the post is long enough to seat and short enough to close.
    func clampFits(_ stackMm: Double) -> Bool {
        stackMm >= clampMinMm - 1e-6 && stackMm <= clampMaxMm + 1e-6
    }

    /// The footprint as JSON-able dicts for `dxf_ops.place_hardware`.
    var footprintPayload: [[String: Any]] { footprint.map { $0.payload } }
}

private struct HardwareFile: Codable {
    var version: Int
    var hardware: [HardwareItem]
}

/// Loads the built-in hardware catalog (bundled `hardware.json`, with a compiled
/// fallback) and merges user parts saved to Application Support. Mirrors
/// `PrickingIronStore` / `LeatherStore`.
@Observable
final class HardwareStore {
    static let shared = HardwareStore()

    private(set) var builtins: [HardwareItem] = []
    private(set) var userItems: [HardwareItem] = []

    var all: [HardwareItem] { builtins + userItems }

    private init() {
        builtins = Self.loadBuiltins()
        userItems = Self.loadUserItems()
    }

    func item(id: String) -> HardwareItem? { all.first { $0.id == id } }

    /// Categories in first-seen order (matches the JSON ordering).
    var categories: [String] {
        var seen = Set<String>(); var out: [String] = []
        for h in all where !seen.contains(h.category) { seen.insert(h.category); out.append(h.category) }
        return out
    }

    func items(in category: String) -> [HardwareItem] { all.filter { $0.category == category } }

    /// Add or replace a user part and persist. Built-ins are never modified.
    func save(_ item: HardwareItem) {
        var copy = item
        copy.builtin = false
        if let idx = userItems.firstIndex(where: { $0.id == copy.id }) {
            userItems[idx] = copy
        } else {
            userItems.append(copy)
        }
        persist()
    }

    func delete(id: String) {
        userItems.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Persistence

    private static func appSupportURL() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("Pathstitch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hardware.json")
    }

    private static func loadBuiltins() -> [HardwareItem] {
        if let url = Bundle.main.url(forResource: "hardware", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(HardwareFile.self, from: data),
           !file.hardware.isEmpty {
            return file.hardware.map { var h = $0; h.builtin = true; return h }
        }
        return embeddedDefaults
    }

    private static func loadUserItems() -> [HardwareItem] {
        guard let url = appSupportURL(), let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(HardwareFile.self, from: data)
        else { return [] }
        return file.hardware.map { var h = $0; h.builtin = false; return h }
    }

    private func persist() {
        guard let url = Self.appSupportURL() else { return }
        let file = HardwareFile(version: 1, hardware: userItems)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Compiled-in fallback so the catalog is never empty even if the bundled JSON
    /// is missing. Mirrors `hardware.json`.
    static let embeddedDefaults: [HardwareItem] = [
        HardwareItem(id: "snap-line20", name: "Line 20 Snap", category: "Snaps", partNumber: "Line 20", vendor: "Generic", footprint: [FootprintPrimitive(kind: "hole", dx: 0, dy: 0, dia: 4.0)], clampMinMm: 0.8, clampMaxMm: 2.5, clearanceMm: 8.0, capDiameterMm: 12.5, builtin: true),
        HardwareItem(id: "snap-line24", name: "Line 24 Snap", category: "Snaps", partNumber: "Line 24", vendor: "Generic", footprint: [FootprintPrimitive(kind: "hole", dx: 0, dy: 0, dia: 4.0)], clampMinMm: 1.0, clampMaxMm: 3.0, clearanceMm: 9.0, capDiameterMm: 15.0, builtin: true),
        HardwareItem(id: "rivet-dc-7", name: "Double-Cap Rivet 7 mm", category: "Rivets", partNumber: "DCR-7", vendor: "Generic", footprint: [FootprintPrimitive(kind: "hole", dx: 0, dy: 0, dia: 3.0)], clampMinMm: 1.5, clampMaxMm: 4.5, clearanceMm: 5.0, capDiameterMm: 7.0, builtin: true),
        HardwareItem(id: "rivet-dc-9", name: "Double-Cap Rivet 9 mm", category: "Rivets", partNumber: "DCR-9", vendor: "Generic", footprint: [FootprintPrimitive(kind: "hole", dx: 0, dy: 0, dia: 4.0)], clampMinMm: 3.0, clampMaxMm: 6.5, clearanceMm: 6.0, capDiameterMm: 9.0, builtin: true),
        HardwareItem(id: "chicago-screw", name: "Chicago Screw", category: "Rivets", partNumber: "CS-standard", vendor: "Generic", footprint: [FootprintPrimitive(kind: "hole", dx: 0, dy: 0, dia: 4.0)], clampMinMm: 3.0, clampMaxMm: 9.0, clearanceMm: 6.0, capDiameterMm: 10.0, builtin: true),
        HardwareItem(id: "magsnap-18", name: "Magnetic Snap 18 mm", category: "Closures", partNumber: "MS-18", vendor: "Generic", footprint: [FootprintPrimitive(kind: "slot", dx: -6.5, dy: 0, length: 5.0, width: 1.2, angle: 90.0), FootprintPrimitive(kind: "slot", dx: 6.5, dy: 0, length: 5.0, width: 1.2, angle: 90.0)], clampMinMm: 1.0, clampMaxMm: 3.0, clearanceMm: 12.0, capDiameterMm: 18.0, builtin: true),
        HardwareItem(id: "eyelet-6", name: "Eyelet 6 mm", category: "Eyelets", partNumber: "EY-6", vendor: "Generic", footprint: [FootprintPrimitive(kind: "hole", dx: 0, dy: 0, dia: 6.0)], clampMinMm: 0.8, clampMaxMm: 3.0, clearanceMm: 5.0, capDiameterMm: 11.0, builtin: true),
    ]
}
