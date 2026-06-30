import Foundation
import Observation

/// One leather (or leather-like sheet material) with the *physical* properties the
/// assembly workflow reasons about — not just a render tint. `thicknessMm` (with
/// `thicknessOz`, 1 oz ≈ 0.4 mm) and `kFactor` drive the sheet-metal bend
/// allowance (`construct_ops.fold_metrics`); `minBendRadiusMm` is the fold-radius
/// DFM threshold (crease tighter than this and the grain may crack); `temper` /
/// `bendingStiffness` describe how stiffly it holds a fold; `stretchPct` and the
/// burnishable / moldable / paintable flags carry the rest of the maker's intent.
struct LeatherMaterial: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var category: String        // Veg-Tan | Chrome-Tan | Bridle | Lining | …
    var thicknessOz: Double
    var thicknessMm: Double
    var temper: String          // firm | medium | soft
    var bendingStiffness: Double // 0 floppy … 1 board-stiff (relative)
    var minBendRadiusMm: Double  // tightest inside fold radius before grain damage
    var kFactor: Double          // neutral-axis position, 0…0.5
    var stretchPct: Double       // give under tension (anisotropy hint)
    var burnishable: Bool
    var moldable: Bool
    var paintable: Bool
    var colorHex: String         // default mockup tint
    var builtin: Bool

    init(id: String, name: String, category: String, thicknessOz: Double, thicknessMm: Double,
         temper: String, bendingStiffness: Double, minBendRadiusMm: Double, kFactor: Double,
         stretchPct: Double, burnishable: Bool, moldable: Bool, paintable: Bool,
         colorHex: String, builtin: Bool = false) {
        self.id = id; self.name = name; self.category = category
        self.thicknessOz = thicknessOz; self.thicknessMm = thicknessMm
        self.temper = temper; self.bendingStiffness = bendingStiffness
        self.minBendRadiusMm = minBendRadiusMm; self.kFactor = kFactor
        self.stretchPct = stretchPct; self.burnishable = burnishable
        self.moldable = moldable; self.paintable = paintable
        self.colorHex = colorHex; self.builtin = builtin
    }

    /// "4–5 oz · 1.8 mm · firm" — the one-line summary shown under the picker.
    var summary: String {
        String(format: "%.1f oz · %.1f mm · %@", thicknessOz, thicknessMm, temper)
    }
}

private struct LeatherFile: Codable {
    var version: Int
    var leathers: [LeatherMaterial]
}

/// Loads the built-in leather catalog (bundled `leathers.json`, with a compiled
/// fallback so the app never ships without materials) and merges user materials
/// saved to Application Support. New / edited / deleted user leathers round-trip
/// to disk. Mirrors `PrickingIronStore`.
@Observable
final class LeatherStore {
    static let shared = LeatherStore()

    private(set) var builtins: [LeatherMaterial] = []
    private(set) var userMaterials: [LeatherMaterial] = []

    var all: [LeatherMaterial] { builtins + userMaterials }

    private init() {
        builtins = Self.loadBuiltins()
        userMaterials = Self.loadUserMaterials()
    }

    func material(id: String) -> LeatherMaterial? { all.first { $0.id == id } }

    /// Add or replace a user leather and persist. Built-ins are never modified.
    func save(_ material: LeatherMaterial) {
        var copy = material
        copy.builtin = false
        if let idx = userMaterials.firstIndex(where: { $0.id == copy.id }) {
            userMaterials[idx] = copy
        } else {
            userMaterials.append(copy)
        }
        persist()
    }

