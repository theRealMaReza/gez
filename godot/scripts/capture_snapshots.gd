extends SceneTree

# Renders screenshots of the main Godot map screen and each UI window, saving
# PNGs into $GEZ_GODOT_SNAPSHOT_DIR (or res://snapshots).
# Run: godot --path godot --script res://scripts/capture_snapshots.gd

var main_scene: PackedScene = load("res://scenes/Main.tscn")
var root_node: Control
var out_dir: String

func _initialize() -> void:
	out_dir = OS.get_environment("GEZ_GODOT_SNAPSHOT_DIR")
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("res://snapshots")
	DirAccess.make_dir_recursive_absolute(out_dir)

	# The game's default window (project.godot), so overflow shows up here.
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))

	root_node = main_scene.instantiate()
	root.add_child(root_node)
	call_deferred("_run_captures")

func _settle(frames: int = 3) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw

func _save_shot(filename: String) -> void:
	await _settle(4)
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		push_error("Empty viewport image for " + filename)
		return
	var path := out_dir.path_join(filename)
	var err := img.save_png(path)
	if err == OK:
		print("snapshot: " + path)
	else:
		push_error("Failed saving %s (err=%d)" % [path, err])

func _run_captures() -> void:
	await _settle(6)

	var bridge = root_node.get("bridge")
	if bridge == null:
		push_error("GezGodotBridge not loaded — aborting snapshots.")
		quit(1)
		return

	# Ensure paused at start date.
	bridge.call("setSpeed", 0)

	# Focus Konstantiniyye (~41N, 29E), open its province panel and market panel for main screen shot.
	var focus_pt: Vector2 = bridge.call("getFocusPoint", 41.0, 29.0)
	var sel_id: int = int(bridge.call("selectAt", int(round(focus_pt.x)), int(round(focus_pt.y))))
	if sel_id >= 2:
		root_node.call("_select_province_by_index", sel_id - 2)
		var details: Dictionary = bridge.call("getSelectedProvinceDetails", false)
		var mkt_idx: int = int(details.get("marketIndex", -1))
		if mkt_idx >= 0:
			root_node.call("_open_market_panel", mkt_idx)
	await _save_shot("godot_screen_main.png")

	# Close province/market panels for clean per-window captures.
	var pp = root_node.get("province_panel")
	if pp is Control:
		(pp as Control).visible = false
	var mp = root_node.get("market_panel")
	if mp is Control:
		(mp as Control).visible = false

	# Each top-left window.
	var windows := [
		["_toggle_budget_window", "godot_budget.png"],
		["_toggle_trade_window", "godot_trade.png"],
		["_toggle_court_window", "godot_court.png"],
		["_toggle_government_window", "godot_government.png"],
		["_toggle_diplomacy_window", "godot_diplomacy.png"],
		["_toggle_wars_window", "godot_wars.png"],
		["_toggle_armies_window", "godot_armies.png"],
	]
	for entry in windows:
		root_node.call(entry[0])
		await _save_shot(entry[1])

	root_node.call("_close_top_left_windows", "")

	# Nation picker & Game menu modals.
	root_node.call("_toggle_nation_picker")
	await _save_shot("godot_nation_picker.png")
	root_node.call("_toggle_nation_picker")

	root_node.call("_toggle_game_menu")
	await _save_shot("godot_game_menu.png")
	root_node.call("_toggle_game_menu")

	# Whole-world map & sample map modes.
	root_node.call("_show_whole_map")
	await _save_shot("godot_map_world.png")

	var mode_btns: Dictionary = root_node.get("map_mode_buttons")
	for mode_key in ["terrain", "religion", "diplomatic"]:
		if mode_btns.has(mode_key):
			(mode_btns[mode_key] as Button).emit_signal("pressed")
			await _save_shot("godot_map_%s.png" % mode_key)

	print("All Godot snapshots captured to: " + out_dir)
	quit(0)
