extends Control

const FIELD_MARGIN := 12.0

var main_view: Control = null
var bridge: Variant = null

var state: Dictionary = {}
var selected_units: Array[int] = []
var drag_unit_index: int = -1
var is_dragging_unit: bool = false
var drag_offset_field := Vector2.ZERO

# Layout transforms (field coords <-> canvas local coords)
var field_w: float = 1200.0
var field_h: float = 800.0
var canvas_scale: float = 1.0
var canvas_origin := Vector2.ZERO

# UI nodes
var root_vbox: VBoxContainer
var top_bar: PanelContainer
var att_title_lbl: Label
var att_stats_lbl: Label
var att_morale_bar: ProgressBar
var title_lbl: Label
var phase_lbl: Label
var speed_buttons: Dictionary = {} # speed_idx -> Button
var def_title_lbl: Label
var def_stats_lbl: Label
var def_morale_bar: ProgressBar

var canvas: Control
var bottom_bar: PanelContainer
var sel_info_lbl: Label
var status_hint_lbl: Label
var start_battle_btn: Button

var _refresh_accum: float = 0.0

func setup(p_main: Control, p_bridge: Variant) -> void:
	main_view = p_main
	bridge = p_bridge
	name = "BattleView"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func set_bridge(p_bridge: Variant) -> void:
	bridge = p_bridge

func open_battle() -> void:
	refresh_state()
	if bool(state.get("active", false)):
		visible = true
		selected_units.clear()
		drag_unit_index = -1
		is_dragging_unit = false
		_sync_ui_from_state()
		if canvas != null:
			canvas.queue_redraw()

func close_battle() -> void:
	visible = false
	selected_units.clear()
	drag_unit_index = -1
	is_dragging_unit = false

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if bridge == null:
		return fallback
	if not bridge.has_method(method_name):
		return fallback
	return bridge.callv(method_name, args)

func _make_panel_style(bg := Color(0.11, 0.09, 0.07, 0.96), border := Color(0.70, 0.56, 0.28, 0.90)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s

func _make_label(txt: String, col := Color(0.95, 0.92, 0.84), font_size := 13) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", font_size)
	return l

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.05, 0.04, 1.0)
	add_child(backdrop)

	root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 4)
	add_child(root_vbox)

	# 1. Top Battle HUD (fits 1440x900 cleanly)
	top_bar = PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0.0, 62.0)
	top_bar.add_theme_stylebox_override("panel", _make_panel_style())
	root_vbox.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_hbox)

	# Attacker block
	var att_box := VBoxContainer.new()
	att_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(att_box)
	att_title_lbl = _make_label("Attacker", Color(0.96, 0.86, 0.56), 14)
	att_box.add_child(att_title_lbl)
	att_stats_lbl = _make_label("0 men", Color(0.90, 0.88, 0.80), 12)
	att_box.add_child(att_stats_lbl)
	att_morale_bar = ProgressBar.new()
	att_morale_bar.custom_minimum_size = Vector2(180.0, 10.0)
	att_morale_bar.max_value = 100.0
	att_morale_bar.value = 100.0
	att_morale_bar.show_percentage = false
	att_box.add_child(att_morale_bar)

	# Center title + timer + speeds
	var center_box := VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(center_box)
	title_lbl = _make_label("Field Battle", Color(0.98, 0.94, 0.84), 15)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(title_lbl)

	var speed_row := HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_row.add_theme_constant_override("separation", 6)
	center_box.add_child(speed_row)
	phase_lbl = _make_label("DEPLOYMENT · 00:00", Color(0.86, 0.82, 0.72), 12)
	speed_row.add_child(phase_lbl)

	for spd_pair in [[0, "Pause"], [1, "0.5x"], [2, "1x"], [3, "2x"]]:
		var s_idx: int = int(spd_pair[0])
		var s_btn := Button.new()
		s_btn.text = str(spd_pair[1])
		s_btn.custom_minimum_size = Vector2(54.0, 28.0)
		s_btn.pressed.connect(func() -> void:
			_call_bridge("setTacticalBattleSpeed", [s_idx], false)
			refresh_state()
		)
		speed_row.add_child(s_btn)
		speed_buttons[s_idx] = s_btn

	# Defender block
	var def_box := VBoxContainer.new()
	def_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(def_box)
	def_title_lbl = _make_label("Defender", Color(0.75, 0.88, 0.98), 14)
	def_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	def_box.add_child(def_title_lbl)
	def_stats_lbl = _make_label("0 men", Color(0.90, 0.88, 0.80), 12)
	def_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	def_box.add_child(def_stats_lbl)
	def_morale_bar = ProgressBar.new()
	def_morale_bar.custom_minimum_size = Vector2(180.0, 10.0)
	def_morale_bar.max_value = 100.0
	def_morale_bar.value = 100.0
	def_morale_bar.show_percentage = false
	def_morale_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	def_box.add_child(def_morale_bar)

	# 2. Central 2D Battlefield Canvas
	canvas = Control.new()
	canvas.name = "BattleCanvas"
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_on_canvas_draw)
	canvas.gui_input.connect(_on_canvas_gui_input)
	root_vbox.add_child(canvas)

	# 3. Bottom Command Bar (touch & Pencil friendly large targets)
	bottom_bar = PanelContainer.new()
	bottom_bar.custom_minimum_size = Vector2(0.0, 92.0)
	bottom_bar.add_theme_stylebox_override("panel", _make_panel_style())
	root_vbox.add_child(bottom_bar)

	var bot_hbox := HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 14)
	bottom_bar.add_child(bot_hbox)

	sel_info_lbl = _make_label("Tap or click a regiment to inspect or deploy it.", Color(0.92, 0.89, 0.80), 13)
	sel_info_lbl.custom_minimum_size = Vector2(360.0, 0.0)
	sel_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bot_hbox.add_child(sel_info_lbl)

	status_hint_lbl = _make_label("Deployment Phase: Drag regiments within your highlighted zone.", Color(0.84, 0.80, 0.72), 13)
	status_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bot_hbox.add_child(status_hint_lbl)

	start_battle_btn = Button.new()
	start_battle_btn.text = "Start Battle!"
	start_battle_btn.custom_minimum_size = Vector2(180.0, 48.0)
	start_battle_btn.modulate = Color(0.75, 1.0, 0.78)
	start_battle_btn.pressed.connect(func() -> void:
		if bool(_call_bridge("startTacticalBattle", [], false)):
			refresh_state()
	)
	bot_hbox.add_child(start_battle_btn)

