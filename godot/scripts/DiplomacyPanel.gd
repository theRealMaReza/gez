extends PanelContainer

var main: Node = null
var content_box: VBoxContainer
var slots_label: Label
var coalition_label: Label
var search_edit: LineEdit
var country_picker: OptionButton
var target_box: VBoxContainer
var country_indices: Array[int] = []
var selected_target_index: int = -1
var selected_cb_index: int = 0
var confirm_break_truce: bool = false
var feedback_label: Label
var search_query: String = ""

func setup(p_main: Node) -> void:
	main = p_main
	name = "DiplomacyWindow"
	visible = false
	custom_minimum_size = Vector2(460.0, 560.0)
	position = Vector2(12.0, 92.0)
	add_theme_stylebox_override("panel", main.call("_make_panel_style"))

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	var header := HBoxContainer.new()
	root_vbox.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	title_box.add_child(main.call("_make_label", "Diplomacy", Color(0.97, 0.90, 0.68), 18))
	slots_label = main.call("_make_label", "Relation Slots: 0 / 0", Color(0.84, 0.80, 0.72), 12)
	title_box.add_child(slots_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close Diplomacy window"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	coalition_label = main.call("_make_label", "", Color(0.96, 0.56, 0.34), 12)
	coalition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coalition_label.visible = false
	root_vbox.add_child(coalition_label)

	var picker_row := HBoxContainer.new()
	picker_row.add_theme_constant_override("separation", 6)
	root_vbox.add_child(picker_row)

	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Filter country name or tag..."
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.text_changed.connect(_on_search_changed)
	picker_row.add_child(search_edit)

	country_picker = OptionButton.new()
	country_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	country_picker.item_selected.connect(_on_country_selected)
	root_vbox.add_child(country_picker)

	root_vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(436.0, 440.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 6)
	scroll.add_child(content_box)

	target_box = VBoxContainer.new()
	target_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_box.add_theme_constant_override("separation", 6)
	content_box.add_child(target_box)

func is_open() -> bool:
	return visible

func open_with_country(country_index: int = -1) -> void:
	if country_index >= 0:
		selected_target_index = country_index
		selected_cb_index = 0
		confirm_break_truce = false
		main.call("_call_bridge", "setSelectedDiplomacyCountry", [country_index], false)
	visible = true
	refresh()

func toggle_window() -> void:
	visible = not visible
	if visible:
		refresh()

func close_window() -> void:
	visible = false

func refresh_if_open() -> void:
	if visible:
		refresh()

func _on_search_changed(new_text: String) -> void:
	search_query = new_text
	refresh()

func _on_country_selected(item_idx: int) -> void:
	if item_idx >= 0 and item_idx < country_indices.size():
		selected_target_index = country_indices[item_idx]
		selected_cb_index = 0
		confirm_break_truce = false
		main.call("_call_bridge", "setSelectedDiplomacyCountry", [selected_target_index], false)
		refresh()

func refresh() -> void:
	if main == null or not visible:
		return
	var d_var: Variant = main.call("_call_bridge", "getDiplomacyDetails", [selected_target_index, search_query, confirm_break_truce], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("hasPlayer", false)):
		return

	var used: int = int(d.get("usedRelationSlots", 0))
	var cap: int = int(d.get("relationSlotsCap", 0))
	var over: bool = bool(d.get("overSlotLimit", false))
	slots_label.text = "Relation Slots: %d / %d%s" % [used, cap, " (Over limit)" if over else ""]
	slots_label.add_theme_color_override("font_color", Color(0.95, 0.42, 0.38) if over else Color(0.84, 0.80, 0.72))

	var coal_count: int = int(d.get("coalitionCount", 0))
	if coal_count > 0:
		coalition_label.visible = true
		coalition_label.text = "Coalition against us (%d): %s" % [coal_count, str(d.get("coalitionSummary", ""))]
	else:
		coalition_label.visible = false

	country_picker.clear()
	country_indices.clear()
	var countries: Array = d.get("countries", [])
	var resolved_idx: int = int(d.get("selectedTargetIndex", -1))
	selected_target_index = resolved_idx
	var picker_select: int = -1
	for item_v in countries:
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v
		var c_idx: int = int(item.get("index", -1))
		country_indices.append(c_idx)
		country_picker.add_item(str(item.get("displayName", "")))
		if c_idx == resolved_idx:
			picker_select = country_indices.size() - 1
	if picker_select >= 0:
		country_picker.select(picker_select)

	main.call("_clear_children", target_box)

	var target_var: Variant = d.get("target", {})
	var target: Dictionary = target_var if target_var is Dictionary else {}
	if not bool(target.get("hasTarget", false)):
		target_box.add_child(main.call("_make_label", "Select a country above or click a foreign province on the map.", Color(0.80, 0.75, 0.66), 13))
		return

	_build_target_section(target)

func _build_target_section(target: Dictionary) -> void:
	var t_idx: int = int(target.get("index", -1))
	var t_tag: String = str(target.get("tag", ""))
	var t_name: String = str(target.get("name", ""))
	var cr: int = int(target.get("colorR", 196))
	var cg: int = int(target.get("colorG", 182))
	var cb: int = int(target.get("colorB", 150))

	# Target identity header + arms
	var id_row := HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 8)
	target_box.add_child(id_row)

	var arms := TextureRect.new()
	arms.custom_minimum_size = Vector2(36.0, 28.0)
	arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arms.texture = main.call("_get_country_arms_texture", t_tag, cr, cg, cb)
	id_row.add_child(arms)

	var id_col := VBoxContainer.new()
	id_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_row.add_child(id_col)
	id_col.add_child(main.call("_make_label", "%s (%s)" % [t_name, t_tag], Color(0.97, 0.90, 0.68), 16))
	id_col.add_child(main.call("_make_label", "%s · %s" % [str(target.get("government", "")), str(target.get("religion", ""))], Color(0.80, 0.75, 0.66), 12))

	var at_war: bool = bool(target.get("atWar", false))
	var in_coalition: bool = bool(target.get("inCoalition", false))
	if at_war:
		id_row.add_child(main.call("_make_label", "[AT WAR]", Color(0.98, 0.38, 0.34), 12))
	elif in_coalition:
		id_row.add_child(main.call("_make_label", "[COALITION]", Color(0.98, 0.62, 0.25), 12))

	# Opinion / Trust / AE pills
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 10)
	target_box.add_child(stats_row)
	var opinion: int = int(target.get("opinion", 0))
	var trust: int = int(target.get("trust", 50))
	var ae: int = int(target.get("ae", 0))
	stats_row.add_child(_make_stat_box("Opinion", "%+d" % opinion, Color(0.45, 0.90, 0.45) if opinion >= 0 else Color(0.95, 0.42, 0.38)))
	stats_row.add_child(_make_stat_box("Trust", "%d" % trust, Color(0.56, 0.80, 0.98)))
	stats_row.add_child(_make_stat_box("Aggressive Exp.", "%d" % ae, Color(0.95, 0.42, 0.38) if ae >= 50 else Color(0.96, 0.70, 0.36)))

	# Active Treaties
	var treaties: Array = target.get("treaties", [])
	if not treaties.is_empty():
		target_box.add_child(main.call("_make_label", "Active Treaties", Color(0.95, 0.85, 0.56), 13))
		for tr_v in treaties:
			if not (tr_v is Dictionary):
				continue
			var tr: Dictionary = tr_v
			var exp_str: String = str(tr.get("expiry", ""))
			var line: String = "  • %s%s" % [str(tr.get("label", "")), (" until " + exp_str) if not exp_str.is_empty() else ""]
			target_box.add_child(main.call("_make_label", line, Color(0.86, 0.84, 0.78), 12))

	target_box.add_child(HSeparator.new())
	target_box.add_child(main.call("_make_label", "Diplomatic Actions", Color(0.95, 0.85, 0.56), 13))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	target_box.add_child(grid)

	var allied: bool = bool(target.get("isAllied", false))
	var guaranteed: bool = bool(target.get("isGuaranteed", false))
	var nap: bool = bool(target.get("hasNonAggression", false))
	var access: bool = bool(target.get("hasMilitaryAccess", false))
	var embargoed: bool = bool(target.get("isEmbargoed", false))
	var can_improve: bool = bool(target.get("canImproveRelations", true))

	_add_action_button(grid, "Break Alliance" if allied else "Form Alliance", at_war, func() -> void:
		main.call("_call_bridge", "toggleAlliance", [t_idx], false)
		main.call("_after_diplomacy_action", true)
	)
	_add_action_button(grid, "Improve Relations (+15)", not can_improve, func() -> void:
		main.call("_call_bridge", "improveRelations", [t_idx], false)
		main.call("_after_diplomacy_action", false)
	)
	_add_action_button(grid, "Revoke Guarantee" if guaranteed else "Guarantee", at_war, func() -> void:
		main.call("_call_bridge", "toggleGuarantee", [t_idx], false)
		main.call("_after_diplomacy_action", true)
	)
	_add_action_button(grid, "Break Non-Aggression" if nap else "Non-Aggression Pact", at_war, func() -> void:
		main.call("_call_bridge", "toggleNonAggression", [t_idx], false)
		main.call("_after_diplomacy_action", true)
	)
	_add_action_button(grid, "Revoke Mil. Access" if access else "Grant Mil. Access", at_war, func() -> void:
		main.call("_call_bridge", "toggleMilitaryAccess", [t_idx], false)
		main.call("_after_diplomacy_action", false)
	)
	_add_action_button(grid, "Lift Embargo" if embargoed else "Embargo", false, func() -> void:
		main.call("_call_bridge", "toggleEmbargo", [t_idx], false)
		main.call("_after_diplomacy_action", false)
	)

	target_box.add_child(HSeparator.new())

	if at_war:
		var war_id: String = str(target.get("warID", ""))
		var peace_btn := Button.new()
		peace_btn.text = "Negotiate Peace"
		peace_btn.pressed.connect(func() -> void:
			close_window()
			main.call("_open_wars_and_peace", war_id)
		)
		target_box.add_child(peace_btn)
	else:
		_build_war_declaration_section(target, t_idx)

	feedback_label = main.call("_make_label", "", Color(0.95, 0.42, 0.38), 12)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.visible = false
	target_box.add_child(feedback_label)

