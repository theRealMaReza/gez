extends Control
## The right-hand outliner (Phase 20.6 part 3b, owner's pick "A"): a
## parchment list at the top right of your armies, fleets, sieges and
## building work. Click a row to jump the map there (armies and fleets are
## selected too). Each heading folds its group; the medallion in the title
## row folds the whole list down to that medallion. Data comes from one
## bridge call, getOutlinerData (GezGodotOutlinerBridge.swift), polled
## twice a second and rebuilt only when it changes.

var main = null   # Main.gd

const WIDTH := 270.0
const TOP := 58.0          # under the top bar
const RIGHT := 12.0
const POLL_SECONDS := 0.5
const SECTIONS := [
	{"key": "armies", "title": "Armies", "icon": "armies"},
	{"key": "fleets", "title": "Fleets", "icon": "fleets"},
	{"key": "sieges", "title": "Sieges", "icon": "alert_underSiege"},
	{"key": "building", "title": "Building", "icon": "build"},
]

var panel: PanelContainer        # the open list
var fold_button: TextureButton   # shown instead of the list when folded
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _empty_label: Label
var folded := false
var _folded_sections: Dictionary = {}
var _last_sig := ""
var _poll := 0.0

func setup(host: Control) -> void:
	main = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	refresh(true)

func _build() -> void:
	panel = PanelContainer.new()
	panel.name = "Outliner"
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -RIGHT
	panel.offset_left = -RIGHT   # grows left to fit its contents
	panel.offset_top = TOP
	panel.offset_bottom = TOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var head := HBoxContainer.new()
	vbox.add_child(head)
	var title := Label.new()
	title.text = "Outliner"
	title.theme_type_variation = "Heading"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var fold := GezStyle.medallion_button("armies", 28.0)
	main.bind_tip(fold, "Fold the Outliner", "Shrinks the list to one medallion. Click it again to open.")
	fold.pressed.connect(func() -> void: set_folded(true))
	head.add_child(fold)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	_scroll.add_child(_rows)

	_empty_label = Label.new()
	_empty_label.text = "No armies, fleets, sieges or building work."
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.custom_minimum_size = Vector2(WIDTH - 40.0, 0)
	vbox.add_child(_empty_label)

	fold_button = GezStyle.medallion_button("armies", 40.0)
	fold_button.name = "OutlinerFolded"
	main.bind_tip(fold_button, "Open the Outliner", "Your armies, fleets, sieges and building work.")
	fold_button.visible = false
	add_child(fold_button)
	fold_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fold_button.offset_right = -RIGHT
	fold_button.offset_left = -RIGHT - 40.0
	fold_button.offset_top = TOP
	fold_button.offset_bottom = TOP + 40.0
	fold_button.pressed.connect(func() -> void: set_folded(false))

func set_folded(f: bool) -> void:
	folded = f
	_apply_visibility(_last_sig != "")

func _apply_visibility(has_player: bool) -> void:
	panel.visible = has_player and not folded
	fold_button.visible = has_player and folded

func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_SECONDS
	refresh()

func refresh(force := false) -> void:
	if main == null:
		return
	var data_v: Variant = main._call_bridge("getOutlinerData", [], {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var valid := bool(data.get("valid", false))
	var sig := str(data) + "|" + str(_folded_sections) if valid else ""
	if not force and sig == _last_sig:
		return
	_last_sig = sig
	_apply_visibility(valid)
	if not valid:
		return
	_rebuild(data)

func _rebuild(data: Dictionary) -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var any := false
	for sec in SECTIONS:
		var key: String = sec["key"]
		var items: Array = data.get(key, [])
		if items.is_empty():
			continue
		any = true
		_add_section_header(sec, items.size())
		if bool(_folded_sections.get(key, false)):
			continue
		for item in items:
			if item is Dictionary:
				_add_row(key, item)
	_empty_label.visible = not any
	_scroll.visible = any
	# Grow with the list, but never past the lower part of the screen
	# (the province drawer and market sit there).
	var cap := maxf(160.0, main.size.y * 0.5)
	_scroll.custom_minimum_size = Vector2(WIDTH - 28.0, minf(_rows.get_combined_minimum_size().y, cap))
	panel.reset_size()

func _add_section_header(sec: Dictionary, count: int) -> void:
	var key: String = sec["key"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var open := not bool(_folded_sections.get(key, false))
	row.add_child(GezStyle.icon_rect(GezStyle.medallion(str(sec["icon"])), 24.0))
	var l := Label.new()
	l.text = "%s (%d)" % [str(sec["title"]), count] if open else "%s (%d), folded" % [str(sec["title"]), count]
	l.theme_type_variation = "Heading"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	main.bind_tip(row, str(sec["title"]), "Click to fold or unfold this group.")
	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_folded_sections[key] = not bool(_folded_sections.get(key, false))
			refresh(true))
	_rows.add_child(row)

func _add_row(kind: String, item: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(top)
	var name_l := Label.new()
	name_l.text = "   " + str(item.get("name", ""))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(name_l)
	var num := _number_text(kind, item)
	if num != "":
		var num_l := Label.new()
		num_l.text = num
		num_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(num_l)

	var status := Label.new()
	status.text = "      " + str(item.get("status", ""))
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.custom_minimum_size = Vector2(WIDTH - 40.0, 0)
	status.add_theme_color_override("font_color", GezStyle.ink(Color(0.6, 0.6, 0.6)))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(status)

	if bool(item.get("inBattle", false)):
		name_l.add_theme_color_override("font_color", GezStyle.ink(Color(0.9, 0.2, 0.15)))

	row.mouse_entered.connect(func() -> void: row.modulate = Color(1.15, 1.05, 0.9))
	row.mouse_exited.connect(func() -> void: row.modulate = Color(1, 1, 1))
	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_jump(kind, item)
			row.accept_event())
	_rows.add_child(row)

func _number_text(kind: String, item: Dictionary) -> String:
	match kind:
		"armies":
			var men := int(item.get("men", 0))
			return "%.1fk" % (men / 1000.0) if men >= 1000 else str(men)
		"fleets":
			return "%d ships" % int(item.get("ships", 0))
		"building":
			return "%d%%" % int(item.get("percent", 0))
	return ""

## Jump the map to a row: select the army or fleet, or the province for
## sieges and building work, and centre the camera on it (zooming in a
## little if the map is far out).
func _jump(kind: String, item: Dictionary) -> void:
	match kind:
		"armies":
			main._call_bridge("clearSelectedFleet", [])
			main._call_bridge("selectArmy", [int(item.get("armyId", -1))], false)
			main._after_army_action()
		"fleets":
			main._call_bridge("clearSelectedArmy", [])
			main._call_bridge("selectFleet", [int(item.get("fleetId", -1))], false)
			main._after_fleet_action()
		_:
			main._select_province_by_index(int(item.get("provinceIndex", -1)))
	var pt := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
	if pt != Vector2.ZERO:
		main.focus_map_point(pt, maxf(main.zoom, main._fit_zoom() * 3.0))
	main.play_sfx("ui_click")
