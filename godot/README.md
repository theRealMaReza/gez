# Gez (1453) — Godot 4.7 Proof of Concept

This folder contains the Phase 8.5 Step 2 proof of concept: the 1453 political map running in **Godot 4.7**, powered by `GezCore`'s pure-Swift `GameSession` through a **SwiftGodot** extension (`GezGodot`).

## How to Open and Run on Your Mac

1. **Build the Swift extension (one command in Terminal):**
   ```bash
   cd godot
   ./build_mac.sh
   ```
   This compiles `GezGodot` in Release mode (so Speed 5 stays fast) and copies `libGezGodot.dylib` and `SwiftGodotRuntime.framework` into `godot/bin/`.

2. **Open the project in Godot 4.7:**
   - Open **Godot 4.7** on your Mac.
   - Click **Import**, choose `godot/project.godot`, and click **Import & Edit**.
   - *(Or from Terminal: `/Applications/Godot.app/Contents/MacOS/Godot --path godot`)*

3. **Run the game:**
   - Press **Cmd + B** (or click the **Play** button in the top-right corner of the Godot editor).

## Controls in the Proof of Concept

- **Pan:** Click and drag with the mouse, two-finger scroll on a Mac trackpad, or use `WASD` / Arrow keys.
- **Zoom:** Scroll wheel, pinch on a Mac trackpad, `+` / `-` keys, or the `+` / `−` / `Fit` buttons in the bottom-right corner (`F` fits the whole map).
- **Select a province:** Click any province on the map to highlight its borders and see its name, owner, and development in the top bar.
- **Pause / Play:** Click **PAUSED / RUNNING** in the top bar or press **Space**.
- **Speeds 1–5:** Click `1`–`5` in the top bar or press keys `1`–`5`.
