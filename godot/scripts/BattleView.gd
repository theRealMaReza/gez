extends Control

const FIELD_MARGIN := 10.0

var main_view: Control = null
var bridge: Variant = null

var state: Dictionary = {}
var selected_units: Array[int] = []
var drag_unit_index: int = -1
var is_dragging_unit: bool = false
var drag_offset_field := Vector2.ZERO

# Interactive Part B order tool states ("select", "move", "attack", "path", "frontline")
var active_tool: String = "select"
var is_box_selecting: bool = false
var box_start_canvas := Vector2.ZERO
var box_cur_canvas := Vector2.ZERO
var is_sketching_path: bool = false
var sketched_points_field: Array[Vector2] = []
var is_dragging_frontline: bool = false
var frontline_start_field := Vector2.ZERO
var frontline_end_field := Vector2.ZERO

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
var tool_buttons: Dictionary = {}      # tool_key -> Button
var siege_buttons: Dictionary = {}     # equip_key -> Button
var formation_buttons: Dictionary = {} # form_key -> Button
var stance_buttons: Dictionary = {}    # stance_key -> Button
var orders_panel: VBoxContainer
var retreat_btn: Button
var result_panel: PanelContainer
var result_title_lbl: Label
var result_sub_lbl: Label
var result_body_lbl: Label
var result_done_btn: Button

var _refresh_accum: float = 0.0

func setup(p_main: Control, p_bridge: Variant) -> void:
	main_view = p_main
	bridge = p_bridge
	name = "BattleView"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func set_bridge(p_bridge: Variant) -> void:
	bridge = p_bridge

func open_battle() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh_state()
	if bool(state.get("active", false)):
		visible = true
		selected_units.clear()
		active_tool = "select"
		_clear_gestures()
		_sync_ui_from_state()
		if canvas != null:
			canvas.queue_redraw()

func close_battle() -> void:
	visible = false
	if result_panel != null:
		result_panel.visible = false
	selected_units.clear()
	_clear_gestures()

func _clear_gestures() -> void:
	drag_unit_index = -1
	is_dragging_unit = false
	is_box_selecting = false
	is_sketching_path = false
	sketched_points_field.clear()
	is_dragging_frontline = false

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if bridge == null:
		return fallback
	if not bridge.has_method(method_name):
		return fallback
	return bridge.callv(method_name, args)

