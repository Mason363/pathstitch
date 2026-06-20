# 3D → 2D Unfolding / UV Flattening — Roadmap

The dream: a person loads an entire 3D model (STEP first; OBJ/STL later) and the
software unwraps it into flat, manufacturable 2D patterns — like clicking on a
globe and unravelling it into a map, with the chosen mode dictating *how* it
unravels. Flat sides unfold exactly; curved sides flatten with the least
possible distortion; seam lines land in the most optimal positions; the user
can override any of it.

---

## Phase 0 — Foundations ✅ SHIPPED

- STEP import via pythonOCC (`pathstitch_core/step_ops.py`)
- Body/face triangulation streamed to the Three.js viewport (`op_list_bodies`)
- Per-face analytic unfolding of developable surfaces — plane, cylinder, cone
  (`pathstitch_core/surface_unfold.py`), laid out side by side
  (`op_unfold_face`, `op_unfold_faces`)
- Wireframe projection sketches onto XY/XZ/YZ or a face plane (`op_project_edges`)
- Face multi-select in 3D mode (shift-click), unfold opens result in 2D mode

## Phase 1 — Connected polyhedral / developable nets ✅ SHIPPED (2026-06-12)

Engine: `pathstitch_core/net_unfold.py`, op `unfold_connected`, UI in the 3D
mode right panel.

- **Face adjacency graph** over the chosen faces (or the whole body); shared
  edges found via `TopTools_IndexedMapOfShape` identity
- **Dihedral rollout**: each face is flattened isometrically (zero distortion
  for plane/cylinder/cone) and rigidly aligned onto its parent across their
  shared edge, child placed on the opposite side of the fold from the parent
- **Fold eligibility rule**: an edge may be a fold only when its 2D image is
  straight in BOTH adjacent faces' unfoldings. A cube edge folds; a cylinder
  wall ↔ flat cap junction is a circle in the cap's plane, so it is forced to
  be a seam — exactly matching physical paper behaviour
- **Unroll modes** (the "globe" modes):
  - *Radial (petal)* — BFS from the anchor face; faces unroll outward in rings
  - *Strip* — greedy DFS along the longest shared edges; long peel-like strips
  - *Spanning tree* — maximum-weight spanning tree (longest, most stable folds)
- **Anchor**: largest selected face by default (user-draggable anchor is Phase 4)
- **Overlap resolution**: shapely union test per placement; a colliding rollout
  cuts that fold and starts a new patch beside the previous one (invariant:
  patches = faces − folds)
- **Multi-select unfolding**: any face subset unfolds together as one connected
  patch where adjacency allows (two sides of a cube, cone + cylinder along a
  shared straight generator, etc.); disconnected selections become side-by-side
  patches
- **Whole-body mode**: every face of every body, one net per body
- **Seam decorations** (sizes reuse the 2D Add Holes / Glue Tab tool settings):
  - *Glue tabs* (OUTWARD): chamfered trapezoids, exactly one per mating pair,
    on the earlier-placed piece; follows curved seams with per-point normals;
    includes the closure seam where a rolled wall mates with itself
  - *Sewing holes* (INWARD): evenly spaced, inset by margin, on BOTH mating
    pieces so hole patterns line up when sewn
- **Layer scheme** (colors are ACI, carried into SVG export per-element):
  - `SEAM_CUT` — red 1, continuous: the physical outline of every piece
  - `CREASE` — blue 5, DASHED: fold lines
  - `GLUE_TABS` / `SEW_HOLES` — green 3
- **SVG color fidelity**: `op_export_svg` writes `stroke` on every element, not
  just the layer `<g>`, so ungroup-by-layer in Illustrator/Inkscape keeps colors

## Phase 2 — Curved / doubly-curved surface flattening ✅ SHIPPED (2026-06-19)

Gauss's Theorema Egregium: doubly-curved surfaces (spheres, freeform) cannot
flatten without distortion — the job is *choosing which distortion to minimize*.

- **Conformal (LSCM) flattening — `surface_unfold.py`.**
  `triangulate_face` → `lscm_flatten` (Lévy et al. 2002 Least Squares Conformal
  Maps) → `boundary_loops`, wired into `unfold_face_geometry` so any non-
  developable ("Other") face flattens conformally instead of raising. A single
  face's OCC triangulation is small, so a **dense numpy `lstsq`** solves it —
  **no scipy dependency** (numpy already present). Gauge fixed by pinning two
  far-apart boundary vertices at their true 3D distance. Verified: a developable
  flat grid round-trips at <1° angle error (LSCM is exact for developables); a
  real OCC sphere face flattens to a finite, non-degenerate boundary loop and
  unfolds end-to-end to DXF via `op_unfold_face`.
- **Equal-area / equidistant / balanced modes — `relax_mesh`.** Seeded from the
  LSCM solution, a constrained **mass-spring relaxation** post-processes the UV:
  edge-length springs restore true 3D lengths (equidistant), per-triangle area
  springs restore true 3D areas (equal-area), and *balanced* blends both. The
  same two LSCM gauge vertices stay pinned so the result keeps a fixed frame.
  This is the practical stand-in for authalic / BFF parameterisation; it needs
  no extra dependency and runs in-process on a single face's mesh.
