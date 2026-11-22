extends Control

# Ledger & Graphs screen (Phase 18):
# - Compare player + up to 7 countries over time (population, income, army, navy, tech)
# - Religion & Culture pie charts for any compared country
# - Full Ledger table of all active realms
# Uses plain Godot controls so the shared Phase 20 Theme styles them automatically.

var main_view: Control = null

var ledger_panel: PanelContainer
var add_country_picker: OptionButton
var selected_chips_box: HBoxContainer
var pie_country_picker: OptionButton
var metric_buttons: Array = []
var line_chart: Control
var line_legend_box: HBoxContainer
var religion_pie: Control
var religion_legend_box: VBoxContainer
var culture_pie: Control
var culture_legend_box: VBoxContainer
var table_box: VBoxContainer

var _player_index: int = -1
var _selected_countries: Array = [] # Array of int (max 8)
var _all_rows: Array = []
var _available_indices: Array = []
var _pie_country_index: int = -1
var _pie_indices: Array = []
var _active_metric: String = "population"

const METRICS := [
	{"key": "population", "label": "Population"},
	{"key": "income", "label": "Monthly Income"},
	{"key": "armySize", "label": "Army Size"},
	{"key": "navySize", "label": "Navy Size"},
	{"key": "tech", "label": "Technology"},
]

class LineChartCanvas extends Control:
	var series_list: Array = []
	var metric_key: String = "population"

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 40.0 or h < 40.0:
			return
		var pad_l := 68.0
		var pad_r := 18.0
		var pad_t := 14.0
		var pad_b := 24.0
		var plot_w := w - pad_l - pad_r
		var plot_h := h - pad_t - pad_b
		if plot_w <= 10.0 or plot_h <= 10.0:
			return

		draw_rect(Rect2(pad_l, pad_t, plot_w, plot_h), Color(0.36, 0.25, 0.12, 0.08), true)
		draw_rect(Rect2(pad_l, pad_t, plot_w, plot_h), Color(0.36, 0.25, 0.12, 0.70), false, 1.0)

		var min_y := 1e18
		var max_y := -1e18
		var min_yr := 999999
		var max_yr := -999999

		for s in series_list:
			if typeof(s) != TYPE_DICTIONARY:
				continue
			var yrs: Array = s.get("years", [])
			var vals: Array = s.get(metric_key, [])
			for i in range(mini(yrs.size(), vals.size())):
				var yr := int(yrs[i])
				var v := float(vals[i])
				if yr < min_yr: min_yr = yr
				if yr > max_yr: max_yr = yr
				if v < min_y: min_y = v
				if v > max_y: max_y = v

		if min_yr > max_yr:
			return
		if max_y <= min_y:
			max_y = min_y + 1.0
		if min_y > 0.0 and min_y < max_y * 0.25:
			min_y = 0.0

		var font := ThemeDB.fallback_font
		var fsize := 11

		# Horizontal grid lines
		for step in range(5):
			var frac := float(step) / 4.0
			var yy := pad_t + plot_h * (1.0 - frac)
			draw_line(Vector2(pad_l, yy), Vector2(pad_l + plot_w, yy), Color(0.36, 0.25, 0.12, 0.22), 1.0)
			var val := min_y + (max_y - min_y) * frac
			draw_string(font, Vector2(4.0, yy + 4.0), _fmt_val(val), HORIZONTAL_ALIGNMENT_LEFT, pad_l - 8.0, fsize, Color(0.24, 0.16, 0.08))

		# Year labels
		draw_string(font, Vector2(pad_l, h - 5.0), str(min_yr), HORIZONTAL_ALIGNMENT_LEFT, 60.0, fsize, Color(0.24, 0.16, 0.08))
		if max_yr > min_yr:
			draw_string(font, Vector2(pad_l + plot_w - 48.0, h - 5.0), str(max_yr), HORIZONTAL_ALIGNMENT_RIGHT, 48.0, fsize, Color(0.24, 0.16, 0.08))

		var yr_span := float(maxi(1, max_yr - min_yr))
		var val_span := max_y - min_y

		for s in series_list:
			if typeof(s) != TYPE_DICTIONARY:
				continue
			var yrs: Array = s.get("years", [])
			var vals: Array = s.get(metric_key, [])
			if yrs.is_empty():
				continue
			var col := Color(float(s.get("r", 0.8)), float(s.get("g", 0.8)), float(s.get("b", 0.8)))
			var pts := PackedVector2Array()
			for i in range(mini(yrs.size(), vals.size())):
				var px := pad_l + (float(int(yrs[i]) - min_yr) / yr_span) * plot_w
				var py := pad_t + (1.0 - (float(vals[i]) - min_y) / val_span) * plot_h
				pts.append(Vector2(px, py))
			if pts.size() >= 2:
				draw_polyline(pts, col, 2.2, true)
			elif pts.size() == 1:
				draw_circle(pts[0], 3.5, col)

	func _fmt_val(v: float) -> String:
		if v >= 1_000_000.0:
			return "%.1fM" % (v / 1_000_000.0)
		if v >= 1_000.0:
			return "%.1fK" % (v / 1_000.0)
		if absf(v - roundf(v)) < 0.05:
			return str(int(roundf(v)))
		return "%.1f" % v

