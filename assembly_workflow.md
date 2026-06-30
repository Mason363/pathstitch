# Pathstitch — Assembly Workflow & Product Plan

A roadmap for turning Pathstitch from "a 2D leather CAD tool that can also unfold STEP files"
into a full **flat ↔ folded ↔ cut** studio, where the **Construct (Assembly) mode** is the live
digital mockup that replaces the physical prototype. Worked example throughout: the molded
glasses case — the *green* build is the finished piece; the *brown* build is the throwaway
prototype this workflow exists to eliminate.

> **How to read this.** This is a feature plan, not a manual. Every capability below is tagged:
> **`[Have]`** ships today (named with the real mode / file / op), **`[Improve]`** exists but needs
> to be made better or more reliable, **`[New]`** doesn't exist yet. The point is to show how far
> Pathstitch already is, and exactly what the assembly workflow needs next.

---

## 1. The thesis: leather is sheet metal, not cloth, not solids

The whole design hinges on picking the right physical analogy, because it decides the data model
and the math — and Pathstitch has already bet on it.

- **It is not solid modeling.** Fusion/Blender model volume. Leather goods are zero-volume shells
  made of flat panels. Modeling them as solids is the overkill Pathstitch deliberately avoids —
  there is no B-rep document; the source of truth is a 2D DXF sketch plus fold lines.
- **It is not cloth.** Apparel CAD (Clo3D, Marvelous Designer, Browzwear) drapes fabric that
  stretches and falls under gravity. Veg-tan leather doesn't drape; it bends to a finite radius and
  holds the crease. This is exactly why Construct mode's solver is **bending-dominant and
  near-inextensible** (the bar-and-hinge model in `construct_ops.py` lets leather bend but never
  stretch) rather than a cloth simulator.
- **It is sheet metal.** A flat blank, bent along lines to a minimum radius, with a computable
  relationship between flat pattern and folded form (bend allowance, neutral axis, K-factor). This
  is the SolidWorks/Fusion sheet-metal paradigm, and it's the correct one.

So the product Pathstitch is becoming is a synthesis no one else ships for leather:

- **Sheet-metal flat-pattern rigor** — flat ↔ folded is exact and parametric. **`[Have]`**
  developable folds are already exact in `net_unfold.py` and in Construct's `foldPanel`;
  **`[New]`** the *bend-allowance / K-factor* deduction that closes the loop is the locked Phase-3
  decision.
- **+ apparel-CAD interaction** — draw flat panels, "sew" edges together, watch them assemble.
  **`[Have]`** Construct mode's drag-to-fold and the seam (`StitchSeam`) tool already do this.
- **+ Pepakura/ExactFlat unfolding** — develop a 3D form down to flat blanks. **`[Have]`** 3D mode
  imports STEP and unfolds developable + doubly-curved (LSCM) faces.
- **+ laser/CAM output** — layered DXF/SVG/PDF, stitch holes, fold/score lines. **`[Have]`** the
  whole 2D export path; **`[Improve]`** hide-aware nesting and operation-layer mapping.

No tool on the market does all four for leather. Apparel CAD is the closest in feel but models the
wrong material; sheet-metal CAD models the right physics but knows nothing about stitching,
hardware, hides, or burnishing. **That intersection is Pathstitch's entire reason to exist**, and
the assembly workflow is where the four threads finally meet.

---

## 2. Core object model

Everything in the system is one of a small number of first-class objects. Get these right and the
rest is UI. Several already exist in `pathstitch_core` and the Construct models; the gaps are what
the plan fills.

- **Material `[Improve]`** — today Construct mode carries a `MaterialRef` (PBR color/finish/texture
  + a thickness slider). It needs to become a *physical* material: thickness (oz **and** mm; 1 oz ≈
  0.4 mm, so 4–5 oz ≈ 1.6–2.0 mm), temper/firmness, bending stiffness, **minimum bend radius**,
  stretch anisotropy, grain/flesh appearance, and flags for burnishable / moldable / paintable.
  Veg-tan and chrome-tan behave differently, and the library should carry that — it's what drives
  bend allowance and the validator thresholds, not just the render.
- **Panel `[Have]`** — a flat cut piece. Today it's a closed region extracted from the DXF sketch
  (`_extract_from_dxf` / `_triangulate_panel`), keyed by DXF handle, with internal features (holes,
  decals, cutouts/stamps/patches). **`[New]`** add an explicit **grain-direction vector** and an
  explicit flesh/grain **face assignment** as panel properties.
