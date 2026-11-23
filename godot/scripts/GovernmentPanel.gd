extends Control

var main_view: Control = null

var gov_panel: PanelContainer
var gov_type_label: Label
var stability_box: VBoxContainer
var estates_box: VBoxContainer
var laws_box: VBoxContainer
var reforms_box: VBoxContainer
var message_label: Label

var open_estate_index: int = -1
var last_message: String = ""
var _last_gov_sig: String = ""

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_gov_panel()

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if main_view == null:
		return fallback
	return main_view.call("_call_bridge", method_name, args, fallback)

func _make_label(txt: String, col: Color, fsize: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", GezStyle.ink(col))
	lbl.add_theme_font_size_override("font_size", GezStyle.fs(fsize))
	return lbl

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _build_gov_panel() -> void:
	gov_panel = PanelContainer.new()
	gov_panel.name = "GovernmentPanel"
	gov_panel.visible = false
	gov_panel.custom_minimum_size = Vector2(440.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBox = main_view.call("_make_panel_style")
		gov_panel.add_theme_stylebox_override("panel", st)
	add_child(gov_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	gov_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := _make_label("Government", Color(0.97, 0.90, 0.68), 18)
	GezStyle.as_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := GezStyle.medallion_button("close", 30.0)
	close_btn.tooltip_text = "Close Government window"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	gov_type_label = _make_label("", Color(0.80, 0.75, 0.66), 12)
	outer.add_child(gov_type_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(414.0, 540.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)

	stability_box = VBoxContainer.new()
	stability_box.add_theme_constant_override("separation", 4)
	body.add_child(stability_box)

	body.add_child(HSeparator.new())
	estates_box = VBoxContainer.new()
	estates_box.add_theme_constant_override("separation", 4)
	body.add_child(estates_box)

	body.add_child(HSeparator.new())
	laws_box = VBoxContainer.new()
	laws_box.add_theme_constant_override("separation", 4)
	body.add_child(laws_box)

	body.add_child(HSeparator.new())
	reforms_box = VBoxContainer.new()
	reforms_box.add_theme_constant_override("separation", 4)
	body.add_child(reforms_box)

	message_label = _make_label("", Color(0.96, 0.45, 0.40), 12)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.visible = false
	outer.add_child(message_label)

	gov_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	gov_panel.offset_top = 60.0

func is_open() -> bool:
	return gov_panel != null and gov_panel.visible

func open_window() -> void:
	if gov_panel == null:
		return
	last_message = ""
	gov_panel.visible = true
	refresh()

func close_window() -> void:
	if gov_panel != null:
		gov_panel.visible = false

func toggle_window() -> void:
	if is_open():
		close_window()
	else:
		open_window()

func refresh_if_open() -> void:
	if is_open():
		refresh()

func _after_gov_change() -> void:
	if main_view != null and main_view.has_method("_after_court_or_gov_action"):
		main_view.call("_after_court_or_gov_action")
	else:
		refresh()

func refresh() -> void:
	if gov_panel == null:
		return
	var d_var: Variant = _call_bridge("getGovernmentDetails", [], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("valid", false)):
		_last_gov_sig = ""
		gov_type_label.text = ""
		_clear_children(stability_box)
		stability_box.add_child(_make_label("No active player country.", Color(0.80, 0.75, 0.66), 13))
		_clear_children(estates_box)
		_clear_children(laws_box)
		_clear_children(reforms_box)
		message_label.visible = false
		return

	var sig := "%d|%s|%s" % [open_estate_index, last_message, var_to_str(d)]
	if sig == _last_gov_sig and stability_box.get_child_count() > 0:
		return
	_last_gov_sig = sig

	gov_type_label.text = str(d.get("governmentName", ""))
	message_label.visible = not last_message.is_empty()
	message_label.text = last_message

	_refresh_stability(d)
	_refresh_estates(d)
	_refresh_laws(d)
	_refresh_reforms(d)

func _refresh_stability(d: Dictionary) -> void:
	_clear_children(stability_box)
	var stab: int = int(d.get("stability", 0))
	var cost: float = float(d.get("stabilityCost", 25.0))
	var can_raise: bool = bool(d.get("canRaiseStability", false))

	var hdr := HBoxContainer.new()
	stability_box.add_child(hdr)
	if main_view != null:
		main_view.call("bind_breakdown", hdr, func() -> Variant: return _call_bridge("getStabilityBreakdown", [], {}), "Stability Cost Breakdown")
	var title := _make_label("Stability", Color(0.96, 0.90, 0.72), 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	var val_col := Color(0.96, 0.45, 0.40) if stab < 0 else Color(0.96, 0.92, 0.84)
	var val_txt := "+%d" % stab if stab > 0 else str(stab)
	hdr.add_child(_make_label(val_txt, val_col, 16))

	var help_lbl := _make_label(str(d.get("stabilityHelpText", "")), Color(0.76, 0.72, 0.64), 11)
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stability_box.add_child(help_lbl)

	var raise_btn := Button.new()
	raise_btn.text = "Raise stability (%.0f ducats)" % cost
	raise_btn.disabled = not can_raise
	if main_view != null:
		main_view.call("bind_breakdown", raise_btn, func() -> Variant: return _call_bridge("getStabilityBreakdown", [], {}), "Raise Stability Cost")
	raise_btn.pressed.connect(func() -> void:
		last_message = ""
		if bool(_call_bridge("raiseStability", [], false)) and main_view != null:
			main_view.call("play_sfx", "coin_clink")
		_after_gov_change()
	)
	stability_box.add_child(raise_btn)

func _add_power_bar_row(label_txt: String, share: float, has_loyalty: bool, loyalty: float, loyal_at: float, disloyal_below: float, clickable: bool, on_click: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	estates_box.add_child(row)

	if clickable:
		var btn := Button.new()
		btn.text = label_txt
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(108.0, 0.0)
		btn.add_theme_color_override("font_color", GezStyle.ink(Color(0.96, 0.88, 0.65)))
		btn.add_theme_font_size_override("font_size", GezStyle.fs(12))
		btn.pressed.connect(on_click)
		row.add_child(btn)
	else:
		var lbl := _make_label(label_txt, Color(0.90, 0.86, 0.76), 12)
		lbl.custom_minimum_size = Vector2(108.0, 0.0)
		row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clampf(share * 100.0, 0.0, 100.0)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	row.add_child(bar)

	var pct_lbl := _make_label("%.0f%%" % (share * 100.0), Color(0.86, 0.82, 0.74), 11)
	pct_lbl.custom_minimum_size = Vector2(36.0, 0.0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct_lbl)

	var loy_lbl := _make_label("", Color(0.86, 0.82, 0.74), 11)
	loy_lbl.custom_minimum_size = Vector2(26.0, 0.0)
	loy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var loy_row := GezStyle.with_glyph("heart", loy_lbl)
	loy_row.custom_minimum_size = Vector2(44.0, 0.0)
	loy_row.alignment = BoxContainer.ALIGNMENT_END
	loy_row.get_child(0).visible = has_loyalty
	if has_loyalty:
		loy_row.tooltip_text = "Loyalty %.0f" % loyalty
		loy_lbl.text = "%.0f" % loyalty
		var col := Color(0.80, 0.76, 0.68)
		if loyalty >= loyal_at:
			col = Color(0.55, 0.90, 0.58)
		elif loyalty < disloyal_below:
			col = Color(0.95, 0.45, 0.40)
		loy_lbl.add_theme_color_override("font_color", GezStyle.ink(col))
	row.add_child(loy_row)

func _refresh_estates(d: Dictionary) -> void:
	_clear_children(estates_box)
	estates_box.add_child(_make_label("Estates", Color(0.96, 0.90, 0.72), 14))

	var loyal_at: float = float(d.get("loyalAt", 60.0))
	var disloyal_below: float = float(d.get("disloyalBelow", 30.0))
	_add_power_bar_row("Crown", float(d.get("crownPower", 0.0)), false, 0.0, loyal_at, disloyal_below, false, Callable())

	var est_var: Variant = d.get("estates", [])
	var est_list: Array = est_var if est_var is Array else []
	for e_item in est_list:
		if e_item is Dictionary:
			var e: Dictionary = e_item
			var e_idx: int = int(e.get("estateIndex", -1))
			_add_power_bar_row(
				str(e.get("name", "")),
				float(e.get("power", 0.0)),
				true,
				float(e.get("loyalty", 0.0)),
				loyal_at,
				disloyal_below,
				true,
				func() -> void:
					open_estate_index = -1 if open_estate_index == e_idx else e_idx
					refresh()
			)
			if open_estate_index == e_idx:
				_add_estate_detail(e)

	var tip := _make_label("Click an estate for its privileges. Loyal estates (60+) help you; disloyal ones (below 30) hurt, and if strong may seize privileges.", Color(0.72, 0.68, 0.60), 11)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	estates_box.add_child(tip)

func _add_estate_detail(e: Dictionary) -> void:
	var box_panel := PanelContainer.new()
	box_panel.theme_type_variation = "Card"
	estates_box.add_child(box_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	box_panel.add_child(vbox)

	var target_txt := "Loyalty heading to %.0f. Contentment of their people: %.0f%%." % [
		float(e.get("loyaltyTarget", 50.0)),
		float(e.get("contentment", 0.5)) * 100.0
	]
	var tl := _make_label(target_txt, Color(0.88, 0.84, 0.74), 11)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tl)

	var ll := _make_label("When loyal: " + str(e.get("loyalText", "")), Color(0.75, 0.85, 0.72), 11)
	ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(ll)

	var dl := _make_label("When disloyal: " + str(e.get("disloyalText", "")), Color(0.88, 0.70, 0.68), 11)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(dl)

	var privs_var: Variant = e.get("privileges", [])
	var privs: Array = privs_var if privs_var is Array else []
	for p_item in privs:
		if p_item is Dictionary:
			var p: Dictionary = p_item
			var pid: int = int(p.get("privilegeIndex", -1))
			var granted: bool = bool(p.get("granted", false))
			var can_grant: bool = bool(p.get("canGrant", false))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			vbox.add_child(row)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_constant_override("separation", 0)
			row.add_child(info)
			info.add_child(_make_label(str(p.get("name", "")), Color(0.95, 0.90, 0.76), 12))
			var desc := _make_label(str(p.get("description", "")), Color(0.76, 0.72, 0.64), 11)
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(desc)

			var act_btn := Button.new()
			if granted:
				act_btn.text = "Revoke"
				act_btn.tooltip_text = "−1 stability; they will resent it for years"
				act_btn.pressed.connect(func() -> void:
					last_message = ""
					_call_bridge("revokePrivilege", [pid], false)
					_after_gov_change()
				)
			else:
				act_btn.text = "Grant"
				act_btn.disabled = not can_grant
				act_btn.pressed.connect(func() -> void:
					last_message = ""
					_call_bridge("grantPrivilege", [pid], false)
					_after_gov_change()
				)
			row.add_child(act_btn)

func _refresh_laws(d: Dictionary) -> void:
	_clear_children(laws_box)
	var hdr := HBoxContainer.new()
	laws_box.add_child(hdr)
	var title := _make_label("Laws", Color(0.96, 0.90, 0.72), 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	var cost_txt := "Change: %.0f ducats, %d months" % [
		float(d.get("lawChangeCost", 0.0)),
		int(d.get("lawChangeMonths", 6))
	]
	hdr.add_child(_make_label(cost_txt, Color(0.76, 0.72, 0.64), 11))

	var laws_var: Variant = d.get("laws", [])
	var laws: Array = laws_var if laws_var is Array else []
	for l_item in laws:
		if l_item is Dictionary:
			var l: Dictionary = l_item
			var area_idx: int = int(l.get("areaIndex", -1))
			var has_pending: bool = bool(l.get("hasPending", false))

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			laws_box.add_child(row)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_constant_override("separation", 0)
			row.add_child(info)

			info.add_child(_make_label(str(l.get("areaName", "")), Color(0.74, 0.70, 0.62), 11))
			info.add_child(_make_label(str(l.get("currentOptionName", "")), Color(0.96, 0.92, 0.84), 12))
			var fx_lbl := _make_label(str(l.get("currentEffects", "")), Color(0.78, 0.74, 0.66), 11)
			fx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(fx_lbl)

			var pend_txt: String = str(l.get("pendingText", ""))
			if not pend_txt.is_empty():
				var pl := _make_label(pend_txt, Color(0.55, 0.78, 0.98), 11)
				pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				info.add_child(pl)

			var menu := MenuButton.new()
			menu.text = "Change"
			menu.flat = false
			menu.disabled = has_pending
			var popup := menu.get_popup()
			var opts_var: Variant = l.get("options", [])
			var opts: Array = opts_var if opts_var is Array else []
			var id_to_opt: Dictionary = {}
			for i in range(opts.size()):
				var o: Dictionary = opts[i]
				var opt_idx: int = int(o.get("optionIndex", -1))
				var ref_txt: String = str(o.get("refusalReason", ""))
				var lbl_txt := "%s: %s" % [str(o.get("name", "")), str(o.get("effects", ""))]
				if not ref_txt.is_empty():
					lbl_txt += " [%s]" % ref_txt
				popup.add_item(lbl_txt, i)
				id_to_opt[i] = opt_idx
			popup.id_pressed.connect(func(pid: int) -> void:
				if id_to_opt.has(pid):
					var res_var: Variant = _call_bridge("changeLaw", [area_idx, int(id_to_opt[pid])], {})
					var res: Dictionary = res_var if res_var is Dictionary else {}
					if bool(res.get("ok", false)):
						last_message = ""
						_after_gov_change()
					else:
						last_message = str(res.get("reason", "Cannot change law"))
						refresh()
			)
			row.add_child(menu)

func _refresh_reforms(d: Dictionary) -> void:
	_clear_children(reforms_box)
	var hdr := HBoxContainer.new()
	reforms_box.add_child(hdr)
	var title := _make_label("Reforms", Color(0.96, 0.90, 0.72), 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	var prog_txt := "Progress %.0f (+%.2f a month)" % [
		float(d.get("reformProgress", 0.0)),
		float(d.get("monthlyReformProgress", 0.0))
	]
	hdr.add_child(_make_label(prog_txt, Color(0.76, 0.72, 0.64), 11))

	var adopted_var: Variant = d.get("adoptedReforms", [])
	var adopted: Array = adopted_var if adopted_var is Array else []
	for a_item in adopted:
		if a_item is Dictionary:
			var r: Dictionary = a_item
			reforms_box.add_child(_make_label("Tier %d: %s" % [int(r.get("tier", 1)), str(r.get("name", ""))], Color(0.88, 0.88, 0.76), 12))
			var fx_lbl := _make_label(str(r.get("effects", "")), Color(0.74, 0.70, 0.62), 11)
			fx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reforms_box.add_child(fx_lbl)

	if bool(d.get("hasNextReformTier", false)):
		var next_tier_lbl := _make_label(
			"Tier %d needs %.0f progress" % [int(d.get("nextReformTierIndex", 1)), float(d.get("nextReformCost", 0.0))],
			Color(0.95, 0.88, 0.66),
			12
		)
		reforms_box.add_child(next_tier_lbl)
		var next_opts_var: Variant = d.get("nextReformOptions", [])
		var next_opts: Array = next_opts_var if next_opts_var is Array else []
		for o_item in next_opts:
			if o_item is Dictionary:
				var o: Dictionary = o_item
				var opt_idx: int = int(o.get("optionIndex", -1))
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				reforms_box.add_child(row)

				var info := VBoxContainer.new()
				info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				info.add_theme_constant_override("separation", 0)
				row.add_child(info)
				info.add_child(_make_label(str(o.get("name", "")), Color(0.95, 0.92, 0.84), 12))
				var fx := _make_label(str(o.get("effects", "")), Color(0.76, 0.72, 0.64), 11)
				fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				info.add_child(fx)

				var adopt_btn := Button.new()
				adopt_btn.text = "Adopt"
				adopt_btn.disabled = not bool(o.get("canAdopt", false))
				adopt_btn.pressed.connect(func() -> void:
					last_message = ""
					_call_bridge("adoptReform", [opt_idx], false)
					_after_gov_change()
				)
				row.add_child(adopt_btn)
	else:
		reforms_box.add_child(_make_label("All reforms taken.", Color(0.75, 0.70, 0.62), 12))
