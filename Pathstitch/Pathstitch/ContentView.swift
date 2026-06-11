import SwiftUI
import UniformTypeIdentifiers

struct ModeButton: View {
    let mode: AppMode
    let systemName: String
    let help: String
    var state: AppState
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            state.activeMode = mode
        }) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .padding(10)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            state.activeMode == mode ? 
            Color.bg_selected : 
            (isHovered ? Color.accent.opacity(0.08) : Color.clear)
        )
        .foregroundColor(
            state.activeMode == mode ? 
            Color.accent : 
            (isHovered ? Color.accent_hover : Color.text_secondary)
        )
        .help(help)
        .onHover { hover in
            isHovered = hover
        }
    }
}

struct ToolButton: View {
    let tool: TwoDTool
    var state: AppState
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            state.currentTool = tool
            state.activeMeasureStart = nil
        }) {
            Image(systemName: tool.icon)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .padding(10)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            state.currentTool == tool ? 
            Color.bg_selected : 
            (isHovered ? Color.accent.opacity(0.08) : Color.clear)
        )
        .foregroundColor(
            state.currentTool == tool ? 
            Color.accent : 
            (isHovered ? Color.accent_hover : Color.text_secondary)
        )
        .help(tool.rawValue)
        .onHover { hover in
            isHovered = hover
        }
    }
}

struct ShapeToolButton: View {
    let tool: TwoDTool
    var state: AppState
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            state.currentTool = tool
            state.activeMeasureStart = nil
        }) {
            Image(systemName: tool.icon)
                .font(.system(size: 12))
                .frame(width: 20, height: 20)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            state.currentTool == tool ? 
            Color.bg_selected : 
            (isHovered ? Color.accent.opacity(0.08) : Color.clear)
        )
        .foregroundColor(
            state.currentTool == tool ? 
            Color.accent : 
            (isHovered ? Color.accent_hover : Color.text_muted)
        )
        .help(tool.rawValue)
        .onHover { hover in
            isHovered = hover
        }
    }
}

struct ToolbarHoverButton: View {
    let systemName: String
    let help: String
    var disabled: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .padding(10)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(
            disabled ? 
            Color.text_muted : 
            (isHovered ? Color.accent_hover : Color.text_secondary)
        )
        .disabled(disabled)
        .help(help)
        .onHover { hover in
            isHovered = hover
        }
    }
}

struct ContentView: View {
    @State var state: AppState
    @State private var showExportDialog = false
    // Debounced processing flag: only becomes true if work runs longer than a
    // short delay, so fast worker ops (~ms) never flash a loading overlay.
    @State private var showSlowLoader = false
    @State private var isShapesHovered = false
    @State private var offsetMode = "curve" // "curve" or "bbox"
    @State private var customLayerName: String = ""
    @State private var selectedExistingLayer: String = ""
    @State private var exportFormat: String = "dxf" // "dxf", "svg", "pdf", "png"
    
    @State private var leftSidebarTopHeight: CGFloat = 350
    @State private var isSelectionExpanded = true
    @State private var isHolesSewingExpanded = false
    @State private var isPaperFoldingExpanded = false
    @State private var isPatterningExpanded = false
    @State private var isTextPlacingExpanded = false
    @State private var isReferenceImageExpanded = false
    @State private var isLayersExpanded = false
    @State private var isImportSettingsExpanded = false
    @State private var isExportSettingsExpanded = false
    @State private var isShapesExpanded = false
    
    @State private var gridCols: Int = 3
    @State private var gridRows: Int = 3
    @State private var gridColSpacing: Double = 20.0
    @State private var gridRowSpacing: Double = 20.0
    @State private var pathHandle: String = ""
    @State private var pathPatternSpacing: Double = 10.0
    
    @State private var textString: String = "Label"
    @State private var textHeight: Double = 5.0
    @State private var textInsertX: Double = 0.0
    @State private var textInsertY: Double = 0.0
    
    @State private var exportSelectedOnly = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leftToolbar
                
                if state.activeMode == .twoD {
                    twoDEditorView
                } else if state.activeMode == .batch {
                    BatchModeView(state: state)
                } else {
                    threeDImporterView
                }
            }
            
            logAndStatusBarView
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color.bg_base)
        .background(WindowAccessor(state: state).frame(width: 0, height: 0).opacity(0))
        .font(PlasticityFont.body)
        .preferredColorScheme(.dark)
        // Bind hotkeys
        .background(hotkeyBindings)
        // Only reveal the loading overlay if work outlasts a short delay, so the
        // now-fast worker ops never flash a loader (§7).
        .task(id: state.isProcessing) {
            if state.isProcessing {
                try? await Task.sleep(nanoseconds: 280_000_000)
                if !Task.isCancelled && state.isProcessing { showSlowLoader = true }
            } else {
                showSlowLoader = false
            }
        }
        .onChange(of: state.selectedHandles) { _ in state.updateLivePreview() }
        .onChange(of: state.currentTool) { _ in state.updateLivePreview() }
        .onChange(of: state.offsetDistance) { _ in state.updateLivePreview() }
        .onChange(of: state.offsetSide) { _ in state.updateLivePreview() }
        .onChange(of: state.holeOffsetDistance) { _ in state.updateLivePreview() }
        .onChange(of: state.holeDiameter) { _ in state.updateLivePreview() }
        .onChange(of: state.holeSpacing) { _ in state.updateLivePreview() }
        .onChange(of: state.holePattern) { _ in state.updateLivePreview() }
        .onChange(of: state.holeCornerBehavior) { _ in state.updateLivePreview() }
        .onChange(of: state.holeSide) { _ in state.updateLivePreview() }
        .onChange(of: state.holeRowSpacing) { _ in state.updateLivePreview() }
        .onChange(of: state.holeEnableVariableSpacing) { _ in state.updateLivePreview() }
        .onChange(of: state.holeEnableProximityFilter) { _ in state.updateLivePreview() }
        .onChange(of: state.holeEnableCornerInterpolation) { _ in state.updateLivePreview() }

    }
    
    @ViewBuilder
    private var hotkeyBindings: some View {
        ZStack {
            Button("") { state.currentTool = .select }.keyboardShortcut("v", modifiers: [])
            Button("") { state.chainSelectionEnabled.toggle() }.keyboardShortcut("a", modifiers: [])
            Button("") { state.currentTool = .pan }.keyboardShortcut("h", modifiers: [])
            Button("") { state.currentTool = .offset }.keyboardShortcut("o", modifiers: [])
            Button("") { state.currentTool = .addHoles }.keyboardShortcut("s", modifiers: [])
            Button("") { state.currentTool = .cleanup }.keyboardShortcut("j", modifiers: [])
            Button("") { state.currentTool = .measure }.keyboardShortcut("m", modifiers: [])
            Button("") {
                state.escapePressedToken += 1
            }.keyboardShortcut(.escape, modifiers: [])
            Button("") { state.undo() }.keyboardShortcut("z", modifiers: [.command])
            Button("") { state.redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
            Button("") {
                if state.selectedMeasurement != nil {
                    state.deleteSelectedMeasurement()
                } else {
                    state.deleteSelectedEntities()
                }
            }.keyboardShortcut(.delete, modifiers: [])
            Button("") {
                if state.selectedMeasurement != nil {
                    state.deleteSelectedMeasurement()
                } else {
                    state.deleteSelectedEntities()
                }
            }.keyboardShortcut(.deleteForward, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
    
    private func runExportPanel(format: String) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Drawing"
        savePanel.nameFieldStringValue = "drawing.\(format)"
        savePanel.allowedContentTypes = [UTType(filenameExtension: format)].compactMap { $0 }
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            state.exportFile(to: url, format: format, selectedOnly: exportSelectedOnly)
        }
    }
    
    private func importFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [
            UTType(filenameExtension: "dxf"),
            UTType(filenameExtension: "step"),
            UTType(filenameExtension: "stp"),
            UTType(filenameExtension: "svg"),
            UTType(filenameExtension: "stch")
        ].compactMap { $0 }
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                if url.pathExtension.lowercased() == "stch" {
                    state.loadProject(from: url)
                } else {
                    state.loadFile(url: url)
                }
            }
        }
    }
    
    private func importReferenceImage() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType.image].compactMap { $0 }
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                state.loadReferenceImage(from: url)
            }
        }
    }
    
    private func saveProject() {
        if let current = state.currentProjectPath {
            // Flush optimistic in-memory edits, then persist (MAS-21).
            state.reconcileThenSave(to: current)
        } else {
            state.saveProjectWithDialog()
        }
    }
    
    private func loadProject() {
        state.loadProjectWithDialog()
    }
}

