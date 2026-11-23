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

	var motion := root.get_node_or_null("Motion")
	if motion != null:
		motion.set("enabled", false)   # windows open at once for screenshots (Phase 20 part 7)
	root_node = main_scene.instantiate()
	root_node.set("show_main_menu_at_start", false)   # Phase 20 part 9: shot separately
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
	# the world is built a couple of frames after the loading screen (Phase 20 part 9)
	for _i in range(120):
		if root_node.get("bridge") != null and bool(root_node.get("title_screens") != null and not root_node.get("title_screens").visible):
			break
		await process_frame

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

	# Phase 20 part 2: the province's buildings and build menu (building and goods icons).
	root_node.set("current_prov_tab", "economy")
	root_node.set("prov_show_build", true)
	root_node.call("_refresh_province_panel")
	await _save_shot("godot_province_build.png")
	root_node.set("prov_show_build", false)
	root_node.set("current_prov_tab", "overview")

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
		["_toggle_religion_window", "godot_religion_window.png"],
		["_toggle_diplomacy_window", "godot_diplomacy.png"],
		["_toggle_wars_window", "godot_wars.png"],
		["_toggle_armies_window", "godot_armies.png"],
	]
	for entry in windows:
		root_node.call(entry[0])
		await _save_shot(entry[1])
		if entry[1] == "godot_court.png":
			var court_ui: Variant = root_node.get("court_ui")
			if court_ui is Node:
				for ch_n in (court_ui as Node).find_children("", "ScrollContainer", true, false):
					if ch_n is ScrollContainer:
						(ch_n as ScrollContainer).scroll_vertical = 360
						break
				await _save_shot("godot_court_council.png")

	root_node.call("_close_top_left_windows", "")

	# Nation picker & Game menu modals.
	root_node.call("_toggle_nation_picker")
	await _save_shot("godot_nation_picker.png")
	root_node.call("_toggle_nation_picker")

	root_node.call("_toggle_game_menu")
	await _save_shot("godot_game_menu.png")
	root_node.call("_toggle_game_menu")

	# Phase 20 part 9: main menu and loading screen (stand-ins until the paintings arrive).
	root_node.call("open_main_menu")
	await _save_shot("godot_main_menu.png")
	var ts: Control = root_node.get("title_screens")
	ts.call("show_loading")
	await _save_shot("godot_loading.png")
	ts.call("hide_screens")

	# Whole-world map & sample map modes.
	root_node.call("_show_whole_map")
	await _save_shot("godot_map_world.png")

	var mode_btns: Dictionary = root_node.get("map_mode_buttons")
	for mode_key in ["terrain", "religion", "diplomatic"]:
		if mode_btns.has(mode_key):
			(mode_btns[mode_key] as BaseButton).emit_signal("pressed")
			await _save_shot("godot_map_%s.png" % mode_key)

	# Phase 17: the 3D map, tilted as you zoom in (political mode).
	if mode_btns.has("political"):
		(mode_btns["political"] as BaseButton).emit_signal("pressed")
	var bosporus: Vector2 = bridge.call("getFocusPoint", 41.0, 29.0)
	root_node.call("focus_map_point", bosporus, 3.0)
	await _save_shot("godot_map_3d_balkans.png")
	var alps: Vector2 = bridge.call("getFocusPoint", 46.5, 9.5)
	root_node.call("focus_map_point", alps, 6.5)
	await _save_shot("godot_map_3d_alps.png")
	# Phase 17 part 2: towns, forts, ports and armies as 3D models.
	root_node.call("focus_map_point", bosporus + Vector2(-30, 10), 5.5)
	await _save_shot("godot_map_3d_models.png")
	var cairo: Vector2 = bridge.call("getFocusPoint", 30.0, 31.2)
	root_node.call("focus_map_point", cairo, 4.5)
	await _save_shot("godot_map_3d_islamic.png")
	var delhi: Vector2 = bridge.call("getFocusPoint", 28.6, 77.2)
	root_node.call("focus_map_point", delhi, 4.5)
	await _save_shot("godot_map_3d_indian.png")
	var steppe: Vector2 = bridge.call("getFocusPoint", 47.0, 55.0)
	root_node.call("focus_map_point", steppe, 4.0)
	await _save_shot("godot_map_3d_steppe.png")
	var tibet: Vector2 = bridge.call("getFocusPoint", 29.6, 91.1)
	root_node.call("focus_map_point", tibet, 4.5)
	await _save_shot("godot_map_3d_eastasian.png")
	var caucasus: Vector2 = bridge.call("getFocusPoint", 42.5, 44.0)
	root_node.call("focus_map_point", caucasus, 4.0)
	await _save_shot("godot_map_3d_caucasus.png")

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

	# Phase 10 Naval Snapshots (Venice, Adriatic & Aegean fleets, Fleet Panel, Naval Battle):
	bridge.call("startNewGame", "VEN")
	root_node.call("_after_world_replaced")
	await _settle(2)
	if mode_btns.has("political"):
		(mode_btns["political"] as BaseButton).emit_signal("pressed")
	var med_fp: Vector2 = bridge.call("getFocusPoint", 41.2, 19.5)
	var fleet_zoom := 2.8
	root_node.set("zoom", fleet_zoom)
	root_node.set("offset", root_node.call("_clamped_offset", root_node.size * 0.5 - med_fp * fleet_zoom, fleet_zoom))
	root_node.call("_sync_camera_uniforms")
	root_node.call("_refresh_fleets", true)
	await _save_shot("godot_fleets_map.png")

	# Open Venice Fleet Panel (SelectedFleetPanel at bottom-right + NaviesWindowPanel at top-left, zero overlap)
	var navies_info: Dictionary = bridge.call("getNaviesWindowDetails")
	var ven_fleets: Array = navies_info.get("fleets", [])
	var ven_fid := -1
	if not ven_fleets.is_empty() and ven_fleets[0] is Dictionary:
		ven_fid = int((ven_fleets[0] as Dictionary).get("fleetId", -1))
	if ven_fid >= 0:
		bridge.call("selectFleet", ven_fid)
	root_node.call("_toggle_fleets_window")
	root_node.call("_after_fleet_action")
	await _save_shot("godot_fleet_panel.png")

	root_node.call("_close_top_left_windows", "")
	if pp is Control:
		(pp as Control).visible = false

	# Trigger a Venice vs Ottoman naval battle in the Aegean Sea
	var tur_fp: Vector2 = bridge.call("getFocusPoint", 41.0, 29.0)
	var tur_sel: int = int(bridge.call("selectAt", int(round(tur_fp.x)), int(round(tur_fp.y))))
	if tur_sel >= 2:
		var tur_info: Dictionary = bridge.call("getSelectedProvinceDetails", false)
		var tur_cid: int = int(tur_info.get("ownerIndex", -1))
		if tur_cid >= 0:
			bridge.call("declareWar", tur_cid, 0, true)
	if ven_fid >= 0:
		var aeg_fp: Vector2 = bridge.call("getFocusPoint", 40.0, 25.4)
		bridge.call("orderFleetMoveAt", ven_fid, int(round(aeg_fp.x)), int(round(aeg_fp.y)))
		if ven_fleets.size() > 1 and ven_fleets[1] is Dictionary:
			var aeg_fid := int((ven_fleets[1] as Dictionary).get("fleetId", -1))
			if aeg_fid >= 0:
				bridge.call("orderFleetMoveAt", aeg_fid, int(round(aeg_fp.x)), int(round(aeg_fp.y)))
		bridge.call("setSpeed", 5)
		var n_steps := 0
		var found_battle := false
		var battle_sz := -1
		while n_steps < 800:
			bridge.call("tickFrame", 0.1)
			if bool(bridge.call("hasPendingBattlePrompt")):
				bridge.call("chooseAutoResolveBattle")
			var mf: Dictionary = bridge.call("getMapFleetsData")
			var bats: Array = mf.get("battles", [])
			for b_v in bats:
				if b_v is Dictionary:
					var bd: Dictionary = b_v
					var atag: String = str(bd.get("attackerTag", ""))
					var dtag: String = str(bd.get("defenderTag", ""))
					if atag == "VEN" or dtag == "VEN" or atag == "TUR" or dtag == "TUR":
						found_battle = true
						battle_sz = int(bd.get("seaZoneIndex", -1))
						break
			if found_battle:
				bridge.call("setSpeed", 0)
				break
			n_steps += 1
		if found_battle and battle_sz >= 0:
			var b_pt: Vector2 = bridge.call("getSeaZoneFocusPoint", battle_sz)
			var b_zoom := 5.0
			root_node.set("zoom", b_zoom)
			root_node.set("offset", root_node.call("_clamped_offset", root_node.size * 0.5 - b_pt * b_zoom, b_zoom))
			root_node.call("_sync_camera_uniforms")
		else:
			push_warning("No VEN vs TUR naval battle found within snapshot guard.")
	root_node.call("_toggle_wars_window")
	root_node.call("_after_fleet_action")
	await _save_shot("godot_naval_battle.png")

	# Phase 12: the Plague map and the Rebels window after five years. The
	# Ottoman peasants are taxed double from day one so a faction is brewing.
	bridge.call("startNewGame", "TUR")
	root_node.call("_after_world_replaced")
	root_node.call("_close_top_left_windows", "")
	bridge.call("setTaxLevel", 0, 2.0)
	bridge.call("advanceSimulationDays", 1825)
	root_node.call("_after_world_replaced")
	root_node.call("_select_map_mode", "plague")
	root_node.call("_show_whole_map")
	await _save_shot("godot_map_plague.png")
	root_node.call("_select_map_mode", "unrest")
	root_node.call("_toggle_rebels_window")
	await _save_shot("godot_rebels_window.png")
	root_node.call("_close_top_left_windows", "")

	# Phase 11 1520 Religion & Culture snapshot (simulate headless to 1520):
	bridge.call("startNewGame", "TUR")
	root_node.call("_after_world_replaced")
	root_node.call("_close_top_left_windows", "")
	bridge.call("advanceSimulationDays", 24400)
	var top_info: Dictionary = bridge.call("getPlayerTopBarDetails")
	var yr: int = int(top_info.get("year", 1453))
	while yr < 1520:
		bridge.call("advanceSimulationDays", 30)
		top_info = bridge.call("getPlayerTopBarDetails")
		yr = int(top_info.get("year", 1453))
	root_node.call("_after_world_replaced")
	if mode_btns.has("religion"):
		(mode_btns["religion"] as BaseButton).emit_signal("pressed")
	else:
		root_node.call("_select_map_mode", "religion")
	root_node.call("_show_whole_map")
	await _save_shot("godot_map_religion_1520.png")

	# Phase 13: Technology window and Institutions map after simulating past Printing Press (1462).
	bridge.call("startNewGame", "VEN")
	root_node.call("_after_world_replaced")
	root_node.call("_close_top_left_windows", "")
	bridge.call("advanceSimulationDays", 4400) # ~1465: Renaissance spreading + Printing Press at Mainz
	root_node.call("_after_world_replaced")
	root_node.call("_select_map_mode", "institutions")
	root_node.call("_show_whole_map")
	await _save_shot("godot_map_institutions.png")
	root_node.call("_toggle_tech_window")
	await _save_shot("godot_technology_window.png")
	root_node.call("_close_top_left_windows", "")

	# Phase 14: Historical event pop-up (advance Hungary until a historical or chronicle event fires).
	bridge.call("startNewGame", "HUN")
	root_node.call("_after_world_replaced")
	root_node.call("_close_top_left_windows", "")
	root_node.call("_select_map_mode", "political")
	var event_steps: int = 0
	while not bool(bridge.call("hasPendingEvent")) and event_steps < 120:
		bridge.call("advanceSimulationDays", 30)
		event_steps += 1
	root_node.call("_refresh_styles_and_country_labels")
	root_node.call("_refresh_top_bar")
	root_node.call("_open_event_popup")
	await _save_shot("godot_event_popup.png")
	var pending_ev: Dictionary = bridge.call("getPendingEventDetails")
	if bool(pending_ev.get("hasPending", false)):
		bridge.call("chooseEventOption", int(pending_ev.get("instanceID", -1)), 0)
		root_node.call("_on_event_resolved")

	print("All Godot snapshots captured to: " + out_dir)
	quit(0)