func _selected_csv() -> String:
	var parts: PackedStringArray = []
	for idx in selected_units:
		parts.append(str(idx))
	return ",".join(parts)

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
	backdrop.color = Color(0.06, 0.05, 0.04, 1.0)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 4)
	add_child(root_vbox)
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 1. Top Battle HUD (62px high)
	top_bar = PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0.0, 62.0)
	top_bar.add_theme_stylebox_override("panel", _make_panel_style())
	root_vbox.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_hbox)

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
		s_btn.custom_minimum_size = Vector2(56.0, 30.0)
		s_btn.pressed.connect(func() -> void:
			_call_bridge("setTacticalBattleSpeed", [s_idx], false)
			refresh_state()
		)
		speed_row.add_child(s_btn)
		speed_buttons[s_idx] = s_btn

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

	# 3. Bottom Command Bar (124px high — large touch & Apple Pencil friendly controls, fits 1440x900)
	bottom_bar = PanelContainer.new()
	bottom_bar.custom_minimum_size = Vector2(0.0, 124.0)
	bottom_bar.add_theme_stylebox_override("panel", _make_panel_style())
	root_vbox.add_child(bottom_bar)

	var bot_hbox := HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 12)
	bottom_bar.add_child(bot_hbox)

	# Left: Selected unit readout
	sel_info_lbl = _make_label("Tap or drag a box to select regiments.", Color(0.92, 0.89, 0.80), 12)
	sel_info_lbl.custom_minimum_size = Vector2(280.0, 0.0)
	sel_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bot_hbox.add_child(sel_info_lbl)

	# Center: Tools + Formations + Stances
	orders_panel = VBoxContainer.new()
	orders_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orders_panel.add_theme_constant_override("separation", 5)
	bot_hbox.add_child(orders_panel)

	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 6)
	orders_panel.add_child(tools_row)

	var all_btn := Button.new()
	all_btn.text = "All (A)"
	all_btn.custom_minimum_size = Vector2(72.0, 34.0)
	all_btn.pressed.connect(func() -> void: _select_all_player_units())
	tools_row.add_child(all_btn)

	for t_pair in [
		["select", "Select / Box"],
		["move", "Move Order"],
		["path", "Draw Path"],
		["frontline", "Drag Frontline"],
		["attack", "Attack Target"]
	]:
		var key: String = str(t_pair[0])
		var btn := Button.new()
		btn.text = str(t_pair[1])
		btn.custom_minimum_size = Vector2(104.0, 34.0)
		btn.pressed.connect(func() -> void:
			active_tool = key
			_sync_tool_styles()
		)
		tools_row.add_child(btn)
		tool_buttons[key] = btn

	retreat_btn = Button.new()
	retreat_btn.text = "Retreat"
	retreat_btn.custom_minimum_size = Vector2(88.0, 34.0)
	retreat_btn.modulate = Color(1.0, 0.56, 0.50)
	retreat_btn.pressed.connect(func() -> void:
		if not selected_units.is_empty():
			_call_bridge("orderBattleRetreat", [_selected_csv()], false)
			refresh_state()
	)
	tools_row.add_child(retreat_btn)

	for eq_pair in [
		["ladders", "Ladders"],
		["ram", "Ram"],
		["none", "Storm"]
	]:
		var eq_key: String = str(eq_pair[0])
		var eq_btn := Button.new()
		eq_btn.text = str(eq_pair[1])
		eq_btn.custom_minimum_size = Vector2(72.0, 34.0)
		eq_btn.visible = false
		eq_btn.pressed.connect(func() -> void:
			if not selected_units.is_empty():
				_call_bridge("orderBattleSiegeEquipment", [_selected_csv(), eq_key], false)
				refresh_state()
		)
		tools_row.add_child(eq_btn)
		siege_buttons[eq_key] = eq_btn

	var form_row := HBoxContainer.new()
	form_row.add_theme_constant_override("separation", 5)
	orders_panel.add_child(form_row)
	form_row.add_child(_make_label("Form:", Color(0.80, 0.76, 0.66), 11))
	for f_pair in [
		["line", "Line"],
		["column", "Column"],
		["wedge", "Wedge"],
		["square", "Square"],
		["wagonLaager", "Wagons"],
		["skirmish", "Skirmish"]
	]:
		var f_key: String = str(f_pair[0])
		var f_btn := Button.new()
		f_btn.text = str(f_pair[1])
		f_btn.custom_minimum_size = Vector2(74.0, 32.0)
		f_btn.pressed.connect(func() -> void:
			if not selected_units.is_empty():
				_call_bridge("orderBattleFormation", [_selected_csv(), f_key], false)
				refresh_state()
		)
		form_row.add_child(f_btn)
		formation_buttons[f_key] = f_btn

	form_row.add_child(VSeparator.new())
	form_row.add_child(_make_label("Stance:", Color(0.80, 0.76, 0.66), 11))
	for st_pair in [
		["hold", "Hold"],
		["advance", "Advance"],
		["charge", "Charge"],
		["volley", "Volley"],
		["holdFire", "Hold Fire"]
	]:
		var st_key: String = str(st_pair[0])
		var st_btn := Button.new()
		st_btn.text = str(st_pair[1])
		st_btn.custom_minimum_size = Vector2(76.0, 32.0)
		st_btn.pressed.connect(func() -> void:
			if not selected_units.is_empty():
				_call_bridge("orderBattleStance", [_selected_csv(), st_key], false)
				refresh_state()
		)
		form_row.add_child(st_btn)
		stance_buttons[st_key] = st_btn

	status_hint_lbl = _make_label("Deployment Phase", Color(0.82, 0.78, 0.70), 11)
	status_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orders_panel.add_child(status_hint_lbl)

	# Right: Start Battle button (visible during Deployment)
	start_battle_btn = Button.new()
	start_battle_btn.text = "Start Battle!"
	start_battle_btn.custom_minimum_size = Vector2(160.0, 52.0)
	start_battle_btn.modulate = Color(0.75, 1.0, 0.78)
	start_battle_btn.pressed.connect(func() -> void:
		if bool(_call_bridge("startTacticalBattle", [], false)):
			active_tool = "select"
			refresh_state()
	)
	bot_hbox.add_child(start_battle_btn)

	# 4. Centered Battle Result Panel (shown when phase == "ended")
	result_panel = PanelContainer.new()
	result_panel.name = "BattleResultPanel"
	result_panel.visible = false
	result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_panel.add_theme_stylebox_override("panel", _make_panel_style())
	result_panel.custom_minimum_size = Vector2(540.0, 320.0)
	add_child(result_panel)
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -270.0
	result_panel.offset_right = 270.0
	result_panel.offset_top = -165.0
	result_panel.offset_bottom = 165.0

	var res_vbox := VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 10)
	result_panel.add_child(res_vbox)

	result_title_lbl = _make_label("Battle Concluded", Color(0.98, 0.88, 0.45), 20)
	result_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_vbox.add_child(result_title_lbl)

	result_sub_lbl = _make_label("", Color(0.88, 0.85, 0.76), 13)
	result_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_vbox.add_child(result_sub_lbl)

	res_vbox.add_child(HSeparator.new())

	result_body_lbl = _make_label("", Color(0.94, 0.92, 0.84), 13)
	result_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body_lbl.custom_minimum_size = Vector2(490.0, 145.0)
	res_vbox.add_child(result_body_lbl)

	result_done_btn = Button.new()
	result_done_btn.text = "Return to Campaign Map"
	result_done_btn.custom_minimum_size = Vector2(240.0, 44.0)
	result_done_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result_done_btn.modulate = Color(0.75, 1.0, 0.78)
	result_done_btn.pressed.connect(func() -> void:
		_call_bridge("finishTacticalBattle", [], {})
		close_battle()
		if main_view != null and main_view.has_method("_on_tactical_battle_closed"):
			main_view.call("_on_tactical_battle_closed")
	)
	res_vbox.add_child(result_done_btn)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ph: String = str(state.get("phase", ""))
		match event.keycode:
			KEY_SPACE:
				if ph == "active":
					var cur := int(state.get("speedIndex", 2))
					var nxt := 2 if cur == 0 else 0
					_call_bridge("setTacticalBattleSpeed", [nxt], false)
					refresh_state()
					get_viewport().set_input_as_handled()
			KEY_1:
				if ph == "active":
					_call_bridge("setTacticalBattleSpeed", [1], false)
					refresh_state()
					get_viewport().set_input_as_handled()
			KEY_2:
				if ph == "active":
					_call_bridge("setTacticalBattleSpeed", [2], false)
					refresh_state()
					get_viewport().set_input_as_handled()
			KEY_3:
				if ph == "active":
					_call_bridge("setTacticalBattleSpeed", [3], false)
					refresh_state()
					get_viewport().set_input_as_handled()
			KEY_A:
				_select_all_player_units()
				get_viewport().set_input_as_handled()
			KEY_S:
				active_tool = "select"
				_sync_tool_styles()
				get_viewport().set_input_as_handled()
			KEY_M:
				active_tool = "move"
				_sync_tool_styles()
				get_viewport().set_input_as_handled()
			KEY_P:
				active_tool = "path"
				_sync_tool_styles()
				get_viewport().set_input_as_handled()
			KEY_F:
				active_tool = "frontline"
				_sync_tool_styles()
				get_viewport().set_input_as_handled()

