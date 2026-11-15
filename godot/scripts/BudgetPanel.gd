extends Control

var main_view: Control = null

var budget_panel: PanelContainer
var bankruptcy_label: Label
var summary_box: VBoxContainer
var taxes_box: VBoxContainer
var coinage_box: VBoxContainer
var loans_box: VBoxContainer

var _tax_rows_built: bool = false
var _updating_sliders: bool = false
var _dragging_tax_class: int = -1
var _tax_sliders: Dictionary = {}
var _tax_level_labels: Dictionary = {}
var _tax_content_labels: Dictionary = {}
var _last_summary_sig: String = ""
var _last_coinage_sig: String = ""
var _last_loans_sig: String = ""

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_budget_panel()

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if main_view == null:
		return fallback
	return main_view.call("_call_bridge", method_name, args, fallback)

func _make_label(txt: String, col: Color, fsize: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", fsize)
	return lbl

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _add_kv_row(parent: VBoxContainer, label_txt: String, value_txt: String, val_col: Color = Color(0.95, 0.92, 0.84)) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _make_label(label_txt, Color(0.80, 0.75, 0.66), 12)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := _make_label(value_txt, val_col, 12)
	row.add_child(v)

func _build_budget_panel() -> void:
	budget_panel = PanelContainer.new()
	budget_panel.name = "BudgetPanel"
	budget_panel.visible = false
	budget_panel.custom_minimum_size = Vector2(416.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBoxFlat = main_view.call("_make_panel_style")
		budget_panel.add_theme_stylebox_override("panel", st)
	add_child(budget_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	budget_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := _make_label("Budget", Color(0.97, 0.90, 0.68), 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close Budget window"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390.0, 490.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)

	bankruptcy_label = _make_label("", Color(0.96, 0.38, 0.34), 12)
	bankruptcy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bankruptcy_label.visible = false
	body.add_child(bankruptcy_label)

	summary_box = VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 3)
	body.add_child(summary_box)

	body.add_child(HSeparator.new())

	taxes_box = VBoxContainer.new()
	taxes_box.add_theme_constant_override("separation", 4)
	body.add_child(taxes_box)

	body.add_child(HSeparator.new())

	coinage_box = VBoxContainer.new()
	coinage_box.add_theme_constant_override("separation", 4)
	body.add_child(coinage_box)

	body.add_child(HSeparator.new())

	loans_box = VBoxContainer.new()
	loans_box.add_theme_constant_override("separation", 4)
	body.add_child(loans_box)

	budget_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	budget_panel.offset_top = 60.0

func is_open() -> bool:
	return budget_panel != null and budget_panel.visible

func open_window() -> void:
	if budget_panel == null:
		return
	budget_panel.visible = true
	refresh()

func close_window() -> void:
	if budget_panel != null:
		budget_panel.visible = false

func toggle_window() -> void:
	if is_open():
		close_window()
	else:
		open_window()

func refresh_if_open() -> void:
	if is_open():
		refresh()

func refresh() -> void:
	if budget_panel == null:
		return
	var d_var: Variant = _call_bridge("getBudgetDetails", [], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("valid", false)):
		_clear_children(summary_box)
		summary_box.add_child(_make_label("No active player country.", Color(0.80, 0.75, 0.66), 13))
		bankruptcy_label.visible = false
		_clear_children(coinage_box)
		_clear_children(loans_box)
		return

	var warn_txt: String = str(d.get("bankruptcyWarning", ""))
	bankruptcy_label.visible = not warn_txt.is_empty()
	bankruptcy_label.text = warn_txt

	_refresh_summary(d)
	_refresh_taxes(d)
	_refresh_coinage(d)
	_refresh_loans(d)

func _refresh_summary(d: Dictionary) -> void:
	var sig := "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(d.get("taxBreakdown", [])), str(d.get("vassalTaxText", "")),
		str(d.get("debaseOngoingIncomeText", "")), str(d.get("merchantsText", "")),
		str(d.get("tollsText", "")), str(d.get("buildingUpkeepText", "")),
		str(d.get("armyUpkeepText", "")), str(d.get("interestText", "")),
		str(d.get("balanceText", "")) + "|" + str(d.get("treasuryText", ""))
	]
	if sig == _last_summary_sig and summary_box.get_child_count() > 0:
		return
	_last_summary_sig = sig
	_clear_children(summary_box)
	summary_box.add_child(_make_label("Last month", Color(0.96, 0.90, 0.72), 14))

	var tax_rows_var: Variant = d.get("taxBreakdown", [])
	var tax_rows: Array = tax_rows_var if tax_rows_var is Array else []
	for item in tax_rows:
		if item is Dictionary:
			var t_dict: Dictionary = item
			_add_kv_row(summary_box, str(t_dict.get("name", "Tax")), str(t_dict.get("amountText", "0.0")))

	var vassal_tax: float = float(d.get("vassalTax", 0.0))
	if vassal_tax > 0.001:
		_add_kv_row(summary_box, "Kept by vassals", str(d.get("vassalTaxText", "−0.0")), Color(0.92, 0.72, 0.62))

	var deb_income: float = float(d.get("debaseOngoingIncome", 0.0))
	if deb_income > 0.001:
		_add_kv_row(summary_box, "Debased coin", str(d.get("debaseOngoingIncomeText", "0.0")), Color(0.98, 0.85, 0.42))

	_add_kv_row(summary_box, "Merchants", str(d.get("merchantsText", "+0.0")))
	_add_kv_row(summary_box, "Tolls", str(d.get("tollsText", "0.0")))
	_add_kv_row(summary_box, "Building upkeep", str(d.get("buildingUpkeepText", "−0.0")))
	_add_kv_row(summary_box, "Army upkeep", str(d.get("armyUpkeepText", "−0.0")))
	_add_kv_row(summary_box, "Interest", str(d.get("interestText", "−0.0")))

	var net: float = float(d.get("monthlyNet", 0.0))
	var bal_col := Color(0.55, 0.92, 0.58) if net >= 0.0 else Color(0.96, 0.45, 0.40)
	_add_kv_row(summary_box, "Balance", str(d.get("balanceText", "+0.0 / month")), bal_col)
	_add_kv_row(summary_box, "Treasury", str(d.get("treasuryText", "0.0")), Color(0.96, 0.84, 0.36))

func _tax_level_name(lvl: float) -> String:
	if lvl < 0.01:
		return "None"
	if lvl < 0.76:
		return "Low"
	if lvl < 1.01:
		return "Normal"
	if lvl < 1.51:
		return "High"
	return "Crushing"

func _refresh_taxes(d: Dictionary) -> void:
	var taxes_var: Variant = d.get("taxes", [])
	var taxes: Array = taxes_var if taxes_var is Array else []
	if not _tax_rows_built and not taxes.is_empty():
		_clear_children(taxes_box)
		taxes_box.add_child(_make_label("Taxes", Color(0.96, 0.90, 0.72), 14))
		var hint := _make_label(
			"Higher taxes bring more money but make that class less content. Taxing nobles also angers your vassals.",
			Color(0.75, 0.70, 0.62),
			11
		)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		taxes_box.add_child(hint)

		for item in taxes:
			if not (item is Dictionary):
				continue
			var t_dict: Dictionary = item
			var tc_idx: int = int(t_dict.get("taxClassIndex", 0))
			var cls_name: String = str(t_dict.get("name", "Class"))
			var max_lvl: float = float(t_dict.get("maxLevel", 2.0))

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			taxes_box.add_child(row)

			var n_lbl := _make_label(cls_name, Color(0.94, 0.90, 0.82), 12)
			n_lbl.custom_minimum_size = Vector2(74.0, 0.0)
			row.add_child(n_lbl)

			var slider := HSlider.new()
			slider.min_value = 0.0
			slider.max_value = max_lvl
			slider.step = 0.25
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.drag_started.connect(func() -> void:
				_dragging_tax_class = tc_idx
			)
			slider.drag_ended.connect(func(_changed: bool) -> void:
				_dragging_tax_class = -1
			)
			slider.value_changed.connect(func(new_val: float) -> void:
				if _updating_sliders:
					return
				var snapped: float = round(new_val * 4.0) * 0.25
				if _tax_level_labels.has(tc_idx):
					var lvl_lbl: Label = _tax_level_labels[tc_idx]
					lvl_lbl.text = _tax_level_name(snapped)
				_call_bridge("setTaxLevel", [tc_idx, snapped], false)
				if main_view != null:
					main_view.call("_refresh_top_bar")
			)
			row.add_child(slider)

			var lvl_lbl := _make_label("Normal", Color(0.90, 0.86, 0.76), 12)
			lvl_lbl.custom_minimum_size = Vector2(68.0, 0.0)
			lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(lvl_lbl)

			var sat_lbl := _make_label("", Color(0.76, 0.72, 0.64), 11)
			taxes_box.add_child(sat_lbl)

			_tax_sliders[tc_idx] = slider
			_tax_level_labels[tc_idx] = lvl_lbl
			_tax_content_labels[tc_idx] = sat_lbl
		_tax_rows_built = true

	_updating_sliders = true
	for item in taxes:
		if not (item is Dictionary):
			continue
		var t_dict: Dictionary = item
		var tc_idx: int = int(t_dict.get("taxClassIndex", 0))
		var lvl: float = float(t_dict.get("level", 1.0))
		var lvl_name: String = str(t_dict.get("levelName", _tax_level_name(lvl)))
		var sat_txt: String = str(t_dict.get("satisfactionText", ""))
		if _tax_sliders.has(tc_idx) and _dragging_tax_class != tc_idx:
			var sl: HSlider = _tax_sliders[tc_idx]
			sl.value = lvl
		if _tax_level_labels.has(tc_idx):
			var ll: Label = _tax_level_labels[tc_idx]
			ll.text = lvl_name
		if _tax_content_labels.has(tc_idx):
			var cl: Label = _tax_content_labels[tc_idx]
			cl.visible = not sat_txt.is_empty()
			cl.text = "  " + sat_txt
	_updating_sliders = false

func _refresh_coinage(d: Dictionary) -> void:
	var sig := "%s|%s|%s|%s|%s|%s" % [
		str(d.get("inflationText", "")), str(d.get("debaseRefusal", "")),
		str(d.get("debaseOnceText", "")), str(d.get("canDebaseOnce", false)),
		str(d.get("debaseOngoingText", "")), str(d.get("isDebasing", false)) + "|" + str(d.get("canToggleDebasing", false))
	]
	if sig == _last_coinage_sig and coinage_box.get_child_count() > 0:
		return
	_last_coinage_sig = sig
	_clear_children(coinage_box)
	coinage_box.add_child(_make_label("Coinage", Color(0.96, 0.90, 0.72), 14))
	_add_kv_row(coinage_box, "Inflation", str(d.get("inflationText", "0.0%")))

	var hint := _make_label(
		"Inflation makes buildings and armies dearer and angers burghers most. It falls slowly when you stop debasing.",
		Color(0.75, 0.70, 0.62),
		11
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coinage_box.add_child(hint)

	var deb_refusal: String = str(d.get("debaseRefusal", ""))
	if not deb_refusal.is_empty():
		var ref_lbl := _make_label(deb_refusal, Color(0.96, 0.42, 0.36), 11)
		ref_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		coinage_box.add_child(ref_lbl)

	var debase_btn := Button.new()
	debase_btn.text = str(d.get("debaseOnceText", "Debase once"))
	debase_btn.disabled = not bool(d.get("canDebaseOnce", false))
	debase_btn.tooltip_text = deb_refusal if not deb_refusal.is_empty() else "Mint debased coin once for immediate ducats"
	debase_btn.pressed.connect(func() -> void:
		_call_bridge("debaseOnce", [], 0.0)
		if main_view != null:
			main_view.call("_after_economy_action")
	)
	coinage_box.add_child(debase_btn)

	var ongoing_toggle := CheckButton.new()
	ongoing_toggle.text = str(d.get("debaseOngoingText", "Keep debasing"))
	ongoing_toggle.button_pressed = bool(d.get("isDebasing", false))
	ongoing_toggle.disabled = not bool(d.get("canToggleDebasing", false))
	ongoing_toggle.toggled.connect(func(pressed: bool) -> void:
		_call_bridge("setDebasing", [pressed], false)
		if main_view != null:
			main_view.call("_after_economy_action")
	)
	coinage_box.add_child(ongoing_toggle)

func _refresh_loans(d: Dictionary) -> void:
	var sig := "%s|%s" % [str(d.get("loans", [])), str(d.get("banks", []))]
	if sig == _last_loans_sig and loans_box.get_child_count() > 0:
		return
	_last_loans_sig = sig
	_clear_children(loans_box)
	loans_box.add_child(_make_label("Loans", Color(0.96, 0.90, 0.72), 14))

	var loans_var: Variant = d.get("loans", [])
	var loans: Array = loans_var if loans_var is Array else []
	if loans.is_empty():
		loans_box.add_child(_make_label("No debts.", Color(0.75, 0.70, 0.62), 12))
	else:
		for item in loans:
			if not (item is Dictionary):
				continue
			var l_dict: Dictionary = item
			var l_idx: int = int(l_dict.get("loanIndex", -1))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			loans_box.add_child(row)

			var b_lbl := _make_label(str(l_dict.get("bankName", "Bank")), Color(0.94, 0.90, 0.82), 12)
			b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b_lbl)

			row.add_child(_make_label(str(l_dict.get("detailsText", "")), Color(0.84, 0.80, 0.72), 11))

			var repay_btn := Button.new()
			repay_btn.text = "Repay"
			repay_btn.disabled = not bool(l_dict.get("canRepay", false))
			repay_btn.tooltip_text = "Repay principal early" if not repay_btn.disabled else "Not enough ducats to repay"
			repay_btn.pressed.connect(func() -> void:
				_call_bridge("repayLoan", [l_idx], false)
				if main_view != null:
					main_view.call("_after_economy_action")
			)
			row.add_child(repay_btn)

	loans_box.add_child(_make_label("Lenders who will deal with you", Color(0.84, 0.78, 0.66), 12))

	var banks_var: Variant = d.get("banks", [])
	var banks: Array = banks_var if banks_var is Array else []
	if banks.is_empty():
		loans_box.add_child(_make_label("No bank will lend to you.", Color(0.96, 0.42, 0.36), 12))
		return

	for b_item in banks:
		if not (b_item is Dictionary):
			continue
		var b_dict: Dictionary = b_item
		var b_idx: int = int(b_dict.get("bankIndex", -1))

		var b_card := VBoxContainer.new()
		b_card.add_theme_constant_override("separation", 2)
		loans_box.add_child(b_card)

		var hdr := HBoxContainer.new()
		b_card.add_child(hdr)
		var name_lbl := _make_label(str(b_dict.get("name", "Bank")), Color(0.95, 0.91, 0.82), 12)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hdr.add_child(name_lbl)
		hdr.add_child(_make_label(str(b_dict.get("rateText", "")), Color(0.80, 0.76, 0.68), 11))

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 4)
		b_card.add_child(btn_row)
		var amts_var: Variant = b_dict.get("amounts", [])
		var amts: Array = amts_var if amts_var is Array else []
		for a_item in amts:
			if not (a_item is Dictionary):
				continue
			var a_dict: Dictionary = a_item
			var amt: float = float(a_dict.get("amount", 0.0))
			var b_btn := Button.new()
			b_btn.text = str(a_dict.get("label", "+50"))
			b_btn.disabled = not bool(a_dict.get("canBorrow", false))
			b_btn.tooltip_text = "Borrow %d ducats" % int(amt)
			b_btn.pressed.connect(func() -> void:
				_call_bridge("borrowFromBank", [b_idx, amt], false)
				if main_view != null:
					main_view.call("_after_economy_action")
			)
			btn_row.add_child(b_btn)
