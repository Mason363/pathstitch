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
VERSION="$(/usr/libexec/PlistBuddy -c 'Print MARKETING_VERSION' /dev/stdin 2>/dev/null <<<'' || true)"
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
  --exclude 'libvtk*' \
  --exclude 'libav*' --exclude 'libpostproc*' --exclude 'libswscale*' --exclude 'libswresample*' --exclude 'ffmpeg' \
  "$CONDA_ENV/" "$RES/pyenv/"

# ---- 3. bundle the geometry engine ------------------------------------------
echo "▶ Bundling pathstitch_core …"
rsync -a --exclude '__pycache__/' "$REPO/pathstitch_core/" "$RES/pathstitch_core/"

# ---- 4. ad-hoc sign (no Developer ID; hardened runtime stays off) -----------
echo "▶ Ad-hoc signing (this is the slow part) …"
codesign --force --deep --sign - "$APP_OUT"
codesign --verify --verbose=1 "$APP_OUT" || true

# ---- 5. build the drag-install .dmg -----------------------------------------
echo "▶ Building .dmg …"
STAGE="$(mktemp -d)"
cp -R "$APP_OUT" "$STAGE/Pathstitch.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Pathstitch" -srcfolder "$STAGE" -ov -format UDZO "$DMG_OUT" >/dev/null
rm -rf "$STAGE"

echo "✓ Done:"
echo "  app: $APP_OUT"
echo "  dmg: $DMG_OUT  ($(du -sh "$DMG_OUT" | cut -f1))"
