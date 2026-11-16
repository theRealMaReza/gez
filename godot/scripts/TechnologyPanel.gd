extends Control

# The Technology & Institutions window (Phase 13):
# - Three research tracks (Administrative, Diplomatic, Military) with level,
#   progress bar, monthly gain breakdown, cost modifiers, and next-level unlocks
# - National research focus selector (Balanced, ADM, DIP, MIL)
# - Historical institutions (spawn origin, spread %, embrace button, tech penalty)

var main_view: Control = null

var tech_panel: PanelContainer
var header_sub_label: Label
var focus_box: HBoxContainer
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
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", fsize)
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
	tech_panel = PanelContainer.new()
	tech_panel.name = "TechnologyPanel"
	tech_panel.visible = false
	tech_panel.custom_minimum_size = Vector2(820.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBoxFlat = main_view.call("_make_panel_style")
		tech_panel.add_theme_stylebox_override("panel", st)
	add_child(tech_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	tech_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := _make_label("Technology & Institutions", Color(0.97, 0.90, 0.68), 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close Technology window"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	header_sub_label = _make_wrapped("", Color(0.84, 0.80, 0.72), 12)
	outer.add_child(header_sub_label)

	focus_box = HBoxContainer.new()
	focus_box.add_theme_constant_override("separation", 6)
	outer.add_child(focus_box)

	outer.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	outer.add_child(cols)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(460.0, 500.0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(left_scroll)

	left_box = VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_box)

	cols.add_child(VSeparator.new())

	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(320.0, 500.0)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(right_scroll)

	right_box = VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 6)
	right_scroll.add_child(right_box)

	message_label = _make_wrapped("", Color(0.96, 0.45, 0.40), 12)
	message_label.visible = false
	outer.add_child(message_label)

func layout(viewport_size: Vector2) -> void:
	if tech_panel == null or not tech_panel.visible:
		return
	var max_w := clampf(viewport_size.x - 32.0, 560.0, 840.0)
	var max_h := clampf(viewport_size.y - 120.0, 440.0, 670.0)
	tech_panel.custom_minimum_size = Vector2(max_w, 0.0)
	tech_panel.position = Vector2(16.0, 62.0)
	tech_panel.size = Vector2(max_w, minf(max_h, 670.0))

func is_open() -> bool:
	return tech_panel != null and tech_panel.visible

func open_window() -> void:
	if tech_panel == null or tech_panel.visible:
		return
	toggle_window()

func toggle_window() -> void:
	if tech_panel == null:
		return
	tech_panel.visible = not tech_panel.visible
	if tech_panel.visible:
		_last_message = ""
		refresh(true)
		layout(get_viewport_rect().size)

func close_window() -> void:
	if tech_panel != null:
		tech_panel.visible = false

func refresh_if_open() -> void:
	if is_open():
		refresh(false)

func refresh(force: bool = false) -> void:
	if tech_panel == null or not tech_panel.visible:
		return
	var d_v: Variant = _call_bridge("getTechnologyWindowDetails", [], {})
	var d: Dictionary = d_v if d_v is Dictionary else {}
	if not bool(d.get("hasPlayer", false)):
		header_sub_label.text = "Observer mode: select a country to view its research and institutions."
		_clear_children(focus_box)
		_clear_children(left_box)
		_clear_children(right_box)
		return

	var tracks: Array = d.get("tracks", [])
	var insts: Array = d.get("institutions", [])
	var sig := "%s|%s|%d|%s" % [
		str(d.get("playerTag", "")),
		str(d.get("focusKey", "")),
		int(d.get("treasury", 0)),
		str(d.get("summary", ""))
	]
	for tr_v in tracks:
		if tr_v is Dictionary:
			var tr: Dictionary = tr_v
			sig += "|%s:%d:%.1f/%.0f:+%.2f" % [
				str(tr.get("key", "")),
				int(tr.get("level", 0)),
				float(tr.get("progress", 0.0)),
				float(tr.get("effectiveCost", 600.0)),
				float(tr.get("totalMonthlyGain", 0.0))
			]
	for in_v in insts:
		if in_v is Dictionary:
			var inst: Dictionary = in_v
			sig += "|%d:%s:%s:%s:%d" % [
				int(inst.get("index", 0)),
				str(inst.get("spawned", false)),
				str(inst.get("embraced", false)),
				str(inst.get("spreadPercentText", "")),
				int(inst.get("penaltyPercent", 0))
			]
	if not force and sig == _last_sig and _last_message.is_empty():
		return
	_last_sig = sig

	header_sub_label.text = str(d.get("summary", ""))

	# Focus buttons bar
	_clear_children(focus_box)
	focus_box.add_child(_make_label("Focus (routes Colleges, Learning, Paper & Books):", Color(0.86, 0.82, 0.72), 12))
	var focus_opts: Array = d.get("focusOptions", [])
	for fo_v in focus_opts:
		if not (fo_v is Dictionary):
			continue
		var fo: Dictionary = fo_v
		var f_key: String = str(fo.get("key", "balanced"))
		var selected: bool = bool(fo.get("selected", false))
		var btn := Button.new()
		btn.text = str(fo.get("name", f_key))
		btn.disabled = selected
		if selected:
			btn.modulate = Color(1.0, 0.90, 0.45)
		btn.tooltip_text = "Focus 50% of shared research onto " + str(fo.get("name", "")) if f_key != "balanced" else "Split shared research evenly across all three tracks"
		btn.pressed.connect(func() -> void: _on_focus_pressed(f_key))
		focus_box.add_child(btn)

	# ---------------- LEFT: RESEARCH TRACKS ----------------
	_clear_children(left_box)
	left_box.add_child(_make_label("Technology Tracks (Levels 1-20)", Color(0.96, 0.88, 0.64), 14))
	for tr_v in tracks:
		if not (tr_v is Dictionary):
			continue
		var tr: Dictionary = tr_v
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.18, 0.15, 0.11, 0.86)
		card_style.set_content_margin_all(8.0)
		card_style.set_corner_radius_all(4)
		card.add_theme_stylebox_override("panel", card_style)
		left_box.add_child(card)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		card.add_child(box)

		var head := HBoxContainer.new()
		box.add_child(head)
		var name_lbl := _make_label("%s (%s) · Lv %d / %d" % [
			str(tr.get("name", "")),
			str(tr.get("shortName", "")),
			int(tr.get("level", 3)),
			int(tr.get("maxLevel", 20))
		], Color(0.97, 0.90, 0.68), 14)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_lbl)

		var at_max: bool = bool(tr.get("atMax", false))
		var gain: float = float(tr.get("totalMonthlyGain", 0.0))
		var mos: int = int(tr.get("monthsToNext", 0))
		var eta_txt := "MAX" if at_max else ("+%.2f/mo (%d mo)" % [gain, mos] if mos > 0 else "+%.2f/mo" % gain)
		head.add_child(_make_label(eta_txt, Color(0.62, 0.90, 0.58) if gain > 0.0 else Color(0.84, 0.78, 0.66), 12))

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = float(tr.get("fraction", 0.0)) * 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 9.0)
		box.add_child(bar)

		if not at_max:
			box.add_child(_make_wrapped("Progress: %.1f / %.0f pts  (%s)" % [
				float(tr.get("progress", 0.0)),
				float(tr.get("effectiveCost", 600.0)),
				str(tr.get("costModifiersText", ""))
			], Color(0.84, 0.80, 0.72), 11))

		box.add_child(_make_wrapped("Research speed: " + str(tr.get("sourcesText", "")), Color(0.74, 0.84, 0.90), 11))
		var cur_sum := str(tr.get("currentSummary", ""))
		if not cur_sum.is_empty():
			box.add_child(_make_wrapped("Current: " + cur_sum, Color(0.76, 0.74, 0.66), 11))
		if not at_max:
			box.add_child(_make_wrapped("Next Lv %d (%d): %s" % [
				int(tr.get("nextLevel", 0)),
				int(tr.get("nextTargetYear", 1453)),
				str(tr.get("nextSummary", ""))
			], Color(0.95, 0.84, 0.54), 12))

	# ---------------- RIGHT: INSTITUTIONS & NOTES ----------------
	_clear_children(right_box)
	right_box.add_child(_make_label("Institutions", Color(0.96, 0.88, 0.64), 14))
	for in_v in insts:
		if not (in_v is Dictionary):
			continue
		var inst: Dictionary = in_v
		var idx: int = int(inst.get("index", 0))
		var spawned: bool = bool(inst.get("spawned", false))
		var embraced: bool = bool(inst.get("embraced", false))
		var can_embrace: bool = bool(inst.get("canEmbrace", false))
		var origin_idx: int = int(inst.get("originProvinceIndex", -1))

		var icard := PanelContainer.new()
		var istyle := StyleBoxFlat.new()
		istyle.bg_color = Color(0.14, 0.21, 0.14, 0.86) if embraced else Color(0.18, 0.15, 0.11, 0.86)
		istyle.set_content_margin_all(7.0)
		istyle.set_corner_radius_all(4)
		icard.add_theme_stylebox_override("panel", istyle)
		right_box.add_child(icard)

		var ibox := VBoxContainer.new()
		ibox.add_theme_constant_override("separation", 3)
		icard.add_child(ibox)

		var ihead := HBoxContainer.new()
		ibox.add_child(ihead)
		var iname := _make_label(str(inst.get("name", "Institution")), Color(0.97, 0.90, 0.68), 13)
		iname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ihead.add_child(iname)

		var status_txt: String
		var status_col: Color
		if embraced:
			status_txt = "Embraced (+5% speed)"
			status_col = Color(0.56, 0.90, 0.54)
		elif spawned:
			var pen: int = int(inst.get("penaltyPercent", 0))
			status_txt = "Spread %s · +%d%% cost" % [str(inst.get("spreadPercentText", "0%")), pen]
			status_col = Color(0.98, 0.68, 0.44)
		else:
			status_txt = "From %d" % int(inst.get("spawnYear", 1453))
			status_col = Color(0.70, 0.66, 0.58)
		ihead.add_child(_make_label(status_txt, status_col, 11))

		if origin_idx >= 0:
			var o_btn := Button.new()
			o_btn.text = "Origin: %s (%d)" % [str(inst.get("originName", "")), int(inst.get("spawnedYear", 1453))]
			o_btn.flat = true
			o_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			o_btn.tooltip_text = "Show origin province on map"
			o_btn.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94))
			o_btn.pressed.connect(func() -> void: _focus_province(origin_idx))
			ibox.add_child(o_btn)
		else:
			ibox.add_child(_make_label("Expected: " + str(inst.get("originName", "")), Color(0.72, 0.68, 0.60), 11))

		if spawned and not embraced:
			var ibar := ProgressBar.new()
			ibar.min_value = 0.0
			ibar.max_value = 100.0
			ibar.value = float(inst.get("spreadShare", 0.0)) * 100.0
			ibar.show_percentage = false
			ibar.custom_minimum_size = Vector2(0.0, 7.0)
			ibox.add_child(ibar)

			var e_btn := Button.new()
			e_btn.text = "Embrace (%d ducats)" % int(inst.get("embraceCost", 0))
			e_btn.disabled = not can_embrace
			e_btn.tooltip_text = "Adopt this institution (+5% research speed, removes penalty)" if can_embrace else str(inst.get("embraceReason", ""))
			e_btn.pressed.connect(func() -> void: _on_embrace_pressed(idx))
			ibox.add_child(e_btn)

		ibox.add_child(_make_wrapped(str(inst.get("summary", "")), Color(0.72, 0.68, 0.60), 11))

	var notes: Array = d.get("notes", [])
	if not notes.is_empty():
		right_box.add_child(HSeparator.new())
		right_box.add_child(_make_label("Recent advances", Color(0.96, 0.88, 0.64), 13))
		for n_v in notes:
			if n_v is Dictionary:
				var n: Dictionary = n_v
				right_box.add_child(_make_wrapped("%s · %s" % [str(n.get("dateText", "")), str(n.get("text", ""))], Color(0.80, 0.84, 0.78), 11))

	if _last_message.is_empty():
		message_label.visible = false
	else:
		message_label.text = _last_message
		message_label.visible = true

	layout(get_viewport_rect().size)

func _on_focus_pressed(f_key: String) -> void:
	var res_v: Variant = _call_bridge("setTechFocus", [f_key], {})
	var res: Dictionary = res_v if res_v is Dictionary else {}
	if bool(res.get("ok", false)):
		_last_message = ""
	else:
		_last_message = str(res.get("reason", "Could not change focus."))
	refresh(true)

func _on_embrace_pressed(inst_idx: int) -> void:
	var res_v: Variant = _call_bridge("embraceInstitution", [inst_idx], {})
	var res: Dictionary = res_v if res_v is Dictionary else {}
	if bool(res.get("ok", false)):
		_last_message = ""
	else:
		_last_message = str(res.get("reason", "Cannot embrace institution yet."))
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