func _process(delta: float) -> void:
	if not visible or bridge == null:
		return
	var ph: String = str(state.get("phase", ""))
	if ph == "active":
		var ticks: int = int(_call_bridge("tickTacticalBattle", [delta], 0))
		_refresh_accum += delta
		if ticks > 0 or _refresh_accum >= 0.05:
			_refresh_accum = 0.0
			refresh_state()

func refresh_state() -> void:
	state = _call_bridge("getBattleState", [], {})
	if not bool(state.get("active", false)):
		return
	field_w = maxf(100.0, float(state.get("fieldW", 1200.0)))
	field_h = maxf(100.0, float(state.get("fieldH", 800.0)))
	_sync_ui_from_state()
	if canvas != null:
		canvas.queue_redraw()

func _sync_ui_from_state() -> void:
	if state.is_empty():
		return
	var p_name: String = str(state.get("provinceName", "Field"))
	var t_name: String = str(state.get("terrainName", "Plains"))
	var crossing_txt := " · River Crossing" if bool(state.get("isRiverCrossing", false)) else ""
	var assault_txt := "Storm Assault: " if bool(state.get("isAssault", false)) else "Battle of "
	title_lbl.text = "%s%s (%s%s)" % [assault_txt, p_name, t_name, crossing_txt]

	var att_name: String = str(state.get("attackerName", "Attacker"))
	var att_cmd: String = str(state.get("attackerCommander", ""))
	var att_mar: int = int(state.get("attackerMartial", 0))
	var att_men: int = int(state.get("attackerMen", 0))
	var att_init: int = maxi(1, int(state.get("attackerInitialMen", 1)))
	att_title_lbl.text = "%s (%s · Martial %d)" % [att_name, att_cmd, att_mar]
	att_stats_lbl.text = "%s / %s men · Morale %.1f" % [_fmt_int(att_men), _fmt_int(att_init), float(state.get("attackerAvgMorale", 0.0))]
	att_morale_bar.value = clampf(float(state.get("attackerAvgMorale", 0.0)) * 33.0, 0.0, 100.0)

	var def_name: String = str(state.get("defenderName", "Defender"))
	var def_cmd: String = str(state.get("defenderCommander", ""))
	var def_mar: int = int(state.get("defenderMartial", 0))
	var def_men: int = int(state.get("defenderMen", 0))
	var def_init: int = maxi(1, int(state.get("defenderInitialMen", 1)))
	def_title_lbl.text = "%s (%s · Martial %d)" % [def_name, def_cmd, def_mar]
	def_stats_lbl.text = "%s / %s men · Morale %.1f" % [_fmt_int(def_men), _fmt_int(def_init), float(state.get("defenderAvgMorale", 0.0))]
	def_morale_bar.value = clampf(float(state.get("defenderAvgMorale", 0.0)) * 33.0, 0.0, 100.0)

	var ph: String = str(state.get("phase", "deployment"))
	var secs := int(floor(float(state.get("elapsedSeconds", 0.0))))
	var mm := secs / 60
	var ss := secs % 60
	phase_lbl.text = "%s · %02d:%02d" % [ph.to_upper(), mm, ss]

	var cur_spd: int = int(state.get("speedIndex", 2))
	for s_idx in speed_buttons.keys():
		var b: Button = speed_buttons[s_idx]
		b.disabled = (ph != "active")
		b.modulate = Color(1.0, 0.88, 0.42) if (ph == "active" and int(s_idx) == cur_spd) else Color(0.86, 0.86, 0.86)

	var is_deploy := (ph == "deployment")
	start_battle_btn.visible = is_deploy
	if is_deploy:
		status_hint_lbl.text = "Deployment Phase: Drag your regiments within your deployment zone, then press Start Battle."
	elif bool(state.get("attackerAmbushed", false)) and str(state.get("playerSide", "attacker")) == "attacker":
		status_hint_lbl.text = "AMBUSH AT THE FORD! Vanguard caught crossing the river — command your regiments now!"
	else:
		status_hint_lbl.text = "Real-time Battle Active (%s)." % str(state.get("speedLabel", "1x"))

	_update_selected_info()

