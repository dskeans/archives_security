#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "1) Cleaning…"
cargo clean

echo "2) Building release lib…"
cargo build --release

echo "3) Scaffolding UDL…"
uniffi-bindgen scaffolding src/lib.rs --out-dir src/udl

UDL_FILE="$(ls src/udl/*.udl)"
echo "  → Generated $UDL_FILE"

echo "4) Generating Swift bindings…"
uniffi-bindgen generate \
  "$UDL_FILE" \
  --crate c2pa_uniffi_custom \
  --language swift \
  --out-dir src/ffi/swift

echo "5) Generating Python bindings…"
uniffi-bindgen generate \
  "$UDL_FILE" \
  --crate c2pa_uniffi_custom \
  --language python \
  --out-dir src/ffi/python

echo "✅ All done."