struct WindowAccessor: NSViewRepresentable {
    var state: AppState
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.setup(window: window, state: state)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        weak var window: NSWindow?
        var state: AppState?
        
        func setup(window: NSWindow, state: AppState) {
            self.window = window
            self.state = state
        }
    }
}

// Helper document wrapper for Swift FileExporter
struct DXFExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.item] }
    var fileURL: URL?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
    }

    init(configuration: ReadConfiguration) throws {
        // Read-only constructor (not strictly used for exporter)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = fileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try FileWrapper(url: url, options: .immediate)
    }
}

struct HoverableButtonLabel<Label: View>: View {
    let label: Label
    let isEnabled: Bool
    let isPressed: Bool
    @State private var isHovered = false
    
    var body: some View {
        label
            .font(PlasticityFont.body)
            .fontWeight(.medium)
            .foregroundColor(isEnabled ? Color.text_primary : Color.text_muted)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isEnabled ? (isPressed ? Color.accent_hover : (isHovered ? Color.accent_hover : Color.accent)) : Color.bg_input)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isEnabled ? Color.clear : Color.border_strong, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .onHover { hover in
                self.isHovered = hover
            }
    }
}

// Plasticity style buttons
struct PlasticityButtonStyle: ButtonStyle {
    var isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        HoverableButtonLabel(label: configuration.label, isEnabled: isEnabled, isPressed: configuration.isPressed)
    }
}

struct LinkButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovered ? Color.accent_hover : Color.accent)
            .font(PlasticityFont.body)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .onHover { hover in
                self.isHovered = hover
            }
    }
}


