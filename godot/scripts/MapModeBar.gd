extends Control
## The map-mode dock (Phase 20.6 part 3, owner's pick "A"): one medallion
## at the bottom right, just above the zoom buttons, shows the current map
## mode; clicking it opens a 4 x 3 grid of all 12 modes. Picking a mode,
## clicking anywhere else or pressing Esc closes the grid. The keys
## (Q, O, W, E...) still switch modes directly (Main.gd). Split out of
## Main.gd in part 2; Main keeps the map state (current_map_mode,
## _select_map_mode) and map_mode_buttons as a thin wrapper.

var main = null   # Main.gd

var map_mode_buttons: Dictionary = {}   # mode key -> medallion in the grid
var dock_button: TextureButton           # the "current mode" medallion
var mode_grid: PanelContainer            # the 4 x 3 grid (hidden until clicked)
var _catcher: Control                    # closes the grid on an outside click

const MODES := [
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

const MARGIN := 16.0
const ZOOM_SIZE := 40.0
const DOCK_SIZE := 48.0
const GAP := 4.0

func setup(host: Control) -> void:
	main = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# offsets too: we are already in the tree, so plain set_anchors_preset
	# would keep our zero size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_zoom_buttons()
	_build_dock()
	update_styles(main.current_map_mode)

func bind_tip(ctrl: Control, title: String, summary: String = "") -> void:
	main.bind_tip(ctrl, title, summary)

func _mode_spec(key: String) -> Dictionary:
	for m in MODES:
		if m["key"] == key:
			return m
	return MODES[0]

func _build_dock() -> void:
	# Click-catcher under the grid: an outside click closes it.
	_catcher = Control.new()
	_catcher.name = "MapModeCatcher"
	_catcher.visible = false
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_catcher)
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close_grid())

	# The current-mode medallion, above the zoom buttons.
	dock_button = GezStyle.medallion_button("map_political", DOCK_SIZE)
	dock_button.name = "MapModeDock"
	add_child(dock_button)
	dock_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var zoom_h := ZOOM_SIZE * 3.0 + GAP * 2.0
	var right := -MARGIN - (ZOOM_SIZE - DOCK_SIZE) * 0.5   # centred over the zoom column
	var bottom := -MARGIN - zoom_h - GAP * 3.0
	dock_button.offset_right = right
	dock_button.offset_left = right - DOCK_SIZE
	dock_button.offset_bottom = bottom
	dock_button.offset_top = bottom - DOCK_SIZE
	dock_button.pressed.connect(toggle_grid)

	# The grid: a parchment window with all 12 medallions and their names.
	mode_grid = PanelContainer.new()
	mode_grid.name = "MapModeGrid"
	mode_grid.visible = false
	add_child(mode_grid)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	mode_grid.add_child(vbox)
	var head := Label.new()
	head.text = "Map Modes"
	head.theme_type_variation = "Heading"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(head)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	map_mode_buttons.clear()
	for m in MODES:
		var k: String = m["key"]
		var title: String = m["title"]
		var sc: String = m["shortcut"]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.custom_minimum_size = Vector2(96, 0)
		grid.add_child(cell)
		var btn := GezStyle.medallion_button("map_" + k, 40.0)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bind_tip(btn, "%s Map Mode" % title, "Key %s" % sc)
		var mode_key := k
		btn.pressed.connect(func() -> void:
			close_grid()
			main._select_map_mode(mode_key))
		cell.add_child(btn)
		var name_l := Label.new()
		name_l.text = "%s (%s)" % [title, sc]
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_l)
		map_mode_buttons[k] = btn

	# Bottom right, to the left of the dock column, bottom edge level with
	# the dock medallion's bottom.
	# Grows up and to the left from its bottom-right corner, so it always
	# hugs its contents.
	mode_grid.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mode_grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mode_grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place_grid()

func _place_grid() -> void:
	if mode_grid == null:
		return
	var right := -MARGIN - maxf(ZOOM_SIZE, DOCK_SIZE) - 10.0
	var bottom := dock_button.offset_bottom
	mode_grid.offset_right = right
	mode_grid.offset_left = right
	mode_grid.offset_bottom = bottom
	mode_grid.offset_top = bottom
	mode_grid.reset_size()

func toggle_grid() -> void:
	if mode_grid.visible:
		close_grid()
	else:
		open_grid()

func open_grid() -> void:
	_place_grid()
	_catcher.visible = true
	mode_grid.visible = true
	GezStyle.set_medallion_on(dock_button, true)

func close_grid() -> void:
	if mode_grid == null:
		return
	_catcher.visible = false
	mode_grid.visible = false
	GezStyle.set_medallion_on(dock_button, false)

func _input(event: InputEvent) -> void:
	if mode_grid != null and mode_grid.visible and event is InputEventKey \
			and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_grid()
		get_viewport().set_input_as_handled()

func _build_zoom_buttons() -> void:
	var zoom_box := VBoxContainer.new()
	zoom_box.name = "ZoomButtons"
	zoom_box.add_theme_constant_override("separation", int(GAP))
	add_child(zoom_box)

	var btn_in := GezStyle.medallion_button("zoom_in", ZOOM_SIZE)
	bind_tip(btn_in, "Zoom In", "Mouse wheel or pinch also zoom.")
	btn_in.pressed.connect(func() -> void: main._zoom_by(1.5, main.size * 0.5))
	zoom_box.add_child(btn_in)

	var btn_out := GezStyle.medallion_button("zoom_out", ZOOM_SIZE)
	bind_tip(btn_out, "Zoom Out", "Mouse wheel or pinch also zoom.")
	btn_out.pressed.connect(func() -> void: main._zoom_by(1.0 / 1.5, main.size * 0.5))
	zoom_box.add_child(btn_out)

	var btn_fit := GezStyle.medallion_button("zoom_fit", ZOOM_SIZE)
	bind_tip(btn_fit, "Show Whole Map (F)", "")
	btn_fit.pressed.connect(Callable(main, "_show_whole_map"))
	zoom_box.add_child(btn_fit)
	zoom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(MARGIN))

func update_styles(current_mode: String) -> void:
	for k in map_mode_buttons.keys():
		GezStyle.set_medallion_on(map_mode_buttons[k], str(k) == current_mode)
	if dock_button == null:
		return
	var m := _mode_spec(current_mode)
	var key := "map_" + str(m["key"])
	dock_button.set_meta("gez_medallion", key)
	dock_button.texture_normal = GezStyle.medallion(key, mode_grid != null and mode_grid.visible)
	dock_button.texture_pressed = GezStyle.medallion(key, true)
	bind_tip(dock_button, "Map Mode: %s" % m["title"],
		"Click to choose another map mode. Keys Q, O, W, E, R, T, Y, U, I, P, L and K switch directly.")
	close_grid()