- **Edge `[New]`** — a segment of a panel boundary carrying an **edge treatment** (raw / beveled /
  burnished / painted / folded-over / bound). Today edges exist only implicitly; making the edge a
  first-class object is what lets treatments change the *pattern* (a turned edge needs allowance, a
  bound edge spawns a binding strip), not just the render.
- **Seam `[Have, flagship]`** — `StitchSeam` is already the most important abstraction in the app.
  A seam owns its mating edges, the arc-length pairing (`op_match_chains`), optional Loft-style
  **anchor pins** + flip, Kabsch panel seating, and an **ease/gather vs deform-to-fit** policy. It
  already guarantees both edges share one hole set and reports a **FITS / EASE / MISMATCH** verdict
  with hole counts, length, and gap-after-seating. You never punch holes on two panels
  independently and hope — the seam does both at once. **`[Improve]`** expose seam/edge *allowance*
  explicitly and feed thickness into the verdict.
- **Fold `[Have]`** — a bend line within or across a panel (`FoldSpec`), with an angle, a per-fold
  **roundness** (true developable fillet, not a smudge), and base-side selection. **`[New]`** clamp
  the radius to the material minimum and drive developed length from bend allowance.
- **Hardware `[New]`** — the biggest missing object. Today there are only **keep-out tags** (the
  stitch line gaps around tagged geometry). The plan: a parametric **Hardware** component (snap,
  rivet, magnetic clasp, D-ring, swivel clip, zipper, buckle, turn-lock) that brings its own 3D
  model for Construct, its **footprint** (the holes/slots it cuts into every layer it touches), a
  **clamp range** (post length vs. stack thickness → instant "won't close" validation), and a part
  number for the BOM.
- **Form (optional) `[Have]`** — an imported 3D object the leather wraps or molds around. 3D mode
  already imports STEP, distributes multiple bodies, and takes plane cross-sections; **`[New]`**
  promote a Form to a clearance-driving fit source (Section 4, Step 0) and add LiDAR/photo intake.
- **Assembly `[Have]`** — the graph of panels + seams + folds + glue that folds into the finished
  object, persisted in the `.stch` file alongside the sketch. The locked target is **one
  deterministic assembly tree** (regions = nodes; fold/seam/glue = joints), one forward BFS seating
  pass, loop-closure gap measured and reported — never silently fudged.

A **parameters table** sits above all of this. **`[Have]`** `DimensionEngine` already gives named
variables, formulas, units, and `fx:`/driven dimensions in 2D mode. **`[Improve]`** wire those
variables through to fold angles, seam allowances, and hardware placement so changing
`glasses_width` re-fits, re-folds, re-stitches, and re-nests the whole assembly.

**File format `[Have]`** — the native **`.stch`** project already embeds the sketch, the assembly
graph, materials, lights, and decals, and tolerates older files (optional fields decode). The plan
keeps it **human-diffable** so designs version-control cleanly in Git — both an open-source enabler
and a genuine differentiator: *leather patterns as code*.

---

## 3. The two-space paradigm

Pathstitch's window already toggles between two synchronized views. The assembly workflow makes the
sync truly bidirectional — the single best UX idea borrowed from Clo3D's 2D/3D split.

**2D mode (`DxfCanvasView`) — the pattern view.** The source of truth for the cut files. Draw and
edit panel outlines with snapping, live on-creation dimensions, parametric per-corner fillet/chamfer
(G1/G2), trim, boolean, offset, fill/hatch, layers, and the `DimensionEngine` parameter solver.
Place fold lines (the **FOLD/CREASE** layer), stitch holes, hardware footprints, grain arrows, and
debossing art. **Everything that gets cut is defined here.** **`[Improve]`** add full
coincident/tangent/equal/symmetric *constraints* on top of today's snapping for a real 2D solver.

**Construct mode (`constructViewport.html`) — the 3D mockup ("Foldspace").** Panels are extruded to
material thickness (real shells, not zero-thickness — you need to see edge stack and bulk), folded
along their folds, and zipped together along their seams by the bar-and-hinge XPBD solver at 60 fps.
This is the "test run without cutting leather."

**The sync is the product.**

- **2D → 3D `[Have]`** — edit the sketch and Construct rebuilds; the 2D↔assembly reconcile migrates
  decals/base/glue/seam references by DXF handle so deletions propagate with no ghosts.
