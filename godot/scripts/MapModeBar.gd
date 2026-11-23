extends Control
## The 12 map-mode medallions (top right, under the top bar) and the zoom
## buttons (bottom right), split out of Main.gd in Phase 20.6 part 2. The
## map-mode dock and outliner of part 3 start from here. Main keeps the
## map state (current_map_mode, _select_map_mode) and map_mode_buttons as
## a thin wrapper.

var main = null   # Main.gd

var map_mode_buttons: Dictionary = {}

func setup(host: Control) -> void:
	main = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_map_mode_bar()
	_build_zoom_buttons()

func bind_tip(ctrl: Control, title: String, summary: String = "") -> void:
	main.bind_tip(ctrl, title, summary)

func _build_map_mode_bar() -> void:
	var mode_panel := PanelContainer.new()
	mode_panel.name = "MapModeBar"
	mode_panel.theme_type_variation = "Bare"
	add_child(mode_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 1)
	mode_panel.add_child(hbox)

	var modes_spec := [
		{"key": "political", "title": "Political", "shortcut": "Q"},
		{"key": "diplomatic", "title": "Diplomatic", "shortcut": "O"},
		{"key": "states", "title": "States", "shortcut": "W"},
		{"key": "terrain", "title": "Terrain", "shortcut": "E"},
		{"key": "religion", "title": "Religion", "shortcut": "R"},
		{"key": "culture", "title": "Culture", "shortcut": "T"},
		{"key": "development", "title": "Development", "shortcut": "Y"},
		{"key": "goods", "title": "Goods", "shortcut": "U"},
		{"key": "markets", "title": "Markets", "shortcut": "I"},
		{"key": "plague", "title": "Plague", "shortcut": "P"},
		{"key": "unrest", "title": "Unrest", "shortcut": "L"},
		{"key": "institutions", "title": "Institutions", "shortcut": "K"}
	]
	map_mode_buttons.clear()
	for m in modes_spec:
		var k: String = m["key"]
		var title: String = m["title"]
		var sc: String = m["shortcut"]
		var btn := GezStyle.medallion_button("map_" + k, 36.0)
		bind_tip(btn, "%s Map Mode" % title, "Key %s" % sc)
		var mode_key := k
		btn.pressed.connect(func() -> void: main._select_map_mode(mode_key))
		hbox.add_child(btn)
		map_mode_buttons[k] = btn

	mode_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	mode_panel.offset_top = 58.0
	update_styles(main.current_map_mode)

func _build_zoom_buttons() -> void:
	var zoom_box := VBoxContainer.new()
	zoom_box.name = "ZoomButtons"
	zoom_box.add_theme_constant_override("separation", 4)
	add_child(zoom_box)

	var btn_in := GezStyle.medallion_button("zoom_in", 40.0)
	bind_tip(btn_in, "Zoom In", "Mouse wheel or pinch also zoom.")
	btn_in.pressed.connect(func() -> void: main._zoom_by(1.5, main.size * 0.5))
	zoom_box.add_child(btn_in)

	var btn_out := GezStyle.medallion_button("zoom_out", 40.0)
	bind_tip(btn_out, "Zoom Out", "Mouse wheel or pinch also zoom.")
	btn_out.pressed.connect(func() -> void: main._zoom_by(1.0 / 1.5, main.size * 0.5))
	zoom_box.add_child(btn_out)

	var btn_fit := GezStyle.medallion_button("zoom_fit", 40.0)
	bind_tip(btn_fit, "Show Whole Map (F)", "")
	btn_fit.pressed.connect(Callable(main, "_show_whole_map"))
	zoom_box.add_child(btn_fit)
	zoom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)

func update_styles(current_mode: String) -> void:
	for k in map_mode_buttons.keys():
		GezStyle.set_medallion_on(map_mode_buttons[k], str(k) == current_mode)
