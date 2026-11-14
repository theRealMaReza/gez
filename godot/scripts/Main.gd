extends Control

const MapShader := preload("res://shaders/map.gdshader")
const LabelsLayerScript := preload("res://scripts/MapLabelsLayer.gd")

var bridge: RefCounted = null
var map_rect: ColorRect
var map_material: ShaderMaterial
var labels_layer: Control

# Top bar widgets
var country_label: Label
var ducats_label: Label
var date_label: Label
var selection_label: Label
var fps_label: Label
var pause_btn: Button
var play_as_btn: Button
var speed_buttons: Array[Button] = []

# Map dimensions & GPU textures
var map_size := Vector2(3936.0, 2384.0)
var style_tex_width: int = 2048
var id_tex: ImageTexture
var sea_tex: ImageTexture
var style_tex: ImageTexture
var terrain_tex: ImageTexture

# Camera state (in viewport points, matching App/Shared/Map/MapCanvasView.swift)
var zoom: float = 0.0
var offset: Vector2 = Vector2.ZERO
var elapsed_time: float = 0.0

# Pointer / drag state
var is_pointer_down: bool = false
var is_dragging: bool = false
var pointer_down_pos: Vector2 = Vector2.ZERO
var drag_start_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# The root Control covers the whole window. With the default mouse filter
	# (STOP) it swallowed every click, drag and scroll before they reached
	# _unhandled_input, so the map could not be clicked, dragged or zoomed.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_scene_ui()
	_init_bridge_and_map()
	resized.connect(_on_viewport_resized)
	call_deferred("_reset_to_start_camera")

func _build_scene_ui() -> void:
	# 1. Fullscreen shaded map ColorRect
	map_rect = ColorRect.new()
	map_rect.name = "MapRect"
	map_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_material = ShaderMaterial.new()
	map_material.shader = MapShader
	map_rect.material = map_material
	add_child(map_rect)

	# 2. Country / Sea / Province labels overlay
	labels_layer = Control.new()
	labels_layer.name = "LabelsLayer"
	labels_layer.set_script(LabelsLayerScript)
	labels_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	labels_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(labels_layer)

	# 3. Top bar panel (country, ducats, date, pause & speeds 1–5)
	var top_bar := PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0.0, 48.0)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.15, 0.12, 0.09, 0.94)
	bar_style.border_color = Color(0.68, 0.55, 0.28, 0.85)
	bar_style.border_width_bottom = 2
	bar_style.content_margin_left = 16.0
	bar_style.content_margin_right = 16.0
	bar_style.content_margin_top = 8.0
	bar_style.content_margin_bottom = 8.0
	top_bar.add_theme_stylebox_override("panel", bar_style)
	add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	top_bar.add_child(hbox)

	country_label = _make_top_label("Ottoman Empire (TUR)", Color(0.97, 0.88, 0.62), 16)
	hbox.add_child(country_label)

	hbox.add_child(_make_separator())

	var ducats_prefix := _make_top_label("Ducats:", Color(0.80, 0.75, 0.65), 14)
	hbox.add_child(ducats_prefix)

	ducats_label = _make_top_label("0 (+0.0/mo)", Color(0.96, 0.82, 0.32), 15)
	hbox.add_child(ducats_label)

	hbox.add_child(_make_separator())

	selection_label = _make_top_label("Click a province to inspect", Color(0.86, 0.83, 0.76), 13)
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(selection_label)

	play_as_btn = Button.new()
	play_as_btn.visible = false
	play_as_btn.tooltip_text = "Switch to the country that owns the selected province"
	play_as_btn.pressed.connect(_on_play_as_pressed)
	hbox.add_child(play_as_btn)

	date_label = _make_top_label("30 May 1453", Color(0.96, 0.93, 0.86), 15)
	date_label.custom_minimum_size = Vector2(130.0, 0.0)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(date_label)

	pause_btn = Button.new()
	pause_btn.text = "PAUSED"
	pause_btn.custom_minimum_size = Vector2(86.0, 30.0)
	pause_btn.tooltip_text = "Toggle Pause (Space)"
	pause_btn.pressed.connect(_on_pause_pressed)
	hbox.add_child(pause_btn)

	var speed_box := HBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 4)
	hbox.add_child(speed_box)

	speed_buttons.clear()
	for s in range(1, 6):
		var b := Button.new()
		b.text = str(s)
		b.custom_minimum_size = Vector2(30.0, 30.0)
		b.tooltip_text = "Speed %d (Key %d)" % [s, s]
		var spd := s
		b.pressed.connect(func() -> void: _on_speed_selected(spd))
		speed_box.add_child(b)
		speed_buttons.append(b)

	hbox.add_child(_make_separator())

	fps_label = _make_top_label("60 FPS", Color(0.72, 0.82, 0.72), 13)
	fps_label.custom_minimum_size = Vector2(64.0, 0.0)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(fps_label)

	# 4. Bottom-right zoom buttons (+, -, Fit)
	var zoom_box := VBoxContainer.new()
	zoom_box.name = "ZoomButtons"
	zoom_box.add_theme_constant_override("separation", 6)
	add_child(zoom_box)

	var btn_in := Button.new()
	btn_in.text = "+"
	btn_in.custom_minimum_size = Vector2(38.0, 38.0)
	btn_in.tooltip_text = "Zoom In"
	btn_in.pressed.connect(func() -> void: _zoom_by(1.5, size * 0.5))
	zoom_box.add_child(btn_in)

	var btn_out := Button.new()
	btn_out.text = "−"
	btn_out.custom_minimum_size = Vector2(38.0, 38.0)
	btn_out.tooltip_text = "Zoom Out"
	btn_out.pressed.connect(func() -> void: _zoom_by(1.0 / 1.5, size * 0.5))
	zoom_box.add_child(btn_out)

	var btn_fit := Button.new()
	btn_fit.text = "Fit"
	btn_fit.custom_minimum_size = Vector2(38.0, 38.0)
	btn_fit.tooltip_text = "Show Whole Map (F)"
	btn_fit.pressed.connect(_show_whole_map)
	zoom_box.add_child(btn_fit)
	# Anchor to the bottom-right corner, 16 px in. (Setting `position` after
	# the anchor preset placed the buttons outside the window.)
	zoom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)

