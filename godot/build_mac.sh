#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${1:-release}"

echo "Building GezGodot ($CONFIG)..."
cd "$SCRIPT_DIR/swift"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

mkdir -p "$SCRIPT_DIR/bin"
cp -f "$BIN_DIR/libGezGodot.dylib" "$SCRIPT_DIR/bin/"

if [ -d "$BIN_DIR/SwiftGodotRuntime.framework" ]; then
    rm -rf "$SCRIPT_DIR/bin/SwiftGodotRuntime.framework"
    cp -R "$BIN_DIR/SwiftGodotRuntime.framework" "$SCRIPT_DIR/bin/"
fi

# Ensure @loader_path is present in rpath so Godot finds SwiftGodotRuntime.framework in godot/bin/
install_name_tool -add_rpath "@loader_path" "$SCRIPT_DIR/bin/libGezGodot.dylib" 2>/dev/null || true
codesign --force --sign - "$SCRIPT_DIR/bin/libGezGodot.dylib" 2>/dev/null || true

echo "Built and staged GDExtension into: $SCRIPT_DIR/bin/"
