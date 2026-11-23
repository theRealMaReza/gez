extends Control
## The province drawer and the sea-zone panel (bottom left), split out of
## Main.gd in Phase 20.6 part 2. Main makes one of these, adds it to the
## windows layer and calls setup(self). Main still owns selection and
## map state; this script only builds and fills the two panels.
## Main keeps thin wrappers (_refresh_province_panel, _refresh_sea_panel,
## province_panel, current_prov_tab, ...) so other screens and the CI
## screenshot script work unchanged.

var main = null   # Main.gd (untyped so its helpers can be called directly)

var _last_prov_sig: String = ""
var province_panel: PanelContainer
var prov_title_label: Label
var prov_subtitle_label: Label
var prov_owner_arms: TextureRect
var prov_owner_label: Label
var prov_diplomacy_btn: Button
var prov_owner_index: int = -1
var prov_capital_label: Label
var prov_occupied_label: Label
var prov_status_label: Label
var prov_tab_buttons: Dictionary = {}
var prov_content_box: VBoxContainer
var current_prov_tab: String = "overview"
var prov_show_build: bool = false
var prov_show_shipbuild: bool = false
var prov_build_category: String = "production"
var prov_people_show_state: bool = false
var sea_panel: PanelContainer
var sea_title_label: Label
var sea_neighbors_label: Label
var sea_coast_title_label: Label
var sea_coast_label: Label

func setup(host: Control) -> void:
	main = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_province_panel()
	_build_sea_panel()

# Shared helpers, forwarded to Main.
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

func bind_breakdown(ctrl: Control, callback: Callable, fallback_title: String = "") -> void:
	main.bind_breakdown(ctrl, callback, fallback_title)

func _build_province_panel() -> void:
	province_panel = PanelContainer.new()
	province_panel.name = "ProvincePanel"
	province_panel.visible = false
	province_panel.custom_minimum_size = Vector2(330.0, 0.0)
	province_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(province_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	province_panel.add_child(vbox)

	# Title + close button
	var header := HBoxContainer.new()
	vbox.add_child(header)
	prov_title_label = _make_label("Province", Color(0.97, 0.90, 0.68), 18)
	GezStyle.as_title(prov_title_label)
	prov_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(prov_title_label)
	var close_btn := GezStyle.medallion_button("close", 30.0)
	close_btn.tooltip_text = "Close province panel"
	close_btn.pressed.connect(Callable(main, "_clear_selection"))
	header.add_child(close_btn)

	prov_subtitle_label = _make_label("State · Region", Color(0.80, 0.75, 0.66), 12)
	vbox.add_child(prov_subtitle_label)

	# Owner row
	var owner_row := HBoxContainer.new()
	owner_row.add_theme_constant_override("separation", 6)
	vbox.add_child(owner_row)
	prov_owner_arms = TextureRect.new()
	prov_owner_arms.custom_minimum_size = Vector2(24.0, 20.0)
	prov_owner_arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prov_owner_arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bind_tip(prov_owner_arms, "Province Sovereign", "Coat of arms of the realm ruling this province.")
	owner_row.add_child(prov_owner_arms)
	prov_owner_label = _make_label("Owner", Color(0.95, 0.92, 0.85), 14)
	prov_owner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_tip(prov_owner_label, "Province Owner", "Country that owns and taxes this province.")
	owner_row.add_child(prov_owner_label)
	prov_diplomacy_btn = Button.new()
	prov_diplomacy_btn.text = "Diplomacy"
	prov_diplomacy_btn.visible = false
	bind_tip(prov_diplomacy_btn, "Open Foreign Diplomacy", "Inspect relations, treaties and the AI's current strategic goal for this country.")
	prov_diplomacy_btn.pressed.connect(func() -> void:
		if prov_owner_index >= 0:
			main._open_diplomacy_with(prov_owner_index)
	)
	owner_row.add_child(prov_diplomacy_btn)
	prov_capital_label = _make_label("★ Capital", Color(0.98, 0.84, 0.32), 12)
	bind_tip(prov_capital_label, "National Capital", "Seat of government and court. Losing a capital yields major war score.")
	owner_row.add_child(prov_capital_label)

	prov_occupied_label = _make_label("", Color(0.95, 0.42, 0.38), 12)
	prov_occupied_label.visible = false
	vbox.add_child(prov_occupied_label)

	prov_status_label = _make_label("", Color(0.78, 0.73, 0.64), 12)
	vbox.add_child(prov_status_label)

	# Tabs: Overview, Economy, People
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 4)
	vbox.add_child(tabs_row)
	prov_tab_buttons.clear()
	for tab_spec in [["overview", "Overview"], ["economy", "Economy"], ["people", "People"]]:
		var tk: String = tab_spec[0]
		var tt: String = tab_spec[1]
		var tb := Button.new()
		tb.text = tt
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tab_key := tk
		tb.pressed.connect(func() -> void:
			current_prov_tab = tab_key
			refresh_province()
		)
		tabs_row.add_child(tb)
		prov_tab_buttons[tk] = tb

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310.0, 270.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	prov_content_box = VBoxContainer.new()
	prov_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prov_content_box.add_theme_constant_override("separation", 5)
	scroll.add_child(prov_content_box)

	province_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)