class PieChartCanvas extends Control:
	var slices: Array = []

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.44
		if radius < 10.0 or slices.is_empty():
			return
		var angle := -PI * 0.5
		for sl in slices:
			if typeof(sl) != TYPE_DICTIONARY:
				continue
			var share := float(sl.get("share", 0.0))
			if share <= 0.0:
				continue
			var sweep := share * TAU
			var col := Color(float(sl.get("r", 0.7)), float(sl.get("g", 0.7)), float(sl.get("b", 0.7)))
			var steps := maxi(4, int(ceil(sweep * 16.0)))
			var pts := PackedVector2Array([center])
			for i in range(steps + 1):
				var a := angle + sweep * (float(i) / float(steps))
				pts.append(center + Vector2(cos(a), sin(a)) * radius)
			draw_colored_polygon(pts, col)
			angle += sweep
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.36, 0.25, 0.12, 0.8), 1.2, true)

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_panel()

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if main_view == null:
		return fallback
	return main_view.call("_call_bridge", method_name, args, fallback)

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _build_panel() -> void:
	ledger_panel = PanelContainer.new()
	ledger_panel.name = "LedgerPanel"
	ledger_panel.visible = false
	ledger_panel.custom_minimum_size = Vector2(860.0, 580.0)
	add_child(ledger_panel)

	var outer := VBoxContainer.new()
	ledger_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := Label.new()
	title.text = "Ledger & Graphs"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close Ledger & Graphs"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(tabs)

	# Tab 1: Graphs & Pies
	var graphs_tab := VBoxContainer.new()
	graphs_tab.name = "Graphs & Pies"
	tabs.add_child(graphs_tab)

	var picker_row := HBoxContainer.new()
	graphs_tab.add_child(picker_row)
	var cmp_lbl := Label.new()
	cmp_lbl.text = "Compare (max 8):"
	picker_row.add_child(cmp_lbl)
	add_country_picker = OptionButton.new()
	add_country_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_row.add_child(add_country_picker)
	var add_btn := Button.new()
	add_btn.text = "Add Realm"
	add_btn.pressed.connect(_on_add_country)
	picker_row.add_child(add_btn)

	selected_chips_box = HBoxContainer.new()
	graphs_tab.add_child(selected_chips_box)

	var metric_row := HBoxContainer.new()
	graphs_tab.add_child(metric_row)
	for m in METRICS:
		var btn := Button.new()
		btn.text = str(m["label"])
		var key := str(m["key"])
		btn.pressed.connect(func() -> void: _on_metric_selected(key))
		metric_row.add_child(btn)
		metric_buttons.append({"key": key, "btn": btn})

	line_chart = LineChartCanvas.new()
	line_chart.custom_minimum_size = Vector2(800.0, 220.0)
	line_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graphs_tab.add_child(line_chart)

	line_legend_box = HBoxContainer.new()
	graphs_tab.add_child(line_legend_box)

	graphs_tab.add_child(HSeparator.new())

	var pie_header := HBoxContainer.new()
	graphs_tab.add_child(pie_header)
	var pie_lbl := Label.new()
	pie_lbl.text = "Demographics Pie Charts for:"
	pie_header.add_child(pie_lbl)
	pie_country_picker = OptionButton.new()
	pie_country_picker.item_selected.connect(_on_pie_country_selected)
	pie_header.add_child(pie_country_picker)

	var pies_row := HBoxContainer.new()
	pies_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphs_tab.add_child(pies_row)

	var rel_col := VBoxContainer.new()
	rel_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pies_row.add_child(rel_col)
	var rel_title := Label.new()
	rel_title.text = "Religion"
	rel_col.add_child(rel_title)
	var rel_body := HBoxContainer.new()
	rel_col.add_child(rel_body)
	religion_pie = PieChartCanvas.new()
	religion_pie.custom_minimum_size = Vector2(150.0, 150.0)
	rel_body.add_child(religion_pie)
	religion_legend_box = VBoxContainer.new()
	religion_legend_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rel_body.add_child(religion_legend_box)

	var cul_col := VBoxContainer.new()
	cul_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pies_row.add_child(cul_col)
	var cul_title := Label.new()
	cul_title.text = "Culture"
	cul_col.add_child(cul_title)
	var cul_body := HBoxContainer.new()
	cul_col.add_child(cul_body)
	culture_pie = PieChartCanvas.new()
	culture_pie.custom_minimum_size = Vector2(150.0, 150.0)
	cul_body.add_child(culture_pie)
	culture_legend_box = VBoxContainer.new()
	culture_legend_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cul_body.add_child(culture_legend_box)

	# Tab 2: Ledger Table
	var table_tab := ScrollContainer.new()
	table_tab.name = "World Ledger"
	table_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(table_tab)

	table_box = VBoxContainer.new()
	table_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_tab.add_child(table_box)