// MARK: - Sidebar Panels Extension
extension ContentView {
    @ViewBuilder
    private var selectionSection: some View {
        if state.currentTool == .select {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cursorarrow.and.square.on.square.dashed")
                        .foregroundColor(Color.accent)
                    Text("SELECTION DETAILS")
                        .font(PlasticityFont.header)
                        .foregroundColor(Color.text_primary)
                        .tracking(0.5)
                    Spacer()
                }
                .padding(.bottom, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    if state.selectedHandles.isEmpty {
                        Text("No selection")
                            .font(PlasticityFont.body)
                            .foregroundColor(Color.text_muted)
                            .padding(.vertical, 4)
                    } else {
                        HStack {
                            Text("\(state.selectedHandles.count) selected")
                                .font(PlasticityFont.body)
                                .foregroundColor(Color.text_primary)
                            Spacer()
                            Button("Deselect") {
                                state.selectedHandles.removeAll()
                            }
                            .buttonStyle(LinkButtonStyle())
                            .help("Deselect all selected entities on the canvas")
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ASSIGN TO LAYER")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            
                            Picker("", selection: $selectedExistingLayer) {
                                Text("Select existing layer...").tag("")
                                ForEach(state.layers) { layer in
                                    Text(layer.name).tag(layer.name)
                                }
                            }
                            .pickerStyle(DefaultPickerStyle())
                            .labelsHidden()
                            .help("Select an existing layer to assign selected entities to")
                            .onChange(of: selectedExistingLayer) { val in
                                if !val.isEmpty {
                                    customLayerName = val
                                }
                            }
                            
                            HStack {
                                TextField("New layer name", text: $customLayerName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(6)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .font(PlasticityFont.body)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Enter a name to assign selected entities to a new layer")
                                
                                Button("Assign") {
                                    state.assignSelectedToLayer(customLayerName)
                                    customLayerName = ""
                                    selectedExistingLayer = ""
                                }
                                .buttonStyle(BorderedButtonStyle())
                                .disabled(customLayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .help("Assign selected entities to the specified layer name")
                            }
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.bg_input.opacity(0.4))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var dimensionEditorSection: some View {
        if state.currentTool == .select, let selected = state.selectedMeasurement {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DIMENSION EDITOR")
                        .font(PlasticityFont.header)
                        .foregroundColor(Color.text_secondary)
                        .tracking(0.5)
                    Spacer()
                    Button("Clear") {
                        state.selectedMeasurement = nil
                    }
                    .buttonStyle(LinkButtonStyle())
                    .help("Deselect the current active measurement/dimension line")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(selected.isAutoDimension ? "Auto-Dimension Line" : "Manual Measurement")
                        .font(PlasticityFont.label)
                        .foregroundColor(Color.text_secondary)
                    
                    if let dimType = selected.dimensionType {
                        Text("Type: \(dimType.capitalized)")
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.text_muted)
                    }
                    
                    HStack {
                        Text("Length (mm)")
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.text_secondary)
                        Spacer()
                    }
                    
                    let binding = Binding<Double>(
                        get: { selected.distanceMm },
                        set: { newValue in
                            if selected.isAutoDimension {
                                state.updateSelectedDimensionValue(newValue: newValue)
                            } else {
                                if let idx = state.measurements.firstIndex(where: { $0.id == selected.id }) {
                                    state.measurements[idx].distanceMm = newValue
                                    state.selectedMeasurement?.distanceMm = newValue
                                }
                            }
                        }
                    )
                    
                    TextField("Dimension", value: binding, format: .number)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(6)
                        .background(Color.bg_input)
                        .cornerRadius(4)
                        .foregroundColor(Color.text_primary)
                        .font(PlasticityFont.body)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                        .disabled(!selected.isAutoDimension && selected.entityHandle == nil)
                        .help("Edit the dimension measurement value in millimeters")
                }
            }
            .padding(8)
            .background(Color.bg_input.opacity(0.4))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var activeToolDetailsSection: some View {
        if state.currentTool == .offset || state.currentTool == .cleanup || state.currentTool == .measure || state.currentTool == .sketchLine || state.currentTool == .sketchCircle || state.currentTool == .sketchRectangle || state.currentTool == .sketchText {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ACTIVE TOOL DETAILS")
                        .font(PlasticityFont.header)
                        .foregroundColor(Color.text_secondary)
                        .tracking(0.5)
                }
                
                if state.currentTool == .offset {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Offset Mode")
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.text_secondary)
                        
                        Picker("", selection: $offsetMode) {
                            Text("Curve").tag("curve")
                            Text("BBox").tag("bbox")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .help("Choose between parallel curve offset and bounding box (BBox) offset")
                        
                        if offsetMode == "curve" {
                            Text("Offset Distance (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            
                            TextField("Distance", value: $state.offsetDistance, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(6)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .font(PlasticityFont.body)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("Offset distance in millimeters")
                            
                            Text("Side")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            
                            Picker("", selection: $state.offsetSide) {
                                Text("Left").tag("left")
                                Text("Right").tag("right")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .help("Select side to offset: left or right")
                            
                            Button("Apply Offset") {
                                state.applyOffset()
                            }
                            .buttonStyle(PlasticityButtonStyle(isEnabled: !state.selectedHandles.isEmpty))
                            .disabled(state.selectedHandles.isEmpty)
                            .help("Apply parallel curve offset to the selected path entities")
                        } else {
                            Text("Offset Distance (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            
                            TextField("Distance", value: $state.bboxOffsetDistance, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(6)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .font(PlasticityFont.body)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("Bounding box offset distance in millimeters")
                            
                            Text("Corner Fillet Radius (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            
                            TextField("Fillet Radius", value: $state.bboxOffsetFillet, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(6)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .font(PlasticityFont.body)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("Radius for rounding bounding box corners in millimeters")
                            
                            Button("Apply BBox Offset") {
                                state.applyBBoxOffset()
                            }
                            .buttonStyle(PlasticityButtonStyle(isEnabled: true))
                            .help("Apply bounding box offset with rounded corners around selected path entities")
                        }
                    }
                } else if state.currentTool == .cleanup {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cleanup Tolerance (mm)")
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.text_secondary)
                        
                        TextField("Tolerance", value: $state.cleanupTolerance, format: .number)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(6)
                            .background(Color.bg_input)
                            .cornerRadius(4)
                            .foregroundColor(Color.text_primary)
                            .font(PlasticityFont.body)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                            .help("Endpoint distance tolerance gap in millimeters to join segments")
                        
                        Button("Apply Join/Cleanup") {
                            state.applyCleanup()
                        }
                        .buttonStyle(PlasticityButtonStyle(isEnabled: state.currentFilePath != nil))
                        .disabled(state.currentFilePath == nil)
                        .help("Join segment endpoints and clean up overlapping geometries")
                    }
                } else if state.currentTool == .measure {
                    VStack(alignment: .leading, spacing: 8) {
                        if state.measurements.isEmpty {
                            Text("No measurements taken")
                                .font(PlasticityFont.body)
                                .foregroundColor(Color.text_muted)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(state.measurements.filter { !$0.isAutoDimension }, id: \.id) { item in
                                HStack {
                                    Text("Dist:")
                                        .foregroundColor(Color.text_secondary)
                                    Text(String(format: "%.2f mm", item.distanceMm))
                                        .foregroundColor(Color.status_warn)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Button(action: {
                                        if let idx = state.measurements.firstIndex(where: { $0.id == item.id }) {
                                            if state.selectedMeasurement?.id == item.id {
                                                state.selectedMeasurement = nil
                                            }
                                            state.measurements.remove(at: idx)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(Color.text_secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Delete this measurement line")
                                }
                                .font(PlasticityFont.body)
                                .padding(.vertical, 2)
                            }
                            
                            Button("Clear All") {
                                state.measurements.removeAll { !$0.isAutoDimension }
                                state.selectedMeasurement = nil
                                state.activeMeasureStart = nil
                            }
                            .buttonStyle(PlasticityButtonStyle(isEnabled: true))
                            .help("Clear all manual measurements from the canvas")
                        }
                    }
                } else if state.currentTool == .sketchLine {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LINE SKETCH TOOL")
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.accent)
                        if state.isLearnModeEnabled {
                            Text("Click and drag on the canvas to draw a line segment. Dimensions are automatically measured and saved.")
                                .font(PlasticityFont.body)
                                .foregroundColor(Color.text_secondary)
                        }
                    }
                } else if state.currentTool == .sketchCircle {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CIRCLE SKETCH TOOL")
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.accent)
                        if state.isLearnModeEnabled {
                            Text("Click at center and drag outward to draw a circle. Radius is automatically measured and saved.")
                                .font(PlasticityFont.body)
                                .foregroundColor(Color.text_secondary)
                        }
                    }
                } else if state.currentTool == .sketchRectangle {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RECTANGLE SKETCH TOOL")
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.accent)
                        Text("Fillet Radius (mm)")
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.text_secondary)
                        
                        TextField("Fillet Radius", value: $state.sketchFilletRadius, format: .number)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(6)
                            .background(Color.bg_input)
                            .cornerRadius(4)
                            .foregroundColor(Color.text_primary)
                            .font(PlasticityFont.body)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                            .help("Fillet radius in millimeters for rounding sketched rectangle corners")
                        
                        if state.isLearnModeEnabled {
                            Text("Click and drag corner-to-corner. Corners are filleted using the radius specified above.")
                                .font(PlasticityFont.body)
                                .foregroundColor(Color.text_secondary)
                        }
                    }
                } else if state.currentTool == .sketchText {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TEXT SKETCH TOOL")
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.accent)
                        if state.isLearnModeEnabled {
                            Text("Click and drag a bounding box on the canvas. When you release, you can type the text to place inside the box.")
                                .font(PlasticityFont.body)
                                .foregroundColor(Color.text_secondary)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.bg_input.opacity(0.2))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var holesSewingSection: some View {
        if state.currentTool == .select || state.currentTool == .addHoles {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "circle.dashed")
                        .foregroundColor(Color.accent)
                    Text("HOLES SEWING")
                        .font(PlasticityFont.header)
                        .foregroundColor(Color.text_primary)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.text_secondary)
                        .rotationEffect(isHolesSewingExpanded ? .degrees(90) : .zero)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isHolesSewingExpanded.toggle()
                    }
                }
                .help("Toggle Holes Sewing settings panel")
                
                if isHolesSewingExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Offset Distance (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_primary)
                            Spacer()
                            TextField("Offset", value: $state.holeOffsetDistance, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(4)
                                .frame(width: 80)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("Distance from boundary path to place sewing holes in millimeters")
                        }
                        
                        HStack {
                            Text("Hole Diameter (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_primary)
                            Spacer()
                            TextField("Diameter", value: $state.holeDiameter, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(4)
                                .frame(width: 80)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("Diameter of each sewing hole in millimeters")
                        }
                        
                        HStack {
                            Text("Hole Spacing (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_primary)
                            Spacer()
                            TextField("Spacing", value: $state.holeSpacing, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(4)
                                .frame(width: 80)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("Distance between consecutive sewing holes in millimeters")
                        }
                        
                        HStack {
                            Text("Pattern Style")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_primary)
                            Spacer()
                            Picker("", selection: $state.holePattern) {
                                Text("Single").tag("single")
                                Text("Saddle").tag("saddle")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 120)
                            .help("Choose between a single row or double-row saddle stitch hole pattern")
                        }
                        
                        HStack {
                            Text("Corner Behavior")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_primary)
                            Spacer()
                            Picker("", selection: $state.holeCornerBehavior) {
                                Text("Keep").tag("keep")
                                Text("Step").tag("step")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 120)
                            .help("Select corner spacing behavior: keep original spacing or step layout to corner")
                        }
                        
                        HStack {
                            Text("Side")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_primary)
                            Spacer()
                            Picker("", selection: $state.holeSide) {
                                Text("Left").tag("left")
                                Text("Right").tag("right")
                                Text("Both").tag("both")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 180)
                            .help("Choose the side(s) of the path to distribute holes (left, right, or both)")
                        }
                        
                        HStack {
                            Text("Row Spacing (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_primary)
                            Spacer()
                            TextField("Row Spacing", value: $state.holeRowSpacing, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(4)
                                .frame(width: 80)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("Row offset spacing in millimeters for double-row saddle stitch holes")
                        }
                        
                        Toggle("Variable Spacing", isOn: $state.holeEnableVariableSpacing)
                            .toggleStyle(.checkbox)
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.text_primary)
                            .help("Enable variable spacing to fit holes perfectly along segment lengths")
                        
                        if state.holeEnableVariableSpacing {
                            HStack {
                                Text("  Min / Max (mm)")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_primary)
                                Spacer()
                                TextField("Min", value: $state.holeVariableSpacingMin, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 45)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Minimum spacing allowed between holes in millimeters")
                                Text("/")
                                TextField("Max", value: $state.holeVariableSpacingMax, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 45)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Maximum spacing allowed between holes in millimeters")
                            }
                            .padding(.leading, 8)
                        }
                        
                        Toggle("Proximity Filter", isOn: $state.holeEnableProximityFilter)
                            .toggleStyle(.checkbox)
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.text_primary)
                            .help("Filter out generated holes that are too close to other canvas paths")
                        
                        if state.holeEnableProximityFilter {
                            HStack {
                                Text("  Distance (mm)")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_primary)
                                Spacer()
                                TextField("Distance", value: $state.holeProximityDistance, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 60)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Proximity detection threshold radius in millimeters")
                            }
                            .padding(.leading, 8)
                        }
                        
                        Toggle("Line Proximity Filter", isOn: $state.holeEnableLineProximityFilter)
                            .toggleStyle(.checkbox)
                            .font(PlasticityFont.label)
                            .foregroundColor(Color.text_primary)
                            .help("Filter out holes close to the ends of lines")
                        
                        if state.holeEnableLineProximityFilter {
                            HStack {
                                Text("  Threshold (mm)")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_primary)
                                Spacer()
                                TextField("Threshold", value: $state.holeLineProximityThreshold, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 60)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Line end proximity threshold distance in millimeters")
                            }
                            .padding(.leading, 8)
                        }
                        
                        Button("Apply Sewing Holes") {
                            state.applySewingHoles()
                        }
                        .buttonStyle(PlasticityButtonStyle(isEnabled: !state.selectedHandles.isEmpty))
                        .disabled(state.selectedHandles.isEmpty)
                        .help("Generate sewing holes along selected paths using these parameters")
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(8)
            .background(Color.bg_input.opacity(0.4))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var paperFoldingSection: some View {
        if state.currentTool == .select {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "scissors")
                        .foregroundColor(Color.accent)
                    Text("PAPER FOLDING")
                        .font(PlasticityFont.header)
                        .foregroundColor(Color.text_primary)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.text_secondary)
                        .rotationEffect(isPaperFoldingExpanded ? .degrees(90) : .zero)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPaperFoldingExpanded.toggle()
                    }
                }
                .help("Toggle Paper Folding (crease pattern / glue tabs) settings panel")
                
                if isPaperFoldingExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CREASE PATTERN")
                                .font(PlasticityFont.label)
                                .fontWeight(.bold)
                                .foregroundColor(Color.accent)
                            Text("Turns selected segments into dashed crease folds.")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            Button("Apply Dashed Creases") {
                                state.applyDashedCreases()
                            }
                            .buttonStyle(PlasticityButtonStyle(isEnabled: !state.selectedHandles.isEmpty))
                            .disabled(state.selectedHandles.isEmpty)
                            .help("Convert selected segments into dashed crease folds for paper/leather modeling")
                        }
                        
                        Divider().background(Color.border_subtle)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GLUE TABS")
                                .font(PlasticityFont.label)
                                .fontWeight(.bold)
                                .foregroundColor(Color.accent)
                            
                            HStack {
                                Text("Tab Height (mm)")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                Spacer()
                                TextField("Height", value: $state.glueTabHeight, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 80)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Height of the generated glue tabs in millimeters")
                            }
                            
                            HStack {
                                Text("Tab Type")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                Spacer()
                                Picker("", selection: $state.glueTabType) {
                                    Text("Trapezoid").tag("trapezoid")
                                    Text("Triangle").tag("triangle")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 140)
                                .help("Choose the shape of the generated glue tabs: trapezoidal or triangular")
                            }
                            
                            HStack {
                                Text("Side")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                Spacer()
                                Picker("", selection: $state.glueTabSide) {
                                    Text("Left").tag("left")
                                    Text("Right").tag("right")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 140)
                                .help("Select the side of the path to place the glue tabs (left or right)")
                            }

                            HStack {
                                Text("Start Offset (mm)")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                Spacer()
                                TextField("Start Offset", value: $state.glueTabStartOffset, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 80)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Offset distance from the starting point of the segment in millimeters")
                            }

                            HStack {
                                Text("End Offset (mm)")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                Spacer()
                                TextField("End Offset", value: $state.glueTabEndOffset, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 80)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Offset distance from the ending point of the segment in millimeters")
                            }
                            
                            Button("Apply Glue Tabs") {
                                state.applyGlueTabs()
                            }
                            .buttonStyle(PlasticityButtonStyle(isEnabled: !state.selectedHandles.isEmpty))
                            .disabled(state.selectedHandles.isEmpty)
                            .help("Generate glue tabs along selected paths using these parameters")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(8)
            .background(Color.bg_input.opacity(0.4))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var patterningSection: some View {
        if state.currentTool == .select {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.grid.3x3")
                        .foregroundColor(Color.accent)
                    Text("PATTERNING")
                        .font(PlasticityFont.header)
                        .foregroundColor(Color.text_primary)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.text_secondary)
                        .rotationEffect(isPatterningExpanded ? .degrees(90) : .zero)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPatterningExpanded.toggle()
                    }
                }
                .help("Toggle Patterning (grid / path duplicate) settings panel")
                
                if isPatterningExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GRID PATTERN")
                                .font(PlasticityFont.label)
                                .fontWeight(.bold)
                                .foregroundColor(Color.accent)
                            
                            HStack {
                                Text("Columns / Rows")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                Spacer()
                                TextField("Cols", value: $gridCols, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 45)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Number of columns in the grid pattern")
                                Text("x")
                                TextField("Rows", value: $gridRows, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 45)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Number of rows in the grid pattern")
                            }
                            
                            HStack {
                                Text("Spacing Col / Row")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                Spacer()
                                TextField("Col Sp", value: $gridColSpacing, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 50)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Spacing between columns in millimeters")
                                Text("/")
                                TextField("Row Sp", value: $gridRowSpacing, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 50)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Spacing between rows in millimeters")
                            }
                            
                            Button("Apply Grid Pattern") {
                                state.applyPatternGrid(columns: gridCols, rows: gridRows, colSpacing: gridColSpacing, rowSpacing: gridRowSpacing)
                            }
                            .buttonStyle(PlasticityButtonStyle(isEnabled: !state.selectedHandles.isEmpty))
                            .disabled(state.selectedHandles.isEmpty)
                            .help("Duplicate selected shapes into a 2D grid pattern")
                        }
                        
                        Divider().background(Color.border_subtle)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PATH PATTERN")
                                .font(PlasticityFont.label)
                                .fontWeight(.bold)
                                .foregroundColor(Color.accent)
                            
                            HStack {
                                Text("Path Handle")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                Spacer()
                                TextField("Handle", text: $pathHandle)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 80)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Handle identifier of the path to duplicate shapes along")
                            }
                            
                            HStack {
                                Text("Spacing (mm)")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                Spacer()
                                TextField("Spacing", value: $pathPatternSpacing, format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .frame(width: 80)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .foregroundColor(Color.text_primary)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    .help("Spacing interval in millimeters between duplicated shapes along the path")
                            }
                            
                            Button("Apply Path Pattern") {
                                state.applyPatternPath(pathHandle: pathHandle, spacing: pathPatternSpacing)
                            }
                            .buttonStyle(PlasticityButtonStyle(isEnabled: !state.selectedHandles.isEmpty && !pathHandle.isEmpty))
                            .disabled(state.selectedHandles.isEmpty || pathHandle.isEmpty)
                            .help("Duplicate selected shapes along the specified path entity")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(8)
            .background(Color.bg_input.opacity(0.4))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var textPlacingSection: some View {
        if state.currentTool == .select || state.currentTool == .sketchText {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "textformat")
                        .foregroundColor(Color.accent)
                    Text("TEXT PLACING")
                        .font(PlasticityFont.header)
                        .foregroundColor(Color.text_primary)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.text_secondary)
                        .rotationEffect(isTextPlacingExpanded ? .degrees(90) : .zero)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isTextPlacingExpanded.toggle()
                    }
                }
                .help("Toggle Text Placing settings panel")
                
                if isTextPlacingExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Text String")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            Spacer()
                            TextField("Text", text: $textString)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(4)
                                .frame(width: 120)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("The text characters to place as a CAD text entity")
                        }
                        
                        HStack {
                            Text("Height (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            Spacer()
                            TextField("Height", value: $textHeight, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(4)
                                .frame(width: 80)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("Height of the text characters in millimeters")
                        }
                        
                        HStack {
                            Text("Insert X (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            Spacer()
                            TextField("X", value: $textInsertX, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(4)
                                .frame(width: 80)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("X insertion origin coordinate in millimeters")
                        }
                        
                        HStack {
                            Text("Insert Y (mm)")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                            Spacer()
                            TextField("Y", value: $textInsertY, format: .number)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(4)
                                .frame(width: 80)
                                .background(Color.bg_input)
                                .cornerRadius(4)
                                .foregroundColor(Color.text_primary)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                .help("Y insertion origin coordinate in millimeters")
                        }
                        
                        Button("Place Text") {
                            state.applyAddText(text: textString, insert: CGPoint(x: textInsertX, y: textInsertY), height: textHeight)
                        }
                        .buttonStyle(PlasticityButtonStyle(isEnabled: !textString.isEmpty))
                        .disabled(textString.isEmpty)
                        .help("Create and place a text entity at the specified coordinates")
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(8)
            .background(Color.bg_input.opacity(0.4))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var referenceImageSection: some View {
        if state.currentTool == .select {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "photo")
                        .foregroundColor(Color.accent)
                    Text("REFERENCE IMAGE")
                        .font(PlasticityFont.header)
                        .foregroundColor(Color.text_primary)
                        .tracking(0.5)
                    Spacer()
                }
                .padding(.bottom, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    if state.refImage == nil {
                        Button("Load Reference Image...") {
                            importReferenceImage()
                        }
                        .buttonStyle(PlasticityButtonStyle(isEnabled: true))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Image Underlay Loaded")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.status_ok)
                                Spacer()
                                Button("Clear") {
                                    state.refImage = nil
                                    state.refImageBase64 = nil
                                }
                                .buttonStyle(LinkButtonStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Opacity")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                HStack {
                                    Slider(value: $state.refImageOpacity, in: 0...1)
                                    Text(String(format: "%.1f", state.refImageOpacity))
                                        .font(PlasticityFont.label)
                                        .foregroundColor(Color.text_primary)
                                        .frame(width: 25)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Position Offset (mm)")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                                
                                HStack {
                                    Text("X:")
                                        .font(PlasticityFont.label)
                                        .foregroundColor(Color.text_muted)
                                    TextField("X Offset", value: Binding<Double>(
                                        get: { Double(state.refImageOffset.width) },
                                        set: { state.refImageOffset.width = CGFloat($0) }
                                    ), format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                    
                                    Text("Y:")
                                        .font(PlasticityFont.label)
                                        .foregroundColor(Color.text_muted)
                                    TextField("Y Offset", value: Binding<Double>(
                                        get: { Double(state.refImageOffset.height) },
                                        set: { state.refImageOffset.height = CGFloat($0) }
                                    ), format: .number)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(4)
                                    .background(Color.bg_input)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                }
                                
                                HStack(spacing: 8) {
                                    Button(action: { state.refImageOffset.width -= NSEvent.modifierFlags.contains(.shift) ? 10.0 : 1.0 }) {
                                        Image(systemName: "arrow.left")
                                            .font(.system(size: 10))
                                            .frame(width: 20, height: 20)
                                            .background(Color.bg_input)
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: { state.refImageOffset.height += NSEvent.modifierFlags.contains(.shift) ? 10.0 : 1.0 }) {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 10))
                                            .frame(width: 20, height: 20)
                                            .background(Color.bg_input)
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: { state.refImageOffset.height -= NSEvent.modifierFlags.contains(.shift) ? 10.0 : 1.0 }) {
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 10))
                                            .frame(width: 20, height: 20)
                                            .background(Color.bg_input)
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: { state.refImageOffset.width += NSEvent.modifierFlags.contains(.shift) ? 10.0 : 1.0 }) {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 10))
                                            .frame(width: 20, height: 20)
                                            .background(Color.bg_input)
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Text("Nudge (Shift=10mm)")
                                        .font(PlasticityFont.label)
                                        .foregroundColor(Color.text_muted)
                                }
                                .padding(.top, 4)
                            }
                            
                            Divider().background(Color.border_subtle)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("2-POINT CALIBRATION")
                                    .font(PlasticityFont.label)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.accent)
                                
                                HStack {
                                    Text("Target Dist (mm)")
                                        .font(PlasticityFont.label)
                                        .foregroundColor(Color.text_secondary)
                                    Spacer()
                                    TextField("Distance", value: $state.calibrationDistance, format: .number)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(4)
                                        .frame(width: 80)
                                        .background(Color.bg_input)
                                        .cornerRadius(4)
                                        .foregroundColor(Color.text_primary)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_strong, lineWidth: 1))
                                }
                                
                                Toggle("Enable Calibrate Mode", isOn: $state.isCalibrationActive)
                                    .toggleStyle(.checkbox)
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_primary)
                                
                                if state.isCalibrationActive {
                                    Text("Click 2 points on grid. Points: \(state.calibrationPoints.count)/2")
                                        .font(PlasticityFont.label)
                                        .foregroundColor(Color.status_warn)
                                }
                            }
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.bg_input.opacity(0.4))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var layersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.3.layers.3d")
                    .foregroundColor(Color.accent)
                Text("LAYERS")
                    .font(PlasticityFont.header)
                    .foregroundColor(Color.text_primary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                if state.layers.isEmpty {
                    Text("No layers")
                        .font(PlasticityFont.body)
                        .foregroundColor(Color.text_muted)
                        .padding(.vertical, 4)
                } else {
                    ForEach($state.layers) { $layer in
                        HStack(spacing: 8) {
                            Button(action: {
                                layer.visible.toggle()
                            }) {
                                Image(systemName: layer.visible ? "eye" : "eye.slash")
                                    .font(.system(size: 11))
                                    .foregroundColor(layer.visible ? Color.text_primary : Color.text_muted)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Circle()
                                .fill(layer.color)
                                .frame(width: 8, height: 8)
                            
                            Text(layer.name)
                                .font(PlasticityFont.body)
                                .foregroundColor(layer.visible ? Color.text_primary : Color.text_muted)
                            
                            Spacer()
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.bg_input.opacity(0.4))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
    }

    @ViewBuilder
    private var importSettingsSection: some View {
        if state.currentTool == .select {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(Color.accent)
                    Text("IMPORT SETTINGS")
                        .font(PlasticityFont.header)
                        .foregroundColor(Color.text_primary)
                        .tracking(0.5)
                    Spacer()
                }
                .padding(.bottom, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Consolidate SVG Strokes", isOn: $state.consolidateSvgStrokes)
                        .font(PlasticityFont.label)
                        .foregroundColor(Color.text_primary)
                        .toggleStyle(.checkbox)
                }
            }
            .padding(8)
            .background(Color.bg_input.opacity(0.4))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.border_subtle, lineWidth: 1))
        }
    }
}