- **Distortion heatmap.** `op_face_distortion` returns one symmetric area-
  distortion value per mesh vertex (`max(a2d/a3d, a3d/a2d) − 1`) for the chosen
  mode; the 3D viewport colours the face mesh from it (`setFaceDistortion` in
  `viewport3d.html`). In the flattened DXF, curved patches also emit per-triangle
  colour fills on a dedicated `DISTORTION` layer (blue → green → red bands).
- **Sphere / hemisphere support.** A closed shell (no boundary loop) is cut by
  `split_closed_mesh` along its principal axis (PCA) into two open sub-meshes,
  each flattened and laid out side by side — "two hemispheres unravel as one".
- **Integrated into the connected-net rollout.** `net_unfold.MeshMapper` wraps a
  curved face's LSCM/relaxed UV with a barycentric UV→2D lookup, so an "Other"
  face is a first-class citizen in radial / strip / spanning layouts under the
  same straight-shared-image seam rule (curved junctions are forced seams).
- Input meshes already exist: `op_list_bodies` produces per-face OCC
  triangulations (vertices + indices) feeding the flattener.

  | Mode        | Algorithm                                   | Preserves            |
  |-------------|---------------------------------------------|----------------------|
  | Conformal   | LSCM (Lévy 2002)                            | Angles / local shape |
  | Equal-area  | LSCM seed + area-spring relaxation          | Surface area         |
  | Equidistant | LSCM seed + length-spring relaxation        | Edge lengths         |
  | Balanced    | LSCM seed + blended length/area relaxation  | Weighted mix         |

## Phase 3 — Seam-line control ✅ SHIPPED

- **Auto mode**: curvature-weighted spanning placement — fold weight is
  `length · (1 + cos θ)` between adjacent face normals, so flatter (lower-
  dihedral) folds are preferred and salient creases are avoided.
- **Manual mode**: the user clicks edges in the 3D viewport (edge raycasting in
  `viewport3d.html`, `selectEdge` callback) to mark them as seams; the engine
  receives `forced_seams` and drops those edges from the fold-candidate
  adjacency (`_fold_candidates`), so they can never become creases.
- **Hybrid mode**: the user marks *forbidden* edges ("never cut here"); the
  engine receives `forbidden_seams` and pins them into the spanning tree by
  boosting their weight, routing seams around them when eligible.
- Both modes are wired through `AppState` (`forcedSeams3D` / `forbiddenSeams3D`,
  `seamControlMode`) into `op_unfold_connected`, with viewport highlighting and
  Clear buttons in the UNFOLD panel.

## Phase 4 — Globe UX / interactivity ✅ SHIPPED

- **Anchor picking**: the rollout "pole" is user-selectable (`anchorFace3D` →
  `anchor` arg); the UI sets it from the current selection and shows a Reset.
- **Live recompute**: a `liveRecomputeEnabled` toggle re-runs the unfold
  (debounced `triggerLiveRecompute`) whenever distortion mode, seam control,
  forced/forbidden seams, per-seam overrides, or the anchor change.
- **Per-seam decoration overrides**: choose tabs / holes / plain seam-by-seam
  (`seamDecorations3D` → `seam_decorations`), overriding the global decoration.
- **OBJ/STL import**: mesh-only models load through `load_step_shape` (OCC
  `RWStl` / a small OBJ reader), every face is "Other" and routes straight into
  the Phase 2 flattener; exposed in the open panel and the `.obj`/`.stl` file
  associations.

## Known limitations (current)

- `EDGE_SAMPLES = 24` per edge: circles in nets are 24-gons; bump if laser
  output needs smoother arcs (or emit true arcs for circular edges)
- Whole-body nets of high-genus/many-face models may split into several
  patches more often than a human would (overlap cuts are greedy, not optimal)
- The equal-area / equidistant / balanced modes use mass-spring relaxation, a
  practical approximation rather than exact authalic / BFF parameterisation;
  conformal (LSCM) is exact for developables and angle-optimal otherwise
- scipy is still worth adding later for sparse solves on very large whole-body
  meshes; the current dense per-face solve is fast enough for interactive use

## Architecture pointers

- Engine: `pathstitch_core/net_unfold.py` (connected nets; `op_unfold_connected`
  is the worker entry) and `pathstitch_core/surface_unfold.py` (per-face
  developable + LSCM/relaxation flattening, `op_unfold_face`, `op_face_distortion`)
- Dispatch: `pathstitch_core/step_ops.py` → `OPERATIONS[...]`, served by the
  persistent worker (`pathstitch_core/worker.py`)
- Swift: `AppState.unfoldConnected(wholeBody:mode:decoration:)` and the seam /
  distortion / anchor state → `ThreeDModeView` UNFOLD section + `ThreeDViewport`
  / `viewport3d.html` (face & edge picking, distortion heatmap)
- Tests:
  - `pathstitch_core/test_dxf_ops.py` — 2D DXF ops
  - `pathstitch_core/test_mesh_imports.py` — OBJ/STL import → `op_list_bodies`
  - `pathstitch_core/test_unfold_full.py` — full roadmap coverage: LSCM &
    all distortion modes, distortion heatmap, hemisphere split, connected nets
    (box cross net, cylinder closure seam, cone, curved-face integration),
    forced/forbidden seams, per-seam overrides, anchor, and mesh-to-flatten