func is_open() -> bool:
	return ledger_panel != null and ledger_panel.visible

func open_window() -> void:
	if ledger_panel == null:
		return
	ledger_panel.visible = true
	_position_panel()
	refresh()

func close_window() -> void:
	if ledger_panel != null:
		ledger_panel.visible = false

func toggle_window() -> void:
	if is_open():
		close_window()
	else:
		open_window()

func _position_panel() -> void:
	if ledger_panel == null:
		return
	var vp := get_viewport_rect().size
	var w := minf(960.0, maxf(680.0, vp.x * 0.72))
	var h := minf(660.0, maxf(480.0, vp.y * 0.78))
	ledger_panel.position = Vector2(18.0, 56.0)
	ledger_panel.size = Vector2(w, h)

func _on_metric_selected(key: String) -> void:
	_active_metric = key
	line_chart.metric_key = key
	line_chart.queue_redraw()
	_refresh_metric_buttons()

func _refresh_metric_buttons() -> void:
	for item in metric_buttons:
		var btn: Button = item["btn"]
		btn.disabled = (str(item["key"]) == _active_metric)

func _on_add_country() -> void:
	if _selected_countries.size() >= 8:
		return
	var sel := add_country_picker.selected
	if sel < 0 or sel >= _available_indices.size():
		return
	var c_idx := int(_available_indices[sel])
	if not _selected_countries.has(c_idx):
		_selected_countries.append(c_idx)
		_refresh_comparison()

func _on_remove_country(c_idx: int) -> void:
	if c_idx == _player_index:
		return
	_selected_countries.erase(c_idx)
	if _pie_country_index == c_idx:
		_pie_country_index = _player_index
	_refresh_comparison()

func _on_pie_country_selected(idx: int) -> void:
	if idx >= 0 and idx < _pie_indices.size():
		_pie_country_index = int(_pie_indices[idx])
		_refresh_comparison()