func _select_all_player_units() -> void:
	selected_units.clear()
	var p_side_int := 1 if str(state.get("playerSide", "attacker")) == "defender" else 0
	var units: Array = state.get("units", [])
	for u_item in units:
		if u_item is Dictionary and int(u_item.get("side", 0)) == p_side_int and int(u_item.get("men", 0)) > 0:
			selected_units.append(int(u_item.get("index", -1)))
	_update_selected_info()
	if canvas != null:
		canvas.queue_redraw()

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

func _sync_tool_styles() -> void:
	var ph: String = str(state.get("phase", "deployment"))
	var is_active := (ph == "active")
	for k in tool_buttons.keys():
		var b: Button = tool_buttons[k]
		b.disabled = (k != "select" and not is_active)
		b.modulate = Color(1.0, 0.88, 0.36) if str(k) == active_tool else Color(0.86, 0.86, 0.86)
	retreat_btn.disabled = (not is_active or selected_units.is_empty())
	for st_k in stance_buttons.keys():
		stance_buttons[st_k].disabled = (not is_active or selected_units.is_empty())
	for f_k in formation_buttons.keys():
		formation_buttons[f_k].disabled = (ph == "ended" or selected_units.is_empty())
	var is_assault := bool(state.get("isAssault", false))
	var p_att := str(state.get("playerSide", "attacker")) == "attacker"
	for eq_k in siege_buttons.keys():
		var sb: Button = siege_buttons[eq_k]
		sb.visible = is_assault and p_att
		sb.disabled = (ph == "ended" or selected_units.is_empty())

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
	phase_lbl.text = "%s · %02d:%02d" % [ph.to_upper(), secs / 60, secs % 60]

	var cur_spd: int = int(state.get("speedIndex", 2))
	for s_idx in speed_buttons.keys():
		var b: Button = speed_buttons[s_idx]
		b.disabled = (ph != "active")
		b.modulate = Color(1.0, 0.88, 0.42) if (ph == "active" and int(s_idx) == cur_spd) else Color(0.86, 0.86, 0.86)

	var is_deploy := (ph == "deployment")
	start_battle_btn.visible = is_deploy
	if is_deploy:
		status_hint_lbl.text = "Deployment: Drag your regiments within the highlighted zone, set formations, then press Start Battle."
		result_panel.visible = false
	elif ph == "ended":
		var win_side := str(state.get("winner", "")).capitalize()
		status_hint_lbl.text = "Battle Concluded — %s Victory!" % win_side
		_sync_result_panel()
	elif bool(state.get("attackerAmbushed", false)) and str(state.get("playerSide", "attacker")) == "attacker":
		status_hint_lbl.text = "AMBUSH AT THE FORD! Choose Select/Move/Path/Frontline tools or right-click to issue orders."
		result_panel.visible = false
	else:
		status_hint_lbl.text = "Active (%s) · Tools work with single-tap/drag (touch & Pencil friendly) or Right-Click Move." % str(state.get("speedLabel", "1x"))
		result_panel.visible = false

	_sync_tool_styles()
	_update_selected_info()