func _update_selected_info() -> void:
	if selected_units.is_empty():
		sel_info_lbl.text = "No regiment selected.\nTap or click any regiment on the field."
		return
	var units: Array = state.get("units", [])
	var idx := selected_units[0]
	if idx < 0 or idx >= units.size():
		sel_info_lbl.text = "%d regiments selected." % selected_units.size()
		return
	var u: Dictionary = units[idx]
	var extra := "" if selected_units.size() == 1 else " (+%d more)" % (selected_units.size() - 1)
	var ammo_txt := ""
	if int(u.get("maxAmmo", 0)) > 0:
		ammo_txt = " · Ammo %d/%d" % [int(u.get("ammo", 0)), int(u.get("maxAmmo", 0))]
	sel_info_lbl.text = "%s%s [%s]\n%d/%d men · Morale %.1f · %s%s" % [
		str(u.get("name", "Unit")),
		extra,
		str(u.get("formation", "line")).capitalize(),
		int(u.get("men", 0)),
		int(u.get("maxMen", 1000)),
		float(u.get("morale", 0.0)),
		str(u.get("stance", "hold")).capitalize(),
		ammo_txt
	]

func _compute_canvas_transform() -> void:
	var c_size := canvas.size
	var avail_w := maxf(100.0, c_size.x - FIELD_MARGIN * 2.0)
	var avail_h := maxf(100.0, c_size.y - FIELD_MARGIN * 2.0)
	canvas_scale = minf(avail_w / field_w, avail_h / field_h)
	var drawn_w := field_w * canvas_scale
	var drawn_h := field_h * canvas_scale
	canvas_origin = Vector2((c_size.x - drawn_w) * 0.5, (c_size.y - drawn_h) * 0.5)

func _field_to_canvas(pt: Vector2) -> Vector2:
	return canvas_origin + pt * canvas_scale

func _canvas_to_field(pos: Vector2) -> Vector2:
	if canvas_scale <= 0.0001:
		return Vector2.ZERO
	return (pos - canvas_origin) / canvas_scale