    func delete(id: String) {
        userMaterials.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Persistence

    private static func appSupportURL() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("Pathstitch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("leathers.json")
    }

    private static func loadBuiltins() -> [LeatherMaterial] {
        if let url = Bundle.main.url(forResource: "leathers", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(LeatherFile.self, from: data),
           !file.leathers.isEmpty {
            return file.leathers.map { var m = $0; m.builtin = true; return m }
        }
        return embeddedDefaults
    }

    private static func loadUserMaterials() -> [LeatherMaterial] {
        guard let url = appSupportURL(), let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(LeatherFile.self, from: data)
        else { return [] }
        return file.leathers.map { var m = $0; m.builtin = false; return m }
    }

    private func persist() {
        guard let url = Self.appSupportURL() else { return }
        let file = LeatherFile(version: 1, leathers: userMaterials)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Compiled-in fallback so the material library is never empty even if the
    /// bundled JSON is missing. Mirrors `leathers.json`.
    static let embeddedDefaults: [LeatherMaterial] = [
        LeatherMaterial(id: "vt-2-3oz", name: "Veg-Tan 2–3 oz", category: "Veg-Tan", thicknessOz: 2.5, thicknessMm: 1.0, temper: "medium", bendingStiffness: 0.30, minBendRadiusMm: 0.5, kFactor: 0.44, stretchPct: 3.0, burnishable: true, moldable: true, paintable: true, colorHex: "C9A36A", builtin: true),
        LeatherMaterial(id: "vt-4-5oz", name: "Veg-Tan 4–5 oz", category: "Veg-Tan", thicknessOz: 4.5, thicknessMm: 1.8, temper: "firm", bendingStiffness: 0.55, minBendRadiusMm: 1.4, kFactor: 0.42, stretchPct: 2.5, burnishable: true, moldable: true, paintable: true, colorHex: "8A5A2B", builtin: true),
        LeatherMaterial(id: "vt-6-7oz", name: "Veg-Tan 6–7 oz", category: "Veg-Tan", thicknessOz: 6.5, thicknessMm: 2.6, temper: "firm", bendingStiffness: 0.72, minBendRadiusMm: 2.1, kFactor: 0.40, stretchPct: 2.0, burnishable: true, moldable: true, paintable: true, colorHex: "7A4A22", builtin: true),
        LeatherMaterial(id: "vt-8-9oz", name: "Veg-Tan 8–9 oz", category: "Veg-Tan", thicknessOz: 8.5, thicknessMm: 3.4, temper: "firm", bendingStiffness: 0.88, minBendRadiusMm: 2.8, kFactor: 0.40, stretchPct: 1.5, burnishable: true, moldable: true, paintable: true, colorHex: "6E4220", builtin: true),
        LeatherMaterial(id: "bridle-5-6oz", name: "Bridle 5–6 oz", category: "Bridle", thicknessOz: 5.5, thicknessMm: 2.2, temper: "firm", bendingStiffness: 0.68, minBendRadiusMm: 1.8, kFactor: 0.41, stretchPct: 1.5, burnishable: true, moldable: false, paintable: false, colorHex: "4A2F1B", builtin: true),
        LeatherMaterial(id: "ct-3-4oz", name: "Chrome-Tan 3–4 oz", category: "Chrome-Tan", thicknessOz: 3.5, thicknessMm: 1.4, temper: "soft", bendingStiffness: 0.25, minBendRadiusMm: 0.5, kFactor: 0.45, stretchPct: 6.0, burnishable: false, moldable: false, paintable: true, colorHex: "3A2418", builtin: true),
        LeatherMaterial(id: "ct-garment", name: "Chrome-Tan Garment", category: "Chrome-Tan", thicknessOz: 2.0, thicknessMm: 0.8, temper: "soft", bendingStiffness: 0.12, minBendRadiusMm: 0.3, kFactor: 0.46, stretchPct: 8.0, burnishable: false, moldable: false, paintable: true, colorHex: "1C1C1E", builtin: true),
        LeatherMaterial(id: "lining-pig", name: "Pig Suede Lining", category: "Lining", thicknessOz: 1.5, thicknessMm: 0.6, temper: "soft", bendingStiffness: 0.08, minBendRadiusMm: 0.2, kFactor: 0.47, stretchPct: 7.0, burnishable: false, moldable: false, paintable: false, colorHex: "C9A36A", builtin: true),
    ]
}
