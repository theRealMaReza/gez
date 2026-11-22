extends Control

# Map Timelapse player (Phase 18):
# Replays yearly province owner and religion snapshots on the live map
# with Play/Pause, speed control, mode toggle (Political / Religion), and year scrubber.
# Uses plain Godot controls so the shared Phase 20 Theme styles them automatically.

var main_view: Control = null

var timelapse_panel: PanelContainer
var year_label: Label
var play_btn: Button
var mode_btn: Button
var speed_btn: Button
var year_slider: HSlider

var _years: Array = []
var _current_index: int = 0
var _playing: bool = false
var _show_religion: bool = false
var _speed_idx: int = 0
var _accum_time: float = 0.0

const SPEEDS := [1.0, 2.0, 5.0, 10.0]

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_panel()

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if main_view == null:
		return fallback
	return main_view.call("_call_bridge", method_name, args, fallback)

func _build_panel() -> void:
	timelapse_panel = PanelContainer.new()
	timelapse_panel.name = "TimelapsePanel"
	timelapse_panel.visible = false
	timelapse_panel.custom_minimum_size = Vector2(680.0, 84.0)
	add_child(timelapse_panel)

	var outer := VBoxContainer.new()
	timelapse_panel.add_child(outer)

	var top_row := HBoxContainer.new()
	outer.add_child(top_row)

	var title := Label.new()
	title.text = "Map Timelapse"
	top_row.add_child(title)

	year_label = Label.new()
	year_label.text = "1453"
	year_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(year_label)

	play_btn = Button.new()
	play_btn.text = "Play"
	play_btn.pressed.connect(_on_play_pressed)
	top_row.add_child(play_btn)

	speed_btn = Button.new()
	speed_btn.text = "1x"
	speed_btn.pressed.connect(_on_speed_pressed)
	top_row.add_child(speed_btn)

	mode_btn = Button.new()
	mode_btn.text = "Political"
	mode_btn.pressed.connect(_on_mode_pressed)
	top_row.add_child(mode_btn)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close Timelapse and return to live map"
	close_btn.pressed.connect(close_window)
	top_row.add_child(close_btn)

	year_slider = HSlider.new()
	year_slider.min_value = 0.0
	year_slider.max_value = 0.0
	year_slider.step = 1.0
	year_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	year_slider.value_changed.connect(_on_slider_changed)
	outer.add_child(year_slider)

func is_open() -> bool:
	return timelapse_panel != null and timelapse_panel.visible

func open_window() -> void:
	if timelapse_panel == null:
		return
	timelapse_panel.visible = true
	_position_panel()
	_playing = false
	_accum_time = 0.0
	refresh()

func close_window() -> void:
	_playing = false
	if timelapse_panel != null:
		timelapse_panel.visible = false
	_call_bridge("setTimelapseActive", [false])
	_set_country_names_visible(true)
	if main_view != null and main_view.has_method("_refresh_styles_and_country_labels"):
		main_view.call("_refresh_styles_and_country_labels")

func toggle_window() -> void:
	if is_open():
		close_window()
	else:
		open_window()

func _position_panel() -> void:
	if timelapse_panel == null:
		return
	var vp := get_viewport_rect().size
	var w := minf(760.0, maxf(520.0, vp.x * 0.56))
	timelapse_panel.size = Vector2(w, 92.0)
	timelapse_panel.position = Vector2((vp.x - w) * 0.5, vp.y - 148.0)

func refresh() -> void:
	if not is_open():
		return
	var info: Variant = _call_bridge("getTimelapseInfo", [], {})
	if typeof(info) != TYPE_DICTIONARY or not bool(info.get("hasWorld", false)):
		return
	_years = info.get("years", [])
	if _years.is_empty():
		year_label.text = "No snapshots"
		return
	year_slider.min_value = 0.0
	year_slider.max_value = float(maxi(0, _years.size() - 1))
	_current_index = clampi(_current_index, 0, _years.size() - 1)
	year_slider.set_value_no_signal(float(_current_index))
	_apply_frame()

func _process(delta: float) -> void:
	if not is_open() or not _playing or _years.size() <= 1:
		return
	_accum_time += delta * float(SPEEDS[_speed_idx])
	if _accum_time >= 1.0:
		var steps := int(_accum_time)
		_accum_time -= float(steps)
		_current_index += steps
		if _current_index >= _years.size() - 1:
			_current_index = _years.size() - 1
			_playing = false
			play_btn.text = "Play"
		year_slider.set_value_no_signal(float(_current_index))
		_apply_frame()

func _on_play_pressed() -> void:
	if _years.size() <= 1:
		return
	if _current_index >= _years.size() - 1:
		_current_index = 0
		year_slider.set_value_no_signal(0.0)
	_playing = not _playing
	play_btn.text = "Pause" if _playing else "Play"

func _on_speed_pressed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEEDS.size()
	speed_btn.text = "%dx" % int(SPEEDS[_speed_idx])

func _on_mode_pressed() -> void:
	_show_religion = not _show_religion
	mode_btn.text = "Religion" if _show_religion else "Political"
	_apply_frame()

func _on_slider_changed(val: float) -> void:
	_current_index = clampi(int(roundf(val)), 0, maxi(0, _years.size() - 1))
	_apply_frame()

func _apply_frame() -> void:
	if _years.is_empty():
		return
	year_label.text = str(_years[_current_index])
	_call_bridge("setTimelapseFrame", [_current_index, _show_religion])
	_set_country_names_visible(false)
	if main_view != null and main_view.has_method("_refresh_styles_and_country_labels"):
		main_view.call("_refresh_styles_and_country_labels")

# The curved country names show today's borders, so hide them while an old
# year is on the map and bring them back when the Timelapse closes.
func _set_country_names_visible(on: bool) -> void:
	if main_view == null:
		return
	var layer = main_view.get("labels_layer")
	if layer is CanvasItem:
		layer.visible = on