func _build_sea_panel() -> void:
	sea_panel = PanelContainer.new()
	sea_panel.name = "SeaPanel"
	sea_panel.visible = false
	sea_panel.custom_minimum_size = Vector2(300.0, 0.0)
	sea_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(sea_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	sea_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	sea_title_label = _make_label("Sea Zone", Color(0.86, 0.93, 0.98), 17)
	sea_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_tip(sea_title_label, "Sea Zone", "Maritime region navigable by fleets. Blockading enemy coasts disrupts trade and fort sieges.")
	header.add_child(sea_title_label)
	var close_btn := GezStyle.medallion_button("close", 30.0)
	bind_tip(close_btn, "Close Sea Panel")
	close_btn.pressed.connect(Callable(main, "_clear_selection"))
	header.add_child(close_btn)

	vbox.add_child(_make_label("Sea zone", Color(0.75, 0.82, 0.88), 12))
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_label("Connects to", Color(0.95, 0.90, 0.78), 13))
	sea_neighbors_label = _make_label("", Color(0.85, 0.83, 0.78), 12)
	sea_neighbors_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bind_tip(sea_neighbors_label, "Adjacent Waters & Activity", "Connected sea zones and any friendly or hostile fleets patrolling here.")
	vbox.add_child(sea_neighbors_label)

	sea_coast_title_label = _make_label("Coast", Color(0.95, 0.90, 0.78), 13)
	vbox.add_child(sea_coast_title_label)
	sea_coast_label = _make_label("", Color(0.85, 0.83, 0.78), 12)
	sea_coast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bind_tip(sea_coast_label, "Coastal Provinces", "Land provinces bordering this sea zone.")
	vbox.add_child(sea_coast_label)

	sea_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)

func refresh_province() -> void:
	var d: Dictionary = _call_bridge("getSelectedProvinceDetails", [prov_people_show_state], {})
	if not bool(d.get("hasSelection", false)):
		province_panel.visible = false
		_last_prov_sig = ""
		return

	var sig := "%s|%s|%s|%s" % [current_prov_tab, str(prov_show_build), str(prov_show_shipbuild), var_to_str(d)]
	if sig == _last_prov_sig and province_panel.visible:
		return
	_last_prov_sig = sig

	sea_panel.visible = false
	province_panel.visible = true

	prov_title_label.text = str(d.get("name", "Province"))
	prov_subtitle_label.text = str(d.get("subtitle", ""))

	var owner_tag: String = str(d.get("ownerTag", ""))
	var owner_name: String = str(d.get("ownerName", "Unclaimed land"))
	var cr: int = int(d.get("ownerColorR", 196))
	var cg: int = int(d.get("ownerColorG", 182))
	var cb: int = int(d.get("ownerColorB", 150))
	prov_owner_arms.visible = not owner_tag.is_empty()
	prov_owner_arms.texture = main._get_country_arms_texture(owner_tag, cr, cg, cb) if prov_owner_arms.visible else null
	prov_owner_label.text = owner_name
	prov_owner_index = int(d.get("ownerIndex", -1))
	if prov_diplomacy_btn != null:
		prov_diplomacy_btn.visible = bool(d.get("isForeignOwner", false)) and prov_owner_index >= 0
	prov_capital_label.visible = bool(d.get("isCapital", false))

	var occ: String = str(d.get("occupiedByName", ""))
	prov_occupied_label.visible = not occ.is_empty()
	prov_occupied_label.text = "Occupied by " + occ

	var status: String = str(d.get("countryStatus", ""))
	prov_status_label.visible = not status.is_empty()
	prov_status_label.text = status

	for k in prov_tab_buttons.keys():
		var btn: Button = prov_tab_buttons[k]
		btn.modulate = Color(1.0, 0.88, 0.40) if k == current_prov_tab else Color(0.86, 0.84, 0.78)

	_clear_children(prov_content_box)
	match current_prov_tab:
		"overview":
			_build_province_overview_tab(d)
		"economy":
			_build_province_economy_tab(d)
		"people":
			_build_province_people_tab(d)

