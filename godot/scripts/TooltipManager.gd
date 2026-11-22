extends CanvasLayer

# Shared parchment hover tooltip overlay for all Gez Godot screens (Phase 16).
# Desktop hover with a short delay (Mac & Windows only).

const HOVER_DELAY := 0.30
const SCREEN_MARGIN := 10.0
const CURSOR_OFFSET := Vector2(16.0, 18.0)

var tooltip_panel: PanelContainer
var content_vbox: VBoxContainer
var title_label: Label
var summary_label: Label
var entries_sep: HSeparator
var entries_box: VBoxContainer
var total_sep: HSeparator
var total_row: HBoxContainer
var total_name_label: Label
var total_val_label: Label
var notes_box: VBoxContainer
var _bold_font: Font
var _italic_font: Font

var _hovered_target: Control = null
var _hover_elapsed: float = 0.0
var _is_showing: bool = false
var _canvas_source_id: String = ""
var _canvas_tip_data: Dictionary = {}
var _canvas_elapsed: float = 0.0
var _canvas_showing: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Suppress Godot's built-in dark tooltip so only our shared parchment panel shows.
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 9999.0)
	_build_panel()

func _build_panel() -> void:
	_bold_font = GezTheme.bold_font()
	_italic_font = GezTheme.italic_font()
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "SharedParchmentTooltip"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.custom_minimum_size = Vector2(210.0, 0.0)
	tooltip_panel.z_index = 100

	# Phase 20 part 6 (owner's choice "A"): a compact parchment card in a
	# thin gold frame; red Cinzel heading, gains green, costs red, a double
	# rule above the total.
	var style: StyleBox = GezTheme.tooltip_style()
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	tooltip_panel.add_theme_stylebox_override("panel", style)
	add_child(tooltip_panel)

	content_vbox = VBoxContainer.new()
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_theme_constant_override("separation", 4)
	tooltip_panel.add_child(content_vbox)

	title_label = _make_ink_label("", GezTheme.ACCENT, 16, true)
	title_label.add_theme_font_override("font", GezTheme.caps_font())
	content_vbox.add_child(title_label)

	summary_label = _make_ink_label("", Color(0.25, 0.18, 0.11), 12, true)
	content_vbox.add_child(summary_label)

	entries_sep = _make_sep()
	content_vbox.add_child(entries_sep)

	entries_box = VBoxContainer.new()
	entries_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entries_box.add_theme_constant_override("separation", 2)
	content_vbox.add_child(entries_box)

	total_sep = _make_sep()
	total_sep.add_theme_constant_override("separation", 3)
	content_vbox.add_child(total_sep)
	var second_rule := _make_sep()
	second_rule.add_theme_constant_override("separation", 1)
	total_sep.set_meta("second_rule", second_rule)
	content_vbox.add_child(second_rule)

	total_row = HBoxContainer.new()
	total_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	total_row.add_theme_constant_override("separation", 12)
	content_vbox.add_child(total_row)

	total_name_label = _make_ink_label("Total", Color(0.14, 0.09, 0.04), 14, false)
	total_name_label.add_theme_font_override("font", GezTheme.caps_font())
	total_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(total_name_label)

	total_val_label = _make_ink_label("", Color(0.14, 0.09, 0.04), 14, false)
	total_val_label.add_theme_font_override("font", GezTheme.caps_font())
	total_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_row.add_child(total_val_label)

	notes_box = VBoxContainer.new()
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_box.add_theme_constant_override("separation", 2)
	content_vbox.add_child(notes_box)

func _make_sep() -> HSeparator:
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.modulate = Color(1, 1, 1, 0.9)
	return sep

func _make_ink_label(txt: String, col: Color, fsize: int, wrap: bool) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", GezStyle.fs(fsize))
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(280.0, 0.0)
	return lbl

# MARK: - Public binding API

static func bind_text(ctrl: Control, title: String, body: String = "") -> void:
	if ctrl == null:
		return
	if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	ctrl.set_meta("gez_tip", {"title": title, "summary": body})
	ctrl.tooltip_text = ""