func _make_top_label(txt: String, col: Color, fsize: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", fsize)
	return lbl

func _make_separator() -> VSeparator:
	var sep := VSeparator.new()
	sep.modulate = Color(0.68, 0.55, 0.28, 0.5)
	return sep

func _init_bridge_and_map() -> void:
	if not ClassDB.class_exists(&"GezGodotBridge"):
		selection_label.text = "ERROR: GezGodotBridge GDExtension not loaded. Run ./build_mac.sh first."
		push_error("GezGodotBridge class not found. Run ./build_mac.sh inside godot/.")
		return

	bridge = ClassDB.instantiate(&"GezGodotBridge")
	var data_dir := ProjectSettings.globalize_path("res://../Packages/GezCore/Sources/GezCore/Resources")
	var ok: bool = bridge.call("setup", data_dir, "TUR")
	if not ok:
		selection_label.text = "Failed to load 1453 scenario from " + data_dir
		push_error("GezGodotBridge.setup failed for path: " + data_dir)
		return

	var w: int = bridge.call("getMapWidth")
	var h: int = bridge.call("getMapHeight")
	map_size = Vector2(float(w), float(h))
	style_tex_width = bridge.call("getStyleTextureWidth")

	# Build ID map, sea map, and style textures.
	var id_bytes: PackedByteArray = bridge.call("getProvinceIDBytes")
	var id_img := Image.create_from_data(w, h, false, Image.FORMAT_RG8, id_bytes)
	id_tex = ImageTexture.create_from_image(id_img)

	var sea_bytes: PackedByteArray = bridge.call("getSeaIDBytes")
	var sea_img := Image.create_from_data(w, h, false, Image.FORMAT_RG8, sea_bytes)
	sea_tex = ImageTexture.create_from_image(sea_img)

	var style_bytes: PackedByteArray = bridge.call("getStyleBytes")
	var style_img := Image.create_from_data(style_tex_width, 2, false, Image.FORMAT_RGBA8, style_bytes)
	style_tex = ImageTexture.create_from_image(style_img)

	var terrain_path := ProjectSettings.globalize_path("res://../App/Resources/Terrain/terrain.jpg")
	var terrain_img := Image.load_from_file(terrain_path)
	if terrain_img != null:
		terrain_tex = ImageTexture.create_from_image(terrain_img)

	map_material.set_shader_parameter("map_size", map_size)
	map_material.set_shader_parameter("id_tex", id_tex)
	map_material.set_shader_parameter("sea_tex", sea_tex)
	map_material.set_shader_parameter("style_tex", style_tex)
	if terrain_tex != null:
		map_material.set_shader_parameter("terrain_tex", terrain_tex)

	# Populate map labels.
	labels_layer.call(
		"set_country_labels",
		bridge.call("getCountryLabelTexts"),
		bridge.call("getCountryLabelMetrics")
	)
	labels_layer.call(
		"set_province_labels",
		bridge.call("getProvinceLabelTexts"),
		bridge.call("getProvinceLabelMetrics")
	)
	labels_layer.call(
		"set_sea_labels",
		bridge.call("getSeaLabelTexts"),
		bridge.call("getSeaLabelMetrics")
	)

	_refresh_top_bar()

func _process(delta: float) -> void:
	elapsed_time += delta
	map_material.set_shader_parameter("time_sec", elapsed_time)
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	# Keyboard panning (WASD / Arrow keys)
	var pan_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		pan_dir.x += 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		pan_dir.x -= 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		pan_dir.y += 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		pan_dir.y -= 1.0
	if pan_dir != Vector2.ZERO and zoom > 0.0:
		offset = _clamped_offset(offset + pan_dir.normalized() * 650.0 * delta, zoom)
		_sync_camera_uniforms()

	if bridge == null:
		return

	var mask: int = bridge.call("tickFrame", delta)
	if mask != 0:
		_refresh_top_bar()
		if (mask & 4) != 0:
			_refresh_styles_and_country_labels()

func _refresh_styles_and_country_labels() -> void:
	if bridge == null:
		return
	var style_bytes: PackedByteArray = bridge.call("getStyleBytes")
	var style_img := Image.create_from_data(style_tex_width, 2, false, Image.FORMAT_RGBA8, style_bytes)
	style_tex.update(style_img)
	labels_layer.call(
		"set_country_labels",
		bridge.call("getCountryLabelTexts"),
		bridge.call("getCountryLabelMetrics")
	)

func _refresh_top_bar() -> void:
	if bridge == null:
		return
	var c_name: String = bridge.call("getCountryName")
	var c_tag: String = bridge.call("getCountryTag")
	country_label.text = "%s (%s)" % [c_name, c_tag]
	ducats_label.text = bridge.call("getDucatsText")
	date_label.text = bridge.call("getDateText")

	var paused: bool = bridge.call("isPaused")
	var spd: int = bridge.call("getSpeed")
	pause_btn.text = "PAUSED" if paused else "RUNNING"
	pause_btn.modulate = Color(1.0, 0.78, 0.45) if paused else Color(0.75, 1.0, 0.78)
	for i in range(speed_buttons.size()):
		var active := (not paused) and (spd == i + 1)
		speed_buttons[i].modulate = Color(1.0, 0.88, 0.40) if active else Color(0.85, 0.85, 0.85)

# MARK: - Camera & Input (matches App/Shared/Map/MapCanvasView.swift)

func _fit_zoom() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.3
	return minf(size.x / map_size.x, size.y / map_size.y)

func _min_zoom() -> float:
	return _fit_zoom() * 0.9

func _max_zoom() -> float:
	return 8.0

func _reset_to_start_camera() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fit := _fit_zoom()
	zoom = minf(fit * 3.0, _max_zoom())
	var focus := Vector2(2150.0, 820.0)
	if bridge != null:
		focus = bridge.call("getFocusPoint", 41.0, 29.0)
	var x := size.x * 0.5 - focus.x * zoom
	var y := size.y * 0.5 - focus.y * zoom
	offset = _clamped_offset(Vector2(x, y), zoom)
	_sync_camera_uniforms()

func _show_whole_map() -> void:
	zoom = _fit_zoom()
	offset = _clamped_offset(Vector2.ZERO, zoom)
	_sync_camera_uniforms()

func _clamped_offset(o: Vector2, z: float) -> Vector2:
	var w := map_size.x * z
	var h := map_size.y * z
	var margin := 80.0
	var x := o.x
	var y := o.y
	if w <= size.x:
		x = (size.x - w) * 0.5
	else:
		x = minf(maxf(x, size.x - w - margin), margin)
	if h <= size.y:
		y = (size.y - h) * 0.5
	else:
		y = minf(maxf(y, size.y - h - margin), margin)
	return Vector2(x, y)

func _zoom_by(factor: float, anchor: Vector2) -> void:
	if zoom <= 0.0:
		return
	var new_zoom := clampf(zoom * factor, _min_zoom(), _max_zoom())
	var ratio := new_zoom / zoom
	var new_offset := Vector2(
		anchor.x - (anchor.x - offset.x) * ratio,
		anchor.y - (anchor.y - offset.y) * ratio
	)
	zoom = new_zoom
	offset = _clamped_offset(new_offset, new_zoom)
	_sync_camera_uniforms()

func _sync_camera_uniforms() -> void:
	if map_material == null:
		return
	map_material.set_shader_parameter("view_size", size)
	map_material.set_shader_parameter("offset", offset)
	map_material.set_shader_parameter("zoom", zoom)
	# Stronger colour tint when zoomed out, lighter when zoomed in so terrain shows through.
	var tint := clampf(0.72 - 0.2 * zoom, 0.38, 0.66)
	map_material.set_shader_parameter("tint", tint)
	if labels_layer != null:
		labels_layer.call("update_camera", zoom, offset)

func _on_viewport_resized() -> void:
	if zoom <= 0.0:
		_reset_to_start_camera()
	else:
		offset = _clamped_offset(offset, zoom)
		_sync_camera_uniforms()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_pause_pressed()
				get_viewport().set_input_as_handled()
			KEY_1:
				_on_speed_selected(1)
				get_viewport().set_input_as_handled()
			KEY_2:
				_on_speed_selected(2)
				get_viewport().set_input_as_handled()
			KEY_3:
				_on_speed_selected(3)
				get_viewport().set_input_as_handled()
			KEY_4:
				_on_speed_selected(4)
				get_viewport().set_input_as_handled()
			KEY_5:
				_on_speed_selected(5)
				get_viewport().set_input_as_handled()
			KEY_EQUAL, KEY_KP_ADD:
				_zoom_by(1.25, size * 0.5)
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_by(1.0 / 1.25, size * 0.5)
				get_viewport().set_input_as_handled()
			KEY_F:
				_show_whole_map()
				get_viewport().set_input_as_handled()
		return

	# macOS trackpad two-finger scroll pan
	if event is InputEventPanGesture:
		offset = _clamped_offset(offset - event.delta * 18.0, zoom)
		_sync_camera_uniforms()
		get_viewport().set_input_as_handled()
		return

	# macOS trackpad pinch-to-zoom
	if event is InputEventMagnifyGesture:
		_zoom_by(event.factor, get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.12, event.position)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / 1.12, event.position)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pointer_down = true
				is_dragging = false
				pointer_down_pos = event.position
				drag_start_offset = offset
			else:
				if is_pointer_down and not is_dragging:
					_handle_map_click(event.position)
				is_pointer_down = false
				is_dragging = false
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and is_pointer_down:
		var delta_pos: Vector2 = event.position - pointer_down_pos
		if not is_dragging and delta_pos.length() >= 3.0:
			is_dragging = true
		if is_dragging:
			offset = _clamped_offset(drag_start_offset + delta_pos, zoom)
			_sync_camera_uniforms()
		get_viewport().set_input_as_handled()

