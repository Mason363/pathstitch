import SwiftUI
import AppKit

/// A Plasticity/Fusion-style command palette (MAS-53). Triggered by the Search
/// keybind (default `S`); type to filter, ↑/↓ to move, ⏎ or click to run.
/// Each row shows the tool icon (left), the title (left-aligned, truncated), and
/// the command's current keyboard shortcut (right) with native modifier glyphs.
struct SearchPalette: View {
    @Bindable var state: AppState
    private let keybinds = KeybindStore.shared

    @State private var query: String = ""
    @State private var selection: Int = 0
    @FocusState private var fieldFocused: Bool
    @State private var lastMousePosition: NSPoint? = nil
    /// Only auto-scroll the list when the selection moved via the keyboard. Hover
    /// must never scroll: centering the hovered row shifts the list under the
    /// cursor, which re-triggers hover and runs away (worst near top/bottom).
    @State private var scrollOnSelectionChange = false
    /// Local key monitor for Esc / ↑ / ↓. The focused TextField's field editor
    /// swallows these before SwiftUI's `.onKeyPress`/`.onExitCommand` see them,
    /// so we intercept at the app level instead.
    @State private var keyMonitor: Any?

    private var results: [AppCommand] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return AppCommands.all }
        // Rank: prefix match on title first, then any substring, preserving order.
        let matches = AppCommands.all.filter { $0.title.lowercased().contains(q) || $0.category.lowercased().contains(q) }
        return matches.sorted { a, b in
            let ap = a.title.lowercased().hasPrefix(q) ? 0 : 1
            let bp = b.title.lowercased().hasPrefix(q) ? 0 : 1
            return ap < bp
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.text_muted)
                TextField("Search tools and commands…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($fieldFocused)
                    .onSubmit { activate(at: selection) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().opacity(0.4)

            // Results
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { idx, cmd in
                            SearchResultRow(
                                command: cmd,
                                combo: keybinds.combo(for: cmd.id),
                                isSelected: idx == selection,
                                isEnabled: cmd.isEnabled(state)
                            )
                            // Identify the row by command id (content), matching the
                            // ForEach key. Using the positional index here instead
                            // conflicts with the ForEach identity and leaves stale
                            // rows when the filtered list shrinks.
                            .id(cmd.id)
                            .contentShape(Rectangle())
                            .onTapGesture { activate(at: idx) }
                            .onHover { hovering in
                                if hovering {
                                    let currentPos = NSEvent.mouseLocation
                                    if lastMousePosition != currentPos {
                                        scrollOnSelectionChange = false   // hover never scrolls
                                        selection = idx
                                        lastMousePosition = currentPos
                                    }
                                }
                            }
                        }
                        if results.isEmpty {
                            Text("No matching commands")
                                .foregroundColor(.text_muted)
                                .font(.system(size: 13))
                                .padding(.vertical, 18)
                        }
                    }
                }
                .frame(maxHeight: 360)
                .onChange(of: selection) { _ in
                    // Only auto-scroll for keyboard moves. Scrolling on a
                    // hover-driven selection shifts the list under the cursor,
                    // which re-fires hover and runs away — worst near the
                    // top/bottom edges. The wheel/trackpad stays free to scroll.
                    guard scrollOnSelectionChange else { return }
                    scrollOnSelectionChange = false
                    guard results.indices.contains(selection) else { return }
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(results[selection].id, anchor: .center) }
                }
            }
        }
        .frame(width: 540)
        .background(.ultraThinMaterial)
        .background(Color.bg_panel.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        .onAppear {
            selection = 0
            // Assert focus after the overlay is in the hierarchy. A single
            // synchronous set is unreliable for overlays presented over the
            // hidden hotkey buttons, so re-assert on the next runloop ticks.
            fieldFocused = true
            DispatchQueue.main.async { fieldFocused = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { fieldFocused = true }
            installKeyMonitor()
            lastMousePosition = NSEvent.mouseLocation
        }
        .onDisappear { removeKeyMonitor() }
        .onChange(of: query) { _ in selection = 0 }
    }

    // MARK: - Key handling

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53:  dismiss(); return nil          // Esc → close
            case 125: moveSelection(1); return nil   // ↓
            case 126: moveSelection(-1); return nil  // ↑
            default:  return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        scrollOnSelectionChange = true   // keyboard navigation may scroll the list
        selection = max(0, min(results.count - 1, selection + delta))
    }

    private func activate(at index: Int) {
        guard results.indices.contains(index) else { return }
        let cmd = results[index]
        guard cmd.isEnabled(state) else { return }
        dismiss()
        cmd.action(state)
    }

    private func dismiss() {
        state.showSearchPalette = false
    }
}

/// One result row in the search palette.
private struct SearchResultRow: View {
    let command: AppCommand
    let combo: KeyCombo
    let isSelected: Bool
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Icon (left-most). Generic dot when the command has no symbol.
            Group {
                if command.icon.isEmpty {
                    Image(systemName: "circle")
                } else {
                    Image(systemName: command.icon)
                }
            }
            .font(.system(size: 13))
            .frame(width: 18)
            .foregroundColor(isEnabled ? .text_secondary : .text_muted)

            // Title, left-aligned, truncated with an ellipsis.
            Text(command.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(isEnabled ? .text_primary : .text_muted)

            Spacer(minLength: 8)

            // Current shortcut on the right with native glyphs.
            if !combo.key.isEmpty {
                Text(combo.displayString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.text_muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accent.opacity(0.22) : Color.clear)
    }
}