static func bind_breakdown(ctrl: Control, callback: Callable, fallback_title: String = "") -> void:
	if ctrl == null:
		return
	if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	ctrl.set_meta("gez_tip", {"callable": callback, "fallback_title": fallback_title})
	ctrl.tooltip_text = ""

static func bind_data(ctrl: Control, data: Dictionary) -> void:
	if ctrl == null:
		return
	if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	ctrl.set_meta("gez_tip", data)
	ctrl.tooltip_text = ""

func set_canvas_tip(source_id: String, tip_data: Dictionary) -> void:
	if source_id != _canvas_source_id:
		_canvas_source_id = source_id
		_canvas_elapsed = 0.0
		_canvas_showing = false
		if _hovered_target == null:
			tooltip_panel.visible = false
	_canvas_tip_data = tip_data

func clear_canvas_tip(source_id: String = "") -> void:
	if source_id.is_empty() or source_id == _canvas_source_id:
		_canvas_source_id = ""
		_canvas_tip_data = {}
		_canvas_elapsed = 0.0
		_canvas_showing = false
		if _hovered_target == null:
			_hide_panel()

func hide_tip() -> void:
	_hovered_target = null
	_hover_elapsed = 0.0
	_is_showing = false
	_canvas_showing = false
	_hide_panel()

func _hide_panel() -> void:
	if tooltip_panel != null:
		tooltip_panel.visible = false

# MARK: - Hover polling

func _find_tooltip_target(start: Control) -> Control:
	var cur: Node = start
	var steps := 0
	while cur != null and steps < 6:
		if cur is Control:
			var c := cur as Control
			if c.has_meta("gez_tip"):
				return c
			if not c.tooltip_text.is_empty():
				# Migrate legacy tooltip_text lazily so Godot's native tooltip stays suppressed.
				var txt := c.tooltip_text
				c.tooltip_text = ""
				c.set_meta("gez_tip", {"title": "", "summary": txt})
				return c
		cur = cur.get_parent()
		steps += 1
	return null

