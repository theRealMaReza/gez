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

	# Phase 9 Battle & Siege Assault Snapshots:
	# Start a fresh Ottoman game and march the Imperial Army to Kruje (660) to engage Albania.
	bridge.call("startNewGame", "TUR")
	await _settle(3)
	var army_id := -1
	var armies_info: Dictionary = bridge.call("getArmiesWindowDetails")
	for a_item in armies_info.get("armies", []):
		if a_item is Dictionary and str(a_item.get("name", "")).contains("Imperial"):
			army_id = int(a_item.get("armyId", -1))
			break
	if army_id < 0:
		var fallback_armies: Array = armies_info.get("armies", [])
		if not fallback_armies.is_empty():
			army_id = int(fallback_armies[0].get("armyId", -1))

	if army_id >= 0:
		bridge.call("orderArmyMove", army_id, 660)
		bridge.call("setSpeed", 5)
		var steps := 0
		while steps < 2500 and not bool(bridge.call("hasPendingBattlePrompt")):
			bridge.call("tickFrame", 0.1)
			steps += 1
		if bool(bridge.call("hasPendingBattlePrompt")):
			bridge.call("chooseLeadBattleInPerson")
			var bc: Variant = root_node.get("battle_choice_panel")
			if bc is Control:
				(bc as Control).visible = false
			var bv: Variant = root_node.get("battle_view")
			if bv is Control:
				bv.call("open_battle")
				bv.call("_select_all_player_units")
				bv.call("refresh_state")
				await _save_shot("godot_battle_deploy.png")

				bridge.call("startTacticalBattle")
				bridge.call("setTacticalBattleSpeed", 2)
				var st_b: Dictionary = bridge.call("getBattleState")
				var p_side_int := 1 if str(st_b.get("playerSide", "attacker")) == "defender" else 0
				var unit_indices: PackedStringArray = []
				var march_x := 460.0 if p_side_int == 0 else 650.0
				for u in st_b.get("units", []):
					if u is Dictionary and int(u.get("side", 0)) == p_side_int:
						unit_indices.append(str(int(u.get("index", -1))))
				var csv := ",".join(unit_indices)
				bridge.call("orderBattleStance", csv, "advance")
				bridge.call("orderBattleFrontline", csv, march_x, 180.0, march_x, 620.0)
				for _t in range(28):
					bridge.call("tickTacticalBattle", 0.5)
				bv.call("refresh_state")
				await _save_shot("godot_battle_fight.png")

				bridge.call("setTacticalBattleSpeed", 3)
				var guard := 0
				while guard < 1200:
					var cur_st: Dictionary = bridge.call("getBattleState")
					if str(cur_st.get("phase", "")) == "ended":
						break
					bridge.call("tickTacticalBattle", 0.5)
					guard += 1
				bv.call("refresh_state")
				await _save_shot("godot_battle_result.png")

				bridge.call("finishTacticalBattle")
				bv.call("close_battle")
				root_node.call("_on_tactical_battle_closed")

				# Deterministic breached fort storm assault: Muscovy besieging Tver (571).
				bridge.call("startNewGame", "MOS")
				await _settle(2)
				bridge.call("selectProvinceByIndex", 571)
				var tve_info: Dictionary = bridge.call("getSelectedProvinceDetails", false)
				var tve_cid := int(tve_info.get("ownerIndex", -1))
				bridge.call("declareWar", tve_cid, 0, true)
				var mos_armies: Array = bridge.call("getArmiesWindowDetails").get("armies", [])
				var mos_aid := -1
				if not mos_armies.is_empty() and mos_armies[0] is Dictionary:
					mos_aid = int(mos_armies[0].get("armyId", -1))
				if mos_aid >= 0:
					bridge.call("orderArmyMove", mos_aid, 571)
				bridge.call("setSpeed", 5)
				var siege_steps := 0
				var assault_opened := false
				while siege_steps < 400:
					bridge.call("tickFrame", 0.08)
					if bool(bridge.call("hasPendingBattlePrompt")):
						bridge.call("chooseAutoResolveBattle")
						if mos_aid >= 0:
							bridge.call("orderArmyMove", mos_aid, 571)
						bridge.call("setSpeed", 5)
					var req: Dictionary = bridge.call("requestStormAssaultChoice", 571)
					if bool(req.get("opened", false)):
						bridge.call("chooseLeadBattleInPerson")
						if bc is Control:
							(bc as Control).visible = false
						bv.call("open_battle")
						bv.call("_select_all_player_units")
						# Assign ladders / battering ram to attacking infantry regiments
						var ast: Dictionary = bridge.call("getBattleState")
						var inf_list: PackedStringArray = []
						for u in ast.get("units", []):
							if u is Dictionary and int(u.get("side", 0)) == 0 and str(u.get("category", "")) == "infantry":
								inf_list.append(str(int(u.get("index", -1))))
						if inf_list.size() >= 1:
							bridge.call("orderBattleSiegeEquipment", inf_list[0], "ladders")
						if inf_list.size() >= 2:
							bridge.call("orderBattleSiegeEquipment", inf_list[1], "ram")
						bridge.call("startTacticalBattle")
						bridge.call("setTacticalBattleSpeed", 2)
						for _s in range(18):
							bridge.call("tickTacticalBattle", 0.5)
						bv.call("refresh_state")
						await _save_shot("godot_assault.png")
						bridge.call("finishTacticalBattle")
						bv.call("close_battle")
						root_node.call("_on_tactical_battle_closed")
						assault_opened = true
						break
					siege_steps += 1
				if not assault_opened:
					push_warning("Tver siege did not breach within snapshot guard; godot_assault.png skipped.")
		else:
			push_warning("No field battle prompt occurred while marching Imperial Army to Kruje (660).")

	print("All Godot snapshots captured to: " + out_dir)
	quit(0)
