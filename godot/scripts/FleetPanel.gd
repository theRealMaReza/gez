extends Control

var main_view: Control = null

var fleets_window_panel: PanelContainer
var fleets_window_arms: TextureRect
var fleets_window_box: VBoxContainer

var selected_fleet_panel: PanelContainer
var sel_fleet_title_label: Label
var sel_fleet_owner_arms: TextureRect
var sel_fleet_owner_label: Label
var sel_fleet_box: VBoxContainer

var _last_sel_fleet_sig: String = ""
var _last_fleets_win_sig: String = ""

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_fleets_window_panel()
	_build_selected_fleet_panel()

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if main_view == null:
		return fallback
	return main_view.call("_call_bridge", method_name, args, fallback)

func _make_label(txt: String, col: Color, fsize: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", fsize)
	return lbl

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _add_kv_row(parent: VBoxContainer, label_txt: String, value_txt: String, val_col: Color = Color(0.95, 0.92, 0.84)) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _make_label(label_txt, Color(0.80, 0.75, 0.66), 12)
	row.add_child(l)
	var v := _make_label(value_txt, val_col, 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.clip_text = true
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(v)

func _build_fleets_window_panel() -> void:
	fleets_window_panel = PanelContainer.new()
	fleets_window_panel.name = "NaviesWindowPanel"
	fleets_window_panel.visible = false
	fleets_window_panel.custom_minimum_size = Vector2(430.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		fleets_window_panel.add_theme_stylebox_override("panel", main_view.call("_make_panel_style"))
	add_child(fleets_window_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	fleets_window_panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)
	fleets_window_arms = TextureRect.new()
	fleets_window_arms.custom_minimum_size = Vector2(26.0, 20.0)
	fleets_window_arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fleets_window_arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(fleets_window_arms)
	var title := _make_label("Navies & Dockyards", Color(0.97, 0.90, 0.68), 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close Navies window"
	close_btn.pressed.connect(func() -> void:
		fleets_window_panel.visible = false
		_call_bridge("setMoveModeForFleet", [-1], false)
		if main_view != null:
			main_view.call("_after_fleet_action")
	)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(404.0, 480.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	fleets_window_box = VBoxContainer.new()
	fleets_window_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fleets_window_box.add_theme_constant_override("separation", 6)
	scroll.add_child(fleets_window_box)

	fleets_window_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	fleets_window_panel.offset_top = 60.0

func _build_selected_fleet_panel() -> void:
	selected_fleet_panel = PanelContainer.new()
	selected_fleet_panel.name = "SelectedFleetPanel"
	selected_fleet_panel.visible = false
	selected_fleet_panel.custom_minimum_size = Vector2(400.0, 0.0)
	selected_fleet_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	selected_fleet_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if main_view != null and main_view.has_method("_make_panel_style"):
		selected_fleet_panel.add_theme_stylebox_override("panel", main_view.call("_make_panel_style"))
	add_child(selected_fleet_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	selected_fleet_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	sel_fleet_title_label = _make_label("Fleet", Color(0.97, 0.90, 0.68), 17)
	sel_fleet_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sel_fleet_title_label)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Deselect fleet"
	close_btn.pressed.connect(func() -> void:
		_call_bridge("clearSelectedFleet")
		selected_fleet_panel.visible = false
		if main_view != null:
			main_view.call("_after_fleet_action")
	)
	header.add_child(close_btn)

	var owner_row := HBoxContainer.new()
	owner_row.add_theme_constant_override("separation", 6)
	outer.add_child(owner_row)
	sel_fleet_owner_arms = TextureRect.new()
	sel_fleet_owner_arms.custom_minimum_size = Vector2(22.0, 18.0)
	sel_fleet_owner_arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sel_fleet_owner_arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_row.add_child(sel_fleet_owner_arms)
	sel_fleet_owner_label = _make_label("Owner", Color(0.94, 0.90, 0.82), 13)
	sel_fleet_owner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_row.add_child(sel_fleet_owner_label)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(376.0, 320.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	sel_fleet_box = VBoxContainer.new()
	sel_fleet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_fleet_box.add_theme_constant_override("separation", 5)
	scroll.add_child(sel_fleet_box)

	selected_fleet_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	selected_fleet_panel.offset_right = -68.0

func toggle_fleets_window() -> void:
	if fleets_window_panel.visible:
		fleets_window_panel.visible = false
	else:
		fleets_window_panel.visible = true
		refresh_fleets_window()

func refresh_all() -> void:
	if fleets_window_panel != null and fleets_window_panel.visible:
		refresh_fleets_window()
	refresh_selected_fleet_panel()

func refresh_fleets_window() -> void:
	if fleets_window_panel == null or not fleets_window_panel.visible:
		return
	var d_var: Variant = _call_bridge("getNaviesWindowDetails", [], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("hasPlayer", false)):
		return

	var sig := var_to_str(d)
	if sig == _last_fleets_win_sig and fleets_window_box.get_child_count() > 0:
		return
	_last_fleets_win_sig = sig

	if main_view != null and main_view.has_method("_get_country_arms_texture"):
		fleets_window_arms.texture = main_view.call(
			"_get_country_arms_texture",
			str(d.get("tag", "")),
			int(d.get("colorR", 180)),
			int(d.get("colorG", 140)),
			int(d.get("colorB", 80))
		)

	_clear_children(fleets_window_box)
	_add_kv_row(fleets_window_box, "Sailor Pool", "%d / %d (+%d/mo)" % [int(d.get("sailors", 0)), int(d.get("maxSailors", 0)), int(d.get("monthlySailors", 0))])
	if main_view != null:
		main_view.call("bind_breakdown", fleets_window_box.get_child(fleets_window_box.get_child_count() - 1), func() -> Variant: return _call_bridge("getSailorsBreakdown", [], {}), "Maximum Sailors Breakdown")
	_add_kv_row(fleets_window_box, "Total Ships · Upkeep", "%d ships · %s" % [int(d.get("totalShips", 0)), str(d.get("upkeepText", "0 d/mo"))])
	if main_view != null:
		main_view.call("bind_breakdown", fleets_window_box.get_child(fleets_window_box.get_child_count() - 1), func() -> Variant: return _call_bridge("getMonthlyIncomeBreakdown", [], {}), "Monthly Treasury & Naval Upkeep")
	fleets_window_box.add_child(HSeparator.new())

	var fleets: Array = d.get("fleets", [])
	if fleets.is_empty():
		fleets_window_box.add_child(_make_label("No active fleets.", Color(0.78, 0.74, 0.66), 12))
	else:
		fleets_window_box.add_child(_make_label("Active Fleets (%d)" % fleets.size(), Color(0.97, 0.90, 0.68), 13))
		for f_v in fleets:
			if not (f_v is Dictionary):
				continue
			var f: Dictionary = f_v
			var fid: int = int(f.get("fleetId", -1))
			var card := VBoxContainer.new()
			card.add_theme_constant_override("separation", 2)
			fleets_window_box.add_child(card)

			var hdr := HBoxContainer.new()
			hdr.add_theme_constant_override("separation", 6)
			card.add_child(hdr)
			var f_btn := Button.new()
			f_btn.text = "%s (%d)" % [str(f.get("name", "Fleet")), int(f.get("ships", 0))]
			f_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			f_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			f_btn.pressed.connect(func() -> void:
				_call_bridge("clearSelectedArmy")
				_call_bridge("selectFleet", [fid], false)
				if main_view != null:
					main_view.call("_after_fleet_action")
			)
			hdr.add_child(f_btn)
			if bool(f.get("inBattle", false)):
				hdr.add_child(_make_label("BATTLE", Color(0.98, 0.34, 0.28), 11))

			var sub := "%s · Hull %d%% · Sup %d%% · %s" % [
				str(f.get("locationText", "")),
				int(f.get("avgHull", 100)),
				int(f.get("supply", 100)),
				str(f.get("admiralName", "No admiral"))
			]
			card.add_child(_make_label(sub, Color(0.80, 0.76, 0.68), 11))

	var builds: Array = d.get("constructions", [])
	if not builds.is_empty():
		fleets_window_box.add_child(HSeparator.new())
		fleets_window_box.add_child(_make_label("Ships Building (%d)" % builds.size(), Color(0.97, 0.90, 0.68), 13))
		for b_v in builds:
			if not (b_v is Dictionary):
				continue
			var b: Dictionary = b_v
			var row := HBoxContainer.new()
			fleets_window_box.add_child(row)
			var lbl := _make_label("%s in %s" % [str(b.get("shipName", "")), str(b.get("provinceName", ""))], Color(0.88, 0.85, 0.78), 12)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
			row.add_child(_make_label("%d/%d mo" % [int(b.get("monthsLeft", 0)), int(b.get("monthsTotal", 1))], Color(0.95, 0.84, 0.45), 11))

func refresh_selected_fleet_panel() -> void:
	if selected_fleet_panel == null:
		return
	var d_var: Variant = _call_bridge("getSelectedFleetDetails", [], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("hasSelection", false)):
		selected_fleet_panel.visible = false
		_last_sel_fleet_sig = ""
		return

	var sig := var_to_str(d)
	if sig == _last_sel_fleet_sig and selected_fleet_panel.visible:
		return
	_last_sel_fleet_sig = sig

	selected_fleet_panel.visible = true
	var fid: int = int(d.get("fleetId", -1))
	sel_fleet_title_label.text = str(d.get("name", "Fleet"))

	var owner_tag: String = str(d.get("ownerTag", ""))
	var owner_name: String = str(d.get("ownerName", ""))
	var cr: int = int(d.get("colorR", 120))
	var cg: int = int(d.get("colorG", 140))
	var cb: int = int(d.get("colorB", 160))
	if main_view != null and main_view.has_method("_get_country_arms_texture"):
		sel_fleet_owner_arms.texture = main_view.call("_get_country_arms_texture", owner_tag, cr, cg, cb)
	sel_fleet_owner_label.text = owner_name

	_clear_children(sel_fleet_box)

	var is_mine: bool = bool(d.get("isPlayerOwned", false))
	var is_move_mode: bool = bool(d.get("isMoveMode", false))
	if is_move_mode:
		var m_row := HBoxContainer.new()
		m_row.add_theme_constant_override("separation", 6)
		sel_fleet_box.add_child(m_row)
		var m_lbl := _make_label("Click a sea zone, friendly port, or hostile coast to sail", Color(0.55, 0.90, 1.0), 11)
		m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_row.add_child(m_lbl)
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.pressed.connect(func() -> void:
			_call_bridge("setMoveModeForFleet", [-1], false)
			if main_view != null:
				main_view.call("_after_fleet_action")
		)
		m_row.add_child(cancel_btn)

	if bool(d.get("inBattle", false)):
		var b_lbl := _make_label("NAVAL BATTLE: " + str(d.get("battleSummaryText", "")), Color(1.0, 0.55, 0.35), 12)
		b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sel_fleet_box.add_child(b_lbl)

	var st_lbl := _make_label("%s · %s" % [str(d.get("locationText", "")), str(d.get("statusText", ""))], Color(0.92, 0.88, 0.76), 12)
	st_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_fleet_box.add_child(st_lbl)

	_add_kv_row(sel_fleet_box, "Ships", "%d (%s)" % [int(d.get("shipCount", 0)), str(d.get("classSummaryText", ""))])
	if main_view != null:
		main_view.call("bind_tip", sel_fleet_box.get_child(sel_fleet_box.get_child_count() - 1), "Fleet Composition", "Warships, galleys, light ships and transports sailing together.")
	_add_kv_row(sel_fleet_box, "Crew · Avg Hull", "%d / %d · %d%%" % [int(d.get("totalCrew", 0)), int(d.get("totalMaxCrew", 0)), int(d.get("avgHull", 100))])
	if main_view != null:
		main_view.call("bind_breakdown", sel_fleet_box.get_child(sel_fleet_box.get_child_count() - 1), func() -> Variant: return _call_bridge("getSailorsBreakdown", [], {}), "Crew & National Sailors")
	_add_kv_row(sel_fleet_box, "Supply · Speed", "%d%% · %s%s" % [int(d.get("supply", 100)), str(d.get("speedText", "1.0x")), " (Inland)" if bool(d.get("isInlandSea", false)) else ""])
	if main_view != null:
		main_view.call("bind_tip", sel_fleet_box.get_child(sel_fleet_box.get_child_count() - 1), "Naval Supply & Speed", "Ships replenish supply in friendly ports. Galleys gain combat advantages in inland seas.")

	# Admiral row
	var adm_row := HBoxContainer.new()
	adm_row.add_theme_constant_override("separation", 6)
	sel_fleet_box.add_child(adm_row)
	var adm_lbl := _make_label("Admiral: " + str(d.get("admiralText", "No admiral")), Color(0.90, 0.85, 0.72), 12)
	adm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adm_lbl.clip_text = true
	adm_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	adm_row.add_child(adm_lbl)

	if is_mine:
		var opt := OptionButton.new()
		opt.clip_text = true
		opt.custom_minimum_size = Vector2(96.0, 0.0)
		opt.add_item("Change...", -1)
		opt.add_item("Unassign", -2)
		var cands: Array = d.get("admiralCandidates", [])
		for c_v in cands:
			if c_v is Dictionary:
				opt.add_item(str(c_v.get("label", "")), int(c_v.get("characterIndex", -1)))
		opt.item_selected.connect(func(item_idx: int) -> void:
			var id_val: int = opt.get_item_id(item_idx)
			if id_val == -1:
				return
			var char_idx: int = -1 if id_val == -2 else id_val
			_call_bridge("assignFleetAdmiral", [fid, char_idx], false)
			if main_view != null:
				main_view.call("_after_fleet_action")
		)
		adm_row.add_child(opt)

	# Action buttons (Move, Blockade, Split, Merge)
	if is_mine:
		var act_row := HFlowContainer.new()
		act_row.add_theme_constant_override("h_separation", 4)
		act_row.add_theme_constant_override("v_separation", 4)
		sel_fleet_box.add_child(act_row)

		var move_btn := Button.new()
		move_btn.text = "Cancel Move" if is_move_mode else "Sail / Move"
		move_btn.disabled = bool(d.get("inBattle", false))
		move_btn.pressed.connect(func() -> void:
			_call_bridge("setMoveModeForFleet", [-1 if is_move_mode else fid], false)
			if main_view != null:
				main_view.call("_after_fleet_action")
		)
		act_row.add_child(move_btn)

		var blk_btn := Button.new()
		blk_btn.text = "Blockade Enemy"
		blk_btn.disabled = not bool(d.get("canBlockadeEnemy", false))
		blk_btn.pressed.connect(func() -> void:
			_call_bridge("orderFleetBlockadeNearestEnemy", [fid], false)
			if main_view != null:
				main_view.call("_after_fleet_action")
		)
		act_row.add_child(blk_btn)

		var split_btn := Button.new()
		split_btn.text = "Split"
		split_btn.disabled = not bool(d.get("canSplit", false))
		split_btn.pressed.connect(func() -> void:
			_call_bridge("splitFleet", [fid], -1)
			if main_view != null:
				main_view.call("_after_fleet_action")
		)
		act_row.add_child(split_btn)

		var merge_btn := Button.new()
		merge_btn.text = "Merge"
		merge_btn.disabled = not bool(d.get("canMerge", false))
		merge_btn.pressed.connect(func() -> void:
			_call_bridge("mergeFleetsInLocation", [fid], false)
			if main_view != null:
				main_view.call("_after_fleet_action")
		)
		act_row.add_child(merge_btn)

	# Transport & Embark / Disembark controls
	var cap_men: int = int(d.get("transportCapacityMen", 0))
	var emb_men: int = int(d.get("embarkedMen", 0))
	if cap_men > 0 or emb_men > 0:
		sel_fleet_box.add_child(HSeparator.new())
		_add_kv_row(sel_fleet_box, "Transport Capacity", "%d / %d men embarked" % [emb_men, cap_men], Color(0.65, 0.90, 0.98))

		var embarkable: Array = d.get("embarkableArmies", [])
		for ea_v in embarkable:
			if not (ea_v is Dictionary):
				continue
			var ea: Dictionary = ea_v
			var aid: int = int(ea.get("armyId", -1))
			var row := HBoxContainer.new()
			sel_fleet_box.add_child(row)
			var l := _make_label("%s (%d)" % [str(ea.get("name", "")), int(ea.get("men", 0))], Color(0.88, 0.85, 0.76), 11)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var eb := Button.new()
			eb.text = "Embark"
			eb.disabled = not bool(ea.get("canEmbark", false))
			eb.pressed.connect(func() -> void:
				_call_bridge("embarkArmyOnFleet", [aid, fid], false)
				if main_view != null:
					main_view.call("_after_fleet_action")
			)
			row.add_child(eb)

		var embarked: Array = d.get("embarkedArmies", [])
		var disembark_targets: Array = d.get("disembarkTargets", [])
		for em_v in embarked:
			if not (em_v is Dictionary):
				continue
			var em: Dictionary = em_v
			var aid: int = int(em.get("armyId", -1))
			var row := HBoxContainer.new()
			sel_fleet_box.add_child(row)
			var l := _make_label("Aboard: %s (%d)" % [str(em.get("name", "")), int(em.get("men", 0))], Color(0.75, 0.96, 0.78), 11)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			if not disembark_targets.is_empty():
				var land_flow := HFlowContainer.new()
				land_flow.add_theme_constant_override("h_separation", 4)
				land_flow.add_theme_constant_override("v_separation", 4)
				sel_fleet_box.add_child(land_flow)
				var shown := 0
				for dt_v in disembark_targets:
					if not (dt_v is Dictionary) or shown >= 4:
						continue
					var dt: Dictionary = dt_v
					var p_idx: int = int(dt.get("provinceIndex", -1))
					var db := Button.new()
					var p_name: String = str(dt.get("name", "Shore"))
					db.text = "Land " + p_name + (" (!)" if bool(dt.get("isHostile", false)) else "")
					db.pressed.connect(func() -> void:
						_call_bridge("disembarkArmyFromFleet", [aid, p_idx], false)
						if main_view != null:
							main_view.call("_after_fleet_action")
					)
					land_flow.add_child(db)
					shown += 1

	# Ships list
	sel_fleet_box.add_child(HSeparator.new())
	var ships: Array = d.get("ships", [])
	sel_fleet_box.add_child(_make_label("Ships (%d)" % ships.size(), Color(0.95, 0.88, 0.68), 12))
	for s_v in ships:
		if not (s_v is Dictionary):
			continue
		var s: Dictionary = s_v
		var row := HBoxContainer.new()
		sel_fleet_box.add_child(row)
		var sl := _make_label("%s (%s)" % [str(s.get("name", "")), str(s.get("shipClass", ""))], Color(0.88, 0.85, 0.78), 11)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(sl)
		row.add_child(_make_label("H%d%% C%d/%d" % [int(s.get("hull", 100)), int(s.get("crew", 0)), int(s.get("maxCrew", 0))], Color(0.76, 0.84, 0.90), 11))