func _add_kv_row(parent: VBoxContainer, label_txt: String, value_txt: String, tip_title: String = "", tip_body: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _make_label(label_txt, Color(0.80, 0.75, 0.66), 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := _make_label(value_txt, Color(0.95, 0.92, 0.84), 13)
	row.add_child(v)
	if not tip_title.is_empty():
		bind_tip(row, tip_title, tip_body)
	return row

func _build_province_overview_tab(d: Dictionary) -> void:
	var is_mine: bool = bool(d.get("isPlayerOwned", false))
	var holder_name: String = str(d.get("holderName", "The crown"))
	var holder_idx: int = int(d.get("holderIndex", -1))
	var stance: String = str(d.get("holderStance", ""))
	var has_holder: bool = bool(d.get("hasHolder", false))

	var holder_row := HBoxContainer.new()
	holder_row.add_theme_constant_override("separation", 6)
	prov_content_box.add_child(holder_row)
	if has_holder and holder_idx >= 0:
		holder_row.add_child(_make_label("Held by:", Color(0.92, 0.88, 0.78), 13))
		var h_btn := Button.new()
		h_btn.text = holder_name + (" (%s)" % stance if not stance.is_empty() else "")
		h_btn.flat = true
		h_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		h_btn.add_theme_color_override("font_color", GezStyle.ink(Color(0.97, 0.88, 0.62)))
		h_btn.add_theme_font_size_override("font_size", GezStyle.fs(13))
		h_btn.pressed.connect(func() -> void:
			if main.court_ui != null:
				main._close_top_left_windows("court")
				main.court_ui.call("open_window", holder_idx)
		)
		holder_row.add_child(h_btn)
	else:
		var h_lbl := _make_label("Held by: " + holder_name + (" (%s)" % stance if not stance.is_empty() else ""), Color(0.92, 0.88, 0.78), 13)
		h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder_row.add_child(h_lbl)

	if is_mine:
		if has_holder:
			var rev_btn := Button.new()
			rev_btn.text = "Revoke"
			rev_btn.tooltip_text = "Take the province back from its vassal holder"
			rev_btn.pressed.connect(func() -> void:
				if bool(_call_bridge("revokeSelectedProvince", [], false)):
					refresh_province()
			)
			holder_row.add_child(rev_btn)
		else:
			var cands: Array = d.get("grantCandidates", [])
			if not cands.is_empty():
				var grant_menu := MenuButton.new()
				grant_menu.text = "Grant..."
				grant_menu.flat = false
				var popup := grant_menu.get_popup()
				for idx in range(cands.size()):
					var c_item: Dictionary = cands[idx]
					popup.add_item(str(c_item.get("label", "Vassal")), int(c_item.get("characterIndex", 0)))
				popup.id_pressed.connect(func(char_id: int) -> void:
					if bool(_call_bridge("grantSelectedProvince", [char_id], false)):
						refresh_province()
				)
				holder_row.add_child(grant_menu)

	var prov_idx_here: int = int(d.get("provinceIndex", -1))
	_add_kv_row(prov_content_box, "Development", str(d.get("developmentText", "")), "Province Development", "Raises local tax base, trade production, manpower recovery, fort capacity and building slots.")
	_add_kv_row(prov_content_box, "Land", str(d.get("landText", "")), "Terrain & Geography", "Affects army combat width, movement speed, attacker terrain penalties and supply capacity.")
	var river_txt: String = str(d.get("riverBordersText", ""))
	if not river_txt.is_empty():
		_add_kv_row(prov_content_box, "River borders", river_txt, "River Crossings", "Attacking across a river inflicts a crossing penalty in land battles unless outmanoeuvred.")
	var sup_row := _add_kv_row(prov_content_box, "Supply limit", str(d.get("supplyText", "")))
	if prov_idx_here >= 0:
		bind_breakdown(sup_row, func() -> Variant: return _call_bridge("getProvinceSupplyBreakdown", [prov_idx_here], {}), "Province Supply Limit")

	if main.army_ui != null:
		main.army_ui.call("append_province_military_sections", prov_content_box, d)

	_append_province_docks_section(d)

	prov_content_box.add_child(HSeparator.new())

	# Buildings section
	_add_kv_row(prov_content_box, "Buildings", str(d.get("slotsText", "0 / 0 slots")))
	var built_details_var: Variant = d.get("builtBuildingDetails", [])
	var built_details: Array = built_details_var if built_details_var is Array else []
	if not built_details.is_empty():
		for bd in built_details:
			if bd is Dictionary:
				var bdict: Dictionary = bd
				var bname: String = str(bdict.get("name", ""))
				var blvl: int = int(bdict.get("level", 1))
				var bmax: int = int(bdict.get("maxLevel", 3))
				var bup: String = str(bdict.get("upkeepText", ""))
				var title_txt := "%s Lv %d/%d" % [bname, blvl, bmax]
				if not bup.is_empty():
					title_txt += " · upkeep %s" % bup
				var b_row := HBoxContainer.new()
				b_row.add_theme_constant_override("separation", 6)
				prov_content_box.add_child(b_row)
				var b_icon := GezStyle.building_icon(bname)
				if b_icon != null:
					b_row.add_child(GezStyle.icon_rect(b_icon, 34.0))
				var b_title := _make_label(title_txt, Color(0.94, 0.90, 0.80), 12)
				b_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b_row.add_child(b_title)
				var beff: String = str(bdict.get("effectText", ""))
				if not beff.is_empty():
					var eff_lbl := _make_label("  " + beff, Color(0.76, 0.72, 0.64), 11)
					eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					prov_content_box.add_child(eff_lbl)
	else:
		var built_arr: Array = d.get("builtBuildings", [])
		if built_arr.is_empty():
			prov_content_box.add_child(_make_label("None built", Color(0.70, 0.66, 0.58), 12))
		else:
			var built_lbl := _make_label(", ".join(PackedStringArray(built_arr)), Color(0.94, 0.90, 0.80), 12)
			built_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			prov_content_box.add_child(built_lbl)

	var constructions: Array = d.get("constructions", [])
	for con in constructions:
		if con is Dictionary:
			var cname: String = str(con.get("name", ""))
			var clvl: int = int(con.get("level", 1))
			var cmo: int = int(con.get("monthsLeft", 0))
			var ctot: int = int(con.get("totalMonths", cmo))
			var cprog: float = float(con.get("progress", 0.0)) * 100.0
			var c_row := VBoxContainer.new()
			c_row.add_theme_constant_override("separation", 2)
			c_row.add_child(_make_label("Building %s Lv %d (%d%% · %d/%d mo left)" % [cname, clvl, int(round(cprog)), cmo, ctot], Color(0.96, 0.84, 0.42), 12))
			var c_bar := ProgressBar.new()
			c_bar.min_value = 0.0
			c_bar.max_value = 100.0
			c_bar.value = clampf(cprog, 0.0, 100.0)
			c_bar.show_percentage = false
			c_bar.custom_minimum_size = Vector2(0.0, 8.0)
			c_row.add_child(c_bar)
			prov_content_box.add_child(c_row)

	if is_mine:
		var build_toggle := Button.new()
		build_toggle.text = "Hide Build Menu" if prov_show_build else "Build..."
		build_toggle.pressed.connect(func() -> void:
			prov_show_build = not prov_show_build
			refresh_province()
		)
		prov_content_box.add_child(build_toggle)

		if prov_show_build:
			var cat_row := HBoxContainer.new()
			cat_row.add_theme_constant_override("separation", 4)
			prov_content_box.add_child(cat_row)
			var cats: Array = d.get("buildCategories", [])
			for cat in cats:
				if cat is Dictionary:
					var ck: String = str(cat.get("key", ""))
					var ct: String = str(cat.get("title", ck))
					var cbtn := Button.new()
					cbtn.text = ct
					cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					if ck == prov_build_category:
						cbtn.modulate = Color(1.0, 0.88, 0.40)
					var cat_key := ck
					cbtn.pressed.connect(func() -> void:
						prov_build_category = cat_key
						refresh_province()
					)
					cat_row.add_child(cbtn)

			var options: Array = d.get("buildableOptions", [])
			for opt in options:
				if not (opt is Dictionary):
					continue
				if str(opt.get("category", "")) != prov_build_category:
					continue
				var t_idx: int = int(opt.get("typeIndex", -1))
				var b_name: String = str(opt.get("name", ""))
				var base_name: String = str(opt.get("baseName", b_name))
				var cur_lvl: int = int(opt.get("currentLevel", 0))
				var max_lvl: int = int(opt.get("maxLevel", 3))
				var next_lvl: int = int(opt.get("level", 1))
				var b_cost: int = int(opt.get("cost", 0))
				var b_ducats_base: int = int(opt.get("ducatsBase", b_cost))
				var b_months: int = int(opt.get("months", 0))
				var mats_txt: String = str(opt.get("materialsText", "None"))
				var can_build: bool = bool(opt.get("canBuild", false))
				var is_applicable: bool = bool(opt.get("isApplicable", true))
				var refusal: String = str(opt.get("refusalReason", ""))
				var effect: String = str(opt.get("effectText", ""))

				var card := VBoxContainer.new()
				card.add_theme_constant_override("separation", 2)
				prov_content_box.add_child(card)

				var hdr := HBoxContainer.new()
				hdr.add_theme_constant_override("separation", 6)
				card.add_child(hdr)

				var lvl_str := "Lv %d/%d" % [cur_lvl, max_lvl] if cur_lvl >= max_lvl else "Lv %d → %d/%d" % [cur_lvl, next_lvl, max_lvl]
				var title_col := Color(0.95, 0.92, 0.84) if (can_build or is_applicable) else Color(0.62, 0.58, 0.52)
				var opt_icon := GezStyle.building_icon(base_name)
				if opt_icon != null:
					var oi := GezStyle.icon_rect(opt_icon, 40.0)
					if not (can_build or is_applicable):
						oi.modulate = Color(1, 1, 1, 0.5)
					hdr.add_child(oi)
				var title_lbl := _make_label("%s (%s)" % [base_name, lvl_str], title_col, 12)
				title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hdr.add_child(title_lbl)

				var b_btn := Button.new()
				b_btn.text = "%dd · %d mo" % [b_cost, b_months]
				b_btn.disabled = not can_build
				b_btn.tooltip_text = refusal if not refusal.is_empty() else ("Build " + b_name)
				var build_idx := t_idx
				b_btn.pressed.connect(func() -> void:
					if bool(_call_bridge("buildInSelectedProvince", [build_idx], false)):
						main.play_sfx("building_finished")
						main._after_economy_action()
				)
				hdr.add_child(b_btn)

				var cost_txt := "Cost: %dd (base %dd) · Goods: %s" % [b_cost, b_ducats_base, mats_txt]
				var cost_lbl := _make_label(cost_txt, Color(0.82, 0.78, 0.70), 11)
				cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				card.add_child(cost_lbl)

				if not effect.is_empty():
					var eff_lbl := _make_label(effect, Color(0.72, 0.78, 0.68), 11)
					eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					card.add_child(eff_lbl)

				if not can_build and not refusal.is_empty():
					var ref_col := Color(0.95, 0.44, 0.38) if is_applicable else Color(0.70, 0.55, 0.50)
					var ref_lbl := _make_label(refusal, ref_col, 11)
					ref_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					card.add_child(ref_lbl)

				card.add_child(HSeparator.new())

func _build_province_economy_tab(d: Dictionary) -> void:
	var hdr := HBoxContainer.new()
	prov_content_box.add_child(hdr)
	var e_lbl := _make_label("Economy", Color(0.96, 0.90, 0.72), 14)
	e_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(e_lbl)

	var m_idx: int = int(d.get("marketIndex", -1))
	var m_name: String = str(d.get("marketName", ""))
	if m_idx >= 0 and not m_name.is_empty():
		var m_btn := Button.new()
		m_btn.text = "%s market" % m_name
		m_btn.tooltip_text = "Show prices, supply and demand in this market"
		var market_id := m_idx
		m_btn.pressed.connect(func() -> void: main._open_market_panel(market_id))
		hdr.add_child(m_btn)

	var goods: Array = d.get("goodsProduced", [])
	for g in goods:
		if not (g is Dictionary):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		prov_content_box.add_child(row)

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

		var g_name := str(g.get("name", "")) + (" [Workshop]" if bool(g.get("isWorkshop", false)) else "")
		var n_lbl := _make_label(g_name, Color(0.94, 0.90, 0.82), 12)
		n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n_lbl)

		row.add_child(_make_label(str(g.get("amountText", "")), Color(0.76, 0.72, 0.64), 12))
		var v_lbl := _make_label(str(g.get("valueText", "")), Color(0.96, 0.86, 0.52), 12)
		v_lbl.custom_minimum_size = Vector2(44.0, 0.0)
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v_lbl)

	prov_content_box.add_child(HSeparator.new())
	_add_kv_row(prov_content_box, "Worth", str(d.get("worthText", "")), "Total Monthly Value", "Estimated combined market value of all goods produced in this province.")

	var sats: Array = d.get("classSatisfactions", [])
	if not sats.is_empty():
		var sat_row := HBoxContainer.new()
		sat_row.add_theme_constant_override("separation", 10)
		prov_content_box.add_child(sat_row)
		for s in sats:
			if s is Dictionary:
				var col := VBoxContainer.new()
				col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				bind_tip(col, "%s Needs Met" % str(s.get("name", "Estate")), "Share of monthly consumer and luxury goods available in the local market.")
				sat_row.add_child(col)
				col.add_child(_make_label(str(s.get("percentText", "")), Color(0.95, 0.92, 0.84), 12))
				col.add_child(_make_label(str(s.get("name", "")), Color(0.75, 0.70, 0.62), 11))

