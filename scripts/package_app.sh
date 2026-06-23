#!/usr/bin/env bash
#
# package_app.sh — build a self-contained, distributable Pathstitch.app + .dmg.
#
# It bundles a trimmed copy of the Python backend (interpreter + pathstitch_core +
# all packages) inside Contents/Resources so the app runs on any Apple-Silicon Mac
# with NO conda/repo installed. Ad-hoc signed (no Apple Developer ID required) —
# recipients bypass Gatekeeper once (see README ▸ Installing a non-notarized app).
#
# Usage:   bash scripts/package_app.sh
# Output:  dist/Pathstitch-<version>.dmg
#
set -euo pipefail

# ---- config -----------------------------------------------------------------
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONDA_ENV="${CONDA_ENV:-/opt/homebrew/Caskroom/miniconda/base/envs/pathstitch}"
SCHEME="Pathstitch"
PROJ="$REPO/Pathstitch/Pathstitch.xcodeproj"
# Version for the DMG filename: honor an explicit VERSION env override, else read
# MARKETING_VERSION straight from the Xcode project (single source of truth).
VERSION="${VERSION:-$(grep -m1 'MARKETING_VERSION = ' "$PROJ/project.pbxproj" | sed 's/.*MARKETING_VERSION = //; s/;.*//')}"
VERSION="${VERSION:-1.0}"
DIST="$REPO/dist"
APP_OUT="$DIST/Pathstitch.app"
DMG_OUT="$DIST/Pathstitch-$VERSION.dmg"

echo "▶ Repo:     $REPO"
echo "▶ Conda env: $CONDA_ENV"
[ -x "$CONDA_ENV/bin/python3.11" ] || { echo "✗ python3.11 not found in $CONDA_ENV"; exit 1; }

# ---- 1. build the Release .app ----------------------------------------------
echo "▶ Building Release .app …"
rm -rf "$REPO/Pathstitch/build"
xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$REPO/Pathstitch/build" clean build >/dev/null
BUILT="$REPO/Pathstitch/build/Build/Products/Release/Pathstitch.app"
[ -d "$BUILT" ] || { echo "✗ build did not produce $BUILT"; exit 1; }

rm -rf "$DIST"; mkdir -p "$DIST"
cp -R "$BUILT" "$APP_OUT"
RES="$APP_OUT/Contents/Resources"

# ---- 2. bundle a trimmed Python env -----------------------------------------
echo "▶ Bundling Python env (trimming dev-only bloat) …"
rsync -a \
  --exclude 'include/' --exclude 'conda-meta/' \
  --exclude 'share/man/' --exclude 'share/doc/' --exclude 'share/gtk-doc/' \
  --exclude 'share/locale/' --exclude 'share/cmake/' \
  --exclude '__pycache__/' --exclude '*.a' \
  --exclude 'lib/cmake/' --exclude 'lib/pkgconfig/' \
  --exclude 'libLLVM*' --exclude 'libclang*' \
  --exclude 'qt6/' --exclude 'libQt6*' \
  --exclude 'libopenvino*' --exclude 'openvino*' \
  --exclude 'libvtk*' --exclude 'vtkmodules/' --exclude 'libviskores*' \
  --exclude 'libav*' --exclude 'libpostproc*' --exclude 'libswscale*' --exclude 'libswresample*' --exclude 'ffmpeg' \
  --exclude 'tests/' \
  "$CONDA_ENV/" "$RES/pyenv/"
# Notes on the additions above (all proven safe — see scripts/dmg/README.md):
#  • vtkmodules/ + libviskores* — VTK's own dylibs (libvtk*) are already dropped,
#    so its Python package and the VTK-m accelerator are dead weight. Nothing in
#    the app's import closure (pathstitch_core.worker → OCC / ezdxf / shapely /
#    numpy / scipy / PIL / rembg→pymatting→numba+skimage) imports VTK.
#  • tests/ — package test suites are never imported at runtime (~80 MB).
# The post-sign smoke test below fails the build if any of this broke an import.

# ---- 3. bundle the geometry engine ------------------------------------------
echo "▶ Bundling pathstitch_core …"
rsync -a --exclude '__pycache__/' "$REPO/pathstitch_core/" "$RES/pathstitch_core/"