func _build_war_declaration_section(target: Dictionary, target_index: int) -> void:
	target_box.add_child(main.call("_make_label", "Casus Belli & War", Color(0.95, 0.85, 0.56), 13))
	var cbs: Array = target.get("casusBelli", [])
	if selected_cb_index >= cbs.size():
		selected_cb_index = 0

	if not cbs.is_empty():
		var cb_picker := OptionButton.new()
		for cb_v in cbs:
			if cb_v is Dictionary:
				cb_picker.add_item(str((cb_v as Dictionary).get("name", "Casus Belli")))
		cb_picker.select(selected_cb_index)
		cb_picker.item_selected.connect(func(idx: int) -> void:
			selected_cb_index = idx
			refresh()
		)
		target_box.add_child(cb_picker)

		var chosen_cb: Dictionary = cbs[selected_cb_index] if cbs[selected_cb_index] is Dictionary else {}
		var desc := main.call("_make_label", str(chosen_cb.get("description", "")), Color(0.84, 0.80, 0.72), 12) as Label
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target_box.add_child(desc)

		var cost_line := main.call("_make_label", "Goal: %s · %s" % [str(chosen_cb.get("warGoalLabel", "")), str(chosen_cb.get("costNote", ""))], Color(0.96, 0.78, 0.42), 12) as Label
		cost_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target_box.add_child(cost_line)

	var v_status: String = str(target.get("warValidationStatus", "invalid"))
	var v_msg: String = str(target.get("warValidationMessage", ""))
	if v_status == "invalid":
		var err_lbl := main.call("_make_label", v_msg, Color(0.95, 0.42, 0.38), 12) as Label
		err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target_box.add_child(err_lbl)
	elif v_status == "requiresTruceBreak":
		var cb_chk := CheckBox.new()
		cb_chk.text = v_msg
		cb_chk.button_pressed = confirm_break_truce
		cb_chk.toggled.connect(func(pressed: bool) -> void:
			confirm_break_truce = pressed
			refresh()
		)
		target_box.add_child(cb_chk)

	var decl_btn := Button.new()
	decl_btn.text = "Declare War"
	decl_btn.disabled = (v_status != "valid") or cbs.is_empty()
	decl_btn.modulate = Color(1.0, 0.65, 0.60) if not decl_btn.disabled else Color(0.6, 0.6, 0.6)
	decl_btn.pressed.connect(func() -> void:
		var res_var: Variant = main.call("_call_bridge", "declareWar", [target_index, selected_cb_index, confirm_break_truce], {})
		var res: Dictionary = res_var if res_var is Dictionary else {}
		if bool(res.get("ok", false)):
			confirm_break_truce = false
			if feedback_label != null:
				feedback_label.visible = false
			main.call("_after_diplomacy_action", true)
		else:
			if feedback_label != null:
				feedback_label.text = str(res.get("error", "War declaration failed."))
				feedback_label.visible = true
	)
	target_box.add_child(decl_btn)

func _make_stat_box(title: String, val_text: String, val_color: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	v.add_child(main.call("_make_label", title, Color(0.80, 0.75, 0.66), 11))
	v.add_child(main.call("_make_label", val_text, val_color, 14))
	return box

func _add_action_button(parent: Control, title: String, is_disabled: bool, on_press: Callable) -> void:
	var btn := Button.new()
	btn.text = title
	btn.disabled = is_disabled
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(on_press)
	parent.add_child(btn)