func _build_province_people_tab(d: Dictionary) -> void:
	var hdr := HBoxContainer.new()
	prov_content_box.add_child(hdr)
	var p_lbl := _make_label(str(d.get("peopleTitle", "People")), Color(0.96, 0.90, 0.72), 14)
	p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(p_lbl)

	var btn_prov := Button.new()
	btn_prov.text = "Province"
	btn_prov.modulate = Color(1.0, 0.88, 0.40) if not prov_people_show_state else Color(0.85, 0.85, 0.85)
	btn_prov.pressed.connect(func() -> void:
		prov_people_show_state = false
		refresh_province()
	)
	hdr.add_child(btn_prov)

	var btn_state := Button.new()
	btn_state.text = "State"
	btn_state.modulate = Color(1.0, 0.88, 0.40) if prov_people_show_state else Color(0.85, 0.85, 0.85)
	btn_state.pressed.connect(func() -> void:
		prov_people_show_state = true
		refresh_province()
	)
	hdr.add_child(btn_state)

	_add_kv_row(prov_content_box, "Population", str(d.get("populationText", "0")), "Total Inhabitants", "Combined population supporting taxes, production, manpower and sailors.")

	prov_content_box.add_child(_make_label("Cultures", Color(0.84, 0.78, 0.66), 12))
	var cultures: Array = d.get("cultures", [])
	for c_item in cultures:
		if c_item is Dictionary:
			_add_kv_row(prov_content_box, str(c_item.get("name", "")), str(c_item.get("percentText", "")))

	prov_content_box.add_child(HSeparator.new())
	prov_content_box.add_child(_make_label("Religions", Color(0.84, 0.78, 0.66), 12))
	var religions: Array = d.get("religions", [])
	for r_item in religions:
		if r_item is Dictionary:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			prov_content_box.add_child(row)
			var swatch := ColorRect.new()
			swatch.custom_minimum_size = Vector2(10.0, 10.0)
			swatch.color = Color(
				float(int(r_item.get("colorR", 180))) / 255.0,
				float(int(r_item.get("colorG", 180))) / 255.0,
				float(int(r_item.get("colorB", 180))) / 255.0
			)
			row.add_child(swatch)
			var rl := _make_label(str(r_item.get("name", "")), Color(0.94, 0.90, 0.82), 12)
			rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(rl)
			row.add_child(_make_label(str(r_item.get("percentText", "")), Color(0.95, 0.92, 0.84), 12))

	prov_content_box.add_child(HSeparator.new())
	var classes: Array = d.get("classes", [])
	if not classes.is_empty():
		var cls_row := HBoxContainer.new()
		cls_row.add_theme_constant_override("separation", 8)
		prov_content_box.add_child(cls_row)
		for cl in classes:
			if cl is Dictionary:
				var col := VBoxContainer.new()
				col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cls_row.add_child(col)
				col.add_child(_make_label(str(cl.get("percentText", "")), Color(0.95, 0.92, 0.84), 12))
				col.add_child(_make_label(str(cl.get("name", "")), Color(0.75, 0.70, 0.62), 11))

	var sufi_txt: String = str(d.get("sufiText", ""))
	if not sufi_txt.is_empty():
		var s_lbl := _make_label(sufi_txt, Color(0.82, 0.78, 0.68), 12)
		s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prov_content_box.add_child(s_lbl)

	if not prov_people_show_state:
		prov_content_box.add_child(HSeparator.new())
		var p_idx: int = int(d.get("provinceIndex", -1))
		var is_mine: bool = bool(d.get("isPlayerOwned", false))
		var conv_rate := str(d.get("monthlyConversionRateText", "—"))
		_add_kv_row(
			prov_content_box,
			"Conversion",
			"%s (%s)" % [str(d.get("conversionText", "100%")), conv_rate],
			"Religious Conversion",
			"Share of the population following your state faith, and current monthly missionary conversion rate."
		)
		_add_kv_row(prov_content_box, "Assimilation", str(d.get("assimilationText", "100%")), "Cultural Assimilation", "Share belonging to an accepted or primary culture of the realm.")
		_add_kv_row(prov_content_box, "Religious Unrest", str(d.get("religiousUnrestText", "0.0")), "Religious Tension", "Local unrest contributed by unaccepted faiths in the province.")
		_add_kv_row(
			prov_content_box,
			"Migration / Devast.",
			"%s · Devast %s" % [str(d.get("netMigrationText", "+0")), str(d.get("devastationText", "0%"))],
			"Population Migration & Devastation",
			"Net monthly migration from war/plague/famine and current physical devastation reducing local output."
		)

		var hs_list: Array = d.get("holySites", [])
		for hs_v in hs_list:
			if hs_v is Dictionary:
				var hs: Dictionary = hs_v
				var hl := _make_label(
					"Holy Site: %s (%s)" % [str(hs.get("name", "")), str(hs.get("religions", ""))],
					Color(0.95, 0.84, 0.42),
					12
				)
				hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				prov_content_box.add_child(hl)

		var rc_v: Variant = d.get("reformationCentre", {})
		if rc_v is Dictionary and bool((rc_v as Dictionary).get("exists", false)):
			var rc := rc_v as Dictionary
			prov_content_box.add_child(_make_label(
				"Centre of Reformation: %s (%d)" % [str(rc.get("religion", "")), int(rc.get("foundedYear", 0))],
				Color(0.98, 0.68, 0.42),
				12
			))

		_append_province_calamity_section(p_idx)
		_append_province_tech_section(p_idx)

		if is_mine and p_idx >= 0:
			var has_miss := bool(d.get("hasMissionary", false))
			if has_miss:
				var rec_btn := Button.new()
				rec_btn.text = "Recall Missionary"
				rec_btn.pressed.connect(func() -> void:
					_call_bridge("recallMissionary", [p_idx], false)
					refresh_province()
					main._refresh_top_bar()
					main._refresh_faith_overlay()
					if main.religion_ui != null:
						main.religion_ui.call("refresh_if_open")
				)
				prov_content_box.add_child(rec_btn)
			else:
				var send_btn := Button.new()
				send_btn.text = "Send Missionary (0.5/mo)"
				send_btn.disabled = not bool(d.get("canSendMissionary", false))
				send_btn.tooltip_text = str(d.get("missionaryRefusal", ""))
				send_btn.pressed.connect(func() -> void:
					_call_bridge("sendMissionary", [p_idx], {})
					refresh_province()
					main._refresh_top_bar()
					main._refresh_faith_overlay()
					if main.religion_ui != null:
						main.religion_ui.call("refresh_if_open")
				)
				prov_content_box.add_child(send_btn)