func _terrain_ground_color(t_key: String) -> Color:
	match t_key:
		"farmland": return Color(0.46, 0.50, 0.30)
		"plains": return Color(0.40, 0.48, 0.28)
		"hills": return Color(0.43, 0.41, 0.29)
		"mountains": return Color(0.37, 0.35, 0.33)
		"forest": return Color(0.28, 0.38, 0.24)
		"marsh": return Color(0.30, 0.36, 0.30)
		"desert": return Color(0.64, 0.55, 0.38)
		"steppe": return Color(0.50, 0.47, 0.30)
		_: return Color(0.40, 0.46, 0.29)

func _on_canvas_draw() -> void:
	if state.is_empty():
		return
	_compute_canvas_transform()

	# 1. Ground fill
	var field_rect := Rect2(canvas_origin, Vector2(field_w, field_h) * canvas_scale)
	var ground_col := _terrain_ground_color(str(state.get("terrainKey", "plains")))
	canvas.draw_rect(field_rect, ground_col, true)
	canvas.draw_rect(field_rect, Color(0.75, 0.65, 0.40, 0.6), false, 2.0)

	# 2. Shaded elevation hills
	var hills: Array = state.get("hills", [])
	for h_item in hills:
		if not (h_item is Dictionary):
			continue
		var hx := float(h_item.get("x", 0.0))
		var hy := float(h_item.get("y", 0.0))
		var rx := float(h_item.get("rx", 80.0))
		var ry := float(h_item.get("ry", 70.0))
		var ang := float(h_item.get("angle", 0.0))
		var height := float(h_item.get("height", 15.0))
		var intensity := clampf(height / 38.0, 0.15, 0.9)
		for ring in [1.0, 0.68, 0.38]:
			var pts := PackedVector2Array()
			for step in range(28):
				var theta := TAU * float(step) / 28.0
				var lx: float = cos(theta) * rx * ring
				var ly: float = sin(theta) * ry * ring
				var wx: float = hx + lx * cos(ang) - ly * sin(ang)
				var wy: float = hy + lx * sin(ang) + ly * cos(ang)
				pts.append(_field_to_canvas(Vector2(wx, wy)))
			var shade := ground_col.lightened(0.10 + intensity * (1.15 - ring) * 0.22)
			shade.a = 0.42
			canvas.draw_colored_polygon(pts, shade)
			pts.append(pts[0])
			canvas.draw_polyline(pts, Color(0.22, 0.20, 0.16, 0.38), 1.2)

	# 3. Forest patches
	var forests: Array = state.get("forests", [])
	for f_item in forests:
		if not (f_item is Dictionary):
			continue
		var fx := float(f_item.get("x", 0.0))
		var fy := float(f_item.get("y", 0.0))
		var rx := float(f_item.get("rx", 60.0))
		var ry := float(f_item.get("ry", 50.0))
		var pts := PackedVector2Array()
		for step in range(24):
			var theta := TAU * float(step) / 24.0
			var wobble := 0.88 + 0.12 * sin(theta * 3.0 + fx * 0.05)
			var wx := fx + cos(theta) * rx * wobble
			var wy := fy + sin(theta) * ry * wobble
			pts.append(_field_to_canvas(Vector2(wx, wy)))
		canvas.draw_colored_polygon(pts, Color(0.13, 0.27, 0.12, 0.62))
		pts.append(pts[0])
		canvas.draw_polyline(pts, Color(0.08, 0.18, 0.08, 0.78), 1.5)

	# 4. River crossing & fords
	if bool(state.get("hasRiver", false)):
		var r_pts: Array = state.get("riverPoints", [])
		var hw := float(state.get("riverHalfWidth", 26.0)) * canvas_scale
		if r_pts.size() >= 2:
			var poly := PackedVector2Array()
			for p_dict in r_pts:
				if p_dict is Dictionary:
					poly.append(_field_to_canvas(Vector2(float(p_dict.get("x", 600.0)), float(p_dict.get("y", 0.0)))))
			if poly.size() >= 2:
				canvas.draw_polyline(poly, Color(0.32, 0.44, 0.34, 0.85), hw * 2.35)
				canvas.draw_polyline(poly, Color(0.18, 0.41, 0.62, 0.92), hw * 1.95)
		var fords: Array = state.get("fords", [])
		for ford in fords:
			if ford is Dictionary:
				var f_tl := _field_to_canvas(Vector2(float(ford.get("x", 0.0)), float(ford.get("y", 0.0))))
				var f_sz := Vector2(float(ford.get("w", 40.0)), float(ford.get("h", 60.0))) * canvas_scale
				canvas.draw_rect(Rect2(f_tl, f_sz), Color(0.58, 0.54, 0.40, 0.84), true)
				canvas.draw_rect(Rect2(f_tl, f_sz), Color(0.84, 0.78, 0.58, 0.75), false, 1.5)

	# 5. Deployment zones
	if str(state.get("phase", "")) == "deployment":
		var p_side: String = str(state.get("playerSide", "attacker"))
		var att_r := Rect2(
			_field_to_canvas(Vector2(float(state.get("attDeployX", 50.0)), float(state.get("attDeployY", 50.0)))),
			Vector2(float(state.get("attDeployW", 350.0)), float(state.get("attDeployH", 700.0))) * canvas_scale
		)
		var def_r := Rect2(
			_field_to_canvas(Vector2(float(state.get("defDeployX", 800.0)), float(state.get("defDeployY", 50.0)))),
			Vector2(float(state.get("defDeployW", 350.0)), float(state.get("defDeployH", 700.0))) * canvas_scale
		)
		var att_border := Color(0.95, 0.78, 0.25, 0.85) if p_side == "attacker" else Color(0.80, 0.35, 0.30, 0.45)
		var def_border := Color(0.95, 0.78, 0.25, 0.85) if p_side == "defender" else Color(0.35, 0.65, 0.90, 0.45)
		canvas.draw_rect(att_r, Color(att_border.r, att_border.g, att_border.b, 0.08), true)
		canvas.draw_rect(att_r, att_border, false, 2.0)
		canvas.draw_rect(def_r, Color(def_border.r, def_border.g, def_border.b, 0.08), true)
		canvas.draw_rect(def_r, def_border, false, 2.0)

	# 6. Unit blocks
	var font := ThemeDB.fallback_font
	var units: Array = state.get("units", [])
	for u_item in units:
		if not (u_item is Dictionary):
			continue
		var men := int(u_item.get("men", 0))
		if men <= 0:
			continue
		var idx := int(u_item.get("index", -1))
		var center := _field_to_canvas(Vector2(float(u_item.get("x", 0.0)), float(u_item.get("y", 0.0))))
		var bw := maxf(18.0, float(u_item.get("w", 24.0)) * canvas_scale)
		var bh := maxf(24.0, float(u_item.get("h", 44.0)) * canvas_scale)
		var ang := float(u_item.get("facing", 0.0))
		var form: String = str(u_item.get("formation", "line"))
		var routing := bool(u_item.get("isRouting", false))
		var is_sel := selected_units.has(idx)

		var col := Color(
			float(int(u_item.get("colorR", 180))) / 255.0,
			float(int(u_item.get("colorG", 120))) / 255.0,
			float(int(u_item.get("colorB", 80))) / 255.0
		)
		if routing:
			col = col.darkened(0.42)
			col.a = 0.72

		var poly := _unit_shape_polygon(center, bw, bh, ang, form)
		canvas.draw_colored_polygon(poly, col)
		var border_col := Color(1.0, 0.90, 0.25, 1.0) if is_sel else (Color(0.95, 0.28, 0.24, 0.9) if routing else Color(0.95, 0.92, 0.82, 0.85))
		var closed := poly.duplicate()
		closed.append(poly[0])
		canvas.draw_polyline(closed, border_col, 2.6 if is_sel else 1.4)

		# Facing arrow
		var fwd := Vector2(cos(ang), sin(ang))
		var arrow_start := center + fwd * (bw * 0.45)
		var arrow_tip := center + fwd * (bw * 0.5 + 11.0 * maxf(0.75, canvas_scale))
		canvas.draw_line(arrow_start, arrow_tip, Color(1.0, 0.95, 0.70, 0.95), 2.0)

		# Strength bar above block
		var max_m := maxf(1.0, float(u_item.get("maxMen", 1000)))
		var hp_frac := clampf(float(men) / max_m, 0.0, 1.0)
		var bar_w := 30.0
		var bar_tl := center + Vector2(-bar_w * 0.5, -maxf(bw, bh) * 0.5 - 9.0)
		canvas.draw_rect(Rect2(bar_tl, Vector2(bar_w, 4.0)), Color(0.08, 0.08, 0.08, 0.85), true)
		var hp_col := Color(0.32, 0.88, 0.42) if hp_frac > 0.45 else Color(0.94, 0.44, 0.30)
		canvas.draw_rect(Rect2(bar_tl, Vector2(bar_w * hp_frac, 4.0)), hp_col, true)

		# Unit glyph & men count
		if font != null:
			var glyph := str(u_item.get("glyph", "I"))
			canvas.draw_string(font, center + Vector2(-5.0, 4.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.98, 0.96, 0.90))
			canvas.draw_string(font, center + Vector2(-14.0, maxf(bw, bh) * 0.5 + 12.0), "%d" % men, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.94, 0.90, 0.80))