func _sync_result_panel() -> void:
	if result_panel == null:
		return
	var res: Dictionary = state.get("resultPreview", {})
	if res.is_empty():
		result_panel.visible = false
		return
	var winner_side := str(res.get("winner", ""))
	var p_side := str(state.get("playerSide", "attacker"))
	var player_won := (winner_side == p_side)
	var kind_lbl := "Storm Assault" if bool(res.get("isAssault", false)) else "Field Battle"
	var prov := str(res.get("provinceName", state.get("provinceName", "")))
	result_title_lbl.text = ("VICTORY AT %s!" if player_won else "DEFEAT AT %s") % prov.to_upper()
	result_title_lbl.add_theme_color_override("font_color", Color(0.55, 0.96, 0.58) if player_won else Color(0.96, 0.45, 0.40))
	result_sub_lbl.text = "%s · Winner: %s (%d s)" % [
		kind_lbl,
		str(res.get("winnerName", winner_side.capitalize())),
		int(round(float(res.get("elapsedSeconds", 0.0))))
	]

	var att_init := int(res.get("attackerInitialMen", 0))
	var att_loss := int(res.get("attackerLosses", 0))
	var att_surv := int(res.get("attackerSurvivors", 0))
	var def_init := int(res.get("defenderInitialMen", 0))
	var def_loss := int(res.get("defenderLosses", 0))
	var def_surv := int(res.get("defenderSurvivors", 0))
	var ws_pct := float(res.get("warScoreDelta", 0.0)) * 100.0

	var lines: PackedStringArray = [
		"%s (Attacker): %s men -> %s lost, %s survived" % [str(res.get("attackerName", "Attacker")), _fmt_int(att_init), _fmt_int(att_loss), _fmt_int(att_surv)],
		"  Commander: %s (%s)" % [str(res.get("attackerCommanderName", "")), str(res.get("attackerCommanderFate", "Active"))],
		"%s (Defender): %s men -> %s lost, %s survived" % [str(res.get("defenderName", "Defender")), _fmt_int(def_init), _fmt_int(def_loss), _fmt_int(def_surv)],
		"  Commander: %s (%s)" % [str(res.get("defenderCommanderName", "")), str(res.get("defenderCommanderFate", "Active"))],
		"War Score Impact: +%.1f%%" % ws_pct
	]
	if bool(res.get("wasStackwipe", false)):
		lines.append("Total Rout — Defeated army overrun!")
	if bool(res.get("isAssault", false)):
		var gar := int(res.get("remainingGarrison", 0))
		if bool(res.get("fortCaptured", false)):
			lines.append("Fortress Captured! New Garrison: %s men." % _fmt_int(gar))
		elif bool(res.get("newBreachCreated", false)):
			lines.append("Fort Held (Garrison: %s), but walls were BREACHED!" % _fmt_int(gar))
		else:
			lines.append("Fort Held — Remaining Garrison: %s men." % _fmt_int(gar))

	result_body_lbl.text = "\n".join(lines)
	result_panel.visible = true