# Phase 12: plague, immunity, famine, unrest with its causes and rebel progress.
func _append_province_calamity_section(p_idx: int) -> void:
	if p_idx < 0:
		return
	var c_v: Variant = _call_bridge("getProvinceCalamityDetails", [p_idx], {})
	var c: Dictionary = c_v if c_v is Dictionary else {}
	if not bool(c.get("hasProvince", false)):
		return
	var mine: bool = bool(c.get("isPlayerOwned", false))
	prov_content_box.add_child(HSeparator.new())
	prov_content_box.add_child(_make_label("Health & Harvest", Color(0.84, 0.78, 0.66), 12))

	var outbreaks: Array = c.get("outbreaks", [])
	for o_v in outbreaks:
		if o_v is Dictionary:
			var o_lbl := _make_label(str((o_v as Dictionary).get("text", "")), Color(0.98, 0.50, 0.44), 12)
			o_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			prov_content_box.add_child(o_lbl)
	var plague_dead: String = str(c.get("plagueDeathsText", ""))
	if not plague_dead.is_empty():
		_add_kv_row(prov_content_box, "Died of sickness (month)", plague_dead)
	if outbreaks.is_empty():
		_add_kv_row(prov_content_box, "Sickness", "None")
	var immunities: Array = c.get("immunities", [])
	if not immunities.is_empty():
		var parts: PackedStringArray = PackedStringArray()
		for i_v in immunities:
			if i_v is Dictionary:
				parts.append("%s %s" % [str((i_v as Dictionary).get("name", "")), str((i_v as Dictionary).get("text", ""))])
		_add_kv_row(prov_content_box, "Immune", ", ".join(parts))

	var famine: float = float(c.get("famine", 0.0))
	_add_kv_row(prov_content_box, "Harvest / Crop", "%s · %s" % [str(c.get("harvestText", "100%")), str(c.get("cropText", "100%"))])
	if famine >= 0.05:
		var fam_txt: String = "Famine %s" % str(c.get("famineText", "0%"))
		var starved: String = str(c.get("famineDeathsText", ""))
		if not starved.is_empty():
			fam_txt += " · %s starved this month" % starved
		prov_content_box.add_child(_make_label(fam_txt, Color(0.96, 0.72, 0.36), 12))
	var quake_txt: String = str(c.get("lastQuakeText", ""))
	if not quake_txt.is_empty():
		var q_lbl := _make_label("Last earthquake: %s" % quake_txt, Color(0.80, 0.70, 0.56), 11)
		q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prov_content_box.add_child(q_lbl)

	if mine:
		var measures := HBoxContainer.new()
		measures.add_theme_constant_override("separation", 6)
		prov_content_box.add_child(measures)
		if bool(c.get("isPort", false)):
			var q_on: bool = bool(c.get("isQuarantined", false))
			var q_btn := Button.new()
			q_btn.text = "Lift Quarantine" if q_on else "Port Quarantine (%s/mo)" % str(c.get("quarantineCostText", "1"))
			q_btn.disabled = not bool(c.get("canQuarantine", false))
			q_btn.tooltip_text = "Ships wait offshore: far less plague arrives or leaves by sea, but the province pays 15% less tax and its market's sea trade is halved. %s" % str(c.get("quarantineRefusal", ""))
			q_btn.pressed.connect(func() -> void:
				_call_bridge("setProvinceQuarantine", [p_idx, not q_on], {})
				_after_calamity_action()
			)
			measures.add_child(q_btn)
		var c_on: bool = bool(c.get("isCordoned", false))
		var c_btn := Button.new()
		c_btn.text = "Lift Cordon" if c_on else "Cordon (%s/mo)" % str(c.get("cordonCostText", "1"))
		c_btn.disabled = not bool(c.get("canCordon", false))
		c_btn.tooltip_text = "Guards close the roads: far less plague crosses by land and nobody flees, but the province pays 10% less tax and armies march half as slow again. %s" % str(c.get("cordonRefusal", ""))
		c_btn.pressed.connect(func() -> void:
			_call_bridge("setProvinceCordon", [p_idx, not c_on], {})
			_after_calamity_action()
		)
		measures.add_child(c_btn)

	prov_content_box.add_child(HSeparator.new())
	var unrest: float = float(c.get("unrest", 0.0))
	var u_col: Color = Color(0.96, 0.42, 0.38) if unrest >= 40.0 else (Color(0.96, 0.78, 0.40) if unrest >= 20.0 else Color(0.84, 0.78, 0.66))
	var u_lbl := _make_label("Unrest %s / 100" % str(c.get("unrestText", "0")), u_col, 12)
	bind_breakdown(u_lbl, func() -> Variant: return _call_bridge("getUnrestBreakdown", [p_idx], {}), "Province Unrest Breakdown")
	prov_content_box.add_child(u_lbl)
	var causes: Array = c.get("unrestCauses", [])
	for u_v in causes:
		if u_v is Dictionary:
			var u_row := _add_kv_row(prov_content_box, "  " + str((u_v as Dictionary).get("name", "")), str((u_v as Dictionary).get("text", "")))
			bind_breakdown(u_row, func() -> Variant: return _call_bridge("getUnrestBreakdown", [p_idx], {}), "Province Unrest Breakdown")
	var rebels: Array = c.get("rebels", [])
	for r_v in rebels:
		if r_v is Dictionary:
			var r_btn := Button.new()
			r_btn.text = str((r_v as Dictionary).get("text", "Rebels"))
			r_btn.flat = true
			r_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			r_btn.add_theme_color_override("font_color", GezStyle.ink(Color(0.98, 0.62, 0.50)))
			r_btn.tooltip_text = "Open the Unrest & Rebels window"
			r_btn.pressed.connect(Callable(main, "_open_rebels_window"))
			prov_content_box.add_child(r_btn)

