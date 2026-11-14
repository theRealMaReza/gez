extends Control

var main_view: Control = null

var armies_window_panel: PanelContainer
var armies_window_box: VBoxContainer

var selected_army_panel: PanelContainer
var sel_army_title_label: Label
var sel_army_owner_arms: TextureRect
var sel_army_owner_label: Label
var sel_army_rebel_label: Label
var sel_army_box: VBoxContainer

var prov_show_recruit: bool = false

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_armies_window_panel()
	_build_selected_army_panel()

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
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := _make_label(value_txt, val_col, 12)
	row.add_child(v)

func _build_armies_window_panel() -> void:
	armies_window_panel = PanelContainer.new()
	armies_window_panel.name = "ArmiesWindowPanel"
	armies_window_panel.visible = false
	armies_window_panel.custom_minimum_size = Vector2(430.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBoxFlat = main_view.call("_make_panel_style")
		armies_window_panel.add_theme_stylebox_override("panel", st)
	add_child(armies_window_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	armies_window_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := _make_label("Armies", Color(0.97, 0.90, 0.68), 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close Armies window"
	close_btn.pressed.connect(func() -> void:
		armies_window_panel.visible = false
		_call_bridge("setMoveModeForArmy", [-1], false)
		if main_view != null:
			main_view.call("_after_army_action")
	)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(404.0, 480.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	armies_window_box = VBoxContainer.new()
	armies_window_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armies_window_box.add_theme_constant_override("separation", 6)
	scroll.add_child(armies_window_box)

	armies_window_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	armies_window_panel.offset_top = 60.0

func _build_selected_army_panel() -> void:
	selected_army_panel = PanelContainer.new()
	selected_army_panel.name = "SelectedArmyPanel"
	selected_army_panel.visible = false
	selected_army_panel.custom_minimum_size = Vector2(360.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBoxFlat = main_view.call("_make_panel_style")
		selected_army_panel.add_theme_stylebox_override("panel", st)
	add_child(selected_army_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	selected_army_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	sel_army_title_label = _make_label("Army", Color(0.97, 0.90, 0.68), 17)
	sel_army_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sel_army_title_label)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Deselect army"
	close_btn.pressed.connect(func() -> void:
		_call_bridge("clearSelectedArmy")
		selected_army_panel.visible = false
		if main_view != null:
			main_view.call("_after_army_action")
	)
	header.add_child(close_btn)

	var owner_row := HBoxContainer.new()
	owner_row.add_theme_constant_override("separation", 6)
	outer.add_child(owner_row)
	sel_army_owner_arms = TextureRect.new()
	sel_army_owner_arms.custom_minimum_size = Vector2(22.0, 18.0)
	sel_army_owner_arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sel_army_owner_arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_row.add_child(sel_army_owner_arms)
	sel_army_owner_label = _make_label("Owner", Color(0.94, 0.90, 0.82), 13)
	sel_army_owner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_row.add_child(sel_army_owner_label)
	sel_army_rebel_label = _make_label("REBEL", Color(0.96, 0.36, 0.32), 12)
	sel_army_rebel_label.visible = false
	owner_row.add_child(sel_army_rebel_label)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(336.0, 290.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	sel_army_box = VBoxContainer.new()
	sel_army_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_army_box.add_theme_constant_override("separation", 5)
	scroll.add_child(sel_army_box)

	selected_army_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	selected_army_panel.offset_right = -68.0
	selected_army_panel.offset_left = -428.0

func toggle_armies_window() -> void:
	if armies_window_panel.visible:
		armies_window_panel.visible = false
	else:
		armies_window_panel.visible = true
		refresh_armies_window()

func refresh_all() -> void:
	if armies_window_panel != null and armies_window_panel.visible:
		refresh_armies_window()
	refresh_selected_army_panel()

func refresh_selected_army_panel() -> void:
	if selected_army_panel == null:
		return
	var d_var: Variant = _call_bridge("getSelectedArmyDetails", [], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("hasSelection", false)):
		selected_army_panel.visible = false
		return

	selected_army_panel.visible = true
	var aid: int = int(d.get("armyId", -1))
	sel_army_title_label.text = str(d.get("name", "Army"))

	var owner_tag: String = str(d.get("ownerTag", ""))
	var owner_name: String = str(d.get("ownerName", ""))
	var cr: int = int(d.get("ownerColorR", 180))
	var cg: int = int(d.get("ownerColorG", 140))
	var cb: int = int(d.get("ownerColorB", 80))
	if main_view != null and main_view.has_method("_get_country_arms_texture"):
		var tex: Texture2D = main_view.call("_get_country_arms_texture", owner_tag, cr, cg, cb)
		sel_army_owner_arms.texture = tex
	sel_army_owner_label.text = owner_name
	sel_army_rebel_label.visible = bool(d.get("isRebel", false))

	_clear_children(sel_army_box)

	# Move mode banner
	var is_move_mode: bool = bool(d.get("isMoveMode", false))
	if is_move_mode:
		var move_row := HBoxContainer.new()
		move_row.add_theme_constant_override("separation", 6)
		sel_army_box.add_child(move_row)
		var m_lbl := _make_label("Click any province on the map to march", Color(1.0, 0.88, 0.38), 12)
		m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		move_row.add_child(m_lbl)
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.pressed.connect(func() -> void:
			_call_bridge("setMoveModeForArmy", [-1], false)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		move_row.add_child(cancel_btn)

	# Status + province button
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	sel_army_box.add_child(status_row)
	var st_lbl := _make_label(str(d.get("statusText", "")), Color(0.92, 0.88, 0.76), 12)
	st_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_row.add_child(st_lbl)
	var prov_idx: int = int(d.get("provinceIndex", -1))
	var prov_name: String = str(d.get("provinceName", "Province"))
	if prov_idx >= 0:
		var p_btn := Button.new()
		p_btn.text = prov_name
		p_btn.tooltip_text = "Inspect province"
		p_btn.pressed.connect(func() -> void:
			if main_view != null:
				main_view.call("_select_province_by_index", prov_idx)
		)
		status_row.add_child(p_btn)

	# Commander row + Assign commander menu
	var cmd_row := HBoxContainer.new()
	cmd_row.add_theme_constant_override("separation", 6)
	sel_army_box.add_child(cmd_row)
	var cmd_lbl := _make_label("Commander: " + str(d.get("commanderText", "No commander")), Color(0.94, 0.90, 0.82), 12)
	cmd_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_row.add_child(cmd_lbl)

	if bool(d.get("canAssignCommander", false)):
		var cmd_menu := MenuButton.new()
		cmd_menu.text = "Assign commander..."
		cmd_menu.flat = false
		var popup := cmd_menu.get_popup()
		popup.add_item("None (Unassign)", 999999)
		var cands_var: Variant = d.get("commanderCandidates", [])
		var cands: Array = cands_var if cands_var is Array else []
		for c_item in cands:
			if c_item is Dictionary:
				var c_dict: Dictionary = c_item
				popup.add_item(str(c_dict.get("label", "Commander")), int(c_dict.get("characterIndex", 0)))
		popup.id_pressed.connect(func(chosen_id: int) -> void:
			var target_char: int = -1 if chosen_id == 999999 else chosen_id
			_call_bridge("assignArmyCommander", [aid, target_char], false)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		cmd_row.add_child(cmd_menu)

	# Strength, morale, combat power, upkeep, supply & attrition
	_add_kv_row(sel_army_box, "Strength", str(d.get("strengthText", "")))
	_add_kv_row(sel_army_box, "Morale", str(d.get("moraleText", "")))
	_add_kv_row(sel_army_box, "Combat power", str(d.get("combatPowerText", "")))
	_add_kv_row(sel_army_box, "Upkeep", str(d.get("upkeepText", "")))

	var over_supply: bool = bool(d.get("overSupply", false))
	var sup_col := Color(0.96, 0.42, 0.36) if over_supply else Color(0.95, 0.92, 0.84)
	_add_kv_row(sel_army_box, "Province supply", str(d.get("supplyText", "")), sup_col)
	_add_kv_row(sel_army_box, "Attrition", str(d.get("attritionText", "")), sup_col)

	# Action buttons: Move, Split, Merge, Disband
	if bool(d.get("isPlayerOwned", false)):
		var act_row := HBoxContainer.new()
		act_row.add_theme_constant_override("separation", 6)
		sel_army_box.add_child(act_row)

		var move_btn := Button.new()
		move_btn.text = "Pick province..." if is_move_mode else "Move"
		move_btn.disabled = not bool(d.get("canMove", false))
		move_btn.tooltip_text = "Click a province on the map (or right-click) to march this army"
		if is_move_mode:
			move_btn.modulate = Color(1.0, 0.88, 0.40)
		move_btn.pressed.connect(func() -> void:
			var next_id: int = -1 if is_move_mode else aid
			_call_bridge("setMoveModeForArmy", [next_id], false)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		act_row.add_child(move_btn)

		var split_btn := Button.new()
		split_btn.text = "Split"
		split_btn.disabled = not bool(d.get("canSplit", false))
		split_btn.tooltip_text = "Split half the regiments into a new detachment"
		split_btn.pressed.connect(func() -> void:
			_call_bridge("splitArmy", [aid], -1)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		act_row.add_child(split_btn)

		var merge_cnt: int = int(d.get("mergeCount", 0))
		var merge_btn := Button.new()
		merge_btn.text = ("Merge (+%d)" % merge_cnt) if merge_cnt > 0 else "Merge"
		merge_btn.disabled = not bool(d.get("canMerge", false))
		merge_btn.tooltip_text = "Merge all friendly armies in this province into this army"
		merge_btn.pressed.connect(func() -> void:
			_call_bridge("mergeArmies", [aid], false)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		act_row.add_child(merge_btn)

		var disband_btn := Button.new()
		disband_btn.text = "Disband"
		disband_btn.disabled = not bool(d.get("canDisband", false))
		disband_btn.modulate = Color(1.0, 0.65, 0.60)
		disband_btn.tooltip_text = "Disband army (levies return to home pops; 50% of professionals return to manpower)"
		disband_btn.pressed.connect(func() -> void:
			_call_bridge("disbandArmy", [aid], false)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		act_row.add_child(disband_btn)

	sel_army_box.add_child(HSeparator.new())

	# Regiments by type and origin
	var regs_var: Variant = d.get("regiments", [])
	var regs: Array = regs_var if regs_var is Array else []
	sel_army_box.add_child(_make_label("Regiments (%d)" % regs.size(), Color(0.96, 0.90, 0.72), 13))
	var summary_lbl := _make_label(str(d.get("regimentSummary", "")), Color(0.82, 0.78, 0.68), 11)
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_army_box.add_child(summary_lbl)

	for r_item in regs:
		if not (r_item is Dictionary):
			continue
		var r_dict: Dictionary = r_item
		var u_name: String = str(r_dict.get("unitName", "Regiment"))
		var u_cat: String = str(r_dict.get("category", ""))
		var orig: String = str(r_dict.get("origin", "Professional"))
		var home_prov: String = str(r_dict.get("homeProvinceName", ""))
		var men: int = int(r_dict.get("men", 0))
		var max_men: int = int(r_dict.get("maxMen", 1000))
		var mor_txt: String = str(r_dict.get("moraleText", ""))

		var orig_tag: String = orig + (" · " + home_prov if not home_prov.is_empty() else "")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		sel_army_box.add_child(row)

		var left_lbl := _make_label("%s (%s) [%s]" % [u_name, u_cat, orig_tag], Color(0.94, 0.90, 0.82), 11)
		left_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left_lbl)

		var right_lbl := _make_label("%d/%d · Mor %s" % [men, max_men, mor_txt], Color(0.84, 0.80, 0.72), 11)
		row.add_child(right_lbl)

func refresh_armies_window() -> void:
	if armies_window_box == null:
		return
	_clear_children(armies_window_box)
	var d_var: Variant = _call_bridge("getArmiesWindowDetails", [], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("valid", false)):
		armies_window_box.add_child(_make_label("No active player country.", Color(0.80, 0.75, 0.66), 13))
		return

	# 1. National manpower & force totals
	_add_kv_row(armies_window_box, "National manpower", str(d.get("manpowerText", "0 / 0")), Color(0.98, 0.92, 0.72))
	_add_kv_row(armies_window_box, "Standing professionals", "%d men" % int(d.get("standingMen", 0)))
	_add_kv_row(armies_window_box, "Raised levies", "%d men" % int(d.get("levyMen", 0)))
	_add_kv_row(armies_window_box, "Mercenaries", str(d.get("mercenaryText", "0 / 0 men")))
	_add_kv_row(armies_window_box, "Army upkeep", str(d.get("upkeepText", "−0.0 / month")))

	var attr_losses: int = int(d.get("lastAttritionLosses", 0))
	if attr_losses > 0:
		armies_window_box.add_child(_make_label("Lost %d men to starvation & camp disease last month" % attr_losses, Color(0.96, 0.42, 0.36), 11))

	var levy_btns := HBoxContainer.new()
	levy_btns.add_theme_constant_override("separation", 6)
	armies_window_box.add_child(levy_btns)

	var raise_all_btn := Button.new()
	raise_all_btn.text = "Raise all levies"
	raise_all_btn.disabled = not bool(d.get("canRaiseAllLevies", false))
	raise_all_btn.pressed.connect(func() -> void:
		_call_bridge("raiseAllLevies", [], false)
		if main_view != null:
			main_view.call("_after_army_action")
	)
	levy_btns.add_child(raise_all_btn)

	var disband_levies_btn := Button.new()
	disband_levies_btn.text = "Disband levies"
	disband_levies_btn.disabled = not bool(d.get("canDisbandLevies", false))
	disband_levies_btn.pressed.connect(func() -> void:
		_call_bridge("disbandAllLevies", [], false)
		if main_view != null:
			main_view.call("_after_army_action")
	)
	levy_btns.add_child(disband_levies_btn)

	armies_window_box.add_child(HSeparator.new())

	# 2. Field armies list
	var armies_var: Variant = d.get("armies", [])
	var armies_list: Array = armies_var if armies_var is Array else []
	armies_window_box.add_child(_make_label("Field armies (%d)" % armies_list.size(), Color(0.96, 0.90, 0.72), 14))

	var move_id: int = int(d.get("moveModeArmyId", -1))
	if move_id >= 0:
		var mv_row := HBoxContainer.new()
		mv_row.add_theme_constant_override("separation", 6)
		armies_window_box.add_child(mv_row)
		var mv_lbl := _make_label("Click any province on the map to march %s" % str(d.get("moveModeArmyName", "army")), Color(1.0, 0.88, 0.38), 12)
		mv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mv_row.add_child(mv_lbl)
		var mv_cancel := Button.new()
		mv_cancel.text = "Cancel"
		mv_cancel.pressed.connect(func() -> void:
			_call_bridge("setMoveModeForArmy", [-1], false)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		mv_row.add_child(mv_cancel)

	if armies_list.is_empty():
		armies_window_box.add_child(_make_label("No armies in the field. Recruit standing regiments or raise levies below.", Color(0.75, 0.70, 0.62), 12))

	var cands_var: Variant = d.get("commanderCandidates", [])
	var cands: Array = cands_var if cands_var is Array else []

	for a_item in armies_list:
		if not (a_item is Dictionary):
			continue
		var a_dict: Dictionary = a_item
		_build_army_card_in_window(a_dict, cands)

	# 3. Rebel armies section if any
	var rebels_var: Variant = d.get("rebelArmies", [])
	var rebels: Array = rebels_var if rebels_var is Array else []
	if not rebels.is_empty():
		armies_window_box.add_child(HSeparator.new())
		armies_window_box.add_child(_make_label("Vassal revolts (%d)" % rebels.size(), Color(0.96, 0.42, 0.36), 14))
		for rb_item in rebels:
			if rb_item is Dictionary:
				var rb: Dictionary = rb_item
				_add_kv_row(
					armies_window_box,
					str(rb.get("name", "Rebel Host")),
					"%d men at %s" % [int(rb.get("men", 0)), str(rb.get("provinceName", ""))],
					Color(0.96, 0.55, 0.48)
				)

	armies_window_box.add_child(HSeparator.new())

	# 4. Recruitment section ("Muster in <Province>")
	var muster_idx: int = int(d.get("musterProvinceIndex", -1))
	var muster_name: String = str(d.get("musterProvinceName", ""))
	if muster_idx >= 0 and not muster_name.is_empty():
		var m_hdr := HBoxContainer.new()
		m_hdr.add_theme_constant_override("separation", 6)
		armies_window_box.add_child(m_hdr)
		var m_lbl := _make_label("Muster in %s" % muster_name, Color(0.96, 0.90, 0.72), 14)
		m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_hdr.add_child(m_lbl)

		var can_levy: bool = bool(d.get("musterCanRaiseLevy", false))
		var avail_levy: int = int(d.get("musterAvailableLevy", 0))
		var levy_refusal: String = str(d.get("musterLevyRefusal", ""))
		var levy_btn := Button.new()
		levy_btn.text = ("Raise levy (%d)" % avail_levy) if can_levy else (levy_refusal if not levy_refusal.is_empty() else "Raise levy")
		levy_btn.disabled = not can_levy
		levy_btn.tooltip_text = levy_refusal if not levy_refusal.is_empty() else "Raise province levies from local pops"
		levy_btn.pressed.connect(func() -> void:
			_call_bridge("raiseLeviesInProvince", [muster_idx], false)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		m_hdr.add_child(levy_btn)

		var units_var: Variant = d.get("recruitUnits", [])
		var units: Array = units_var if units_var is Array else []
		_build_recruit_unit_rows(armies_window_box, units, muster_idx)
	else:
		armies_window_box.add_child(_make_label("Select one of your provinces to recruit regiments.", Color(0.75, 0.70, 0.62), 12))

func _build_army_card_in_window(a_dict: Dictionary, cands: Array) -> void:
	var aid: int = int(a_dict.get("armyId", -1))
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)
	armies_window_box.add_child(card)

	var top_row := HBoxContainer.new()
	card.add_child(top_row)
	var name_btn := Button.new()
	name_btn.text = str(a_dict.get("name", "Army"))
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_sel: bool = bool(a_dict.get("isSelected", false))
	name_btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42) if is_sel else Color(0.96, 0.92, 0.82))
	name_btn.pressed.connect(func() -> void:
		_call_bridge("selectArmy", [aid], false)
		if main_view != null:
			main_view.call("_after_army_action")
	)
	top_row.add_child(name_btn)

	var men_upkeep := "%d men · %s" % [int(a_dict.get("men", 0)), str(a_dict.get("upkeepText", "0.0/mo"))]
	top_row.add_child(_make_label(men_upkeep, Color(0.86, 0.82, 0.74), 12))

	var loc_row := HBoxContainer.new()
	loc_row.add_theme_constant_override("separation", 6)
	card.add_child(loc_row)
	var p_idx: int = int(a_dict.get("provinceIndex", -1))
	var p_btn := Button.new()
	p_btn.text = str(a_dict.get("provinceName", "Province"))
	p_btn.pressed.connect(func() -> void:
		if main_view != null:
			main_view.call("_select_province_by_index", p_idx)
	)
	loc_row.add_child(p_btn)

	if bool(a_dict.get("isMoving", false)):
		var move_txt := "-> %s (next: %s, %dd)" % [
			str(a_dict.get("destinationName", "")),
			str(a_dict.get("nextHopName", "")),
			int(a_dict.get("daysLeft", 1))
		]
		var mv_lbl := _make_label(move_txt, Color(0.84, 0.80, 0.70), 11)
		mv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		loc_row.add_child(mv_lbl)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		loc_row.add_child(spacer)

	var over_sup: bool = bool(a_dict.get("overSupply", false))
	loc_row.add_child(_make_label(
		str(a_dict.get("supplyText", "")),
		Color(0.96, 0.42, 0.36) if over_sup else Color(0.78, 0.74, 0.66),
		11
	))

	# Commander menu
	var cmd_row := HBoxContainer.new()
	cmd_row.add_theme_constant_override("separation", 6)
	card.add_child(cmd_row)
	cmd_row.add_child(_make_label("Commander:", Color(0.78, 0.74, 0.66), 11))
	var cmd_menu := MenuButton.new()
	cmd_menu.text = str(a_dict.get("commanderText", "Assign commander…"))
	cmd_menu.flat = false
	var popup := cmd_menu.get_popup()
	popup.add_item("None", 999999)
	for c_item in cands:
		if c_item is Dictionary:
			var c_dict: Dictionary = c_item
			popup.add_item(str(c_dict.get("label", "Commander")), int(c_dict.get("characterIndex", 0)))
	popup.id_pressed.connect(func(chosen_id: int) -> void:
		var target_char: int = -1 if chosen_id == 999999 else chosen_id
		_call_bridge("assignArmyCommander", [aid, target_char], false)
		if main_view != null:
			main_view.call("_after_army_action")
	)
	cmd_row.add_child(cmd_menu)

	var reg_lbl := _make_label(str(a_dict.get("regimentSummary", "")), Color(0.78, 0.74, 0.66), 11)
	reg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(reg_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 5)
	card.add_child(btn_row)

	var inspect_btn := Button.new()
	inspect_btn.text = "Inspect"
	inspect_btn.pressed.connect(func() -> void:
		_call_bridge("selectArmy", [aid], false)
		if main_view != null:
			main_view.call("_after_army_action")
	)
	btn_row.add_child(inspect_btn)

	var is_mv: bool = bool(a_dict.get("isMoveMode", false))
	var march_btn := Button.new()
	march_btn.text = "Pick province…" if is_mv else "March…"
	march_btn.disabled = not bool(a_dict.get("canMove", false))
	if is_mv:
		march_btn.modulate = Color(1.0, 0.88, 0.40)
	march_btn.pressed.connect(func() -> void:
		var next_id: int = -1 if is_mv else aid
		_call_bridge("setMoveModeForArmy", [next_id], false)
		if main_view != null:
			main_view.call("_after_army_action")
	)
	btn_row.add_child(march_btn)

	if bool(a_dict.get("canSplit", false)):
		var split_btn := Button.new()
		split_btn.text = "Split"
		split_btn.pressed.connect(func() -> void:
			_call_bridge("splitArmy", [aid], -1)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		btn_row.add_child(split_btn)

	if bool(a_dict.get("canMerge", false)):
		var merge_btn := Button.new()
		merge_btn.text = "Merge"
		merge_btn.pressed.connect(func() -> void:
			_call_bridge("mergeArmies", [aid], false)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		btn_row.add_child(merge_btn)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(sp)

	var dis_btn := Button.new()
	dis_btn.text = "Disband"
	dis_btn.disabled = not bool(a_dict.get("canDisband", false))
	dis_btn.modulate = Color(1.0, 0.65, 0.60)
	dis_btn.pressed.connect(func() -> void:
		_call_bridge("disbandArmy", [aid], false)
		if main_view != null:
			main_view.call("_after_army_action")
	)
	btn_row.add_child(dis_btn)

	armies_window_box.add_child(HSeparator.new())

func _build_recruit_unit_rows(parent: VBoxContainer, units: Array, province_idx: int) -> void:
	for u_item in units:
		if not (u_item is Dictionary):
			continue
		var u: Dictionary = u_item
		var u_idx: int = int(u.get("unitTypeIndex", -1))
		var u_name: String = str(u.get("name", "Unit"))
		var u_cat: String = str(u.get("category", ""))
		var stats_txt: String = str(u.get("statsText", ""))
		var prof_cost: int = int(u.get("profCost", 0))
		var can_prof: bool = bool(u.get("canRecruitProf", false))
		var prof_ref: String = str(u.get("profRefusal", ""))
		var merc_allowed: bool = bool(u.get("mercAllowed", false))
		var merc_cost: int = int(u.get("mercCost", 0))
		var can_merc: bool = bool(u.get("canHireMerc", false))
		var merc_ref: String = str(u.get("mercRefusal", ""))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		parent.add_child(row)

		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_col)
		info_col.add_child(_make_label("%s (%s)" % [u_name, u_cat], Color(0.95, 0.91, 0.82), 12))
		var st_line := stats_txt
		if not can_prof and not prof_ref.is_empty():
			st_line += " · " + prof_ref
		info_col.add_child(_make_label(st_line, Color(0.76, 0.72, 0.64), 11))

		var prof_btn := Button.new()
		prof_btn.text = "Recruit %dd" % prof_cost
		prof_btn.disabled = not can_prof
		prof_btn.tooltip_text = prof_ref if not prof_ref.is_empty() else "Recruit standing professional regiment"
		prof_btn.pressed.connect(func() -> void:
			_call_bridge("recruitProfessionalInProvince", [u_idx, province_idx], false)
			if main_view != null:
				main_view.call("_after_army_action")
		)
		row.add_child(prof_btn)

		if merc_allowed:
			var merc_btn := Button.new()
			merc_btn.text = "Merc %dd" % merc_cost
			merc_btn.disabled = not can_merc
			merc_btn.tooltip_text = merc_ref if not merc_ref.is_empty() else "Hire mercenary regiment for gold"
			merc_btn.pressed.connect(func() -> void:
				_call_bridge("hireMercenaryInProvince", [u_idx, province_idx], false)
				if main_view != null:
					main_view.call("_after_army_action")
			)
			row.add_child(merc_btn)

# Builds the Siege progress & Storm Assault section and Province Recruiting menu inside the Province Panel.
func append_province_military_sections(parent: VBoxContainer, d: Dictionary) -> void:
	var prov_idx: int = int(d.get("provinceIndex", -1))
	var is_mine: bool = bool(d.get("isPlayerOwned", false))

	# 1. Province levy & recruiting controls for player-owned provinces
	if is_mine and prov_idx >= 0:
		var levy_row := HBoxContainer.new()
		levy_row.add_theme_constant_override("separation", 6)
		parent.add_child(levy_row)
		var l_title := _make_label("Province levy", Color(0.80, 0.75, 0.66), 13)
		l_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		levy_row.add_child(l_title)

		var can_raise: bool = bool(d.get("canRaiseLevy", false))
		var avail: int = int(d.get("availableLevyMen", 0))
		var levy_ref: String = str(d.get("levyRefusal", ""))
		if can_raise:
			var raise_btn := Button.new()
			raise_btn.text = "Raise %d men" % avail
			raise_btn.pressed.connect(func() -> void:
				if bool(_call_bridge("raiseSelectedProvinceLevies", [], false)):
					if main_view != null:
						main_view.call("_after_army_action")
			)
			levy_row.add_child(raise_btn)
		else:
			var l_lbl := _make_label(str(d.get("levyText", "0 men")), Color(0.95, 0.92, 0.84), 13)
			l_lbl.tooltip_text = levy_ref
			levy_row.add_child(l_lbl)

		if bool(d.get("canDisbandLevies", false)):
			var disb_btn := Button.new()
			disb_btn.text = "Disband levies"
			disb_btn.pressed.connect(func() -> void:
				_call_bridge("disbandAllLevies", [], false)
				if main_view != null:
					main_view.call("_after_army_action")
			)
			levy_row.add_child(disb_btn)

		var rec_toggle := Button.new()
		rec_toggle.text = "Hide Recruit Menu" if prov_show_recruit else "Recruit Regiments..."
		rec_toggle.pressed.connect(func() -> void:
			prov_show_recruit = not prov_show_recruit
			if main_view != null:
				main_view.call("_refresh_province_panel")
		)
		parent.add_child(rec_toggle)

		if prov_show_recruit:
			var units_var: Variant = d.get("recruitUnits", [])
			var units: Array = units_var if units_var is Array else []
			_build_recruit_unit_rows(parent, units, prov_idx)

	# 2. Fortress & Siege progress + Storm Assault button
	var fort_lvl: int = int(d.get("fortLevel", 0))
	var is_besieged: bool = bool(d.get("isBesieged", false))
	var assault_res_txt: String = str(d.get("assaultResultText", ""))
	if fort_lvl > 0 or is_besieged or not assault_res_txt.is_empty():
		parent.add_child(HSeparator.new())
		if fort_lvl > 0:
			_add_kv_row(
				parent,
				"Fortress (Lv %d)" % fort_lvl,
				"%d / %d garrison" % [int(d.get("fortGarrison", 0)), int(d.get("maxGarrison", 0))]
			)
		elif is_besieged:
			parent.add_child(_make_label("Siege", Color(0.96, 0.90, 0.72), 13))

		if is_besieged:
			var besieger_name: String = str(d.get("siegeBesiegerName", ""))
			var phase_days: int = int(d.get("siegePhaseDaysRemaining", 0))
			_add_kv_row(
				parent,
				"Besieged by %s" % besieger_name,
				"%dd to roll" % phase_days,
				Color(0.96, 0.45, 0.38)
			)

			var prog_row := HBoxContainer.new()
			prog_row.add_theme_constant_override("separation", 8)
			parent.add_child(prog_row)
			prog_row.add_child(_make_label("Progress: %d" % int(d.get("siegeProgress", 0)), Color(0.95, 0.92, 0.84), 12))
			if bool(d.get("siegeBreached", false)):
				prog_row.add_child(_make_label("WALLS BREACHED", Color(1.0, 0.68, 0.24), 12))
			var port_txt: String = str(d.get("siegePortStatusText", ""))
			if not port_txt.is_empty():
				prog_row.add_child(_make_label(port_txt, Color(0.78, 0.74, 0.66), 11))

			var last_roll_txt: String = str(d.get("siegeLastRollText", ""))
			if not last_roll_txt.is_empty():
				parent.add_child(_make_label(last_roll_txt, Color(0.84, 0.80, 0.70), 11))

			if bool(d.get("siegeIsPlayerBesieger", false)):
				var assault_row := HBoxContainer.new()
				assault_row.add_theme_constant_override("separation", 8)
				parent.add_child(assault_row)
				var can_assault: bool = bool(d.get("siegeCanAssault", false))
				var assault_btn := Button.new()
				assault_btn.text = "Storm Assault"
				assault_btn.disabled = not can_assault
				if can_assault:
					assault_btn.modulate = Color(1.0, 0.55, 0.48)
				assault_btn.tooltip_text = "Order infantry and cavalry to storm the breached walls" if can_assault else "Walls must be breached before ordering a Storm Assault"
				assault_btn.pressed.connect(func() -> void:
					_call_bridge("assaultSelectedProvinceFort", [], {})
					if main_view != null:
						main_view.call("_after_army_action")
						main_view.call("_refresh_styles_and_country_labels")
				)
				assault_row.add_child(assault_btn)
				if not can_assault:
					assault_row.add_child(_make_label("Needs breach", Color(0.75, 0.70, 0.62), 11))

		if not assault_res_txt.is_empty():
			var status_kind: String = str(d.get("assaultResultStatus", ""))
			var res_col := Color(0.55, 0.94, 0.58) if status_kind == "captured" else (Color(0.98, 0.72, 0.34) if status_kind == "repelled" else Color(0.96, 0.42, 0.36))
			var res_lbl := _make_label(assault_res_txt, res_col, 12)
			res_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			parent.add_child(res_lbl)
