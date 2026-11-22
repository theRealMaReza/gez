extends Control

var main_view: Control = null

var rel_panel: PanelContainer
var header_sub_label: Label
var left_box: VBoxContainer
var right_box: VBoxContainer
var message_label: Label

var _last_message: String = ""
var _last_sig: String = ""

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_panel()

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

func _build_panel() -> void:
	rel_panel = PanelContainer.new()
	rel_panel.name = "ReligionPanel"
	rel_panel.visible = false
	rel_panel.custom_minimum_size = Vector2(780.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBox = main_view.call("_make_panel_style")
		rel_panel.add_theme_stylebox_override("panel", st)
	add_child(rel_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	rel_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := _make_label("Religion & Culture", Color(0.97, 0.90, 0.68), 18)
	GezStyle.as_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := GezStyle.medallion_button("close", 30.0)
	close_btn.tooltip_text = "Close Religion & Culture window"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	header_sub_label = _make_label("", Color(0.84, 0.80, 0.72), 12)
	header_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(header_sub_label)

	outer.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	outer.add_child(cols)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(372.0, 560.0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(left_scroll)

	left_box = VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 5)
	left_scroll.add_child(left_box)

	var vsep := VSeparator.new()
	cols.add_child(vsep)

	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(372.0, 560.0)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(right_scroll)

	right_box = VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 5)
	right_scroll.add_child(right_box)

	message_label = _make_label("", Color(0.96, 0.45, 0.40), 12)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.visible = false
	outer.add_child(message_label)

func layout(viewport_size: Vector2) -> void:
	if rel_panel == null or not rel_panel.visible:
		return
	var max_w := clampf(viewport_size.x - 32.0, 520.0, 800.0)
	var max_h := clampf(viewport_size.y - 120.0, 420.0, 680.0)
	rel_panel.custom_minimum_size = Vector2(max_w, 0.0)
	rel_panel.position = Vector2(16.0, 62.0)
	rel_panel.size = Vector2(max_w, minf(max_h, 680.0))

func is_open() -> bool:
	return rel_panel != null and rel_panel.visible

func toggle_window() -> void:
	if rel_panel == null:
		return
	rel_panel.visible = not rel_panel.visible
	if rel_panel.visible:
		_last_message = ""
		refresh(true)
		layout(get_viewport_rect().size)

func close_window() -> void:
	if rel_panel != null:
		rel_panel.visible = false

func refresh_if_open() -> void:
	if is_open():
		refresh(false)

func refresh(force: bool = false) -> void:
	if rel_panel == null or not rel_panel.visible:
		return
	var d_var: Variant = _call_bridge("getReligionWindowDetails", [], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("hasPlayer", false)):
		header_sub_label.text = "Observer mode: pick a country to manage religion and culture."
		_clear_children(left_box)
		_clear_children(right_box)
		return

	var sig := "%s|%s|%d|%d|%s|%s|%d|%d|%d|%d" % [
		str(d.get("playerTag", "")),
		str(d.get("stateReligion", "")),
		int(d.get("missionariesUsed", 0)),
		int(d.get("missionariesMax", 0)),
		str(d.get("prestigeText", "")),
		str(d.get("hussiteOutcome", "")),
		int(d.get("reformationCentres", []).size()),
		int(d.get("acceptedSlotsUsed", 0)),
		int(d.get("acceptedSlotsMax", 0)),
		int(d.get("convertibleProvinces", []).size())
	]
	if not force and sig == _last_sig and _last_message.is_empty():
		return
	_last_sig = sig

	var st_rel := str(d.get("stateReligion", ""))
	var st_fam := str(d.get("stateReligionFamily", ""))
	var law_name := str(d.get("faithLawName", ""))
	var cl_loy := str(d.get("clergyLoyaltyText", "50%"))
	var prest := str(d.get("prestigeText", "+0.0"))
	header_sub_label.text = "%s (%s)  ·  Faith Law: %s  ·  Clergy Loyalty: %s  ·  Prestige: %s" % [
		st_rel, st_fam, law_name, cl_loy, prest
	]

	_clear_children(left_box)
	_clear_children(right_box)

	# ---------------- LEFT COLUMN: MISSIONARIES, CONVERSION & HOLY SITES ----------------
	var m_used := int(d.get("missionariesUsed", 0))
	var m_max := int(d.get("missionariesMax", 1))
	var m_cost := float(d.get("missionaryMonthlyCost", 0.5))
	var m_hdr := _make_label(
		"Missionaries (%d / %d active · %.1f duc/mo each)" % [m_used, m_max, m_cost],
		Color(0.96, 0.88, 0.64),
		14
	)
	left_box.add_child(m_hdr)

	var active_miss: Array = d.get("activeMissionaries", [])
	if active_miss.is_empty():
		left_box.add_child(_make_label("No active missionaries assigned.", Color(0.72, 0.68, 0.60), 12))
	else:
		for am_v in active_miss:
			if am_v is Dictionary:
				var am: Dictionary = am_v
				var p_idx := int(am.get("provinceIndex", -1))
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				left_box.add_child(row)

				var p_btn := Button.new()
				p_btn.text = str(am.get("provinceName", ""))
				p_btn.flat = true
				p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				p_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				p_btn.pressed.connect(func() -> void: _focus_province(p_idx))
				row.add_child(p_btn)

				row.add_child(_make_label(
					"%s · %s · Unrest %s" % [str(am.get("conversionText", "")), str(am.get("rateText", "")), str(am.get("unrestText", "0"))],
					Color(0.60, 0.92, 0.66),
					11
				))

				var rec_btn := Button.new()
				rec_btn.text = "Recall"
				rec_btn.pressed.connect(func() -> void:
					if bool(_call_bridge("recallMissionary", [p_idx], false)):
						_last_message = ""
						_after_faith_action()
				)
				row.add_child(rec_btn)

	left_box.add_child(HSeparator.new())
	var held_sites: Array = d.get("heldHolySites", [])
	left_box.add_child(_make_label(
		"Holy Sites Held (%d · %s prestige · %s Clergy · %s stab cost)" % [
			held_sites.size(),
			str(d.get("holySitePrestigeYearText", "+0.0/yr")),
			str(d.get("holySiteClergyBonusText", "+0%")),
			str(d.get("holySiteStabilityDiscountText", "-0%"))
		],
		Color(0.96, 0.88, 0.64),
		13
	))

	var all_sites: Array = d.get("allHolySites", [])
	var site_shown := 0
	for hs_v in all_sites:
		if hs_v is Dictionary:
			var hs: Dictionary = hs_v
			var is_held := bool(hs.get("isHeldByPlayer", false))
			var is_sacred := bool(hs.get("isSacredToPlayer", false))
			if not is_held and not is_sacred and site_shown >= 4:
				continue
			site_shown += 1
			if site_shown > 6:
				break
			var p_idx := int(hs.get("provinceIndex", -1))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			left_box.add_child(row)

			var site_btn := Button.new()
			site_btn.text = "%s (%s)" % [str(hs.get("name", "")), str(hs.get("provinceName", ""))]
			site_btn.flat = true
			site_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			site_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			site_btn.pressed.connect(func() -> void: _focus_province(p_idx))
			row.add_child(site_btn)

			var badge := "HELD" if is_held else ("Sacred · " + str(hs.get("ownerTag", "")))
			var col := Color(0.55, 0.92, 0.62) if is_held else (Color(0.92, 0.80, 0.45) if is_sacred else Color(0.68, 0.65, 0.60))
			row.add_child(_make_label(badge, col, 11))

	left_box.add_child(HSeparator.new())
	left_box.add_child(_make_label("Non-State Faith Provinces (Conversion & Unrest)", Color(0.88, 0.82, 0.70), 13))

	var conv_list: Array = d.get("convertibleProvinces", [])
	if conv_list.is_empty():
		left_box.add_child(_make_label("All provinces follow %s." % st_rel, Color(0.65, 0.90, 0.68), 12))
	else:
		var shown := 0
		for cp_v in conv_list:
			if cp_v is Dictionary:
				var cp: Dictionary = cp_v
				shown += 1
				if shown > 16:
					break
				var p_idx := int(cp.get("provinceIndex", -1))
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				left_box.add_child(row)

				var info_col := VBoxContainer.new()
				info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(info_col)

				var name_btn := Button.new()
				name_btn.text = "%s (%s · %s)" % [
					str(cp.get("provinceName", "")),
					str(cp.get("majorityReligion", "")),
					str(cp.get("conversionText", "0%"))
				]
				name_btn.flat = true
				name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				name_btn.pressed.connect(func() -> void: _focus_province(p_idx))
				info_col.add_child(name_btn)

				info_col.add_child(_make_label(
					"Non-state %s · %s · Unrest %s" % [
						str(cp.get("wrongPopText", "")),
						str(cp.get("rateText", "")),
						str(cp.get("unrestText", "0.0"))
					],
					Color(0.76, 0.72, 0.64),
					11
				))

				var has_miss := bool(cp.get("hasMissionary", false))
				if has_miss:
					var r_btn := Button.new()
					r_btn.text = "Recall"
					r_btn.pressed.connect(func() -> void:
						_call_bridge("recallMissionary", [p_idx], false)
						_after_faith_action()
					)
					row.add_child(r_btn)
				else:
					var s_btn := Button.new()
					s_btn.text = "Missionary"
					s_btn.disabled = not bool(cp.get("canSend", false))
					s_btn.tooltip_text = str(cp.get("refusal", ""))
					s_btn.pressed.connect(func() -> void:
						var res_v: Variant = _call_bridge("sendMissionary", [p_idx], {})
						var res: Dictionary = res_v if res_v is Dictionary else {}
						if bool(res.get("ok", false)):
							_last_message = ""
						else:
							_last_message = str(res.get("reason", "Cannot send missionary."))
						_after_faith_action()
					)
					row.add_child(s_btn)

	# ---------------- RIGHT COLUMN: HISTORICAL MOVEMENTS & CULTURE ----------------
	right_box.add_child(_make_label("Historical Movements", Color(0.96, 0.88, 0.64), 14))

	var huss_text := "Hussite Question: %s%s" % [
		str(d.get("hussiteOutcomeName", "")),
		" (Basel Compacts active)" if bool(d.get("hussiteCompactsActive", false)) else ""
	]
	right_box.add_child(_make_label(huss_text, Color(0.88, 0.85, 0.78), 12))

	if bool(d.get("isBohemia", false)) and str(d.get("hussiteOutcome", "")) == "unresolved":
		var huss_row := HBoxContainer.new()
		huss_row.add_theme_constant_override("separation", 4)
		right_box.add_child(huss_row)
		for opt in [
			["utraquistCompacts", "Uphold Compacts"],
			["taboriteRevival", "Taborite Revival"],
			["catholicSubmission", "Submit to Rome"]
		]:
			var b := Button.new()
			b.text = opt[1]
			var key: String = opt[0]
			b.pressed.connect(func() -> void:
				_call_bridge("resolveHussiteQuestion", [key], false)
				_after_faith_action()
			)
			huss_row.add_child(b)

	var saf_yr := int(d.get("safaviyyaYear", 0))
	var saf_str := "Safaviyya (Ardabil): %s · Strength %s%s" % [
		str(d.get("safaviyyaPhase", "Growing")),
		str(d.get("safaviyyaStrengthText", "25%")),
		(" (%d)" % saf_yr) if saf_yr > 0 else ""
	]
	right_box.add_child(_make_label(saf_str, Color(0.86, 0.82, 0.74), 12))

	var ref_started := bool(d.get("reformationStarted", false))
	var ref_centres: Array = d.get("reformationCentres", [])
	var ref_summary := "Reformation: Active (%d Centres)" % ref_centres.size() if ref_started else "Reformation: Not yet begun (after 1500)"
	right_box.add_child(_make_label(ref_summary, Color(0.92, 0.78, 0.56) if ref_started else Color(0.75, 0.72, 0.66), 12))

	for rc_v in ref_centres:
		if rc_v is Dictionary:
			var rc: Dictionary = rc_v
			var p_idx := int(rc.get("provinceIndex", -1))
			var rc_btn := Button.new()
			rc_btn.flat = true
			rc_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			rc_btn.text = "  • %s Centre in %s (%s, %d)" % [
				str(rc.get("religion", "")),
				str(rc.get("provinceName", "")),
				str(rc.get("ownerTag", "")),
				int(rc.get("foundedYear", 0))
			]
			rc_btn.pressed.connect(func() -> void: _focus_province(p_idx))
			right_box.add_child(rc_btn)

	if bool(d.get("canAdoptProtestant", false)) or bool(d.get("canAdoptReformed", false)):
		var adopt_row := HBoxContainer.new()
		adopt_row.add_theme_constant_override("separation", 6)
		right_box.add_child(adopt_row)
		if bool(d.get("canAdoptProtestant", false)):
			var bp := Button.new()
			bp.text = "Convert to Protestant"
			bp.pressed.connect(func() -> void:
				_call_bridge("adoptReformationReligion", ["protestant"], false)
				_after_faith_action()
			)
			adopt_row.add_child(bp)
		if bool(d.get("canAdoptReformed", false)):
			var br := Button.new()
			br.text = "Convert to Reformed"
			br.pressed.connect(func() -> void:
				_call_bridge("adoptReformationReligion", ["reformed"], false)
				_after_faith_action()
			)
			adopt_row.add_child(br)

	right_box.add_child(HSeparator.new())
	right_box.add_child(_make_label(
		"Culture · %s · Primary: %s (%s)" % [
			str(d.get("governmentRank", "Duchy")),
			str(d.get("primaryCultureName", "")),
			str(d.get("primaryCultureFamily", ""))
		],
		Color(0.96, 0.88, 0.64),
		14
	))
	right_box.add_child(_make_label(
		"Accepted Culture Slots: %d / %d" % [
			int(d.get("acceptedSlotsUsed", 0)),
			int(d.get("acceptedSlotsMax", 1))
		],
		Color(0.84, 0.80, 0.72),
		12
	))
	var slots_hdr_lbl := right_box.get_child(right_box.get_child_count() - 1) as Control
	if main_view != null:
		main_view.call("bind_tip", slots_hdr_lbl, "Accepted Culture Capacity", "Non-accepted cultures suffer tax (-25%) and manpower penalties and raise province unrest. Accepted cultures count as loyal subjects.")

	var cultures: Array = d.get("cultures", [])
	for c_v in cultures:
		if c_v is Dictionary:
			var c_item: Dictionary = c_v
			var c_idx := int(c_item.get("cultureIndex", -1))
			var is_prim := bool(c_item.get("isPrimary", false))
			var is_acc := bool(c_item.get("isAccepted", false))

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			right_box.add_child(row)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)

			var tag_str := " [Primary]" if is_prim else (" [Accepted]" if is_acc else "")
			var title_col := Color(0.96, 0.86, 0.48) if is_prim else (Color(0.58, 0.90, 0.68) if is_acc else Color(0.90, 0.86, 0.78))
			info.add_child(_make_label(
				"%s%s · %s (%s)" % [
					str(c_item.get("name", "")),
					tag_str,
					str(c_item.get("populationText", "0")),
					str(c_item.get("shareText", "0%"))
				],
				title_col,
				12
			))
			info.add_child(_make_label(
				"Tax %s · Manpower %s · Mood %s" % [
					str(c_item.get("taxText", "100%")),
					str(c_item.get("manpowerText", "100%")),
					str(c_item.get("moodText", "+0%"))
				],
				Color(0.74, 0.70, 0.64),
				11
			))

			if is_prim:
				row.add_child(_make_label("Primary", Color(0.96, 0.86, 0.48), 11))
			elif is_acc:
				var rev_btn := Button.new()
				rev_btn.text = "Revoke"
				rev_btn.pressed.connect(func() -> void:
					if bool(_call_bridge("revokeCulture", [c_idx], false)):
						_last_message = ""
						_after_faith_action()
				)
				row.add_child(rev_btn)
			else:
				var acc_btn := Button.new()
				acc_btn.text = "Accept"
				acc_btn.disabled = not bool(c_item.get("canAccept", false))
				acc_btn.tooltip_text = str(c_item.get("acceptRefusal", ""))
				acc_btn.pressed.connect(func() -> void:
					var res_v: Variant = _call_bridge("acceptCulture", [c_idx], {})
					var res: Dictionary = res_v if res_v is Dictionary else {}
					if bool(res.get("ok", false)):
						_last_message = ""
					else:
						_last_message = str(res.get("reason", "Cannot accept culture."))
					_after_faith_action()
				)
				row.add_child(acc_btn)

	if _last_message.is_empty():
		message_label.visible = false
	else:
		message_label.text = _last_message
		message_label.visible = true

	layout(get_viewport_rect().size)

func _focus_province(province_idx: int) -> void:
	if province_idx < 0 or main_view == null:
		return
	main_view.call("_focus_and_select_province", province_idx)

func _after_faith_action() -> void:
	refresh(true)
	if main_view != null:
		main_view.call("_refresh_top_bar")
		main_view.call("_refresh_styles_and_country_labels")
		main_view.call("_refresh_faith_overlay")
		if bool(main_view.get("province_panel").visible):
			main_view.call("_refresh_province_panel")