func _after_calamity_action() -> void:
	refresh_province()
	main._refresh_top_bar()
	main._refresh_styles_and_country_labels()
	main._refresh_faith_overlay()

func _append_province_tech_section(p_idx: int) -> void:
	if p_idx < 0:
		return
	var t_v: Variant = _call_bridge("getProvinceTechDetails", [p_idx], {})
	var t: Dictionary = t_v if t_v is Dictionary else {}
	if not bool(t.get("hasProvince", false)):
		return
	var insts: Array = t.get("institutions", [])
	if insts.is_empty():
		return
	prov_content_box.add_child(HSeparator.new())
	prov_content_box.add_child(_make_label("Institutions", Color(0.95, 0.88, 0.65), 13))
	for i_v in insts:
		if not (i_v is Dictionary):
			continue
		var inst: Dictionary = i_v
		var pct_txt: String = str(inst.get("percentText", ""))
		if bool(inst.get("isOrigin", false)):
			pct_txt += " (Origin)"
		elif bool(inst.get("ownerEmbraced", false)):
			pct_txt += " (Embraced)"
		_add_kv_row(prov_content_box, str(inst.get("name", "")), pct_txt)

func _append_province_docks_section(d: Dictionary) -> void:
	var has_docks: bool = bool(d.get("hasDocks", false))
	var blockaded: bool = bool(d.get("isPortBlockaded", false))
	var ship_jobs_v: Variant = d.get("shipConstructions", [])
	var ship_jobs: Array = ship_jobs_v if ship_jobs_v is Array else []
	var stationed_v: Variant = d.get("stationedFleets", [])
	var stationed: Array = stationed_v if stationed_v is Array else []
	if not has_docks and not blockaded and ship_jobs.is_empty() and stationed.is_empty():
		return

	prov_content_box.add_child(HSeparator.new())
	if blockaded:
		prov_content_box.add_child(_make_label("PORT BLOCKADED BY ENEMY FLEET", Color(0.96, 0.42, 0.38), 12))

	for sf_v in stationed:
		if sf_v is Dictionary:
			var sf: Dictionary = sf_v
			var fid: int = int(sf.get("fleetId", -1))
			var f_btn := Button.new()
			f_btn.text = "Fleet: %s (%s · %d ships)" % [str(sf.get("name", "Fleet")), str(sf.get("ownerTag", "")), int(sf.get("ships", 0))]
			f_btn.pressed.connect(func() -> void:
				_call_bridge("clearSelectedArmy", [])
				_call_bridge("selectFleet", [fid], false)
				main._after_fleet_action()
			)
			prov_content_box.add_child(f_btn)

	if not has_docks:
		return

	var dock_cap: int = int(d.get("dockCapacity", 1))
	_add_kv_row(prov_content_box, "Docks", "Level %d (Shipyard Ready)" % dock_cap)
	for job_v in ship_jobs:
		if job_v is Dictionary:
			var job: Dictionary = job_v
			_add_kv_row(prov_content_box, "Building " + str(job.get("shipName", "Ship")), "%d / %d mo" % [int(job.get("monthsLeft", 0)), int(job.get("monthsTotal", 0))])

	var buildable_v: Variant = d.get("buildableShips", [])
	var buildable: Array = buildable_v if buildable_v is Array else []
	if not buildable.is_empty():
		var ship_toggle := Button.new()
		ship_toggle.text = "Hide Shipyard" if prov_show_shipbuild else "Build Ships..."
		ship_toggle.pressed.connect(func() -> void:
			prov_show_shipbuild = not prov_show_shipbuild
			refresh_province()
		)
		prov_content_box.add_child(ship_toggle)
		if prov_show_shipbuild:
			for sh_v in buildable:
				if not (sh_v is Dictionary):
					continue
				var sh: Dictionary = sh_v
				var st_idx: int = int(sh.get("shipTypeIndex", -1))
				var can_b: bool = bool(sh.get("canBuild", false))
				var sbtn := Button.new()
				sbtn.text = "%s (%s) · %dd · %d sailors · %dmo" % [
					str(sh.get("name", "Ship")),
					str(sh.get("shipClass", "")),
					int(sh.get("cost", 0)),
					int(sh.get("sailorsCost", 0)),
					int(sh.get("months", 0))
				]
				sbtn.tooltip_text = ("Goods: " + str(sh.get("materialsText", "None"))) if can_b else str(sh.get("refusalReason", "Cannot build"))
				sbtn.disabled = not can_b
				sbtn.pressed.connect(func() -> void:
					if bool(_call_bridge("buildShipInSelectedProvince", [st_idx], false)):
						main.play_sfx("building_finished")
						main._after_fleet_action()
				)
				prov_content_box.add_child(sbtn)

