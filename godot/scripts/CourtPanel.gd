extends Control

var main_view: Control = null

var court_panel: PanelContainer
var header_arms: TextureRect
var person_box: VBoxContainer
var family_tree_box: VBoxContainer
var council_box: VBoxContainer
var vassals_box: VBoxContainer
var marriages_box: VBoxContainer
var chronicle_box: VBoxContainer

var marrying_char_index: int = -1
var selected_grant_prov_index: int = -1
var _last_court_sig: String = ""

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_court_panel()

func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if main_view == null:
		return fallback
	return main_view.call("_call_bridge", method_name, args, fallback)

func _get_arms(tag: String, r: int, g: int, b: int) -> Texture2D:
	if main_view == null:
		return null
	return main_view.call("_get_country_arms_texture", tag, r, g, b)

func _make_label(txt: String, col: Color, fsize: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", GezStyle.ink(col))
	lbl.add_theme_font_size_override("font_size", fsize)
	return lbl

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _build_court_panel() -> void:
	court_panel = PanelContainer.new()
	court_panel.name = "CourtPanel"
	court_panel.visible = false
	court_panel.custom_minimum_size = Vector2(430.0, 0.0)
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBox = main_view.call("_make_panel_style")
		court_panel.add_theme_stylebox_override("panel", st)
	add_child(court_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	court_panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)

	header_arms = TextureRect.new()
	header_arms.custom_minimum_size = Vector2(28.0, 22.0)
	header_arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(header_arms)

	var title := _make_label("Court", Color(0.97, 0.90, 0.68), 18)
	GezStyle.as_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := GezStyle.medallion_button("close", 30.0)
	close_btn.tooltip_text = "Close Court window"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(404.0, 560.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)

	person_box = VBoxContainer.new()
	person_box.add_theme_constant_override("separation", 4)
	body.add_child(person_box)

	body.add_child(HSeparator.new())
	family_tree_box = VBoxContainer.new()
	family_tree_box.add_theme_constant_override("separation", 3)
	body.add_child(family_tree_box)

	body.add_child(HSeparator.new())
	council_box = VBoxContainer.new()
	council_box.add_theme_constant_override("separation", 4)
	body.add_child(council_box)

	body.add_child(HSeparator.new())
	vassals_box = VBoxContainer.new()
	vassals_box.add_theme_constant_override("separation", 4)
	body.add_child(vassals_box)

	body.add_child(HSeparator.new())
	marriages_box = VBoxContainer.new()
	marriages_box.add_theme_constant_override("separation", 4)
	body.add_child(marriages_box)

	body.add_child(HSeparator.new())
	chronicle_box = VBoxContainer.new()
	chronicle_box.add_theme_constant_override("separation", 3)
	body.add_child(chronicle_box)

	court_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	court_panel.offset_top = 60.0

func is_open() -> bool:
	return court_panel != null and court_panel.visible

func open_window(character_index: int = -2) -> void:
	if court_panel == null:
		return
	if character_index >= -1:
		_call_bridge("setViewedCharacter", [character_index], false)
	court_panel.visible = true
	refresh()

func close_window() -> void:
	if court_panel != null:
		court_panel.visible = false

func toggle_window() -> void:
	if is_open():
		close_window()
	else:
		open_window()

func refresh_if_open() -> void:
	if is_open():
		refresh()

func _after_court_change() -> void:
	if main_view != null and main_view.has_method("_after_court_or_gov_action"):
		main_view.call("_after_court_or_gov_action")
	else:
		refresh()

func _view_character(char_idx: int) -> void:
	_call_bridge("setViewedCharacter", [char_idx], false)
	refresh()

func refresh() -> void:
	if court_panel == null:
		return
	var d_var: Variant = _call_bridge("getCourtDetails", [marrying_char_index], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("valid", false)):
		_last_court_sig = ""
		_clear_children(person_box)
		person_box.add_child(_make_label("No active player country.", Color(0.80, 0.75, 0.66), 13))
		_clear_children(family_tree_box)
		_clear_children(council_box)
		_clear_children(vassals_box)
		_clear_children(marriages_box)
		_clear_children(chronicle_box)
		return

	var sig := "%d|%d|%s" % [marrying_char_index, selected_grant_prov_index, var_to_str(d)]
	if sig == _last_court_sig and person_box.get_child_count() > 0:
		return
	_last_court_sig = sig

	var p_tag: String = str(d.get("playerTag", ""))
	var pr: int = int(d.get("playerColorR", 180))
	var pg: int = int(d.get("playerColorG", 140))
	var pb: int = int(d.get("playerColorB", 80))
	header_arms.texture = _get_arms(p_tag, pr, pg, pb)
	marrying_char_index = int(d.get("selectedMarryingIndex", -1))

	_refresh_person(d)
	_refresh_family_tree(d)
	_refresh_council(d)
	_refresh_vassals(d)
	_refresh_marriages(d)
	_refresh_chronicle(d)

func _refresh_person(d: Dictionary) -> void:
	_clear_children(person_box)
	var ch_var: Variant = d.get("character", {})
	var ch: Dictionary = ch_var if ch_var is Dictionary else {}
	if not bool(ch.get("valid", false)):
		person_box.add_child(_make_label("No ruler.", Color(0.80, 0.75, 0.66), 13))
		return

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	person_box.add_child(top)

	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(40.0, 40.0)
	var av_style := StyleBoxFlat.new()
	av_style.bg_color = Color(0.45, 0.25, 0.30, 0.9) if bool(ch.get("female", false)) else Color(0.28, 0.34, 0.44, 0.9)
	av_style.set_corner_radius_all(20)
	avatar.add_theme_stylebox_override("panel", av_style)
	var av_lbl := _make_label(str(ch.get("initial", "?")), Color(0.96, 0.92, 0.84), 18)
	av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(av_lbl)
	top.add_child(avatar)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	top.add_child(info)

	var name_lbl := _make_label(str(ch.get("fullName", "")), Color(0.97, 0.90, 0.68), 15)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name_lbl)

	var sub_lbl := _make_label(str(ch.get("subtitle", "")), Color(0.82, 0.77, 0.68), 12)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(sub_lbl)

	if bool(ch.get("invented", false)):
		info.add_child(_make_label("Invented (history does not record them)", Color(0.68, 0.64, 0.56), 11))
	else:
		var note_txt: String = str(ch.get("note", ""))
		if not note_txt.is_empty():
			var n_lbl := _make_label(note_txt, Color(0.72, 0.68, 0.60), 11)
			n_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(n_lbl)

	# Skills row
	var skills_row := HBoxContainer.new()
	skills_row.add_theme_constant_override("separation", 10)
	person_box.add_child(skills_row)
	var skills_var: Variant = ch.get("skills", [])
	var skills_arr: Array = skills_var if skills_var is Array else []
	for sk in skills_arr:
		if sk is Dictionary:
			var sk_dict: Dictionary = sk
			var col_box := VBoxContainer.new()
			var sk_name := str(sk_dict.get("name", "Skill"))
			var sk_val := int(sk_dict.get("value", 0))
			if main_view != null:
				main_view.call("bind_tip", col_box, "%s (%d)" % [sk_name, sk_val], "Character attribute affecting council bonuses, military leadership or research.")
			else:
				col_box.tooltip_text = sk_name
			var v_lbl := _make_label(str(sk_val), Color(0.96, 0.92, 0.84), 14)
			v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col_box.add_child(v_lbl)
			var k_lbl := _make_label(str(sk_dict.get("shortName", "")), Color(0.72, 0.68, 0.60), 10)
			k_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col_box.add_child(k_lbl)
			skills_row.add_child(col_box)

	# Traits
	var traits_var: Variant = ch.get("traits", [])
	var traits_arr: Array = traits_var if traits_var is Array else []
	if not traits_arr.is_empty():
		var t_flow := HFlowContainer.new()
		t_flow.add_theme_constant_override("h_separation", 6)
		t_flow.add_theme_constant_override("v_separation", 3)
		person_box.add_child(t_flow)
		for t in traits_arr:
			# Phase 20: each trait is a wax seal stamped with its initial.
			var badge := HBoxContainer.new()
			badge.add_theme_constant_override("separation", 3)
			var seal := TextureRect.new()
			seal.texture = GezStyle.trait_seal(str(t).to_lower().replace(" ", "_"))
			seal.custom_minimum_size = Vector2(22.0, 22.0)
			seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge.add_child(seal)
			badge.add_child(_make_label(str(t), Color(0.92, 0.86, 0.72), 13))
			t_flow.add_child(badge)

	if bool(ch.get("isRuler", false)):
		var succ_row := HBoxContainer.new()
		succ_row.add_theme_constant_override("separation", 6)
		person_box.add_child(succ_row)
		var succ_lbl := _make_label(str(ch.get("successionText", "")), Color(0.88, 0.84, 0.74), 12)
		succ_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		succ_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		succ_row.add_child(succ_lbl)
		var heir_idx: int = int(ch.get("heirIndex", -1))
		if heir_idx >= 0:
			var h_btn := Button.new()
			h_btn.text = "Inspect Heir"
			h_btn.pressed.connect(func() -> void: _view_character(heir_idx))
			succ_row.add_child(h_btn)

	_add_family_links("Spouse", ch.get("spouses", []))
	_add_family_links("Children", ch.get("children", []))
	_add_family_links("Siblings", ch.get("siblings", []))
	_add_family_links("Parents", ch.get("parents", []))

	var holdings_txt: String = str(ch.get("holdingsText", ""))
	if not holdings_txt.is_empty():
		var hl := _make_label(holdings_txt, Color(0.86, 0.82, 0.72), 12)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		person_box.add_child(hl)

	if bool(ch.get("illegitimate", false)):
		person_box.add_child(_make_label("Born outside marriage", Color(0.75, 0.68, 0.58), 11))

	if not bool(d.get("showingRuler", true)):
		var back_btn := Button.new()
		back_btn.text = "Back to your ruler"
		back_btn.pressed.connect(func() -> void: _view_character(-1))
		person_box.add_child(back_btn)