func refresh() -> void:
	if not is_open():
		return
	var ov: Variant = _call_bridge("getLedgerOverview", [], {})
	if typeof(ov) != TYPE_DICTIONARY or not bool(ov.get("hasWorld", false)):
		return

	_player_index = int(ov.get("playerIndex", 0))
	_all_rows = ov.get("rows", [])

	if _selected_countries.is_empty():
		_selected_countries.append(_player_index)
		# Pre-seed up to 2 major neighbors/rivals if available so the graph has immediate context
		for r in _all_rows:
			if typeof(r) == TYPE_DICTIONARY:
				var idx := int(r.get("countryIndex", -1))
				if idx >= 0 and not _selected_countries.has(idx):
					_selected_countries.append(idx)
					if _selected_countries.size() >= 3:
						break
	if _pie_country_index < 0:
		_pie_country_index = _player_index

	add_country_picker.clear()
	_available_indices.clear()
	for r in _all_rows:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var idx := int(r.get("countryIndex", 0))
		add_country_picker.add_item("%s (%s)" % [str(r.get("name", "")), str(r.get("tag", ""))])
		_available_indices.append(idx)

	_refresh_table()
	_refresh_metric_buttons()
	_refresh_comparison()

func _refresh_comparison() -> void:
	var cmp: Variant = _call_bridge("getLedgerComparison", [_selected_countries, _pie_country_index], {})
	if typeof(cmp) != TYPE_DICTIONARY or not bool(cmp.get("hasWorld", false)):
		return

	var series: Array = cmp.get("series", [])

	_clear_children(selected_chips_box)
	_clear_children(line_legend_box)
	pie_country_picker.clear()
	_pie_indices.clear()
	var pie_select := 0

	for i in range(series.size()):
		var s: Dictionary = series[i]
		var idx := int(s.get("countryIndex", 0))
		var tag := str(s.get("tag", ""))
		var cname := str(s.get("name", ""))

		var chip := Button.new()
		chip.text = tag if idx == _player_index else "%s x" % tag
		chip.disabled = (idx == _player_index)
		chip.pressed.connect(func() -> void: _on_remove_country(idx))
		selected_chips_box.add_child(chip)

		var leg := Label.new()
		leg.text = "● %s" % cname
		leg.add_theme_color_override("font_color", Color(float(s.get("r", 0.8)), float(s.get("g", 0.8)), float(s.get("b", 0.8))))
		line_legend_box.add_child(leg)

		pie_country_picker.add_item("%s (%s)" % [cname, tag])
		_pie_indices.append(idx)
		if idx == _pie_country_index:
			pie_select = i
	pie_country_picker.select(pie_select)

	line_chart.series_list = series
	line_chart.metric_key = _active_metric
	line_chart.queue_redraw()

	var rel_slices: Array = cmp.get("religionSlices", [])
	religion_pie.slices = rel_slices
	religion_pie.queue_redraw()
	_fill_pie_legend(religion_legend_box, rel_slices)

	var cul_slices: Array = cmp.get("cultureSlices", [])
	culture_pie.slices = cul_slices
	culture_pie.queue_redraw()
	_fill_pie_legend(culture_legend_box, cul_slices)

func _fill_pie_legend(box: VBoxContainer, slices: Array) -> void:
	_clear_children(box)
	for sl in slices:
		if typeof(sl) != TYPE_DICTIONARY:
			continue
		var lbl := Label.new()
		lbl.text = "● %s: %.1f%%" % [str(sl.get("label", "")), float(sl.get("share", 0.0)) * 100.0]
		lbl.add_theme_color_override("font_color", Color(float(sl.get("r", 0.8)), float(sl.get("g", 0.8)), float(sl.get("b", 0.8))))
		box.add_child(lbl)

func _refresh_table() -> void:
	_clear_children(table_box)
	var hdr := Label.new()
	hdr.text = "Realm | Prov | Pop | Income | Army | Navy | Tech (A/D/M)"
	table_box.add_child(hdr)
	table_box.add_child(HSeparator.new())
	for r in _all_rows:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var row_lbl := Label.new()
		row_lbl.text = "%s (%s) | %d | %d | %.1f | %d | %d | %d (%d/%d/%d)" % [
			str(r.get("name", "")),
			str(r.get("tag", "")),
			int(r.get("provinces", 0)),
			int(r.get("population", 0)),
			float(r.get("income", 0.0)),
			int(r.get("armySize", 0)),
			int(r.get("navySize", 0)),
			int(r.get("totalTech", 0)),
			int(r.get("adminTech", 0)),
			int(r.get("diploTech", 0)),
			int(r.get("milTech", 0)),
		]
		table_box.add_child(row_lbl)