func _update_selected_info() -> void:
	if selected_units.is_empty():
		sel_info_lbl.text = "No regiment selected.\nTap, box-drag, or press All (A) to command regiments."
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
	var fatigue_pct := int(round(float(u.get("fatigue", 0.0)) * 100.0))
	var routing_txt := " · ROUTING!" if bool(u.get("isRouting", false)) else ""
	var equip_txt := ""
	var eq_key := str(u.get("siegeEquipment", "none"))
	if bool(state.get("isAssault", false)) and eq_key != "none":
		equip_txt = " · Gear: %s" % eq_key.capitalize()
	sel_info_lbl.text = "%s%s [%s]\n%d/%d men · Morale %.1f · Fatigue %d%% · %s%s%s%s" % [
		str(u.get("name", "Unit")),
		extra,
		str(u.get("formation", "line")).capitalize(),
		int(u.get("men", 0)),
		int(u.get("maxMen", 1000)),
		float(u.get("morale", 0.0)),
		fatigue_pct,
		str(u.get("stance", "hold")).capitalize(),
		ammo_txt,
		equip_txt,
		routing_txt
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

	# 5b. Fortification structures & Inner Keep Zone (Part C Assaults)
	var font := ThemeDB.fallback_font
	var structures: Array = state.get("structures", [])
	if not structures.is_empty():
		var kz_dict: Dictionary = state.get("keepZone", {})
		if not kz_dict.is_empty():
			var kz_rect := Rect2(
				_field_to_canvas(Vector2(float(kz_dict.get("x", 965.0)), float(kz_dict.get("y", 290.0)))),
				Vector2(float(kz_dict.get("w", 165.0)), float(kz_dict.get("h", 220.0))) * canvas_scale
			)
			canvas.draw_rect(kz_rect, Color(0.75, 0.62, 0.25, 0.14), true)
			canvas.draw_rect(kz_rect, Color(0.92, 0.78, 0.30, 0.65), false, 2.0)
			var k_prog := float(state.get("keepCaptureProgress", 0.0))
			if k_prog > 0.005:
				var arc_center := kz_rect.get_center()
				canvas.draw_arc(arc_center, 34.0 * canvas_scale, -PI * 0.5, -PI * 0.5 + TAU * clampf(k_prog, 0.0, 1.0), 32, Color(0.98, 0.82, 0.22, 0.95), 4.5)
				if font != null:
					canvas.draw_string(font, arc_center + Vector2(-24.0, 4.0), "KEEP %d%%" % int(round(k_prog * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.94, 0.72))

		for s_item in structures:
			if not (s_item is Dictionary):
				continue
			var sx := float(s_item.get("x", 0.0))
			var sy := float(s_item.get("y", 0.0))
			var sw := float(s_item.get("w", 28.0))
			var sh := float(s_item.get("h", 120.0))
			var s_kind: String = str(s_item.get("kind", "wall"))
			var s_breached := bool(s_item.get("breached", false))
			var s_hp := float(s_item.get("hp", 1.0))
			var s_max := maxf(1.0, float(s_item.get("maxHp", 1.0)))
			var tl := _field_to_canvas(Vector2(sx - sw * 0.5, sy - sh * 0.5))
			var r_rect := Rect2(tl, Vector2(sw, sh) * canvas_scale)

			if s_breached:
				# Rubble / open breach passage
				canvas.draw_rect(r_rect, Color(0.32, 0.27, 0.22, 0.45), true)
				canvas.draw_line(r_rect.position, r_rect.position + Vector2(r_rect.size.x, 0.0), Color(0.55, 0.48, 0.38, 0.8), 2.0)
				canvas.draw_line(r_rect.position + Vector2(0.0, r_rect.size.y), r_rect.end, Color(0.55, 0.48, 0.38, 0.8), 2.0)
				if font != null:
					canvas.draw_string(font, r_rect.get_center() + Vector2(-22.0, 4.0), "BREACH", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.65, 0.30))
			else:
				var col := Color(0.54, 0.52, 0.49)
				if s_kind == "gate":
					col = Color(0.42, 0.28, 0.16)
				elif s_kind == "tower":
					col = Color(0.62, 0.60, 0.56)
				elif s_kind == "keep":
					col = Color(0.48, 0.46, 0.44)
				canvas.draw_rect(r_rect, col, true)
				canvas.draw_rect(r_rect, Color(0.24, 0.22, 0.20), false, 2.2)
				if s_kind == "gate" or s_kind == "keep":
					if font != null:
						var lbl_txt := "GATE" if s_kind == "gate" else "KEEP"
						canvas.draw_string(font, r_rect.get_center() + Vector2(-14.0, 4.0), lbl_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.90, 0.80))
				if s_hp < s_max and s_kind != "keep":
					var hp_f := clampf(s_hp / s_max, 0.0, 1.0)
					var bar_r := Rect2(r_rect.position + Vector2(0.0, -7.0), Vector2(r_rect.size.x, 4.0))
					canvas.draw_rect(bar_r, Color(0.1, 0.1, 0.1, 0.85), true)
					canvas.draw_rect(Rect2(bar_r.position, Vector2(bar_r.size.x * hp_f, 4.0)), Color(0.92, 0.62, 0.26), true)

	# 6. Active unit order paths/targets
	var units: Array = state.get("units", [])
	for u_item in units:
		if not (u_item is Dictionary) or int(u_item.get("men", 0)) <= 0:
			continue
		var idx := int(u_item.get("index", -1))
		if not selected_units.has(idx):
			continue
		var c_pos := _field_to_canvas(Vector2(float(u_item.get("x", 0.0)), float(u_item.get("y", 0.0))))
		var wps: Array = u_item.get("waypoints", [])
		if not wps.is_empty():
			var line := PackedVector2Array([c_pos])
			for wp in wps:
				if wp is Dictionary:
					line.append(_field_to_canvas(Vector2(float(wp.get("x", 0.0)), float(wp.get("y", 0.0)))))
			if line.size() >= 2:
				canvas.draw_polyline(line, Color(0.96, 0.84, 0.32, 0.8), 2.0)
		elif bool(u_item.get("hasMoveOrder", false)):
			var dest := _field_to_canvas(Vector2(float(u_item.get("targetX", 0.0)), float(u_item.get("targetY", 0.0))))
			canvas.draw_line(c_pos, dest, Color(0.96, 0.84, 0.32, 0.7), 1.8)
			canvas.draw_circle(dest, 4.0, Color(0.96, 0.84, 0.32, 0.85))

	# 7. Unit blocks
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

		if form == "wagonLaager":
			canvas.draw_arc(center, maxf(bw, bh) * 0.56, 0.0, TAU, 16, Color(0.84, 0.68, 0.42, 0.88), 2.0)

		var fwd := Vector2(cos(ang), sin(ang))
		var arrow_start := center + fwd * (bw * 0.45)
		var arrow_tip := center + fwd * (bw * 0.5 + 11.0 * maxf(0.75, canvas_scale))
		canvas.draw_line(arrow_start, arrow_tip, Color(1.0, 0.95, 0.70, 0.95), 2.0)

		var max_m := maxf(1.0, float(u_item.get("maxMen", 1000)))
		var hp_frac := clampf(float(men) / max_m, 0.0, 1.0)
		var mor_frac := clampf(float(u_item.get("morale", 0.0)) / maxf(1.0, float(u_item.get("maxMorale", 3.0))), 0.0, 1.0)
		var bar_w := 30.0
		var bar_tl := center + Vector2(-bar_w * 0.5, -maxf(bw, bh) * 0.5 - 11.0)
		canvas.draw_rect(Rect2(bar_tl, Vector2(bar_w, 4.0)), Color(0.08, 0.08, 0.08, 0.85), true)
		var hp_col := Color(0.32, 0.88, 0.42) if hp_frac > 0.45 else Color(0.94, 0.44, 0.30)
		canvas.draw_rect(Rect2(bar_tl, Vector2(bar_w * hp_frac, 4.0)), hp_col, true)
		canvas.draw_rect(Rect2(bar_tl + Vector2(0.0, 5.0), Vector2(bar_w * mor_frac, 2.5)), Color(0.94, 0.82, 0.30), true)

		if font != null:
			var glyph := str(u_item.get("glyph", "I"))
			var eq_str := str(u_item.get("siegeEquipment", "none"))
			var badge := ""
			if eq_str == "ladders":
				badge = " [L]"
			elif eq_str == "ram":
				badge = " [R]"
			canvas.draw_string(font, center + Vector2(-5.0, 4.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.98, 0.96, 0.90))
			canvas.draw_string(font, center + Vector2(-14.0, maxf(bw, bh) * 0.5 + 12.0), "%d%s" % [men, badge], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.94, 0.90, 0.80))

	# 8. Drag gestures overlay (box select / sketched path / dragged frontline)
	if is_box_selecting:
		var tl := Vector2(minf(box_start_canvas.x, box_cur_canvas.x), minf(box_start_canvas.y, box_cur_canvas.y))
		var sz := Vector2(absf(box_cur_canvas.x - box_start_canvas.x), absf(box_cur_canvas.y - box_start_canvas.y))
		canvas.draw_rect(Rect2(tl, sz), Color(1.0, 0.88, 0.36, 0.14), true)
		canvas.draw_rect(Rect2(tl, sz), Color(1.0, 0.88, 0.36, 0.9), false, 1.8)
	elif is_sketching_path and sketched_points_field.size() >= 2:
		var cpts := PackedVector2Array()
		for fp in sketched_points_field:
			cpts.append(_field_to_canvas(fp))
		canvas.draw_polyline(cpts, Color(0.48, 0.92, 1.0, 0.92), 2.5)
	elif is_dragging_frontline:
		var a := _field_to_canvas(frontline_start_field)
		var b := _field_to_canvas(frontline_end_field)
		canvas.draw_line(a, b, Color(1.0, 0.86, 0.32, 0.95), 3.0)
		var count_sel := maxi(1, selected_units.size())
		for k in range(count_sel):
			var frac := 0.5 if count_sel == 1 else (float(k) / float(count_sel - 1))
			canvas.draw_circle(a.lerp(b, frac), 5.0, Color(1.0, 0.94, 0.55, 0.95))