func _add_family_links(label_txt: String, items_var: Variant) -> void:
	var items: Array = items_var if items_var is Array else []
	if items.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	person_box.add_child(row)

	var lbl := _make_label(label_txt, Color(0.82, 0.76, 0.65), 12)
	lbl.custom_minimum_size = Vector2(58.0, 0.0)
	row.add_child(lbl)

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 2)
	row.add_child(flow)

	for item in items:
		if item is Dictionary:
			var it: Dictionary = item
			var idx: int = int(it.get("characterIndex", -1))
			var btn := Button.new()
			btn.text = str(it.get("label", ""))
			btn.flat = true
			btn.add_theme_color_override("font_color", GezStyle.ink(Color(0.95, 0.86, 0.62)))
			btn.add_theme_font_size_override("font_size", 12)
			btn.pressed.connect(func() -> void: _view_character(idx))
			flow.add_child(btn)

func _refresh_family_tree(d: Dictionary) -> void:
	_clear_children(family_tree_box)
	family_tree_box.add_child(_make_label("Ruling Family", Color(0.96, 0.90, 0.72), 14))
	var tree_var: Variant = d.get("familyTree", [])
	var tree: Array = tree_var if tree_var is Array else []
	if tree.is_empty():
		family_tree_box.add_child(_make_label("No ruling family recorded.", Color(0.75, 0.70, 0.62), 12))
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 3)
	family_tree_box.add_child(flow)
	for item in tree:
		if item is Dictionary:
			var node: Dictionary = item
			var idx: int = int(node.get("characterIndex", -1))
			var role: String = str(node.get("role", ""))
			var full_name: String = str(node.get("fullName", ""))
			var age_txt: String = str(node.get("ageText", ""))
			var btn := Button.new()
			btn.text = "%s: %s (%s)" % [role, full_name, age_txt]
			if bool(node.get("isViewed", false)):
				btn.modulate = Color(1.0, 0.88, 0.45)
			btn.pressed.connect(func() -> void: _view_character(idx))
			flow.add_child(btn)

