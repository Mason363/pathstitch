# Pathstitch

**Pathstitch** is a native macOS CAD/CAM application for leathercraft, pattern making, and sewing. It pairs a SwiftUI front‑end with a Python geometry engine to give you precise 2D vector sketching, parametric editing, automatic stitch‑hole generation, and 3D‑to‑2D unfolding — all in one app.

> **Distribution:** the release `.app` is **self‑contained** — it bundles its own Python backend, so it runs on any **Apple‑Silicon Mac (macOS 14+)** with nothing else installed. Build one with [`scripts/package_app.sh`](scripts/package_app.sh) → a ready‑to‑share `.dmg`. It is ad‑hoc signed (no Apple Developer ID), so users [bypass Gatekeeper once](#installing-a-non-notarized-app).

---

## Features

- **2D sketching** — line, circle, rectangle, text, and an Illustrator‑style **pen** tool.
- **Parametric corners** — per‑corner **fillet** and **chamfer** (G1/G2), live‑draggable radius, editable after the fact. Works on polylines, two‑line corners, and imported geometry.
- **Trim** — Fusion‑style: click or drag across a segment and it's cut at its intersections.
- **Offset, holes & stitching** — generate sewing holes / saddle‑stitch patterns along paths.
- **Measure & dimensioning** — on‑creation dimensions, tab between fields, construction‑line export.
- **Transforms** — move/rotate gizmo, point‑to‑point move, scale, mirror, reflect, duplicate, patterning.
- **Layers**, **convert‑lines** styles, **paper folding** (crease lines + glue tabs).
- **3D** — import `.step`/`.stp`, view in a Three.js viewport, and unfold developable nets to 2D.
- **Import/Export** — DXF, SVG, PDF, PNG; native `.stch` project files; Finder QuickLook + thumbnails for DXF/STEP.
- **Quality‑of‑life** — customizable keybinds, light/dark themes, a ⌘K command palette, and a rearrangeable toolbar.

---

## Architecture

```
┌──────────────────────────────┐        JSON over stdin/stdout        ┌────────────────────────────┐
│  SwiftUI front-end (macOS)    │  ─────────────────────────────────▶ │  Python engine             │
│  AppState · DxfCanvasView ·   │   PythonBridge ↔ pathstitch_core    │  ezdxf · shapely · numpy   │
│  ThreeDViewport (WKWebView)   │  ◀───────────────────────────────── │  pythonOCC (STEP) ·        │
└──────────────────────────────┘                                      │  matplotlib (PDF/PNG)      │
                                                                       └────────────────────────────┘
```

- **Front‑end:** Swift / SwiftUI (`Pathstitch/Pathstitch`). All geometry ops are dispatched to the backend through `PythonBridge.swift`, which keeps a persistent `python -m pathstitch_core.worker` process and streams JSON requests to it.
- **Backend:** `pathstitch_core/` — `dxf_ops.py` (2D), `step_ops.py` / `surface_unfold.py` / `net_unfold.py` (3D), driven by `worker.py`.
- **3D viewport:** `viewport3d.html` (Three.js) rendered inside a `WKWebView`.

---

## Requirements

### To run / build from source

| Component | Version | Notes |
|---|---|---|
| **macOS** | **14.0 (Sonoma) or newer** | Built and tested on macOS 26 (Tahoe). No known upper bound. |
| **Xcode** | **16 or newer** | Built with Xcode 26.5 / Swift 6.3. Needed only to build from source. |
| **Python** | **3.11** | The backend; see the Python packages below. |

**Python packages** (`pathstitch_core/requirements.txt` + 3D extras):

```
ezdxf        # DXF read/write + 2D geometry
shapely      # offsets, booleans, polygon ops
numpy        # math
svgwrite     # SVG export
matplotlib   # PDF / PNG raster export
pythonocc-core   # STEP import + 3D (OpenCASCADE bindings)
```

> `pythonocc-core` (OpenCASCADE) is easiest to install via **conda/conda‑forge**, not pip.

---

## Build & run from source

1. **Clone**
   ```bash
   git clone https://github.com/Mason363/pathstitch.git
   cd pathstitch
   ```

2. **Create the Python environment** (conda recommended because of `pythonocc-core`):
   ```bash
   conda create -n pathstitch python=3.11
   conda activate pathstitch
   conda install -c conda-forge pythonocc-core
   pip install -r pathstitch_core/requirements.txt
   pip install matplotlib
   ```

3. **Verify the backend works:**
   ```bash
   PYTHONPATH=. python pathstitch_core/test_dxf_ops.py   # should print "ALL TESTS PASSED SUCCESSFULLY!"
   ```

4. **Point the app at your interpreter.** Open
   [`Pathstitch/Pathstitch/Bridge/PythonBridge.swift`](Pathstitch/Pathstitch/Bridge/PythonBridge.swift)
   and set the two paths near the top to match your machine:
   ```swift
   private let pythonPath  = "/opt/homebrew/Caskroom/miniconda/base/envs/pathstitch/bin/python"
   private let projectPath = "/absolute/path/to/this/repo"
   ```
   (`echo $CONDA_PREFIX/bin/python` while the env is active gives you the first one.)

5. **Build & run** in Xcode (open `Pathstitch/Pathstitch.xcodeproj`, ⌘R), or from the CLI:
   ```bash
   cd Pathstitch
   xcodebuild -project Pathstitch.xcodeproj -scheme Pathstitch -configuration Debug build
   ```

---

## How distribution works

The release app no longer depends on your conda env or repo path. At launch, `PythonBridge` looks for a
bundled interpreter at `Pathstitch.app/Contents/Resources/pyenv/bin/python3.11` and a bundled copy of
`pathstitch_core` next to it; if present (a packaged build) it uses those, otherwise it falls back to the
developer conda env + repo (a build run straight from Xcode). So:

- **From Xcode** → uses your local env (set the two fallback paths once, as in [Build & run](#build--run-from-source)).
- **From a packaged `.dmg`** → uses the bundled env. Fully self‑contained.

**Platform:** the bundled env is **Apple‑Silicon (arm64)**, so the `.dmg` targets **Apple‑Silicon Macs**.
For Intel you'd repackage on an Intel Mac (or build a universal env).

---

## Building a `.dmg` (one command)

```bash
bash scripts/package_app.sh
# → dist/Pathstitch-1.0.dmg   (~400 MB, self-contained, ad-hoc signed)
```

The script: builds the Release `.app`, copies a **trimmed** Python env (≈2.8 GB → ≈1.1 GB; OpenCASCADE
stays, dev‑only LLVM/Qt/VTK/headers are dropped) and `pathstitch_core` into `Contents/Resources/`, ad‑hoc
signs the bundle, and produces a **drag‑to‑install** `.dmg` (the app + an `Applications` symlink, so users
drag one onto the other). Override the env location with `CONDA_ENV=/path/to/env bash scripts/package_app.sh`.

### Prefer a prettier window? (`create-dmg`)

The `hdiutil` image the script makes is functional (app + Applications). For the classic window with a
background arrow, install `brew install create-dmg` and run it against `dist/Pathstitch.app`:

```bash
create-dmg --volname "Pathstitch" --window-size 540 380 \
  --icon "Pathstitch.app" 140 190 --app-drop-link 400 190 \
  --hide-extension "Pathstitch.app" "Pathstitch-1.0.dmg" "dist/Pathstitch.app"
```

> **Real notarization:** for a no‑warning install you'd need a paid **Apple Developer ID** signature +
> `xcrun notarytool`. Without it the app is ad‑hoc signed and users do the one‑time Gatekeeper bypass below.

---

## Installing a non‑notarized app

Because the app isn't notarized by Apple, Gatekeeper will warn the first time. Pick **one**:

**Option A — System Settings (works on every modern macOS, required on macOS 15+):**
1. Drag **Pathstitch** into **Applications** and double‑click it.
2. macOS says it "cannot be opened because Apple cannot check it for malicious software." Click **Done**.
3. Open **System Settings ▸ Privacy & Security**, scroll down, and click **Open Anyway** next to the
   Pathstitch message. Confirm with your password / Touch ID.

**Option B — Right‑click Open (macOS 14 only):**
- Right‑click (Control‑click) **Pathstitch.app ▸ Open ▸ Open**.
  *(Apple removed this shortcut starting in macOS 15 Sequoia — use Option A there.)*

**Option C — Terminal (fastest if you trust the source):**
```bash
xattr -dr com.apple.quarantine /Applications/Pathstitch.app
```

---

## Checking your versions

**Your macOS version** (to confirm it's 14.0+):
- Menu  ▸ **About This Mac**, or in Terminal:
  ```bash
  sw_vers -productVersion
  ```

**The app's minimum macOS** (from a built `.app`):
```bash
plutil -p /Applications/Pathstitch.app/Contents/Info.plist | grep LSMinimumSystemVersion
```

**The deployment target in source** (what you'd change to support older systems):
```bash
grep MACOSX_DEPLOYMENT_TARGET Pathstitch/Pathstitch.xcodeproj/project.pbxproj   # → 14.0
```

**Your toolchain** (to build from source):
```bash
xcodebuild -version     # Xcode + build number
swift --version         # Swift toolchain
python --version        # should be 3.11.x in the pathstitch env
```

---

## Project layout

```
pathstitch/
├── Pathstitch/                     # Xcode project + Swift sources
│   ├── Pathstitch.xcodeproj
│   ├── Pathstitch/                 # the main app target
│   │   ├── App/                    # AppState, keybinds, toolbar layout
│   │   ├── Bridge/PythonBridge.swift
│   │   ├── Modes/{TwoDMode,ThreeDMode}/
│   │   └── Welcome/                # start screen + window management
│   ├── DxfPreviewer/               # QuickLook preview extension
│   └── PathstitchThumbnail/        # Finder thumbnail extension
├── pathstitch_core/                # Python geometry engine
│   ├── worker.py                   # persistent JSON worker
│   ├── dxf_ops.py                  # 2D operations
│   ├── step_ops.py · surface_unfold.py · net_unfold.py   # 3D / unfolding
│   └── requirements.txt
└── README.md
```

---

## License & credits

Built with ❤️ by **Mason Chen**.

This project is a personal/work‑in‑progress build; add a license file if you intend to share or accept
contributions.