func _unit_shape_polygon(center: Vector2, w: float, h: float, ang: float, form: String) -> PackedVector2Array:
	var local_pts: Array[Vector2]
	var hw := w * 0.5
	var hh := h * 0.5
	if form == "wedge":
		local_pts = [Vector2(hw * 1.15, 0.0), Vector2(-hw * 0.85, hh), Vector2(-hw * 0.85, -hh)]
	elif form == "wagonLaager":
		local_pts = [
			Vector2(hw, -hh * 0.5), Vector2(hw, hh * 0.5),
			Vector2(hw * 0.5, hh), Vector2(-hw * 0.5, hh),
			Vector2(-hw, hh * 0.5), Vector2(-hw, -hh * 0.5),
			Vector2(-hw * 0.5, -hh), Vector2(hw * 0.5, -hh)
		]
	else:
		local_pts = [Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh)]
	var c := cos(ang)
	var s := sin(ang)
	var out := PackedVector2Array()
	for p in local_pts:
		out.append(center + Vector2(p.x * c - p.y * s, p.x * s + p.y * c))
	return out

func _hit_test_unit(canvas_pos: Vector2, own_only: bool = false, enemy_only: bool = false) -> int:
	var f_pos := _canvas_to_field(canvas_pos)
	var p_side_int := 1 if str(state.get("playerSide", "attacker")) == "defender" else 0
	var units: Array = state.get("units", [])
	var best_idx := -1
	var best_d2 := 34.0 * 34.0
	for u_item in units:
		if not (u_item is Dictionary) or int(u_item.get("men", 0)) <= 0:
			continue
		var u_side := int(u_item.get("side", 0))
		if own_only and u_side != p_side_int:
			continue
		if enemy_only and u_side == p_side_int:
			continue
		var ux := float(u_item.get("x", 0.0))
		var uy := float(u_item.get("y", 0.0))
		var d2 := Vector2(ux, uy).distance_squared_to(f_pos)
		if d2 <= best_d2:
			best_d2 = d2
			best_idx = int(u_item.get("index", -1))
	return best_idx