- **3D → 2D `[Have, partial]`** — the **Crease tool** writes a real FOLD-layer line back into the
  sketch (editable, parametric); dragging/deleting a crease in 3D round-trips via
  `op_edit_fold_line`. **`[Improve]`** extend the round-trip so creating a seam by clicking two
  edges in 3D writes the seam allowance + developed length back into Flatland automatically (the
  Clo3D "click two edges to sew" gesture, fully bidirectional).

Under the hood the flat↔fold map is the sheet-metal one: developed length across a fold =
`θ·(R + K·T)`, with K calibrated per leather temper. **`[Have]`** the developable rollout is exact
today; **`[New]`** the K-factor term is what's missing. For molded (non-developable) regions, fall
back to LSCM surface flattening with a strain map (Section 8).

---

## 4. Full workflow — building the glasses case

The heart of it: walking the actual green case through Pathstitch, start to finish. (`templates.json`
already ships an *"Eyeglasses Case Interior"* template — `150 × 60 mm`, `~40 mm` deep.)

**Step 0 — Fit source.** You need the glasses' real envelope. Three paths, simplest first:

1. Pick the glasses-case template (or any Devices template) and type the folded dimensions, or
2. **`[New]`** LiDAR-scan the actual glasses with iPhone/iPad and drop the mesh in as a **Form**, or
3. Photograph them on a gridded mat and trace — **`[Have]`** reference-image import + calibrate +
   vectorize already exists in 2D mode.

Set `clearance` (e.g. 3 mm) as a `DimensionEngine` variable. The case is now parametrically bound to
the object: swap the glasses, the case resizes.

**Step 1 — Start from a template, not a blank. `[Improve]`** Today `TemplateLibrary` drops sized
primitives. The plan upgrades templates into **working parametric assemblies** — a "flap pouch"
arrives as body panel + flap + seam + snap, all live — so a beginner gets a closing case in two
minutes and you override parameters as needed.

**Step 2 — Body and wrap. `[Have]`** Draw/adjust the single body panel in 2D mode; its width is
driven by `glasses_width + 2·clearance + bend_allowance`, its height by glasses height + flap.
Construct mode wraps and stitches the two sides into the pouch and updates live as you reshape the
back-panel silhouette.

**Step 3 — The molded front. `[New]`** Flag the front region as a **molded zone** with a stretch
allowance; the LSCM flattener (already in `surface_unfold.py` for 3D mode) accounts for take-up so
the flat blank is correct after wet-molding, and Construct shows the bulge. Because molding needs a
buck, **`[New]`** export the buck as STL (print on the A1) plus an edge-creasing guide — the
software makes the jigs, not just the part (`jig_ops.py` is the seed of this).

**Step 4 — The hinge reinforcement. `[Have]`** Drop the stiffener patch as a second panel, lap it
onto the body, and create a **glue** joint (Construct's Glue tool: face/edge/piece pick, clicked-side
seating). Assign it a firmer/thicker material so validation knows the fold there resists more.

**Step 5 — Closure. `[New]` (hardware) + `[Have]` (articulation).** Place a snap from the hardware
library: male stud on the body, female on the reinforcement; the footprint auto-cuts the post holes
in both layers. Then articulate the flap closed in Construct (drag-to-fold) and confirm the snap
registers and the flap reaches — **this is exactly the check the brown prototype existed to
perform**, done in software.

**Step 6 — Strap, monogram, hardware. `[New]` + `[Have]`.** Add the bottom strap tab; place a
D-ring + swivel clip (footprint cuts the slot, sets the rivet). Add the "MC" monogram as **decal /
debossing art** — **`[Have]`** Construct's per-face decal placement (move/scale/spin/flip-side) and
2D engrave layers already do this; it lands on its own engrave layer for the laser.

**Step 7 — Stitching. `[Have, flagship]`.** Select the perimeter, pick a **pricking iron** from
`pricking_irons.json` (e.g. Diamond 3.85 mm), set edge distance (≈3.5 mm) and corner behavior.
`op_add_holes` lays a stitch line parallel to every edge, fits a whole number of evenly spaced
diamond holes, forces a hole at each corner with balanced spacing, and — because the seam is shared
— punches matching holes on both mating panels (`op_match_chains` + Kabsch seating). **`[Improve]`**
surface the total-holes and thread-length readout in the stitch panel (Section 5).

**Step 8 — Edges. `[New]`.** Set the perimeter edge treatment to beveled + burnished + painted dark
brown; Construct renders the painted edge stack so proportions read correctly.