# ---- 3b. strip symbols from bundled native libraries ------------------------
# `strip -x` removes only local symbols; exported/global symbols (PyInit_*, dylib
# externals, every dlsym target) are preserved, so modules still load and link.
# This is the same strip PyInstaller applies by default. It trims ~150–250 MB off
# heavy binaries (onnxruntime −38%, llvmlite −13%, OCC bindings, numpy/scipy).
# Done BEFORE codesign so the ad-hoc signatures match the stripped files. The
# smoke test in step 4b then proves nothing was broken before any DMG is built.
echo "▶ Stripping local symbols from native libs (lossless) …"
find "$RES/pyenv" \( -name '*.so' -o -name '*.dylib' \) -type f -print0 \
  | xargs -0 -n1 -P4 strip -x 2>/dev/null || true

# ---- 4. re-sign stripped libraries (so the smoke test can load them) --------
# Stripping invalidates the ad-hoc signatures conda ships on every arm64
# .so/.dylib, and on Apple Silicon the kernel SIGKILLs ("Killed: 9") any process
# that loads an invalidly-signed library. Re-sign every stripped Mach-O
# individually so the runtime smoke test below can dlopen them. The bundle is
# sealed LAST (step 4c), after the test, so the final CodeResources seal covers
# the exact tree we ship.
echo "▶ Re-signing stripped libraries …"
find "$RES/pyenv" \( -name '*.so' -o -name '*.dylib' \) -type f -print0 \
  | xargs -0 -n1 -P4 codesign --force --sign - 2>/dev/null || true

# ---- 4b. verify the trimmed+stripped runtime still imports everything -------
# Faithful to runtime: same interpreter, PYTHONHOME unset, PYTHONPATH=Resources
# (see PythonBridge.swift). Imports the app's full dependency closure — including
# rembg→pymatting→numba+skimage, which exercise the most aggressively stripped
# libs. A single failure aborts packaging so a broken bundle can never ship.
# The test must not mutate the bundle: -B/PYTHONDONTWRITEBYTECODE suppress .pyc,
# and NUMBA_CACHE_DIR/PYTHONPYCACHEPREFIX redirect numba's .nbi/.nbc caches (it
# JIT-compiles pymatting's cache=True kernels on import) to a throwaway dir.
echo "▶ Smoke-testing bundled Python runtime …"
SMOKE_CACHE="$(mktemp -d)"
PYTHONHOME= PYTHONDONTWRITEBYTECODE=1 PYTHONPYCACHEPREFIX="$SMOKE_CACHE" \
  NUMBA_CACHE_DIR="$SMOKE_CACHE" PYTHONPATH="$RES" \
  "$RES/pyenv/bin/python3.11" -B - <<'PY'
import importlib, sys
mods = [
    "pathstitch_core",
    "OCC.Core.STEPControl", "OCC.Core.BRepMesh", "OCC.Core.TopoDS", "OCC.Core.gp",
    "ezdxf", "shapely.geometry", "numpy", "scipy", "scipy.sparse", "scipy.spatial",
    "PIL.Image", "svgwrite", "potrace", "pdfplumber", "matplotlib",
    "psd_tools", "rembg", "pymatting", "numba", "skimage",
]
bad = []
for m in mods:
    try:
        importlib.import_module(m)
    except Exception as e:
        bad.append(f"{m}: {type(e).__name__}: {e}")
if bad:
    sys.stderr.write("✗ import failures after trim/strip:\n")
    for b in bad:
        sys.stderr.write("    " + b + "\n")
    sys.exit(1)
print(f"✓ all {len(mods)} critical modules import cleanly")
PY
rm -rf "$SMOKE_CACHE"

# ---- 4c. seal the bundle LAST, over a pristine tree -------------------------
# Remove any __pycache__/numba caches that slipped in (belt-and-suspenders), then
# apply the final ad-hoc signature. Verify is strict and NOT ignored: a broken
# seal aborts packaging so no mis-sealed bundle can ever reach a DMG.
echo "▶ Sealing the app bundle (final signature) …"
find "$APP_OUT" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
# Drop dangling symlinks (e.g. pyenv/bin/qmake6 → the excluded qt6/ dir). They are
# dead cruft, and `codesign --deep` nondeterministically tries to sign them and
# fails with "No such file or directory". Removing them makes sealing reliable.
find "$APP_OUT" -type l ! -exec test -e {} \; -delete 2>/dev/null || true
codesign --force --deep --sign - "$APP_OUT"
codesign --verify --deep --strict --verbose=1 "$APP_OUT"
echo "  ✓ bundle signature valid"