extension ContentView {
    @ViewBuilder
    private var activeToolOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.currentTool == .offset {
                activeToolDetailsSection
            } else if state.currentTool == .cleanup {
                activeToolDetailsSection
            } else if state.currentTool == .addHoles {
                holesSewingSection
            } else if state.currentTool == .sketchRectangle {
                activeToolDetailsSection
            } else if state.currentTool == .sketchText {
                textPlacingSection
            } else if state.currentTool == .sketchLine || state.currentTool == .sketchCircle {
                activeToolDetailsSection
            } else if state.currentTool == .select {
                paperFoldingSection
                patterningSection
            }
        }
    }
}

extension ContentView {
    @ViewBuilder
    private var leftToolbar: some View {
        VStack(spacing: 4) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    Spacer().frame(height: 12)
                    // Mode Toggle Buttons
                    ModeButton(mode: .twoD, systemName: "square.on.square", help: "2D Editor", state: state)
                    ModeButton(mode: .threeD, systemName: "cube", help: "3D STEP Importer", state: state)
                    ModeButton(mode: .batch, systemName: "square.grid.2x2", help: "Batch Mode", state: state)
                    
                    Divider()
                        .background(Color.border_subtle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    
                    if state.activeMode == .twoD {
                        // Show 2D tools only when in 2D mode
                        let mainTools: [TwoDTool] = [.select, .pan, .offset, .addHoles, .cleanup, .measure]
                        ForEach(mainTools, id: \.self) { tool in
                            ToolButton(tool: tool, state: state)
                        }
                        
                        Divider()
                            .background(Color.border_subtle)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                        
                        let isShapeActive = state.currentTool == .sketchLine || state.currentTool == .sketchCircle || state.currentTool == .sketchRectangle || state.currentTool == .sketchText
                        Button(action: {
                            isShapesExpanded.toggle()
                        }) {
                            HStack(spacing: 0) {
                                Image(systemName: "triangle")
                                    .font(.system(size: 14))
                                Image(systemName: isShapesExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 8))
                                    .padding(.leading, 2)
                            }
                            .frame(width: 28, height: 24)
                            .padding(8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(isShapeActive ? Color.bg_selected.opacity(0.6) : (isShapesHovered ? Color.accent.opacity(0.08) : Color.clear))
                        .foregroundColor(isShapeActive ? Color.accent : (isShapesHovered ? Color.accent_hover : Color.text_secondary))
                        .help("Shapes Sketching")
                        .onHover { hover in
                            isShapesHovered = hover
                        }
                        
                        if isShapesExpanded || isShapeActive {
                            VStack(spacing: 2) {
                                let shapeTools: [TwoDTool] = [.sketchLine, .sketchCircle, .sketchRectangle, .sketchText]
                                ForEach(shapeTools, id: \.self) { tool in
                                    ShapeToolButton(tool: tool, state: state)
                                }
                            }
                            .padding(.vertical, 4)
                            .background(Color.bg_panel.opacity(0.5))
                            .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .frame(width: 48)
        .background(Color.bg_panel)
        .border(Color.border_subtle, width: 1)
    }

    @ViewBuilder
    private var twoDEditorView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VSplitView(
                    top: ScrollView {
                        activeToolOptions
                            .padding(14)
                    },
                    bottom: ScrollView {
                        layersSection
                            .padding(14)
                    },
                    topHeight: $leftSidebarTopHeight,
                    minTopHeight: 100,
                    minBottomHeight: 100
                )
            }
            .frame(width: 240)
            .background(Color.bg_panel)
            .border(width: 1, edges: [.trailing], color: Color.border_subtle)
            
            VStack(spacing: 0) {
                if let editingItem = state.activeEditingBatchItem {
                    HStack {
                        Button(action: {
                            if let activeURL = state.currentFilePath {
                                try? FileManager.default.removeItem(at: editingItem.fileURL)
                                try? FileManager.default.copyItem(at: activeURL, to: editingItem.fileURL)
                            }
                            
                            let tempDir = state.sessionTempDirectory.appendingPathComponent("batch")
                            let svgURL = tempDir.appendingPathComponent("\(UUID().uuidString).svg")
                            Task {
                                do {
                                    _ = try await PythonBridge.shared.run(
                                        module: "dxf_ops",
                                        op: "export_svg",
                                        args: ["input": editingItem.fileURL.path, "output": svgURL.path]
                                    )
                                    let svgStr = (try? String(contentsOf: svgURL, encoding: .utf8)) ?? ""
                                    try? FileManager.default.removeItem(at: svgURL)
                                    
                                    let listResult = try await PythonBridge.shared.run(
                                        module: "dxf_ops",
                                        op: "list_entities",
                                        args: ["input": editingItem.fileURL.path]
                                    )
                                    var itemsEnts: [DXFEntity] = []
                                    if let data = listResult["data"] as? [String: Any],
                                       let jsonEntities = data["entities"] as? [[String: Any]] {
                                        let jsonData = try JSONSerialization.data(withJSONObject: jsonEntities)
                                        itemsEnts = try JSONDecoder().decode([DXFEntity].self, from: jsonData)
                                    }
                                    
                                    await MainActor.run {
                                        if let idx = state.batchItems.firstIndex(where: { $0.id == editingItem.id }) {
                                            state.batchItems[idx].svgContent = svgStr
                                            state.batchItems[idx].entities = itemsEnts
                                        }
                                        state.activeEditingBatchItem = nil
                                        state.activeMode = .batch
                                    }
                                } catch {}
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Save & Return to Batch")
                            }
                            .foregroundColor(Color.accent)
                            .font(PlasticityFont.body.weight(.medium))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        Text("Editing: \(editingItem.originalName)")
                            .font(PlasticityFont.body.weight(.semibold))
                            .foregroundColor(Color.text_primary)
                        
                        Spacer()
                        Color.clear.frame(width: 150, height: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bg_panel)
                    .border(width: 1, edges: [.bottom], color: Color.border_subtle)
                }
                
                // Top Toolbar (always visible in 2D mode)
                HStack(spacing: 16) {
                    Button(action: {
                        state.canvasScale = 1.0
                        state.canvasOffset = .zero
                    }) {
                        Image(systemName: "house.fill")
                            .foregroundColor(Color.text_primary)
                            .padding(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Recenter View")

                    Button(action: { state.snapEnabled.toggle() }) {
                        Image(systemName: state.snapEnabled ? "dot.scope" : "scope")
                            .foregroundColor(state.snapEnabled ? Color.accent : Color.text_secondary)
                            .padding(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(state.snapEnabled ? "Snapping: On (placement snaps to points & 90°)" : "Snapping: Off")

                    Button(action: { state.chainSelectionEnabled.toggle() }) {
                        Image(systemName: state.chainSelectionEnabled ? "link.circle.fill" : "link.circle")
                            .foregroundColor(state.chainSelectionEnabled ? Color.accent : Color.text_secondary)
                            .padding(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(state.chainSelectionEnabled ? "Chain Selection: On" : "Chain Selection: Off")

                    Button(action: { state.gridVisible.toggle() }) {
                        Image(systemName: state.gridVisible ? "grid" : "grid.circle")
                            .foregroundColor(state.gridVisible ? Color.accent : Color.text_secondary)
                            .padding(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(state.gridVisible ? "Grid: Visible" : "Grid: Hidden")

                    Button(action: { state.isLogTrayExpanded.toggle() }) {
                        Image(systemName: state.isLogTrayExpanded ? "terminal.fill" : "terminal")
                            .foregroundColor(state.isLogTrayExpanded ? Color.accent : Color.text_secondary)
                            .padding(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(state.isLogTrayExpanded ? "Log Tray: Expanded" : "Log Tray: Collapsed")

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.bg_panel)
                .border(width: 1, edges: [.bottom], color: Color.border_subtle)
                
                // Main 2D Viewport
                ZStack {
                    // A blank/empty document is a first-class, editable canvas
                    // (MAS-8 / MAS-9 / MAS-49): show the canvas whenever a working
                    // document exists, not only once geometry has been rendered.
                    // The drop-zone is a fallback for the no-document state only.
                    if state.currentFilePath != nil || state.svgContent != nil || state.refImage != nil {
                        DxfCanvasView(state: state)
                    } else {
                        // Empty State Viewport (Plasticity Style)
                        VStack(spacing: 12) {
                            Image(systemName: "plus.square.dashed")
                                .font(.system(size: 32))
                                .foregroundColor(Color.text_muted)
                            
                            Text("DRAG & DROP DXF / STEP / SVG / STCH")
                                .font(PlasticityFont.header)
                                .foregroundColor(Color.text_secondary)
                                .tracking(0.5)
                            
                            Button("SELECT FILE") {
                                importFile()
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.bg_base)
                    }
                    
                    // Live Process Loader Overlay
                    if showSlowLoader {
                        ZStack {
                            Color.black.opacity(0.3)
                            VStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accent))
                                Text("Processing...")
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_secondary)
                            }
                            .padding(12)
                            .background(Color.bg_panel)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.border_strong, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Floating error banner
                    if let error = state.errorMessage {
                        VStack {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(Color.status_err)
                                Text(error)
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_primary)
                                Spacer()
                                Button(action: { state.errorMessage = nil }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(Color.text_secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(10)
                            .background(Color.bg_panel)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.status_err, lineWidth: 1)
                            )
                            .padding()
                            Spacer()
                        }
                    }
                }
                .contentShape(Rectangle())
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    collectDroppedURLs(providers) { urls in
                        if !urls.isEmpty { state.importFiles(urls) }
                    }
                    return true
                }
            }
            .frame(maxWidth: .infinity)
            
            // Right Panel (240px wide)
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        selectionSection
                        dimensionEditorSection
                        referenceImageSection
                        importSettingsSection
                    }
                    .padding(14)
                }
                
                // Bottom-anchored Export Settings (Always visible)
                Divider().background(Color.border_subtle)
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(Color.accent)
                            Text("EXPORT SETTINGS")
                                .font(PlasticityFont.header)
                                .foregroundColor(Color.text_primary)
                                .tracking(0.5)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color.text_secondary)
                                .rotationEffect(isExportSettingsExpanded ? .degrees(90) : .zero)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) {
                                isExportSettingsExpanded.toggle()
                            }
                        }
                        .help("Toggle Export Settings panel")
                        
                        if isExportSettingsExpanded {
                            VStack(alignment: .leading, spacing: 6) {
                                Picker("", selection: $exportFormat) {
                                    Text("AutoCAD DXF (.dxf)").tag("dxf")
                                    Text("Scalable Vector Graphics (.svg)").tag("svg")
                                    Text("Document PDF (.pdf)").tag("pdf")
                                    Text("Raster Image (.png)").tag("png")
                                }
                                .pickerStyle(DefaultPickerStyle())
                                .labelsHidden()
                                .help("Select format: AutoCAD DXF, SVG, PDF document, or PNG raster image")
                                
                                Toggle("Export Selected Only", isOn: $exportSelectedOnly)
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_primary)
                                    .toggleStyle(.checkbox)
                                    .help("Export only currently selected canvas entities instead of the whole drawing")

                                Toggle("Export Measurement Lines", isOn: $state.exportMeasurementLines)
                                    .font(PlasticityFont.label)
                                    .foregroundColor(Color.text_primary)
                                    .toggleStyle(.checkbox)
                                    .help("Include measurement/ruler lines as dashed construction lines (no dimension text). Saved with the project.")
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    Button("Export...") {
                        runExportPanel(format: exportFormat)
                    }
                    .buttonStyle(PlasticityButtonStyle(isEnabled: state.currentFilePath != nil))
                    .disabled(state.currentFilePath == nil)
                    .help("Export the drawing file to disk with the selected format and options")
                }
                .padding(12)
                .background(Color.bg_panel)
            }
            .frame(width: 240)
            .background(Color.bg_panel)
            .border(Color.border_subtle, width: 1)
        }
    }

    @ViewBuilder
    private var threeDImporterView: some View {
        VStack(spacing: 0) {
            ZStack {
                if state.stepJsonContent != nil {
                    ThreeDModeView(state: state)
                } else {
                    // Empty State Viewport (Plasticity Style)
                    VStack(spacing: 12) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 32))
                            .foregroundColor(Color.text_muted)
                        
                        Text("DRAG & DROP DXF / STEP / SVG / STCH")
                            .font(PlasticityFont.header)
                            .foregroundColor(Color.text_secondary)
                            .tracking(0.5)
                        
                        Button("SELECT FILE") {
                            importFile()
                        }
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bg_base)
                }
                
                // Live Process Loader Overlay
                if showSlowLoader {
                    ZStack {
                        Color.black.opacity(0.3)
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.accent))
                            Text("Processing...")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_secondary)
                        }
                        .padding(12)
                        .background(Color.bg_panel)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.border_strong, lineWidth: 1)
                        )
                    }
                }
                
                // Floating error banner
                if let error = state.errorMessage {
                    VStack {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(Color.status_err)
                            Text(error)
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_primary)
                            Spacer()
                            Button(action: { state.errorMessage = nil }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(Color.text_secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                        }
                        .padding(10)
                        .background(Color.bg_panel)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.status_err, lineWidth: 1)
                        )
                        .padding()
                        Spacer()
                    }
                }
            }
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                collectDroppedURLs(providers) { urls in
                    if !urls.isEmpty { state.importFiles(urls) }
                }
                return true
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var logAndStatusBarView: some View {
        VStack(spacing: 0) {
            if state.isLogTrayExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if state.logEntries.isEmpty {
                            Text("No logs yet")
                                .font(PlasticityFont.label)
                                .foregroundColor(Color.text_muted)
                                .padding(12)
                        } else {
                            ForEach(state.logEntries) { entry in
                                HStack {
                                    Text(entry.timestamp, style: .time)
                                        .font(PlasticityFont.label)
                                        .foregroundColor(Color.text_muted)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Text(entry.action.uppercased())
                                        .font(PlasticityFont.label)
                                        .foregroundColor(Color.accent)
                                        .frame(width: 150, alignment: .leading)
                                    
                                    Text(entry.details)
                                        .font(PlasticityFont.label)
                                        .foregroundColor(Color.text_primary)
                                    
                                    if let layer = entry.layerAffected {
                                        Text("(\(layer))")
                                            .font(PlasticityFont.label)
                                            .foregroundColor(Color.text_muted)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(height: 120)
                .background(Color.bg_panel)
                .border(Color.border_subtle, width: 1)
            }
            
            HStack {
                Button(action: {
                    state.isLogTrayExpanded.toggle()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: state.isLogTrayExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10))
                        Text("LOGS (\(state.logEntries.count))")
                            .font(PlasticityFont.label)
                    }
                    .foregroundColor(Color.text_secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("MODE: \(state.activeMode == .twoD ? "2D DXF EDITOR" : "3D STEP IMPORTER")")
                    .font(PlasticityFont.label)
                    .foregroundColor(Color.accent)

                Spacer()

                if let selectedMeasure = state.selectedMeasurement {
                    Text("MEASUREMENT | Length: \(String(format: "%.2f mm", selectedMeasure.distanceMm))")
                        .font(PlasticityFont.label)
                        .foregroundColor(Color.text_secondary)
                } else if state.selectedHandles.count == 1,
                          let handle = state.selectedHandles.first,
                          let entity = state.entities.first(where: { $0.handle == handle }) {
                    Text(entity.geometryDetails)
                        .font(PlasticityFont.label)
                        .foregroundColor(Color.text_secondary)
                } else if state.selectedHandles.count > 1 {
                    Text("SELECTED: \(state.selectedHandles.count) ENTITIES")
                        .font(PlasticityFont.label)
                        .foregroundColor(Color.text_secondary)
                } else {
                    Spacer().frame(width: 0)
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .background(Color.bg_panel)
            .border(Color.border_subtle, width: 1)
        }
    }
}

/// Resolves *every* dragged file into a `[URL]`, then delivers them on the main
/// queue. Uses `public.file-url` item loading — reliable for file drops, unlike
/// `loadObject(ofClass: URL.self)`, which silently resolved only one provider and
/// was the real "only one file imports" bug (MAS-13). Waits for all providers.
func collectDroppedURLs(_ providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
    let group = DispatchGroup()
    let lock = NSLock()
    var urls: [URL] = []
    for provider in providers {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            defer { group.leave() }
            var resolved: URL? = nil
            if let data = item as? Data {
                resolved = URL(dataRepresentation: data, relativeTo: nil)
            } else if let u = item as? URL {
                resolved = u
            }
            if let u = resolved {
                lock.lock(); urls.append(u); lock.unlock()
            }
        }
    }
    group.notify(queue: .main) { completion(urls) }
}

struct VSplitView<Top: View, Bottom: View>: View {
    let top: Top
    let bottom: Bottom
    @Binding var topHeight: CGFloat
    let minTopHeight: CGFloat
    let minBottomHeight: CGFloat
    
    @State private var isHoveringDivider = false
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                top
                    .frame(height: max(minTopHeight, min(topHeight, geo.size.height - minBottomHeight)))
                
                Rectangle()
                    .fill(isHoveringDivider ? Color.accent : Color.border_subtle)
                    .frame(height: 5)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringDivider = hovering
                        if hovering {
                            NSCursor.resizeUpDown.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                let newHeight = topHeight + val.translation.height
                                topHeight = max(minTopHeight, min(newHeight, geo.size.height - minBottomHeight))
                            }
                    )
                
                bottom
                    .frame(maxHeight: .infinity)
            }
        }
    }
}