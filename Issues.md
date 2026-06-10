# Pathstitch AI Implementation Plan & Checklist

> **SYSTEM PROMPT / AI DIRECTIVE:**
> This document is the master state and implementation plan for the Pathstitch macOS application. You are to read this document, identify the current uncompleted phase, and execute tasks sequentially. 
> Update the `- [ ]` checkboxes to `- [x]` as issues are completed and verified. Do not skip phases; dependencies are strict.

## 🏗️ Architectural Standards (CRITICAL)

* **State & File Storage:** * **Rule:** DO NOT use `.dxf` or `.json` files on disk as the active "working state" (this causes severe I/O bottlenecks and windowing/freak-out bugs). 
    * **Standard:** Use **Native In-Memory State** (`SwiftUI @Published` observable objects or a Python object graph) as the single source of truth.
    * **Serialization:** Only serialize this native state to disk (as a zipped JSON payload via the custom `.stch` extension) upon explicit "Save" or via an asynchronous background "Auto-Save" to `NSTemporaryDirectory()`.
* **Language Bridge:** Minimize Swift <-> PythonBridge roundtrips. Handle UI, immediate transforms, and optimistic updates in Swift. Batch sync to Python for heavy geometry processing.

---

## 📋 Phase 1: Foundation (File System & State)
**Dependency:** None. **Blocks:** All subsequent phases.
**Goal:** Establish memory-based state. Fix load/save logic. Handle zero-entity canvases.

- [ ] **MAS-21 / MAS-24:** Refactor workspace architecture. Remove temp `.dxf` disk writes for working state. Implement native in-memory state source of truth.
- [ ] **MAS-14 / MAS-12:** Overhaul file parser/serializer to correctly save and load `.stch` (zipped JSON) and import `.svg` without relying on legacy `.dxf` scratchpads.
- [ ] **MAS-13:** Fix multiple file handling (resolve error after save dialog).
- [ ] **MAS-8 / MAS-49 / MAS-9:** Refactor rendering engine to gracefully handle empty (0-entity) states. Ensure deleting the last item or opening a clean canvas does not crash or freak out the renderer.

## 📋 Phase 2: Windowing (New Window & Startup)
**Dependency:** Phase 1.
**Goal:** Resolve macOS window lifecycle bugs so navigation functions normally.

- [ ] **MAS-22 / MAS-32:** Fix window presentation mode in `ContentView` / `AppState`. Ensure text creation or "open with" logic does NOT spawn a new `NSWindow` or `WKWebView` instance.
- [ ] **MAS-37:** Resolve blank window rendering on initial startup click.
- [ ] **MAS-15 / MAS-39:** Rename "New Window" to "New File" in the macOS menu bar. Remove the redundant in-app new file button.
- [ ] **MAS-41:** Fix window creation coordinate offset positioning.

## 📋 Phase 3: Performance (Loading & Movement)
**Dependency:** Phase 1.
**Goal:** Eliminate pervasive lag and unnecessary loading screens.

- [ ] **MAS-25 / MAS-10:** Profile `PythonBridge`. Migrate synchronous/trivial operations from Python backend to pure Swift to drastically reduce IPC roundtrips (the main cause of loading screens).
- [ ] **MAS-6:** Fix object movement lagging behind cursor. Implement optimistic UI: apply gizmo drag delta immediately in SwiftUI, and asynchronously batch the coordinate transform sync to Python.

## 📋 Phase 4: Creation Tools (Text, Shapes, Images)
**Dependency:** Phases 1 & 2.
**Goal:** Stabilize the major creation pipelines.

- [ ] **MAS-20:** Refactor text/shape creation. Convert text creation to a pure Swift operation to avoid the "no renderable geometry" DXF pipeline error.
- [ ] **MAS-23:** Fix image upload pipeline. Resolve the Python-side `Potrace` error (`'Curve' object has no attribute`) in `dxf_ops.py` by correcting curve output serialization.
- [ ] **MAS-18:** Fix batch item preview. Resolve broken offsets and missing lines by applying the coordinate transforms established in Phase 3.