func refresh_sea() -> void:
	var d: Dictionary = _call_bridge("getSelectedSeaDetails", [], {})
	if not bool(d.get("hasSelection", false)):
		sea_panel.visible = false
		return
	province_panel.visible = false
	sea_panel.visible = true
	var title: String = str(d.get("name", "Sea Zone"))
	if bool(d.get("isInland", false)):
		title += " (Inland)"
	sea_title_label.text = title
	var extra_lines: PackedStringArray = []
	var battle_txt: String = str(d.get("activeBattleText", ""))
	if not battle_txt.is_empty():
		extra_lines.append("NAVAL BATTLE: " + battle_txt)
	var fleets_v: Variant = d.get("fleets", [])
	var fleets_arr: Array = fleets_v if fleets_v is Array else []
	if not fleets_arr.is_empty():
		var fnames: PackedStringArray = []
		for fv in fleets_arr:
			if fv is Dictionary:
				var fdict: Dictionary = fv
				fnames.append("%s %s (%d)" % [str(fdict.get("ownerTag", "")), str(fdict.get("name", "")), int(fdict.get("ships", 0))])
		extra_lines.append("Fleets: " + ", ".join(fnames))
	var nb_str: String = str(d.get("neighborsText", ""))
	if not extra_lines.is_empty():
		sea_neighbors_label.text = nb_str + "\n" + "\n".join(extra_lines)
	else:
		sea_neighbors_label.text = nb_str
	sea_coast_title_label.text = "Coast (%d provinces)" % int(d.get("coastCount", 0))
	sea_coast_label.text = str(d.get("coastText", ""))