func _unit_shape_polygon(center: Vector2, w: float, h: float, ang: float, form: String) -> PackedVector2Array:
	var local_pts: Array[Vector2]
	var hw := w * 0.5
	var hh := h * 0.5
	if form == "wedge":
		local_pts = [Vector2(hw * 1.15, 0.0), Vector2(-hw * 0.85, hh), Vector2(-hw * 0.85, -hh)]
	else:
		local_pts = [Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh)]
	var c := cos(ang)
	var s := sin(ang)
	var out := PackedVector2Array()
	for p in local_pts:
		out.append(center + Vector2(p.x * c - p.y * s, p.x * s + p.y * c))
	return out

func _hit_test_unit(canvas_pos: Vector2, own_only: bool = false) -> int:
	var f_pos := _canvas_to_field(canvas_pos)
	var p_side_int := 1 if str(state.get("playerSide", "attacker")) == "defender" else 0
	var units: Array = state.get("units", [])
	var best_idx := -1
	var best_d2 := 34.0 * 34.0 # Generous touch / Pencil hit radius
	for u_item in units:
		if not (u_item is Dictionary) or int(u_item.get("men", 0)) <= 0:
			continue
		if own_only and int(u_item.get("side", 0)) != p_side_int:
			continue
		var ux := float(u_item.get("x", 0.0))
		var uy := float(u_item.get("y", 0.0))
		var d2 := Vector2(ux, uy).distance_squared_to(f_pos)
		if d2 <= best_d2:
			best_d2 = d2
			best_idx = int(u_item.get("index", -1))
	return best_idx

