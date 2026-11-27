extends Control

# Holy Roman Empire — "Imperial Diet" window (Phase 20.8, mock-up A).
# Built from plain Godot controls styled by the shared Phase 20 Theme:
# - Emperor shield, ruler name, realm, and years on the throne
# - Imperial Authority progress bar (0..100) with monthly delta
# - The seven Prince-Electors' shields in a row with each elector's lean tag
# - The six Reichstag reforms as a ladder of plates (passed = green, next = with cost/button, later = faded)
# - Footer line with member count, Free Imperial City count, and player's Imperial favour

var main_view: Control = null
var diet_panel: PanelContainer = null

var emperor_shield: TextureRect
var emperor_ruler_lbl: Label
var emperor_realm_lbl: Label
var religious_lbl: Label

var authority_val_lbl: Label
var authority_bar: ProgressBar

var electors_row: HBoxContainer
var reforms_box: VBoxContainer
var footer_lbl: Label

var _last_sig: String = ""

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_panel()

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if main_view == null:
		return fallback
	return main_view.call("_call_bridge", method_name, args, fallback)

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _build_panel() -> void:
	diet_panel = PanelContainer.new()
	diet_panel.name = "ImperialDietPanel"
	diet_panel.visible = false
	diet_panel.custom_minimum_size = Vector2(660.0, 580.0)
	add_child(diet_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	diet_panel.add_child(outer)

	# Header: red banner title + gold close medallion
	var header := HBoxContainer.new()
	outer.add_child(header)

	var title_lbl := GezStyle.title("Imperial Diet")
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := GezStyle.close_button(close_window)
	close_btn.tooltip_text = "Close Imperial Diet"
	header.add_child(close_btn)

	# 1. Emperor card
	var emp_card := PanelContainer.new()
	emp_card.theme_type_variation = "Card"
	outer.add_child(emp_card)

	var emp_row := HBoxContainer.new()
	emp_row.add_theme_constant_override("separation", 12)
	emp_card.add_child(emp_row)

	emperor_shield = TextureRect.new()
	emperor_shield.custom_minimum_size = Vector2(52.0, 60.0)
	emperor_shield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emperor_shield.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emp_row.add_child(emperor_shield)

	var emp_info := VBoxContainer.new()
	emp_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emp_row.add_child(emp_info)

	emperor_ruler_lbl = GezStyle.as_heading(Label.new())
	emperor_ruler_lbl.text = "Holy Roman Emperor"
	emp_info.add_child(emperor_ruler_lbl)

	emperor_realm_lbl = Label.new()
	emperor_realm_lbl.text = ""
	emp_info.add_child(emperor_realm_lbl)

	religious_lbl = Label.new()
	religious_lbl.text = ""
	religious_lbl.visible = false
	emp_info.add_child(religious_lbl)

	# 2. Imperial Authority bar card
	var auth_card := PanelContainer.new()
	auth_card.theme_type_variation = "Card"
	outer.add_child(auth_card)

	var auth_box := VBoxContainer.new()
	auth_box.add_theme_constant_override("separation", 4)
	auth_card.add_child(auth_box)

	var auth_head := HBoxContainer.new()
	auth_box.add_child(auth_head)

	var auth_title := GezStyle.as_heading(Label.new())
	auth_title.text = "Imperial Authority"
	auth_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auth_head.add_child(auth_title)

	authority_val_lbl = Label.new()
	authority_val_lbl.text = "0 / 100"
	auth_head.add_child(authority_val_lbl)

	authority_bar = ProgressBar.new()
	authority_bar.min_value = 0.0
	authority_bar.max_value = 100.0
	authority_bar.value = 0.0
	authority_bar.show_percentage = false
	authority_bar.custom_minimum_size = Vector2(0.0, 18.0)
	auth_box.add_child(authority_bar)

	# 3. Seven Prince-Electors row card
	var elec_card := PanelContainer.new()
	elec_card.theme_type_variation = "Card"
	outer.add_child(elec_card)

	var elec_box := VBoxContainer.new()
	elec_box.add_theme_constant_override("separation", 6)
	elec_card.add_child(elec_box)

	var elec_title := GezStyle.as_heading(Label.new())
	elec_title.text = "Prince-Electors"
	elec_box.add_child(elec_title)

	electors_row = HBoxContainer.new()
	electors_row.alignment = BoxContainer.ALIGNMENT_CENTER
	electors_row.add_theme_constant_override("separation", 8)
	elec_box.add_child(electors_row)

	# 4. Reichstag Reforms ladder card
	var ref_card := PanelContainer.new()
	ref_card.theme_type_variation = "Card"
	ref_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(ref_card)

	var ref_outer := VBoxContainer.new()
	ref_outer.add_theme_constant_override("separation", 4)
	ref_card.add_child(ref_outer)

	var ref_title := GezStyle.as_heading(Label.new())
	ref_title.text = "Reichstag Reforms"
	ref_outer.add_child(ref_title)

	var ref_scroll := ScrollContainer.new()
	ref_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ref_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ref_scroll.custom_minimum_size = Vector2(620.0, 210.0)
	ref_outer.add_child(ref_scroll)

	reforms_box = VBoxContainer.new()
	reforms_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reforms_box.add_theme_constant_override("separation", 4)
	ref_scroll.add_child(reforms_box)

	# 5. Footer line
	footer_lbl = Label.new()
	footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_lbl.text = ""
	outer.add_child(footer_lbl)

func is_open() -> bool:
	return diet_panel != null and diet_panel.visible

func open_window() -> void:
	if diet_panel == null:
		return
	diet_panel.visible = true
	_position_panel()
	_last_sig = ""
	refresh()

func close_window() -> void:
	if diet_panel != null:
		diet_panel.visible = false

func toggle_window() -> void:
	if is_open():
		close_window()
	else:
		open_window()

func _position_panel() -> void:
	if diet_panel == null:
		return
	diet_panel.position = Vector2(8.0, 62.0)

func refresh() -> void:
	if not is_open():
		return
	var data: Variant = _call_bridge("getImperialDietData", [], {})
	if not (data is Dictionary):
		return
	var d: Dictionary = data
	var sig := str(d)
	if sig == _last_sig:
		return
	_last_sig = sig

	if not bool(d.get("active", false)):
		emperor_ruler_lbl.text = "Holy Roman Empire Dissolved"
		emperor_realm_lbl.text = "The Imperial Diet no longer sits."
		religious_lbl.visible = false
		authority_bar.value = 0.0
		authority_val_lbl.text = "—"
		_clear_children(electors_row)
		_clear_children(reforms_box)
		footer_lbl.text = ""
		return

	# Emperor section
	var emp_tag := str(d.get("emperorTag", ""))
	var emp_name := str(d.get("emperorName", "Vacant"))
	var emp_ruler := str(d.get("emperorRuler", "Interregnum"))
	var emp_years := int(d.get("emperorYears", 1))
	var yr_word := "year" if emp_years == 1 else "years"
	emperor_ruler_lbl.text = "Emperor %s" % emp_ruler
	emperor_realm_lbl.text = "%s (%s) — %d %s on the Imperial throne" % [emp_name, emp_tag, emp_years, yr_word]
	if main_view != null and not emp_tag.is_empty():
		emperor_shield.texture = main_view.call(
			"_get_country_arms_texture",
			emp_tag,
			int(d.get("emperorR", 180)),
			int(d.get("emperorG", 140)),
			int(d.get("emperorB", 80))
		)

	var rel_status := str(d.get("religiousStatus", ""))
	religious_lbl.text = rel_status
	religious_lbl.visible = not rel_status.is_empty()

	# Imperial Authority bar
	var auth := float(d.get("authority", 0.0))
	var monthly := float(d.get("monthlyAuthority", 0.0))
	authority_bar.value = clampf(auth, 0.0, 100.0)
	authority_val_lbl.text = "%.0f / 100 (%+.2f / mo)" % [auth, monthly]

	# Seven Prince-Electors row
	_clear_children(electors_row)
	var electors: Array = d.get("electors", [])
	for entry in electors:
		if not (entry is Dictionary):
			continue
		var ed: Dictionary = entry
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.custom_minimum_size = Vector2(76.0, 0.0)
		var e_tag := str(ed.get("tag", ""))
		var e_name := str(ed.get("name", e_tag))
		var lean_tag := str(ed.get("leanTag", "—"))
		var lean_name := str(ed.get("leanName", lean_tag))
		col.tooltip_text = "%s (%s)\nLeans to: %s (%s)" % [e_name, e_tag, lean_name, lean_tag]

		var shield_rect := TextureRect.new()
		shield_rect.custom_minimum_size = Vector2(36.0, 42.0)
		shield_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shield_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shield_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if main_view != null and not e_tag.is_empty():
			shield_rect.texture = main_view.call(
				"_get_country_arms_texture",
				e_tag,
				int(ed.get("r", 180)),
				int(ed.get("g", 140)),
				int(ed.get("b", 80))
			)
		col.add_child(shield_rect)

		var tag_lbl := Label.new()
		tag_lbl.text = e_tag
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tag_lbl)

		var lean_lbl := Label.new()
		lean_lbl.text = "→ %s" % lean_tag
		lean_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lean_lbl)

		electors_row.add_child(col)

	# Reichstag Reforms ladder
	_clear_children(reforms_box)
	var reforms: Array = d.get("reforms", [])
	for r_entry in reforms:
		if not (r_entry is Dictionary):
			continue
		var rd: Dictionary = r_entry
		var passed := bool(rd.get("passed", false))
		var is_next := bool(rd.get("isNext", false))
		var can_enact := bool(rd.get("canEnact", false))
		var r_cost := int(round(float(rd.get("cost", 50.0))))

		var plate := PanelContainer.new()
		plate.theme_type_variation = "Card"
		if passed:
			plate.modulate = Color(0.84, 0.96, 0.84, 1.0)
		elif not is_next:
			plate.modulate = Color(1.0, 1.0, 1.0, 0.55)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		plate.add_child(row)

		var txt_col := VBoxContainer.new()
		txt_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt_col)

		var name_lbl := Label.new()
		name_lbl.text = "%d. %s" % [int(rd.get("stage", 0)), str(rd.get("name", ""))]
		txt_col.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(rd.get("summary", ""))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt_col.add_child(desc_lbl)

		if passed:
			var done_lbl := Label.new()
			done_lbl.text = "Passed"
			row.add_child(done_lbl)
		elif is_next:
			var btn := Button.new()
			btn.text = "Enact (%d IA)" % r_cost
			btn.disabled = not can_enact
			btn.tooltip_text = "Requires %d Imperial Authority and the Imperial crown." % r_cost
			btn.pressed.connect(_on_enact_reform)
			row.add_child(btn)
		else:
			var cost_lbl := Label.new()
			cost_lbl.text = "%d IA" % r_cost
			row.add_child(cost_lbl)

		reforms_box.add_child(plate)

	# Footer line
	var m_count := int(d.get("memberCount", 0))
	var fc_count := int(d.get("freeCityCount", 0))
	var favour := int(round(float(d.get("playerFavour", 0.0))))
	var is_mem := bool(d.get("playerIsMember", false))
	var fav_text := ("Your Favour: %d" % favour) if is_mem else "Outside the Empire"
	footer_lbl.text = "Members: %d   •   Free Cities: %d   •   %s" % [m_count, fc_count, fav_text]

func _on_enact_reform() -> void:
	var ok := bool(_call_bridge("enactNextHREReform", [], false))
	if ok:
		_last_sig = ""
		refresh()
