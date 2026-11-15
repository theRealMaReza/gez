#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${1:-release}"

echo "Building GezGodot ($CONFIG) for Linux..."
cd "$SCRIPT_DIR/swift"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

mkdir -p "$SCRIPT_DIR/bin"
cp -f "$BIN_DIR/libGezGodot.so" "$SCRIPT_DIR/bin/"
if [ -f "$BIN_DIR/libSwiftGodotRuntime.so" ]; then
    cp -f "$BIN_DIR/libSwiftGodotRuntime.so" "$SCRIPT_DIR/bin/"
fi

if command -v patchelf >/dev/null 2>&1; then
    patchelf --set-rpath '$ORIGIN' "$SCRIPT_DIR/bin/libGezGodot.so" || true
fi

echo "Built and staged Linux GDExtension into: $SCRIPT_DIR/bin/"
