#!/usr/bin/env bash
set -euo pipefail

# Copies GezCore scenario data, terrain texture, and heraldry PNGs into
# `<dest_resources_dir>/{data,Terrain,Heraldry}` for exported Godot builds.
DEST_RESOURCES="${1:?Usage: stage_resources.sh <dest_resources_dir>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$DEST_RESOURCES/data" "$DEST_RESOURCES/Terrain" "$DEST_RESOURCES/Heraldry"
cp -f "$ROOT_DIR/Packages/GezCore/Sources/GezCore/Resources/"* "$DEST_RESOURCES/data/"
cp -f "$ROOT_DIR/App/Resources/Terrain/terrain.jpg" "$ROOT_DIR/App/Resources/Terrain/height.png" "$DEST_RESOURCES/Terrain/"
cp -f "$ROOT_DIR/App/Resources/Heraldry/"*.png "$DEST_RESOURCES/Heraldry/"

echo "Staged game resources into: $DEST_RESOURCES"
