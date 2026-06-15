import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text("Pathstitch Documentation")
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.text_primary)

                Divider()
                    .background(Color.gray)

                // Overview
                Group {
                    sectionHeader("Overview")

                    Text("Pathstitch is a macOS CAD editor for turning shapes and 3D models into flat, sewable patterns. A typical workflow:")
                        .foregroundColor(.text_secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("Import a DXF, SVG, STEP, STL, PDF, or image — or start from a blank canvas.")
                        bulletPoint("Unfold 3D model faces into connected 2D nets (seam, crease, and tab lines included).")
                        bulletPoint("Add offset outlines, sewing holes, glue tabs, and measurements.")
                        bulletPoint("Export precise SVG and DXF for cutting, or batch many pieces at once.")
                    }
                }

                Divider().background(Color.gray)

                // Modes
                Group {
                    sectionHeader("Modes")

                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("2D — the main drawing and editing canvas. Tied to the 3D tab in the same project.")
                        bulletPoint("3D — import a model, select faces, and unfold them into the 2D canvas.")
                        bulletPoint("Batch — lay out and preview many pieces together; opens in its own window.")
                    }
                }

                Divider().background(Color.gray)

                // Tools
                Group {
                    sectionHeader("Tools")

                    Text("Pick a tool from the left toolbar or with its single-key shortcut:")
                        .foregroundColor(.text_secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        shortcutRow("V", "Select / move")
                        shortcutRow("H", "Pan tool")
                        shortcutRow("O", "Offset (expand / shrink an outline)")
                        shortcutRow("S", "Add sewing holes")
                        shortcutRow("J", "Clean up geometry")
                        shortcutRow("M", "Measure")
                        shortcutRow("L", "Draw line")
                        shortcutRow("C", "Draw circle")
                        shortcutRow("R", "Draw rectangle")
                        shortcutRow("T", "Add text")
                        shortcutRow("K", "Fillet corners (G1 / G2)")
                        shortcutRow("B", "Chamfer corners")
                        shortcutRow("F", "Paper folding / glue tabs")
                        shortcutRow("P", "Patterning")
                    }
                }

                Divider().background(Color.gray)

                // Navigation & view
                Group {
                    sectionHeader("Navigation & View")

                    VStack(alignment: .leading, spacing: 10) {
                        shortcutRow("Trackpad scroll", "Pan the 2D canvas")
                        shortcutRow("Pinch / CMD + scroll", "Zoom the 2D canvas")
                        shortcutRow("Right- or middle-drag", "Pan the 2D canvas")
                        shortcutRow("Home button", "Frame all geometry (optimal fit)")
                        shortcutRow("G", "Toggle the grid")
                        shortcutRow("N", "Toggle snapping")
                        shortcutRow("A", "Toggle chain selection")
                        shortcutRow("Esc", "Cancel the current action / deselect")
                    }
                }

                Divider().background(Color.gray)

                // File & edit shortcuts
                Group {
                    sectionHeader("File & Edit")

                    VStack(alignment: .leading, spacing: 10) {
                        shortcutRow("CMD + N", "New file")
                        shortcutRow("CMD + O", "Open project")
                        shortcutRow("CMD + S", "Save")
                        shortcutRow("CMD + SHIFT + S", "Save as")
                        shortcutRow("CMD + E", "Export (SVG / DXF)")
                        shortcutRow("CMD + Z", "Undo")
                        shortcutRow("CMD + SHIFT + Z", "Redo")
                        shortcutRow("Delete / Backspace", "Delete selection")
                    }
                }

                Divider().background(Color.gray)

                // Layers
                Group {
                    sectionHeader("Layers")

                    Text("Every entity lives on a layer; the active layer always follows your selection. Unfolding and pattern tools sort their output onto dedicated, color-coded layers:")
                        .foregroundColor(.text_secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("SEAM_CUT — the physical cut outline of each piece (red).")
                        bulletPoint("CREASE — fold lines, drawn dashed (blue).")
                        bulletPoint("GLUE_TABS / SEW_HOLES — assembly tabs and sewing holes (green).")
                        bulletPoint("OFFSET — outlines created with the Offset tool.")
                    }

                    Text("Layer colors carry through to SVG export per element, so ungrouping by layer in Illustrator or Inkscape keeps them intact.")
                        .foregroundColor(.text_secondary)
                }
            }
            .padding(30)
        }
        .frame(width: 560, height: 640)
        // Adaptive panel background so the Help window follows the app theme (MAS-72).
        .background(Color.bg_panel)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.title2, design: .monospaced))
            .fontWeight(.semibold)
            .foregroundColor(.yellow)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.yellow)
            Text(text)
                .foregroundColor(.text_primary)
        }
        .font(.body)
    }

    private func shortcutRow(_ keys: String, _ desc: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.text_primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.bg_input)
                .cornerRadius(4)

            Text(desc)
                .foregroundColor(.text_primary)
                .font(.body)
        }
    }
}