func _refresh_council(d: Dictionary) -> void:
	_clear_children(council_box)
	var hdr := HBoxContainer.new()
	council_box.add_child(hdr)
	var title := _make_label("Council", Color(0.96, 0.90, 0.72), 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	hdr.add_child(_make_label(str(d.get("councilSummary", "")), Color(0.76, 0.72, 0.64), 11))

	var seats_var: Variant = d.get("councilSeats", [])
	var seats: Array = seats_var if seats_var is Array else []
	for s_item in seats:
		if s_item is Dictionary:
			var s: Dictionary = s_item
			var seat_idx: int = int(s.get("seatIndex", 0))
			var holder_idx: int = int(s.get("holderIndex", -1))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.tooltip_text = str(s.get("effectText", ""))
			council_box.add_child(row)

			var left := VBoxContainer.new()
			left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			left.add_theme_constant_override("separation", 0)
			row.add_child(left)
			left.add_child(_make_label(str(s.get("seatName", "")), Color(0.90, 0.85, 0.74), 12))
			if holder_idx >= 0:
				var h_btn := Button.new()
				h_btn.text = str(s.get("holderName", ""))
				h_btn.flat = true
				h_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				h_btn.add_theme_color_override("font_color", GezStyle.ink(Color(0.96, 0.88, 0.65)))
				h_btn.add_theme_font_size_override("font_size", 12)
				h_btn.pressed.connect(func() -> void: _view_character(holder_idx))
				left.add_child(h_btn)
			else:
				left.add_child(_make_label("Empty", Color(0.94, 0.44, 0.38), 12))

			if holder_idx >= 0:
				var sk_txt := "%s %d" % [str(s.get("skillName", "")), int(s.get("holderSkill", 0))]
				row.add_child(_make_label(sk_txt, Color(0.84, 0.80, 0.72), 11))
				if bool(s.get("hasOpinion", false)):
					var op: int = int(s.get("opinion", 0))
					var op_col := Color(0.55, 0.90, 0.58) if op >= 0 else Color(0.95, 0.45, 0.40)
					var op_lbl := _make_label("♥%d" % op if op >= 0 else "✗%d" % (-op), op_col, 11)
					op_lbl.tooltip_text = "Opinion of your ruler"
					row.add_child(op_lbl)

			var menu := MenuButton.new()
			menu.text = "Change"
			menu.flat = false
			var popup := menu.get_popup()
			var cands_var: Variant = s.get("candidates", [])
			var cands: Array = cands_var if cands_var is Array else []
			var id_to_char: Dictionary = {}
			var item_id := 1
			for c in cands:
				if c is Dictionary:
					var c_dict: Dictionary = c
					popup.add_item(str(c_dict.get("label", "")), item_id)
					id_to_char[item_id] = int(c_dict.get("characterIndex", -1))
					item_id += 1
			popup.add_separator()
			var newcomer_id := 10001
			popup.add_item("Invite someone new to court", newcomer_id)
			var empty_id := 10002
			if holder_idx >= 0:
				popup.add_item("Leave empty", empty_id)
			popup.id_pressed.connect(func(pid: int) -> void:
				if pid == newcomer_id:
					_call_bridge("appointCouncilNewcomer", [seat_idx], false)
				elif pid == empty_id:
					_call_bridge("appointCouncilSeat", [seat_idx, -1], false)
				elif id_to_char.has(pid):
					_call_bridge("appointCouncilSeat", [seat_idx, int(id_to_char[pid])], false)
				_after_court_change()
			)
			row.add_child(menu)

func _refresh_vassals(d: Dictionary) -> void:
	_clear_children(vassals_box)
	var hdr := HBoxContainer.new()
	vassals_box.add_child(hdr)
	var title := _make_label("Vassals", Color(0.96, 0.90, 0.72), 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	hdr.add_child(_make_label(str(d.get("vassalsSummary", "")), Color(0.76, 0.72, 0.64), 11))

	var v_var: Variant = d.get("vassals", [])
	var v_list: Array = v_var if v_var is Array else []
	if v_list.is_empty():
		var empty_lbl := _make_label("No great vassals: all land is the crown's.", Color(0.75, 0.70, 0.62), 12)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vassals_box.add_child(empty_lbl)
	else:
		for v_item in v_list:
			if v_item is Dictionary:
				var v: Dictionary = v_item
				var v_idx: int = int(v.get("characterIndex", -1))
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				vassals_box.add_child(row)

				var left := VBoxContainer.new()
				left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				left.add_theme_constant_override("separation", 0)
				row.add_child(left)

				var v_btn := Button.new()
				v_btn.text = str(v.get("name", ""))
				v_btn.flat = true
				v_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				v_btn.add_theme_color_override("font_color", GezStyle.ink(Color(0.96, 0.88, 0.65)))
				v_btn.add_theme_font_size_override("font_size", 12)
				v_btn.pressed.connect(func() -> void: _view_character(v_idx))
				left.add_child(v_btn)

				var hl := _make_label(str(v.get("holdingsText", "")), Color(0.78, 0.73, 0.65), 11)
				hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				left.add_child(hl)

				var is_loyal: bool = bool(v.get("isLoyal", true))
				var st_col := Color(0.78, 0.74, 0.66) if is_loyal else Color(0.95, 0.45, 0.40)
				row.add_child(_make_label(str(v.get("stance", "")), st_col, 11))

				var op: int = int(v.get("opinion", 0))
				var op_col := Color(0.55, 0.90, 0.58) if op >= 0 else Color(0.95, 0.45, 0.40)
				row.add_child(_make_label("♥%d" % op if op >= 0 else "✗%d" % (-op), op_col, 11))

				var holdings_var: Variant = v.get("holdings", [])
				var holdings: Array = holdings_var if holdings_var is Array else []
				if not holdings.is_empty():
					var rev_menu := MenuButton.new()
					rev_menu.text = "Revoke"
					rev_menu.flat = false
					rev_menu.tooltip_text = "Take a held province back: all vassals will trust you less"
					var rev_popup := rev_menu.get_popup()
					var id_to_prov: Dictionary = {}
					for h_idx in range(holdings.size()):
						var h_item: Dictionary = holdings[h_idx]
						var p_idx: int = int(h_item.get("provinceIndex", -1))
						rev_popup.add_item("Revoke " + str(h_item.get("provinceName", "")), h_idx)
						id_to_prov[h_idx] = p_idx
					rev_popup.id_pressed.connect(func(pid: int) -> void:
						if id_to_prov.has(pid):
							_call_bridge("revokeProvinceHolder", [int(id_to_prov[pid])], false)
							_after_court_change()
					)
					row.add_child(rev_menu)

	# Grant crown land from Court
	var unheld_var: Variant = d.get("unheldProvinces", [])
	var unheld: Array = unheld_var if unheld_var is Array else []
	var grant_cands_var: Variant = d.get("grantCandidates", [])
	var grant_cands: Array = grant_cands_var if grant_cands_var is Array else []
	if not unheld.is_empty() and not grant_cands.is_empty():
		var grant_row := HBoxContainer.new()
		grant_row.add_theme_constant_override("separation", 6)
		vassals_box.add_child(grant_row)
		grant_row.add_child(_make_label("Grant land:", Color(0.82, 0.78, 0.70), 12))

		var prov_opt := OptionButton.new()
		prov_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sel_idx := 0
		for i in range(unheld.size()):
			var up: Dictionary = unheld[i]
			var pid: int = int(up.get("provinceIndex", -1))
			prov_opt.add_item(str(up.get("name", "")), pid)
			if pid == selected_grant_prov_index:
				sel_idx = i
		prov_opt.select(sel_idx)
		selected_grant_prov_index = prov_opt.get_item_id(sel_idx)
		prov_opt.item_selected.connect(func(idx: int) -> void:
			selected_grant_prov_index = prov_opt.get_item_id(idx)
		)
		grant_row.add_child(prov_opt)

		var cand_menu := MenuButton.new()
		cand_menu.text = "Grant to..."
		cand_menu.flat = false
		var cand_popup := cand_menu.get_popup()
		var id_to_c: Dictionary = {}
		for i in range(grant_cands.size()):
			var c_item: Dictionary = grant_cands[i]
			cand_popup.add_item(str(c_item.get("label", "")), i)
			id_to_c[i] = int(c_item.get("characterIndex", -1))
		cand_popup.id_pressed.connect(func(pid: int) -> void:
			if id_to_c.has(pid) and selected_grant_prov_index >= 0:
				_call_bridge("grantProvinceToCharacter", [selected_grant_prov_index, int(id_to_c[pid])], false)
				_after_court_change()
		)
		grant_row.add_child(cand_menu)

func _refresh_marriages(d: Dictionary) -> void:
	_clear_children(marriages_box)
	marriages_box.add_child(_make_label("Marriages", Color(0.96, 0.90, 0.72), 14))

	var fam_var: Variant = d.get("marriageableFamily", [])
	var fam: Array = fam_var if fam_var is Array else []
	if fam.is_empty():
		marriages_box.add_child(_make_label("No one in the ruling family is free to marry.", Color(0.75, 0.70, 0.62), 12))
		return

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	marriages_box.add_child(flow)

	for item in fam:
		if item is Dictionary:
			var f: Dictionary = item
			var f_idx: int = int(f.get("characterIndex", -1))
			var btn := Button.new()
			btn.text = str(f.get("label", ""))
			if f_idx == marrying_char_index:
				btn.modulate = Color(1.0, 0.88, 0.45)
			btn.pressed.connect(func() -> void:
				marrying_char_index = -1 if marrying_char_index == f_idx else f_idx
				refresh()
			)
			flow.add_child(btn)

	if marrying_char_index >= 0:
		var cands_var: Variant = d.get("marriageCandidates", [])
		var cands: Array = cands_var if cands_var is Array else []
		if cands.is_empty():
			marriages_box.add_child(_make_label("No suitable match abroad right now.", Color(0.75, 0.70, 0.62), 12))
		else:
			for c_item in cands:
				if c_item is Dictionary:
					var m: Dictionary = c_item
					var m_idx: int = int(m.get("characterIndex", -1))
					var row := HBoxContainer.new()
					row.add_theme_constant_override("separation", 6)
					marriages_box.add_child(row)

					var arms := TextureRect.new()
					arms.custom_minimum_size = Vector2(22.0, 16.0)
					arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					arms.texture = _get_arms(
						str(m.get("courtTag", "")),
						int(m.get("colorR", 180)),
						int(m.get("colorG", 140)),
						int(m.get("colorB", 80))
					)
					row.add_child(arms)

					var info := VBoxContainer.new()
					info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					info.add_theme_constant_override("separation", 0)
					row.add_child(info)

					var m_btn := Button.new()
					m_btn.text = str(m.get("fullName", ""))
					m_btn.flat = true
					m_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
					m_btn.add_theme_color_override("font_color", GezStyle.ink(Color(0.96, 0.88, 0.65)))
					m_btn.add_theme_font_size_override("font_size", 12)
					m_btn.pressed.connect(func() -> void: _view_character(m_idx))
					info.add_child(m_btn)

					var sub_txt := "%d · %s%s" % [int(m.get("age", 0)), str(m.get("courtName", "")), str(m.get("roleText", ""))]
					info.add_child(_make_label(sub_txt, Color(0.76, 0.72, 0.64), 11))

					var prop_btn := Button.new()
					prop_btn.text = "Propose"
					var fam_idx := marrying_char_index
					prop_btn.pressed.connect(func() -> void:
						_call_bridge("proposeMarriage", [fam_idx, m_idx], false)
						marrying_char_index = -1
						_after_court_change()
					)
					row.add_child(prop_btn)

func _refresh_chronicle(d: Dictionary) -> void:
	_clear_children(chronicle_box)
	chronicle_box.add_child(_make_label("Chronicle", Color(0.96, 0.90, 0.72), 14))
	var entries_var: Variant = d.get("chronicle", [])
	var entries: Array = entries_var if entries_var is Array else []
	if entries.is_empty():
		chronicle_box.add_child(_make_label("Nothing of note yet.", Color(0.75, 0.70, 0.62), 12))
		return
	for e in entries:
		if e is Dictionary:
			var lbl := _make_label(str((e as Dictionary).get("text", "")), Color(0.86, 0.82, 0.74), 11)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			chronicle_box.add_child(lbl)