func _process(delta: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return

	var raw_hovered: Control = vp.gui_get_hovered_control()
	var target: Control = _find_tooltip_target(raw_hovered) if raw_hovered != null else null

	if target != null:
		if target != _hovered_target:
			_hovered_target = target
			_hover_elapsed = 0.0
			_is_showing = false
			_hide_panel()
		else:
			_hover_elapsed += delta
			if _hover_elapsed >= HOVER_DELAY and not _is_showing:
				var resolved := _resolve_control_tip(target)
				if not resolved.is_empty():
					_populate_panel(resolved)
					_is_showing = true
		if _is_showing:
			_place_near_mouse(vp)
		return

	if _hovered_target != null:
		_hovered_target = null
		_hover_elapsed = 0.0
		_is_showing = false
		if _canvas_source_id.is_empty():
			_hide_panel()

	# Fallback for 2D canvas hover targets (e.g. BattleView units/structures, map armies/fleets)
	if not _canvas_source_id.is_empty() and not _canvas_tip_data.is_empty():
		_canvas_elapsed += delta
		if _canvas_elapsed >= HOVER_DELAY and not _canvas_showing:
			_populate_panel(_canvas_tip_data)
			_canvas_showing = true
		if _canvas_showing:
			_place_near_mouse(vp)
	else:
		_hide_panel()

func _resolve_control_tip(ctrl: Control) -> Dictionary:
	if not is_instance_valid(ctrl) or not ctrl.has_meta("gez_tip"):
		return {}
	var spec: Variant = ctrl.get_meta("gez_tip")
	if spec is Dictionary:
		var d: Dictionary = spec
		if d.has("callable"):
			var cb: Variant = d["callable"]
			if cb is Callable and (cb as Callable).is_valid():
				var res: Variant = (cb as Callable).call()
				if res is Dictionary and bool((res as Dictionary).get("valid", true)):
					return res as Dictionary
			var fb := str(d.get("fallback_title", ""))
			return {"title": fb} if not fb.is_empty() else {}
		return d
	elif spec is String:
		return {"summary": str(spec)}
	return {}

func _populate_panel(data: Dictionary) -> void:
	for c in entries_box.get_children():
		entries_box.remove_child(c)
		c.queue_free()
	for c in notes_box.get_children():
		notes_box.remove_child(c)
		c.queue_free()

	var title_txt := str(data.get("title", ""))
	title_label.text = title_txt
	title_label.visible = not title_txt.is_empty()

	var sum_txt := str(data.get("summary", ""))
	summary_label.text = sum_txt
	summary_label.visible = not sum_txt.is_empty()

	var entries: Array = data.get("entries", [])
	entries_sep.visible = not entries.is_empty() and (title_label.visible or summary_label.visible)
	entries_box.visible = not entries.is_empty()

	for item_v in entries:
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 14)
		entries_box.add_child(row)

		var l := _make_ink_label(str(item.get("label", "")), Color(0.25, 0.18, 0.11), 12, false)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)

		var val_txt := str(item.get("valueText", ""))
		if val_txt.is_empty() and item.has("value"):
			val_txt = str(item.get("value"))
		var val_num := float(item.get("value", 0.0))
		var v_col := Color(0.18, 0.13, 0.07)
		if val_txt.begins_with("+") or val_num > 0.0005:
			v_col = Color(0.11, 0.46, 0.16)
		elif val_txt.begins_with("-") or val_txt.begins_with("−") or val_num < -0.0005:
			v_col = Color(0.65, 0.15, 0.11)
		var v := _make_ink_label(val_txt, v_col, 12, false)
		v.add_theme_font_override("font", _bold_font)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)

	var total_txt := str(data.get("totalText", ""))
	var has_total := (not total_txt.is_empty()) and (not entries.is_empty())
	total_sep.visible = has_total
	(total_sep.get_meta("second_rule") as Control).visible = has_total
	total_row.visible = has_total
	if has_total:
		total_name_label.text = str(data.get("totalLabel", "Total"))
		total_val_label.text = total_txt
		var tot_num := float(data.get("total", 0.0))
		var tot_col := Color(0.14, 0.09, 0.04)
		if total_txt.begins_with("+") or tot_num > 0.0005:
			tot_col = Color(0.10, 0.44, 0.15)
		elif total_txt.begins_with("-") or total_txt.begins_with("−") or tot_num < -0.0005:
			tot_col = Color(0.64, 0.14, 0.10)
		total_val_label.add_theme_color_override("font_color", tot_col)

	var notes: Array = data.get("notes", [])
	notes_box.visible = not notes.is_empty()
	for n_v in notes:
		var n_txt := str(n_v)
		if n_txt.is_empty():
			continue
		var note := _make_ink_label(n_txt, Color(0.36, 0.27, 0.17), 11, true)
		note.add_theme_font_override("font", _italic_font)
		notes_box.add_child(note)

	tooltip_panel.reset_size()
	tooltip_panel.visible = true

func _place_near_mouse(vp: Viewport) -> void:
	var vp_size := vp.get_visible_rect().size
	var panel_size := tooltip_panel.get_combined_minimum_size()
	if tooltip_panel.size.x > panel_size.x:
		panel_size.x = tooltip_panel.size.x
	if tooltip_panel.size.y > panel_size.y:
		panel_size.y = tooltip_panel.size.y

	var mouse_pos := vp.get_mouse_position()
	var pos := mouse_pos + CURSOR_OFFSET
	if pos.x + panel_size.x + SCREEN_MARGIN > vp_size.x:
		pos.x = mouse_pos.x - panel_size.x - 12.0
	if pos.y + panel_size.y + SCREEN_MARGIN > vp_size.y:
		pos.y = mouse_pos.y - panel_size.y - 12.0

	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp_size.x - panel_size.x - SCREEN_MARGIN))
	pos.y = clampf(pos.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp_size.y - panel_size.y - SCREEN_MARGIN))
	tooltip_panel.position = pos
