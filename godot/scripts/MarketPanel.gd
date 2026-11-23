extends Control
## The market window (bottom right, left of the zoom buttons), split out
## of Main.gd in Phase 20.6 part 2. A market belongs to a trade node, not
## a province. Main makes one, adds it to the windows layer and calls
## setup(self); Main keeps _open_market_panel, _refresh_market_panel and
## market_panel as thin wrappers.

var main = null   # Main.gd

var market_panel: PanelContainer
var market_title_label: Label
var market_subtitle_label: Label
var market_cat_box: HBoxContainer
var market_goods_box: VBoxContainer
var open_market_index: int = -1
var current_market_category: String = ""

func setup(host: Control) -> void:
	main = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_market_panel()

func close() -> void:
	open_market_index = -1
	market_panel.visible = false

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	return main._call_bridge(method_name, args, fallback)

func _make_label(txt: String, col: Color, fsize: int) -> Label:
	return main._make_label(txt, col, fsize)

func _make_panel_style() -> StyleBox:
	return main._make_panel_style()

func _clear_children(node: Node) -> void:
	main._clear_children(node)

func bind_tip(ctrl: Control, title: String, summary: String = "") -> void:
	main.bind_tip(ctrl, title, summary)

func _build_market_panel() -> void:
	market_panel = PanelContainer.new()
	market_panel.name = "MarketPanel"
	market_panel.visible = false
	market_panel.custom_minimum_size = Vector2(390.0, 0.0)
	market_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(market_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	market_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	market_title_label = _make_label("Market", Color(0.97, 0.90, 0.68), 17)
	GezStyle.as_title(market_title_label)
	market_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_tip(market_title_label, "Regional Market", "Regional trading hub setting supply, demand and monthly prices for all goods in member provinces.")
	header.add_child(market_title_label)
	var close_btn := GezStyle.medallion_button("close", 30.0)
	bind_tip(close_btn, "Close Market Panel")
	close_btn.pressed.connect(func() -> void:
		open_market_index = -1
		market_panel.visible = false
	)
	header.add_child(close_btn)

	market_subtitle_label = _make_label("", Color(0.80, 0.75, 0.66), 12)
	bind_tip(market_subtitle_label, "Market Summary", "Number of member provinces and market activity.")
	vbox.add_child(market_subtitle_label)

	market_cat_box = HBoxContainer.new()
	market_cat_box.add_theme_constant_override("separation", 4)
	vbox.add_child(market_cat_box)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 6)
	vbox.add_child(cols)
	var g_hdr := _make_label("Good", Color(0.82, 0.78, 0.68), 12)
	g_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_tip(g_hdr, "Trade Good", "Click any good below to plan an import route into this market.")
	cols.add_child(g_hdr)
	var p_hdr := _make_label("Price", Color(0.82, 0.78, 0.68), 12)
	p_hdr.custom_minimum_size = Vector2(68.0, 0.0)
	p_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bind_tip(p_hdr, "Local Price", "Current market price per unit and recent monthly direction (▲ rising, ▼ falling).")
	cols.add_child(p_hdr)
	var s_hdr := _make_label("Supply", Color(0.82, 0.78, 0.68), 12)
	s_hdr.custom_minimum_size = Vector2(64.0, 0.0)
	s_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bind_tip(s_hdr, "Market Supply", "Total units produced and imported here each month.")
	cols.add_child(s_hdr)
	var d_hdr := _make_label("Demand", Color(0.82, 0.78, 0.68), 12)
	d_hdr.custom_minimum_size = Vector2(64.0, 0.0)
	d_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bind_tip(d_hdr, "Market Demand", "Total units consumed by population, construction and workshops each month.")
	cols.add_child(d_hdr)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(364.0, 260.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	market_goods_box = VBoxContainer.new()
	market_goods_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_goods_box.add_theme_constant_override("separation", 3)
	scroll.add_child(market_goods_box)

	market_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	market_panel.offset_right = -68.0
	market_panel.offset_left = -458.0
	# grow to the left when its contents are wider (Phase 20 fonts and frames)
	market_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	market_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

func open_market(market_idx: int) -> void:
	open_market_index = market_idx
	current_market_category = ""
	market_panel.visible = true
	refresh()

func refresh() -> void:
	if open_market_index < 0:
		market_panel.visible = false
		return
	var d: Dictionary = _call_bridge("getMarketDetails", [open_market_index, current_market_category], {})
	if not bool(d.get("valid", false)):
		market_panel.visible = false
		return

	market_title_label.text = str(d.get("name", "Market"))
	market_subtitle_label.text = str(d.get("subtitle", ""))

	_clear_children(market_cat_box)
	var cats: Array = d.get("categories", [])
	for cat in cats:
		if cat is Dictionary:
			var ck: String = str(cat.get("key", ""))
			var ct: String = str(cat.get("title", "All"))
			var btn := Button.new()
			btn.text = ct
			if ck == current_market_category:
				btn.modulate = Color(1.0, 0.88, 0.40)
			var cat_key := ck
			btn.pressed.connect(func() -> void:
				current_market_category = cat_key
				refresh()
			)
			market_cat_box.add_child(btn)

	_clear_children(market_goods_box)
	var goods: Array = d.get("goods", [])
	for g in goods:
		if not (g is Dictionary):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		market_goods_box.add_child(row)

		var g_icon := GezStyle.good_icon(str(g.get("name", "")))
		if g_icon != null:
			row.add_child(GezStyle.icon_rect(g_icon, 24.0))
		else:
			var swatch := ColorRect.new()
			swatch.custom_minimum_size = Vector2(10.0, 10.0)
			swatch.color = Color(
				float(int(g.get("colorR", 180))) / 255.0,
				float(int(g.get("colorG", 180))) / 255.0,
				float(int(g.get("colorB", 180))) / 255.0
			)
			row.add_child(swatch)

		var g_idx: int = int(g.get("goodIndex", -1))
		var g_btn := Button.new()
		g_btn.text = str(g.get("name", ""))
		g_btn.flat = true
		g_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		g_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g_btn.tooltip_text = "Import into this market in Trade"
		var good_idx_copy := g_idx
		var mkt_idx_copy := open_market_index
		g_btn.pressed.connect(func() -> void:
			if main.trade_ui != null and good_idx_copy >= 0 and mkt_idx_copy >= 0:
				main.trade_ui.call("plan_import", good_idx_copy, mkt_idx_copy)
		)
		row.add_child(g_btn)

		var trend: String = str(g.get("trend", "·"))
		var price_col := Color(0.95, 0.52, 0.45) if trend == "▲" else (Color(0.55, 0.92, 0.58) if trend == "▼" else Color(0.92, 0.89, 0.82))
		var p_lbl := _make_label("%s %s" % [str(g.get("priceText", "0.0")), trend], price_col, 12)
		p_lbl.custom_minimum_size = Vector2(68.0, 0.0)
		p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p_lbl.tooltip_text = "%d%% of normal price" % int(g.get("ratioPercent", 100))
		row.add_child(p_lbl)

		var s_lbl := _make_label(str(g.get("supplyText", "")), Color(0.84, 0.80, 0.72), 12)
		s_lbl.custom_minimum_size = Vector2(64.0, 0.0)
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(s_lbl)

		var d_lbl := _make_label(str(g.get("demandText", "")), Color(0.84, 0.80, 0.72), 12)
		d_lbl.custom_minimum_size = Vector2(64.0, 0.0)
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(d_lbl)
