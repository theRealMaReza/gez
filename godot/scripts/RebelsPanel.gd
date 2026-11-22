extends Control

# The Rebels window (Phase 12): every rebel faction of the player's country
# with its progress, demand and the three answers (concession, troops, lower
# taxes), plus the most restless provinces.

var main_view: Control = null

var rebels_panel: PanelContainer
var header_sub_label: Label
var left_box: VBoxContainer
var right_box: VBoxContainer
var message_label: Label

var _last_message: String = ""
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

func _make_label(txt: String, col: Color, fsize: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", GezStyle.ink(col))
	lbl.add_theme_font_size_override("font_size", GezStyle.fs(fsize))
	return lbl

func _make_wrapped(txt: String, col: Color, fsize: int) -> Label:
	var lbl := _make_label(txt, col, fsize)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _build_panel() -> void:
	rebels_panel = PanelContainer.new()
	rebels_panel.name = "RebelsPanel"
	rebels_panel.visible = false
	rebels_panel.custom_minimum_size = Vector2(780.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBox = main_view.call("_make_panel_style")
		rebels_panel.add_theme_stylebox_override("panel", st)
	add_child(rebels_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	rebels_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := _make_label("Unrest & Rebels", Color(0.97, 0.90, 0.68), 18)
	GezStyle.as_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := GezStyle.medallion_button("close", 30.0)
	close_btn.tooltip_text = "Close Unrest & Rebels window"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	header_sub_label = _make_label("", Color(0.84, 0.80, 0.72), 12)
	header_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(header_sub_label)

	outer.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	outer.add_child(cols)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(440.0, 520.0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(left_scroll)

	left_box = VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 5)
	left_scroll.add_child(left_box)

	cols.add_child(VSeparator.new())

	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(300.0, 520.0)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(right_scroll)

	right_box = VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 4)
	right_scroll.add_child(right_box)

	message_label = _make_label("", Color(0.96, 0.45, 0.40), 12)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.visible = false
	outer.add_child(message_label)

func layout(viewport_size: Vector2) -> void:
	if rebels_panel == null or not rebels_panel.visible:
		return
	var max_w := clampf(viewport_size.x - 32.0, 520.0, 800.0)
	var max_h := clampf(viewport_size.y - 120.0, 420.0, 660.0)
	rebels_panel.custom_minimum_size = Vector2(max_w, 0.0)
	rebels_panel.position = Vector2(16.0, 62.0)
	rebels_panel.size = Vector2(max_w, minf(max_h, 660.0))

func is_open() -> bool:
	return rebels_panel != null and rebels_panel.visible

func open_window() -> void:
	if rebels_panel == null or rebels_panel.visible:
		return
	toggle_window()

func toggle_window() -> void:
	if rebels_panel == null:
		return
	rebels_panel.visible = not rebels_panel.visible
	if rebels_panel.visible:
		_last_message = ""
		refresh(true)
		layout(get_viewport_rect().size)

func close_window() -> void:
	if rebels_panel != null:
		rebels_panel.visible = false

func refresh_if_open() -> void:
	if is_open():
		refresh(false)

func refresh(force: bool = false) -> void:
	if rebels_panel == null or not rebels_panel.visible:
		return
	var d_var: Variant = _call_bridge("getRebelsWindowDetails", [], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("hasPlayer", false)):
		header_sub_label.text = "Observer mode: pick a country to see its rebels."
		_clear_children(left_box)
		_clear_children(right_box)
		return

	var factions: Array = d.get("factions", [])
	var provinces: Array = d.get("provinces", [])
	var sig: String = "%s|%s|%s|%d" % [
		str(d.get("playerTag", "")),
		str(d.get("averageUnrestText", "0")),
		str(d.get("peasantTaxText", "")),
		provinces.size()
	]
	for f_sig in factions:
		if f_sig is Dictionary:
			sig += "|%d:%s:%s" % [int(f_sig.get("factionId", 0)), str(f_sig.get("status", "")), str(f_sig.get("demand", ""))]
	if not force and sig == _last_sig and _last_message.is_empty():
		return
	_last_sig = sig

	header_sub_label.text = "Average unrest %s  ·  %d restless provinces  ·  Tax on peasants %s" % [
		str(d.get("averageUnrestText", "0")),
		int(d.get("restlessCount", 0)),
		str(d.get("peasantTaxText", "100%"))
	]

	_clear_children(left_box)
	_clear_children(right_box)

	# ---------------- LEFT: FACTIONS ----------------
	left_box.add_child(_make_label("Rebel factions", Color(0.96, 0.88, 0.64), 14))
	if factions.is_empty():
		left_box.add_child(_make_wrapped(
			"No rebel faction is gathering against you. Factions appear when taxes, hunger, faith, foreign rule, a disloyal estate or a shaky throne give people a cause.",
			Color(0.72, 0.68, 0.60), 12))
	for f_v in factions:
		if not (f_v is Dictionary):
			continue
		var f: Dictionary = f_v
		var f_id: int = int(f.get("factionId", -1))
		var risen: bool = bool(f.get("risen", false))
		var target_idx: int = int(f.get("targetProvinceIndex", -1))

		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		if risen:
			card.self_modulate = Color(1.0, 0.82, 0.78)
		left_box.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		card.add_child(box)

		var head := HBoxContainer.new()
		box.add_child(head)
		var name_btn := Button.new()
		name_btn.text = str(f.get("name", "Rebels"))
		name_btn.flat = true
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_btn.tooltip_text = "Show on the map"
		name_btn.add_theme_color_override("font_color", GezStyle.ink(Color(0.98, 0.62, 0.50) if risen else Color(0.97, 0.90, 0.68)))
		name_btn.pressed.connect(func() -> void: _focus_province(target_idx))
		head.add_child(name_btn)
		head.add_child(_make_label("IN ARMS" if risen else str(f.get("progressText", "0%")), Color(0.98, 0.45, 0.38) if risen else Color(0.95, 0.80, 0.45), 13))

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = float(f.get("progress", 0.0))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 8.0)
		box.add_child(bar)

		box.add_child(_make_wrapped(str(f.get("status", "")), Color(0.90, 0.86, 0.78), 12))
		box.add_child(_make_wrapped("Where: %s" % str(f.get("provincesText", "")), Color(0.74, 0.70, 0.64), 11))
		box.add_child(_make_wrapped("If they win: %s" % str(f.get("demand", "")), Color(0.96, 0.66, 0.52), 12))

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		box.add_child(actions)

		var concede_btn := Button.new()
		concede_btn.text = "Concede"
		concede_btn.tooltip_text = "%s They go home at once; prestige suffers a little." % str(f.get("concession", ""))
		concede_btn.pressed.connect(func() -> void: _answer("concedeToRebels", [f_id]))
		actions.add_child(concede_btn)

		var troops_btn := Button.new()
		troops_btn.text = "Send troops"
		troops_btn.tooltip_text = "March your strongest free army there. Soldiers on the spot slow a brewing faction; a risen one must be beaten in the field."
		troops_btn.pressed.connect(func() -> void: _answer("sendTroopsAgainstRebels", [f_id]))
		actions.add_child(troops_btn)

		if bool(f.get("canLowerTaxes", false)):
			var tax_btn := Button.new()
			tax_btn.text = "Lower taxes"
			tax_btn.tooltip_text = "Cut the tax on peasants by a quarter of the normal rate. Their anger cools over the next months."
			tax_btn.pressed.connect(func() -> void: _answer("lowerPeasantTaxes", []))
			actions.add_child(tax_btn)

		box.add_child(_make_wrapped("Concession: %s" % str(f.get("concession", "")), Color(0.66, 0.82, 0.66), 11))

	var notes: Array = d.get("notes", [])
	for n_v in notes:
		left_box.add_child(_make_wrapped(str(n_v), Color(0.70, 0.82, 0.92), 11))
	left_box.add_child(_make_wrapped(str(d.get("ralliesText", "")), Color(0.62, 0.58, 0.52), 11))

	# ---------------- RIGHT: RESTLESS PROVINCES ----------------
	right_box.add_child(_make_label("Most restless provinces", Color(0.96, 0.88, 0.64), 14))
	if provinces.is_empty():
		right_box.add_child(_make_label("The realm is calm.", Color(0.72, 0.68, 0.60), 12))
	for p_v in provinces:
		if not (p_v is Dictionary):
			continue
		var p: Dictionary = p_v
		var p_idx: int = int(p.get("provinceIndex", -1))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		right_box.add_child(row)
		var p_btn := Button.new()
		p_btn.text = str(p.get("name", ""))
		p_btn.flat = true
		p_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var prov_u_idx := p_idx
		if main_view != null and prov_u_idx >= 0:
			main_view.call("bind_breakdown", p_btn, func() -> Variant: return _call_bridge("getUnrestBreakdown", [prov_u_idx], {}), "Province Unrest Breakdown")
			main_view.call("bind_breakdown", row, func() -> Variant: return _call_bridge("getUnrestBreakdown", [prov_u_idx], {}), "Province Unrest Breakdown")
		p_btn.pressed.connect(func() -> void: _focus_province(p_idx))
		row.add_child(p_btn)
		row.add_child(_make_label(str(p.get("causeText", "")), Color(0.74, 0.70, 0.64), 11))
		var u: float = float(p.get("unrest", 0.0))
		var u_col: Color = Color(0.96, 0.42, 0.38) if u >= 40.0 else (Color(0.96, 0.78, 0.40) if u >= 20.0 else Color(0.80, 0.86, 0.70))
		row.add_child(_make_label(str(p.get("unrestText", "0")), u_col, 13))
	right_box.add_child(HSeparator.new())
	right_box.add_child(_make_wrapped(
		"Open a province's People tab to see every cause of its unrest. Press L for the Unrest map.",
		Color(0.62, 0.58, 0.52), 11))

	if _last_message.is_empty():
		message_label.visible = false
	else:
		message_label.text = _last_message
		message_label.visible = true

	layout(get_viewport_rect().size)

func _answer(method_name: String, args: Array) -> void:
	var res_v: Variant = _call_bridge(method_name, args, {})
	var res: Dictionary = res_v if res_v is Dictionary else {}
	if bool(res.get("ok", false)):
		_last_message = ""
	else:
		_last_message = str(res.get("reason", "That cannot be done."))
	refresh(true)
	if main_view != null:
		main_view.call("_refresh_top_bar")
		main_view.call("_refresh_styles_and_country_labels")
		main_view.call("_refresh_faith_overlay")
		main_view.call("_refresh_alerts_bar")
		if bool(main_view.get("province_panel").visible):
			main_view.call("_refresh_province_panel")

func _focus_province(province_idx: int) -> void:
	if province_idx < 0 or main_view == null:
		return
	main_view.call("_focus_and_select_province", province_idx)