**Step 9 — Mock it up. `[Have]`.** In Construct's **Mockup render mode**, close the flap, render in
green leather with diagonal saddle stitching, brass hardware, studio lighting, chosen finish
(matte/satin/glossy). **`[Improve]`** automated interference + closure + fit checks (Section 11).
**`[New]`** AR at 1:1 on iPhone/iPad to hold it before a single cut. This whole loop *is* the brown
prototype — now zero leather, 30 seconds.

**Step 10 — Output. `[Have]` + `[Improve]`.** Run validation, **`[New]`** nest on your hide,
**`[Have]`** export layered DXF/SVG/PDF mapped to laser operations, **`[Improve]`** plus the BOM. Cut.

The point: every physical decision the two real builds embody — wrap, mold, reinforce, snap, stitch
spacing, edge finish, hardware fit — has a direct parametric handle, and the expensive prototype step
collapses into a live Construct-mode preview.

---

## 5. The stitching engine (the distinctive bit)

Stitching is where generic CAD and apparel CAD both fall down for leather, and it's already
Pathstitch's strongest leather-specific feature. Status by piece:

- **Stitch line `[Have]`** — an offset curve at the chosen edge distance, owned by the seam (or a
  single edge for decorative topstitching). Per-edge selection (`segment_override`) and `chain_selection`
  off mean each clicked edge is its own path.
- **Hole placement is iron-driven `[Have]`** — pick a physical pricking iron by pitch from
  `pricking_irons.json` (diamond 2.0–5.0 mm, French, round punch, lacing flat); the engine fits a
  whole number of evenly spaced holes, nudges within tolerance, and orients diamond slits to the
  curve tangent.
- **Corner handling `[Have]`** — a hole at the corner, symmetric spacing in/out, no bunching; the
  single most common hand-stitching mistake, automatic.
- **Seam alignment by construction `[Have]`** — both mated edges share one hole set via
  `op_match_chains`; Loft-style anchor pins + flip handle mismatched runs; front and back always
  line up.
- **Output mode `[New]`** — purists don't laser their holes. Add a per-seam choice: **cut holes**
  (laser through), **mark centers** (tiny score dots to punch by hand — preserves the chisel look,
  no burnt edges), or **guide line only** (score the stitch channel for a pricking iron). Default to
  mark-centers; let the laser-everything crowd opt in.
- **Stitch styles `[Improve]`** — saddle today; add running / cross / baseball, backstitch count at
  ends, and an optional recessed **stitch groove** (which also adjusts edge distance and the 3D
  look). Construct already renders thread geometry with the correct diagonal saddle front/back
  pattern.
- **Thread + hole readout `[Improve]`** — the seam-fit report already computes hole counts and
  length; surface a thread-length estimate (stitch run × waste factor) for the BOM.

This is the embroidery-digitizer idea (SewArt et al.) applied to hand-stitch holes, married to the
seam abstraction — and it's the part of the assembly workflow that already works end to end.

---

## 6. Hardware and material systems

**Hardware library `[New]` — the headline new object for this workflow.** A McMaster-style
parametric catalog of real parts: Line 20/24 snaps, Sam Browne studs, Chicago screws, double-cap
rivets, magnetic snaps, D-/O-/rectangular rings, lobster/swivel/trigger clasps, turn-locks, bag
feet, and zippers (YKK #3/#5 coil with tape-width and box/stop allowances — zippers are their own
sub-tool because they eat into the opening). Each part carries:

