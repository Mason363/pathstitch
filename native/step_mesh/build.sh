#!/bin/bash
# Rebuilds the foxtrot-backed STEP tessellation static library used by the
# QuickLook extensions. Run this only when the Rust crate or its foxtrot pin
# changes — the produced lib/libstep_mesh.a is committed so the Xcode build does
# NOT need a Rust toolchain. Requires `cargo` (https://rustup.rs).
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.cargo/bin:$PATH"
cargo build --release
mkdir -p lib
cp target/release/libstep_mesh.a lib/libstep_mesh.a
echo "Updated lib/libstep_mesh.a ($(du -h lib/libstep_mesh.a | cut -f1))"