func _handle_map_click(screen_pos: Vector2) -> void:
	if bridge == null or zoom <= 0.0:
		return
	var map_x := int(floor((screen_pos.x - offset.x) / zoom))
	var map_y := int(floor((screen_pos.y - offset.y) / zoom))
	var sel_id: int = bridge.call("selectAt", map_x, map_y)
	var sel_sea: int = bridge.call("getSelectedSeaValue")
	map_material.set_shader_parameter("selected", sel_id)
	map_material.set_shader_parameter("selected_sea", sel_sea)
	var summary: String = bridge.call("getProvinceSummaryAt", map_x, map_y)
	selection_label.text = summary if not summary.is_empty() else "Deep Sea"
	_refresh_play_as_button()

func _refresh_play_as_button() -> void:
	if bridge == null or play_as_btn == null:
		return
	var owner_name: String = bridge.call("getSelectedOwnerName")
	play_as_btn.visible = not owner_name.is_empty()
	play_as_btn.text = "Play as " + owner_name

func _on_play_as_pressed() -> void:
	if bridge == null:
		return
	var switched: bool = bridge.call("playAsSelectedOwner")
	if switched:
		_refresh_styles_and_country_labels()
		_refresh_top_bar()
		_refresh_play_as_button()

func _on_pause_pressed() -> void:
	if bridge == null:
		return
	bridge.call("togglePause")
	_refresh_top_bar()

func _on_speed_selected(spd: int) -> void:
	if bridge == null:
		return
	bridge.call("setSpeed", spd)
	_refresh_top_bar()