func _hit_test_structure(canvas_pos: Vector2) -> int:
	if not bool(state.get("isAssault", false)):
		return -1
	var f_pos := _canvas_to_field(canvas_pos)
	var structures: Array = state.get("structures", [])
	for s_item in structures:
		if not (s_item is Dictionary):
			continue
		if bool(s_item.get("breached", false)) or str(s_item.get("kind", "")) == "keep":
			continue
		var sx := float(s_item.get("x", 0.0))
		var sy := float(s_item.get("y", 0.0))
		var sw := float(s_item.get("w", 28.0)) + 20.0
		var sh := float(s_item.get("h", 100.0)) + 12.0
		if absf(f_pos.x - sx) <= sw * 0.5 and absf(f_pos.y - sy) <= sh * 0.5:
			return int(s_item.get("id", -1))
	return -1

func _on_canvas_gui_input(event: InputEvent) -> void:
	if state.is_empty():
		return
	var ph: String = str(state.get("phase", ""))

	# Optional convenience right-click in active battle: move or attack target
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if ph == "active" and not selected_units.is_empty():
			var hit_enemy := _hit_test_unit(event.position, false, true)
			var hit_struct := _hit_test_structure(event.position)
			if hit_enemy >= 0:
				_call_bridge("orderBattleAttack", [_selected_csv(), hit_enemy], false)
			elif hit_struct >= 0:
				_call_bridge("orderBattleAttackStructure", [_selected_csv(), hit_struct], false)
			else:
				var fp := _canvas_to_field(event.position)
				_call_bridge("orderBattleMove", [_selected_csv(), fp.x, fp.y], false)
			refresh_state()
		canvas.accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if ph == "deployment":
				var hit_own := _hit_test_unit(event.position, true)
				if hit_own >= 0:
					selected_units = [hit_own]
					drag_unit_index = hit_own
					is_dragging_unit = true
					var u: Dictionary = state.get("units", [])[hit_own]
					drag_offset_field = Vector2(float(u.get("x", 0.0)), float(u.get("y", 0.0))) - _canvas_to_field(event.position)
				else:
					selected_units.clear()
				_sync_tool_styles()
				_update_selected_info()
				canvas.queue_redraw()
			elif ph == "active":
				match active_tool:
					"move":
						if not selected_units.is_empty():
							var fp := _canvas_to_field(event.position)
							_call_bridge("orderBattleMove", [_selected_csv(), fp.x, fp.y], false)
							refresh_state()
					"attack":
						if not selected_units.is_empty():
							var hit_enemy := _hit_test_unit(event.position, false, true)
							var hit_struct := _hit_test_structure(event.position)
							if hit_enemy >= 0:
								_call_bridge("orderBattleAttack", [_selected_csv(), hit_enemy], false)
								refresh_state()
							elif hit_struct >= 0:
								_call_bridge("orderBattleAttackStructure", [_selected_csv(), hit_struct], false)
								refresh_state()
					"path":
						if not selected_units.is_empty():
							is_sketching_path = true
							sketched_points_field = [_canvas_to_field(event.position)]
					"frontline":
						if not selected_units.is_empty():
							is_dragging_frontline = true
							frontline_start_field = _canvas_to_field(event.position)
							frontline_end_field = frontline_start_field
					_:
						# "select": start drag box or tap unit
						is_box_selecting = true
						box_start_canvas = event.position
						box_cur_canvas = event.position
			canvas.accept_event()
			return
		else:
			# Mouse release
			if is_dragging_unit:
				is_dragging_unit = false
				drag_unit_index = -1
			elif is_sketching_path:
				is_sketching_path = false
				if not selected_units.is_empty() and not sketched_points_field.is_empty():
					var pts_parts: PackedStringArray = []
					for fp in sketched_points_field:
						pts_parts.append("%.1f,%.1f" % [fp.x, fp.y])
					_call_bridge("orderBattlePath", [_selected_csv(), ";".join(pts_parts)], false)
					sketched_points_field.clear()
					refresh_state()
			elif is_dragging_frontline:
				is_dragging_frontline = false
				if not selected_units.is_empty():
					_call_bridge("orderBattleFrontline", [
						_selected_csv(),
						frontline_start_field.x, frontline_start_field.y,
						frontline_end_field.x, frontline_end_field.y
					], false)
					refresh_state()
			elif is_box_selecting:
				is_box_selecting = false
				var drag_dist := box_start_canvas.distance_to(box_cur_canvas)
				if drag_dist < 8.0:
					var hit_own := _hit_test_unit(event.position, true)
					if hit_own >= 0:
						selected_units = [hit_own]
					else:
						selected_units.clear()
				else:
					_select_units_in_box(box_start_canvas, box_cur_canvas)
				_sync_tool_styles()
				_update_selected_info()
				canvas.queue_redraw()
			canvas.accept_event()
			return

	if event is InputEventMouseMotion:
		if is_dragging_unit and drag_unit_index >= 0 and ph == "deployment":
			var f_target := _canvas_to_field(event.position) + drag_offset_field
			var units: Array = state.get("units", [])
			var cur_facing := 0.0
			if drag_unit_index < units.size():
				cur_facing = float(units[drag_unit_index].get("facing", 0.0))
			if bool(_call_bridge("deployMoveBattleUnit", [drag_unit_index, f_target.x, f_target.y, cur_facing], false)):
				refresh_state()
		elif is_box_selecting:
			box_cur_canvas = event.position
			canvas.queue_redraw()
		elif is_sketching_path:
			var fp := _canvas_to_field(event.position)
			if sketched_points_field.is_empty() or sketched_points_field[-1].distance_to(fp) >= 18.0:
				sketched_points_field.append(fp)
				canvas.queue_redraw()
		elif is_dragging_frontline:
			frontline_end_field = _canvas_to_field(event.position)
			canvas.queue_redraw()
		canvas.accept_event()

func _select_units_in_box(p0: Vector2, p1: Vector2) -> void:
	selected_units.clear()
	var fa := _canvas_to_field(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)))
	var fb := _canvas_to_field(Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y)))
	var rect := Rect2(fa, fb - fa)
	var p_side_int := 1 if str(state.get("playerSide", "attacker")) == "defender" else 0
	var units: Array = state.get("units", [])
	for u_item in units:
		if not (u_item is Dictionary) or int(u_item.get("men", 0)) <= 0:
			continue
		if int(u_item.get("side", 0)) != p_side_int:
			continue
		var pos := Vector2(float(u_item.get("x", 0.0)), float(u_item.get("y", 0.0)))
		if rect.has_point(pos):
			selected_units.append(int(u_item.get("index", -1)))

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