func _on_canvas_gui_input(event: InputEvent) -> void:
	if state.is_empty():
		return
	var ph: String = str(state.get("phase", ""))
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit_own := _hit_test_unit(event.position, true)
			var hit_any := hit_own if hit_own >= 0 else _hit_test_unit(event.position, false)
			if hit_any >= 0:
				selected_units = [hit_any]
				_update_selected_info()
				canvas.queue_redraw()
			else:
				selected_units.clear()
				_update_selected_info()
				canvas.queue_redraw()
			if ph == "deployment" and hit_own >= 0:
				drag_unit_index = hit_own
				is_dragging_unit = true
				var u: Dictionary = state.get("units", [])[hit_own]
				drag_offset_field = Vector2(float(u.get("x", 0.0)), float(u.get("y", 0.0))) - _canvas_to_field(event.position)
		else:
			is_dragging_unit = false
			drag_unit_index = -1
		canvas.accept_event()
		return

	if event is InputEventMouseMotion and is_dragging_unit and drag_unit_index >= 0 and ph == "deployment":
		var f_target := _canvas_to_field(event.position) + drag_offset_field
		var units: Array = state.get("units", [])
		var cur_facing := 0.0
		if drag_unit_index < units.size():
			cur_facing = float(units[drag_unit_index].get("facing", 0.0))
		if bool(_call_bridge("deployMoveBattleUnit", [drag_unit_index, f_target.x, f_target.y, cur_facing], false)):
			refresh_state()
		canvas.accept_event()

func _fmt_int(v: int) -> String:
	var s := str(abs(v))
	var out := ""
	var n := s.length()
	for i in range(n):
		out += s[i]
		var rem := n - 1 - i
		if rem > 0 and rem % 3 == 0:
			out += ","
	return ("-" + out) if v < 0 else out
