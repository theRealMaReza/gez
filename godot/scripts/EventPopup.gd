extends Control

# Historical & Chronicle Event Pop-up modal (Phase 14):
# Shows title, category, date, narrative text, 2–4 choice buttons with effect
# tooltips, optional province focus link, and the Pause-on-Events setting toggle.

var main_view: Control = null

var backdrop: ColorRect
var popup_panel: PanelContainer
var category_label: Label
var date_label: Label
var title_label: Label
var body_label: Label
var focus_btn: Button
var options_box: VBoxContainer
var pause_check: CheckBox

var current_instance_id: int = -1
var current_province_index: int = -1
var _last_opened_instance_id: int = -1

func setup(host: Control) -> void:
	main_view = host
	# fill the screen so the pop-up is centred (it sat in the top-left corner before)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()

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

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.02, 0.02, 0.56)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	popup_panel = PanelContainer.new()
	popup_panel.name = "EventPopupPanel"
	popup_panel.custom_minimum_size = Vector2(560.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBox = main_view.call("_make_panel_style", Color(0.15, 0.12, 0.09, 0.98))
		popup_panel.add_theme_stylebox_override("panel", st)
	center.add_child(popup_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	popup_panel.add_child(outer)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	outer.add_child(top_row)

	category_label = _make_label("HISTORICAL EVENT", Color(0.84, 0.72, 0.42), 11)
	category_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(category_label)

	date_label = _make_label("", Color(0.78, 0.74, 0.66), 12)
	top_row.add_child(date_label)

	focus_btn = Button.new()
	focus_btn.text = "Locate"
	focus_btn.tooltip_text = "Center the map on this province"
	focus_btn.visible = false
	focus_btn.pressed.connect(_on_focus_pressed)
	top_row.add_child(focus_btn)

	title_label = _make_wrapped("", Color(0.98, 0.90, 0.64), 20)
	outer.add_child(title_label)

	outer.add_child(HSeparator.new())

	var text_scroll := ScrollContainer.new()
	text_scroll.custom_minimum_size = Vector2(520.0, 120.0)
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(text_scroll)

	body_label = _make_wrapped("", Color(0.92, 0.89, 0.82), 14)
	text_scroll.add_child(body_label)

	outer.add_child(HSeparator.new())

	options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 6)
	outer.add_child(options_box)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	outer.add_child(footer)

	pause_check = CheckBox.new()
	pause_check.text = "Pause game on events"
	pause_check.button_pressed = true
	pause_check.toggled.connect(_on_pause_toggled)
	footer.add_child(pause_check)

func is_open() -> bool:
	return visible

func reset_seen() -> void:
	_last_opened_instance_id = -1

func open_pending_if_new(force: bool = false) -> void:
	var details: Dictionary = _call_bridge("getPendingEventDetails", [], {})
	if not bool(details.get("hasPending", false)):
		visible = false
		current_instance_id = -1
		return
	var inst_id: int = int(details.get("instanceID", -1))
	if not force and inst_id == _last_opened_instance_id and visible:
		return
	if not force and inst_id == _last_opened_instance_id:
		return
	_populate(details)
	_last_opened_instance_id = inst_id
	visible = true

func _populate(details: Dictionary) -> void:
	current_instance_id = int(details.get("instanceID", -1))
	current_province_index = int(details.get("contextProvinceIndex", -1))
	var cat_name: String = str(details.get("categoryName", "Historical"))
	category_label.text = cat_name.to_upper() + " EVENT"
	date_label.text = str(details.get("dateText", ""))
	title_label.text = str(details.get("title", "Event"))
	body_label.text = str(details.get("text", ""))
	focus_btn.visible = current_province_index >= 0

	pause_check.set_pressed_no_signal(bool(details.get("pauseOnEvents", true)))

	_clear_children(options_box)
	var opts: Array = details.get("options", [])
	for opt_v in opts:
		if not (opt_v is Dictionary):
			continue
		var opt: Dictionary = opt_v
		var opt_idx: int = int(opt.get("index", 0))
		var lbl_text: String = str(opt.get("label", "Choose"))
		var tip_text: String = str(opt.get("tooltip", "No immediate effect."))

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		options_box.add_child(row)

		var btn := Button.new()
		btn.text = lbl_text
		if main_view != null:
			main_view.call("bind_tip", btn, lbl_text, tip_text)
		else:
			btn.tooltip_text = tip_text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(520.0, 34.0)
		btn.modulate = Color(1.0, 0.94, 0.78)
		btn.pressed.connect(_on_option_pressed.bind(opt_idx))
		row.add_child(btn)

		var eff_lbl := _make_wrapped("  -> " + tip_text, Color(0.76, 0.84, 0.68), 11)
		row.add_child(eff_lbl)

func _on_option_pressed(opt_idx: int) -> void:
	if current_instance_id < 0:
		return
	var resolved_id := current_instance_id
	var ok: bool = bool(_call_bridge("chooseEventOption", [resolved_id, opt_idx], false))
	if not ok:
		return
	visible = false
	current_instance_id = -1
	if main_view != null and main_view.has_method("_on_event_resolved"):
		main_view.call("_on_event_resolved")

func _on_pause_toggled(enabled: bool) -> void:
	_call_bridge("setPauseOnEvents", [enabled], enabled)
	if main_view != null and main_view.has_method("_sync_pause_on_events_ui"):
		main_view.call("_sync_pause_on_events_ui")

func _on_focus_pressed() -> void:
	if current_province_index >= 0 and main_view != null and main_view.has_method("_focus_and_select_province"):
		main_view.call("_focus_and_select_province", current_province_index)