# ---- 5. build the drag-install .dmg -----------------------------------------
# A styled window (leather background + positioned icons + Applications arrow)
# when scripts/dmg/background.png exists; otherwise a plain drag-install DMG so
# packaging never depends on the artwork being present. Layout constants here
# MUST match scripts/dmg/background-template.svg.
echo "▶ Building .dmg …"
STAGE="$(mktemp -d)"
cp -R "$APP_OUT" "$STAGE/Pathstitch.app"
ln -s /Applications "$STAGE/Applications"

DMG_BG="$REPO/scripts/dmg/background.png"
VOL="Pathstitch"
# Square window (500×500 pt) so a square 10×10 cm leather background maps 1:1.
# Scale is 5 pt/mm: 100 mm → 500 pt. Finder y is top-down, so a point at model
# height h mm sits at y = 500 − h·5. Constants below match the engraving spec /
# scripts/dmg/background-template.svg.
WIN_W=500; WIN_H=500          # window content size (points)
# Icon centers are aligned to the hand-stitched frames in the leather photo
# (scripts/dmg/background.png), measured at fractional centers (0.301, 0.476)
# and (0.704, 0.478) — i.e. ~y=238 in the 500-pt window, slightly above middle.
APP_X=150;  APP_Y=238         # Pathstitch.app icon center  → left stitched frame
APPL_X=352; APPL_Y=238        # Applications shortcut center → right stitched frame
ICON_SIZE=100                 # 100 pt = 20 mm icon (fills the ~20 mm stitched frame)

build_plain_dmg() {
  hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG_OUT" >/dev/null
}

build_styled_dmg() {
  mkdir -p "$STAGE/.background"
  cp "$DMG_BG" "$STAGE/.background/background.png" || return 1

  # Finder draws a background picture at (image_px × 72 / dpi) points, NOT scaled
  # to the window. A too-high DPI (e.g. 600) renders the image tiny in a corner
  # instead of filling the window. Force the DPI so the PNG maps exactly onto the
  # WIN_W×WIN_H-pt window at full pixel resolution (1000 px ÷ 500 pt → 144 dpi).
  local bg_px
  bg_px=$(sips -g pixelWidth "$STAGE/.background/background.png" 2>/dev/null | awk '/pixelWidth/{print $2}')
  if [ -n "$bg_px" ] && [ "$bg_px" -gt 0 ]; then
    sips -s dpiWidth  "$(( bg_px * 72 / WIN_W ))" \
         -s dpiHeight "$(( bg_px * 72 / WIN_H ))" \
         "$STAGE/.background/background.png" >/dev/null 2>&1 || true
  fi

  local rw="$DIST/Pathstitch-rw.dmg"
  rm -f "$rw"
  hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDRW "$rw" >/dev/null || return 1

  local dev
  dev=$(hdiutil attach -readwrite -noverify -noautoopen "$rw" | grep -E '^/dev/' | head -1 | awk '{print $1}')
  [ -n "$dev" ] || return 1
  sleep 2

  osascript <<OSA || { hdiutil detach "$dev" >/dev/null 2>&1 || true; return 1; }
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, $((200 + WIN_W)), $((120 + WIN_H))}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to $ICON_SIZE
    set background picture of opts to file ".background:background.png"
    set position of item "Pathstitch.app" of container window to {$APP_X, $APP_Y}
    set position of item "Applications" of container window to {$APPL_X, $APPL_Y}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA

  sync
  hdiutil detach "$dev" >/dev/null 2>&1 || true
  hdiutil convert "$rw" -format UDZO -ov -o "$DMG_OUT" >/dev/null || { rm -f "$rw"; return 1; }
  rm -f "$rw"
}

if [ -f "$DMG_BG" ]; then
  echo "  • styling DMG with scripts/dmg/background.png …"
  build_styled_dmg || { echo "  • styled DMG failed — falling back to a plain drag-install DMG"; build_plain_dmg; }
else
  echo "  • no scripts/dmg/background.png — plain drag-install DMG (see scripts/dmg/README.md to add the leather background)"
  build_plain_dmg
fi
rm -rf "$STAGE"

echo "✓ Done:"
echo "  app: $APP_OUT"
echo "  dmg: $DMG_OUT  ($(du -sh "$DMG_OUT" | cut -f1))"