- a 3D model for Construct mode,
- a **footprint** (the exact holes/slots/prong cuts it generates on every layer it touches — this is
  the upgrade path from today's keep-out tags),
- a **clamp range** (post length vs. stacked thickness → instant validation if it won't close), and
- a part number + vendor for the BOM.

Place hardware in 2D or Construct; footprints propagate to the cut files automatically.
Community-extensible as JSON data packs — the same shape as `pricking_irons.json` and
`templates.json`.

**Material library `[Improve]`** — extend today's `MaterialRef` (PBR color/finish/texture +
thickness) with the physical properties from Section 2, plus per-region firmness. Selecting a
material updates bend allowances, validation thresholds, **and** the render — one library, both
jobs.

---

## 7. Edge and surface treatment

**Edge finish `[New]`** — a per-edge property (raw / beveled / burnished / painted / folded-over /
bound) that can change the **pattern**, not just the look: a folded (turned) edge needs extra
material for the fold-back, a bound edge spawns a separate binding-strip panel with its own seam.
Construct renders the resulting edge stack so proportions stay honest.

**Surface treatments `[Have, partial]`** — debossing/embossing, stamping, dyed regions, and laser
engraving art (vector or raster) live on panel faces. Construct's per-face **decal** system already
places, frames, and flips art per side; 2D mode already keeps engrave on its own layer. **`[Improve]`**
map each treatment to the correct laser operation on export (vector-engrave vs raster-engrave vs
score). The "MC" monogram is the trivial case; full tooled art is the same pipeline.

---

## 8. The digital mockup — simulation and rendering

This is the "test run without leather," and it has to be believable enough to trust before cutting.
Construct mode is already most of the way there.

- **Solver `[Have]`** — a thickened-shell **bar-and-hinge XPBD** model (`construct_ops.py` builds
  it; `constructViewport.html` runs it). Bars hold rest length (no stretch), hinges carry the
  bending/fold constraints; facet creases stay rigid, user fold lines become the adjustable folds.
  This gives held folds and stiff drape — leather behavior, not floppy cloth. The locked replan
  deliberately removed the old soft-fold "brush" gimmick: **posing = a fold angle on a hinge.**
- **Developable unfold `[Have]`** — planes/cones/cylinders unfold exactly (`net_unfold.py`);
  doubly-curved faces flatten via conformal **LSCM** (`surface_unfold.py`). **`[Improve]`** surface
  a **strain heat-map** on molded/compound-curved regions (red = "won't lie flat without help") so
  you can add molding allowance or a dart — the Pepakura/ExactFlat idea.
- **Articulation `[Have]`** — open/close flaps (drag-to-fold with detents + angle badge), re-root
  the ground panel, glue/seat panels, transform with a snapping gizmo. Not a static render — an
  interactive physical check.
- **Interference + fit checks `[Improve]`** — today **assembly health** flags floating panels (BFS
  from ground over fold/seam/glue), open chains, and mismatched seams. Extend with collision /
  closure / "do the contents fit with clearance" / "do mated edges actually meet" checks (Step 9).
- **Presentation render `[Have]`** — Mockup mode already gives PBR leather (procedural grain,
  clearcoat), thread, decals, matte/satin/glossy finish, and Illustrator-style draggable lighting,
  on a studio gradient — clean enough for client previews (Stained Glass Stables, Artistory).
- **AR `[New]`** — true-scale preview on iPhone/iPad to hold the result pre-cut.

---

## 9. Going far beyond — how it makes almost any leather design

Generality comes from a library of **parametric construction components**, each a self-contained
recipe that drops in its own panels + seams + folds + hardware and re-parameterizes to context.
Compose them and you can build essentially anything. Today Construct mode assembles hand-drawn
panels; the plan is to let it assemble *recipes*.

**Component primitives `[New]`:** gussets (flat, boxed-corner, accordion), welts/piping, turned and
bound edges; pockets (patch, gusseted, zippered), card slots, bill compartments, dividers, pen
loops; straps (with keepers, adjusters, buckles), handles, D-ring tabs, belt loops; closures (snap,
magnetic, turn-lock, buckle, zip, drawstring, flap+strap).

**Product-family templates `[Improve]`** — upgrade `TemplateLibrary` entries into fully parametric
*assemblies*: cardholder, bifold, long wallet, zip pouch, glasses case, AirPods case, key case,
watch strap, belt, dog collar, knife sheath, camera strap, tote, messenger, backpack, Dopp kit.

Worked mini-cases proving the range:

- **Watch strap** — two parametric panels driven by `lug_width` + wrist circumference, taper +
  keeper loops + buckle + spring-bar slots, saddle-stitched perimeter. (`templates.json` already has
  16–24 mm strap stock.)
- **Bifold wallet** — spine fold where **bend allowance matters** (stacked layers thicken the spine;
  the validator catches a spine that won't close), four stepped card-slot components with skive
  zones, an interior bill panel.
- **Knife sheath** — welt strip sets the blade channel; wet-molded front (buck exported as STL);
  belt loop; heavy saddle stitch at a wider edge distance.
- **Backpack** — many panels, boxed gussets, zip + buckle closures, strap hardware — the same
  objects, just more of them, held honest by seams that keep every mating length and hole count
  equal.

**Depth features that keep it a real CAD tool, not a toy:**

- **`[Improve]`** constraint-based 2D sketching with a solver, on top of today's snapping + the
  `DimensionEngine` expression table.
- **`[Have]`** a hybrid direct-edit model (direct manipulation by default) — **`[New]`** add an
  optional feature timeline for power edits (the Shapr3D/Plasticity philosophy: parametric power
  without Fusion's ceremony).
- **`[Have]`** mirror/symmetry and pattern arrays (rectangular/circular/along-path) already exist in
  2D mode.
- **`[New]`** multi-material assemblies (leather + fabric lining + foam insert).
- **`[New]`** a Python plugin/scripting API — a natural fit, since the whole engine is already a
  Python worker (`pathstitch_core`).
- **`[New]`** a community pattern marketplace where designs publish as re-parameterizable `.stch`
  recipes — a "MakerWorld for leather," diffable and versioned, fitting the GPLv3 / open-source
  posture.

---

## 10. Manufacturing output

Where it earns its keep, and where leather diverges hard from apparel.

- **Hide-aware nesting `[New]`** — fabric is a rectangular bolt; a hide is an irregular outline with
  weak/stretchy bellies, firm backbone, and defects (scars, brands, bug bites, holes). Photograph or
  scan the hide, mark firm/loose zones and defects, and the nester places strong parts (flap, body,
  strap) on firm grain-aligned regions, keeps weak parts off the belly, respects each panel's grain
  arrow, and routes around defects. No hobby tool does this — a flagship feature.
- **Layered DXF/SVG export `[Have / Improve]`** — DXF/SVG/PDF/PNG already export. Formalize clean
  layer separation: cut, stitch-hole marks, fold/score lines, registration marks, hardware holes,
  vector-engrave, raster-engrave — mapping directly to xTool Creative Space / LightBurn operations.
- **Kerf compensation `[New]`** — offset cut paths by half the measured kerf so molded/lined fits
  are dimensionally right.
- **Cut strategy `[New]`** — ordering + micro-tabs so small parts don't shift mid-cut; inner
  features before outer contour.
- **Print-to-scale 1:1 tiled PDF `[Improve]`** — with alignment marks for the knife-and-paper crowd;
  multiplies the audience beyond laser owners. (PDF export exists; tiling + registration is the add.)
- **Tooling export `[New / partial]`** — molding bucks, edge-creasing guides, and hole-punch jigs as
  STL (3D-print on the A1) or DXF. `jig_ops.py` and the Construct STEP/STL export
  (`op_export_assembly`) are the foundation.
- **Production bridge `[New]`** — clicker-die line drawings for ordering steel-rule dies when a
  design graduates from one-off to batch.
- **BOM + costing `[New]`** — leather area (sq ft / dm²), thread length, hardware list with part
  numbers, edge paint, estimated material cost, laser cut-time estimate. Directly usable for pricing
  client and Artistory work.

---

## 11. DFM / validation — leather-specific rules

Run continuously (soft warnings) and as a pre-export gate, encoding the hard-won knowledge that
otherwise costs a ruined hide. **`[Have]`** assembly health already covers floating panels, open
chains, and seam fit; the rest is **`[New]`**, mostly gated on the material-properties upgrade
(Section 6).

- Fold radius ≥ material minimum bend radius (no creasing-to-failure).
- Hole-to-edge distance ≥ threshold (too close tears out).
- Snap/rivet/clasp clamp range vs. actual stacked thickness (will it close / will the post seat).
- **`[Have]`** mated seam edges equal developed length and equal hole count (the `StitchSeam`
  FITS/EASE/MISMATCH verdict — verify, don't just trust).
- Grain-direction consistency across panels that should align; warning on parts on stretchy belly.
- Spine/fold stack thickness vs. closability (the wallet-won't-shut check).
- Molded-region strain within the leather's stretch limit, else suggest a dart or more clearance.
- Each panel fits within the available hide/stock.
- Corner radii ≥ the minimum the laser/cutter can resolve.
- Skive recommendations where overlap thickness exceeds a target.

---

## 12. UX principles — intuitive and powerful

The tension (powerful enough for anything, yet very intuitive) is resolved by progressive
disclosure — and Pathstitch's assembly-mode replan already locked this in.

- **Simple lane** — pick a template, drag sliders / type a few dimensions, pick a material and
  hardware, export. A first-timer closes the loop on a real case in minutes. The locked replan
  shrank Construct's tool rail to **Select + Add-fold + Add-seam** with a **guided
  auto-structure-with-confirm** flow and a one-click **Assemble** / **Auto-stitch**.
- **Advanced lane** — full sketching, custom seams, scripting, hide nesting. Same `.stch` document,
  more surface exposed on demand.

Plus:

- **Direct manipulation everywhere `[Have]`** — sew by picking edges, bend by dragging a flap (with
  angle detents + badge), glue by clicking a face, place hardware by dropping it. Inline dimensions,
  snapping, minimal modal dialogs.
- **Smart defaults that are correct `[Have / Improve]`** — apply a stitch style and you get a sane
  edge distance, even spacing, corner holes, and tangent-oriented slits without configuring
  anything; override freely. Quick-value preset chips already exist across many tools.
- **Live BOM / cost / validation panels `[Improve]`** — the contextual inspector already shows
  assembly size, stitch count, area, and a health icon; extend to live cost + full validation.
- **Asset browser `[Improve]`** — for materials, hardware, stitch styles, templates, and saved
  components (libraries already exist as JSON; the browser is the add).
- **Native Apple feel `[Have]`** — SwiftUI, trackpad gestures, customizable keybinds, command
  palette (`S` / `⌘K`), rearrangeable toolbar; **`[New]`** Apple Pencil / Cintiq tracing → clean up
  with constraints, plus LiDAR scan-to-fit and AR.

---

## 13. Architecture notes

For the build, not the pitch — and mostly already true.

- **Geometry `[Have]`** — a Python geometry worker (`pathstitch_core`) over `ezdxf` + `shapely` +
  `numpy` for 2D, with **OpenCASCADE (pythonOCC)** for the STEP / Form-import / 3D-develop path. The
  SwiftUI front-end never blocks: every op is framed JSON over stdin/stdout via `PythonBridge`.
  (Gotcha already handled: OCC/STEP writers must not print to fd 1 or they corrupt the frame
  protocol — `worker.py` does `dup2(2,1)`.)
- **Simulation `[Have]`** — XPBD bar-and-hinge shell (bending-dominant) in `constructViewport.html`,
  real-time on M-series hardware.
- **Flattening `[Have]`** — exact developable unroll (`net_unfold.py`) + least-distortion LSCM with
  strain output (`surface_unfold.py`).
- **File format `[Have]`** — diffable native `.stch` embedding parameters, the construction graph,
  materials, and asset references → Git-/marketplace-friendly. (Note the PackCAD-style rigid
  bar-and-hinge lineage is cited directly in `construct_ops.py`.)
- **Extensibility `[New]`** — Python plugin/scripting API; hardware + material libraries as
  community data packs (same JSON shape as the existing libraries).
- **CAM `[Have / Improve]`** — DXF/SVG/PDF/PNG writer; add layer→operation mapping, kerf offset,
  irregular-boundary + defect-avoidance nesting, and 1:1 tiled PDF.
- **Stack fit `[Have]`** — Swift/SwiftUI front end + Python backend is already the architecture; the
  heavy solvers (flatten, nest, sim) sit in the Python / JS-viewport layer.

---

## 14. Design north-stars (what to borrow, what to reject)

- **Clo3D / Marvelous / Browzwear** → the 2D/3D synced split and click-two-edges-to-sew. *Already
  borrowed* in 2D ↔ Construct + the seam tool. (Reject their cloth physics — Pathstitch's solver is
  bending-dominant by design.)
- **Fusion / Onshape** → parameters table, sketch constraints, expression-driven dimensions;
  Onshape's Git-like versioning. *Partly borrowed* via `DimensionEngine` + diffable `.stch`. (Reject
  the solid-modeling weight.)
- **SolidWorks/Fusion sheet-metal** → the flat-pattern ↔ folded-form model, bend allowance,
  K-factor — the conceptual core; the K-factor term is the key gap to close.
- **PackCAD** → the rigid bar-and-hinge representation. *Already borrowed* (cited in
  `construct_ops.py`).
- **Pepakura / ExactFlat / Autometrix** → 3D-to-flat unfolding with strain mapping; irregular hide
  nesting.
- **Shapr3D / Plasticity** → modern, direct-manipulation, low-ceremony UX north star. *Already the
  posture* of the Construct replan.
- **LightBurn / xTool Creative Space** → layer/color→operation mapping, kerf, cut ordering — the
  export target.
- **Valentina / Seamly2D** → open-source, formula-driven parametric drafting as a community
  precedent (fits the GPLv3 license).
- **Embroidery digitizers (SewArt)** → stitch-path generation, repurposed for hand-stitch holes.
  *Already the model* for `op_add_holes`.

---

## 15. Delivery plan — four phases

Phasing the vision against what already ships. Much of the original "MVP" and "v1" are **done** in
Pathstitch; the real work is the assembly workflow's missing objects and the manufacturing layer.

**Already shipped (the floor).** Constrained-ish 2D sketcher with parameters → iron-driven,
corner-aware stitch holes → first-class seams with FITS/EASE/MISMATCH validation → Construct-mode
fold/glue/seam assembly with XPBD, thickness, PBR mockup, lighting, decals → STEP import + developable
& LSCM unfold → layered DXF/SVG/PDF/PNG export + `.stch` → QuickLook previews. **This already beats
Illustrator-template workflows and produces the glasses-case cut files.**

### Phase 1 — Material & Bend-Allowance Foundation  ✅ SHIPPED

The physics and the core object-model upgrade everything downstream depends on. Hardware clamp
validation, edge treatments, the DFM suite, BOM area/cost — all need a real material and an exact
flat↔folded relationship first. This is also the section that finally lands the *sheet-metal thesis*
(Section 1) as running code.

1. **`[New]` Physical leather model + library.** Promote `MaterialRef` (today: PBR tint +
   thickness) into a real material — thickness (oz **and** mm), temper, bending stiffness, **minimum
   bend radius**, K-factor, stretch, and burnishable/moldable/paintable flags. Ship a built-in
   `leathers.json` data pack + a `LeatherStore` (bundled + user round-trip), mirroring the existing
   `PrickingIronStore` / template library.
2. **`[New]` Bend-allowance / K-factor engine.** The standard sheet-metal relations — bend
   allowance `BA = θ·(R + K·T)`, outside setback, and bend deduction — as pure, unit-tested
   functions in `construct_ops.py` (`op_fold_metrics`), with the Construct inspector mirroring them
   for a live read-out. Closes the flat↔folded loop the zero-radius crease model can't.
3. **`[Improve]` Wire material into Construct.** Picking a leather drives thickness, default tint,
   and the physical properties that feed bend allowance + validation; persisted in the `.stch`
   (backward-compatible).
4. **`[New]` Fold-radius DFM (first rule).** Per-fold bend allowance + a soft warning when a fold is
   tighter than the leather's minimum bend radius (grain-crack risk) — surfaced inline in the Folds
   inspector. The first of the Section 11 rules, and the template for the rest.

### Phase 2 — Hardware, Edges & Parametric Assemblies  ✅ SHIPPED

5. **`[New]` Hardware object** — 3D model + footprint (cuts both layers) + clamp-range validation;
   the upgrade path from today's keep-out tags (Sections 2, 6).
6. **`[New]` Edge object + treatments** that change the *pattern* — turned/bound allowances, binding
   strips (Section 7).
7. **`[Improve]` Parametric template assemblies** — templates arrive as working designs, not blanks
   (Sections 4, 9).
8. **`[New]` Multi-material assemblies** — leather + lining + foam.

### Phase 3 — Manufacturing Output & Validation  ✅ SHIPPED (core engines)

9. **`[New]` Hide-aware nesting** with grain + defect avoidance — the flagship CAM feature.
10. **`[Improve]` Operation-layer export mapping + kerf + 1:1 tiled PDF** — laser and knife crowds.
11. **`[New]` BOM + costing** (area/thread/hardware/cost); molding-buck / jig STL (`jig_ops.py`).
12. **`[New]` Stitch output modes** (cut / mark / guide) + more styles + thread readout.
13. **`[New]` Full DFM suite** + molded-zone strain heat-map + interference/closure checks.

### Phase 4 — Platform & Reach  ◑ PARTIAL (plugin API shipped; device/infra items scoped out)

14. **`[Needs iOS target]` AR 1:1 preview, LiDAR scan-to-fit, Apple Pencil tracing.**
    These require an iOS/iPadOS app target and device hardware (ARKit / RoomPlan /
    PencilKit) — they cannot live in the macOS app. The macOS reference-image
    **trace / vectorize** path already covers underlay tracing with a pen/mouse;
    Apple Pencil is the same pipeline on an iPad build.
15. **`[Shipped]` Python plugin / scripting API.** `pathstitch_core/plugins.py` loads
    user `*.py` files (each exposing an `OPERATIONS` dict) from the plugins folder
    and exposes them through the worker's `plugins` module — no rebuild, broken
    plugins skipped. **Manufacturing ▸ Open Plugins Folder…** reveals the directory.
16. **`[Needs backend]` Community `.stch` pattern marketplace.** The diffable `.stch`
    file already *is* the shareable, re-parameterizable pattern format; a marketplace
    additionally needs a hosting / accounts / discovery backend service, which is out
    of scope for this client repo.

---

Threaded throughout: the brown prototype and the green final are the same design at two fidelities.
The job of Pathstitch's assembly workflow is to make the brown one **digital** — so the next real cut
is the *only* cut.