## 📋 Phase 5: Canvas Interactions
**Dependency:** Phase 3.
**Goal:** Polish canvas tools, shortcuts, and gizmos.

- [ ] **MAS-27 / MAS-5:** Rewrite gizmos in `DxfCanvasView.swift`. Add object rotation handle inside the gizmo. Enlarge scale/rotation/size handles and increase spacing between them.
- [ ] **MAS-38:** Implement a new overlay layer in the 2D canvas to support Draggable Handles for Offset and Fillet tools.
- [ ] **MAS-30:** Add Photoshop-equivalent global key bindings (e.g., `V` = Select, `Space` = Pan) via a `sendEvent` override in the window controller.
- [ ] **MAS-33:** Implement ruler deletion via `Backspace` key.

## 📋 Phase 6: Geometry Operations (Backend)
**Dependency:** Phase 1 (Can run parallel to UI phases).
**Goal:** Resolve algorithm and calculation bugs in the Python backend.

- [ ] **MAS-34:** Fix "Clean Up" feature. Implement snap-endpoints-within-tolerance algorithm using `Shapely` in `dxf_ops.py`.
- [ ] **MAS-35:** Fix Hole Sewing algorithm. Restore the "both" side option in the sewing hole distributor and correct acute-angle corner handling.
- [ ] **MAS-29:** Update Paper Tab Generator. Add `startOffset` and `endOffset` parameters; include arrow indicators.
- [ ] **MAS-40:** Fix DXF Quick Look. Update `DxfParser.swift` to build CoreGraphics paths for arcs/splines correctly, and skip isolated `POINT` entities.

## 📋 Phase 7: UI Architecture
**Dependency:** Phase 5.
**Goal:** Major layout overhaul to match professional design software (e.g., Photoshop).

- [ ] **MAS-44:** Redesign left sidebar. Split into Top 2/3 (scrollable tool options) and Bottom 1/3 (persistent Layers panel placeholder).
- [ ] **MAS-26:** Convert right panel to a full, persistent, non-collapsible Options view.
- [ ] **MAS-19 / MAS-16 / MAS-45:** Cleanup `ContentView`. Remove redundant bottom-4 file control icons. Move "Learn" toggle strictly to menu bar. Reorganize extra tool options.

## 📋 Phase 8: Polish & UX
**Dependency:** Phase 7 (Can run parallel).
**Goal:** Fix visual inconsistencies, add tooltips, and remove remaining UI bugs.

- [ ] **MAS-48:** Wire provided app icons into `AppIcon.appiconset` with correct macOS Dark/Light mode support. Remove the old sidebar logo.
- [ ] **MAS-7:** Fix hover state CSS/SwiftUI color tokens (ensure consistent orange-to-blue transition and add missing object canvas hover states).
- [ ] **MAS-11:** Make entire `DisclosureGroup` rows in the right sidebar tappable, rather than just the chevron/text.
- [ ] **MAS-46:** Implement hover tooltips for all clickable UI elements.
- [ ] **MAS-43:** Add a Line Details panel (a small `Text` overlay anchored to the bottom-right of the canvas).
- [ ] **MAS-36:** Execute full suite stress test to identify and patch unexpected runtime errors.

## 📋 Phase 9: Advanced Feature - Layering
**Dependency:** Phase 7.
**Goal:** Implement full layer management system.

- [ ] **MAS-42:** Implement `LayerStore` model in `AppState`. Assign a `layerId` to all entities. 
- [ ] **MAS-42 (UI):** Build Photoshop-style layers panel in the bottom 1/3 of the left sidebar. Must include: drag-to-reorder, rename on double-click, color-coded identifiers, and folder grouping. Ensure all new entities are created on the active layer.
