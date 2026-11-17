extends Control

var main: Node = null
var wars_panel: PanelContainer
var peace_modal: PanelContainer
var show_all_wars: bool = false
var toggle_scope_btn: Button
var content_box: VBoxContainer
var feedback_label: Label
var peace_box: VBoxContainer

# Peace modal state
var active_peace_war_id: String = ""
var selected_provinces: Dictionary = {} # prov_idx -> true
var indemnity_amount: float = 0.0
var include_reparations: bool = false
var subject_mode: int = 0 # 0=none, 1=vassal, 2=tributary
var selected_releases: Dictionary = {} # country_idx -> true
var selected_annuls: Dictionary = {} # country_idx -> true
var peace_feedback: String = ""
var _last_wars_sig: String = ""
var _last_peace_sig: String = ""

func setup(p_main: Node) -> void:
	main = p_main
	name = "WarsAndPeaceLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_wars_panel()
	_build_peace_modal()

func _build_wars_panel() -> void:
	wars_panel = PanelContainer.new()
	wars_panel.name = "WarsOverviewWindow"
	wars_panel.visible = false
	wars_panel.custom_minimum_size = Vector2(490.0, 520.0)
	wars_panel.position = Vector2(12.0, 92.0)
	wars_panel.add_theme_stylebox_override("panel", main.call("_make_panel_style"))
	add_child(wars_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	wars_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := main.call("_make_label", "Wars & Peace", Color(0.97, 0.90, 0.68), 18) as Label
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	toggle_scope_btn = Button.new()
	toggle_scope_btn.text = "My Wars"
	toggle_scope_btn.pressed.connect(func() -> void:
		show_all_wars = not show_all_wars
		toggle_scope_btn.text = "All World Wars" if show_all_wars else "My Wars"
		refresh()
	)
	header.add_child(toggle_scope_btn)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	feedback_label = main.call("_make_label", "", Color(0.96, 0.78, 0.42), 12)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.visible = false
	vbox.add_child(feedback_label)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(466.0, 460.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 8)
	scroll.add_child(content_box)

func _build_peace_modal() -> void:
	peace_modal = PanelContainer.new()
	peace_modal.name = "PeaceNegotiationModal"
	peace_modal.visible = false
	peace_modal.custom_minimum_size = Vector2(480.0, 560.0)
	peace_modal.add_theme_stylebox_override("panel", main.call("_make_panel_style"))
	add_child(peace_modal)
	peace_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	peace_box = VBoxContainer.new()
	peace_box.add_theme_constant_override("separation", 6)
	peace_modal.add_child(peace_box)

func is_open() -> bool:
	return wars_panel.visible or peace_modal.visible

func toggle_window() -> void:
	wars_panel.visible = not wars_panel.visible
	if wars_panel.visible:
		feedback_label.visible = false
		refresh()

func close_window() -> void:
	wars_panel.visible = false
	peace_modal.visible = false
	active_peace_war_id = ""

func open_wars_window() -> void:
	wars_panel.visible = true
	feedback_label.visible = false
	refresh()

func open_peace_for_war(war_id: String) -> void:
	if war_id.is_empty():
		open_wars_window()
		return
	active_peace_war_id = war_id
	selected_provinces.clear()
	indemnity_amount = 0.0
	include_reparations = false
	subject_mode = 0
	selected_releases.clear()
	selected_annuls.clear()
	peace_feedback = ""
	peace_modal.visible = true
	_refresh_peace_modal()

func refresh_if_open() -> void:
	if wars_panel.visible:
		refresh()
	if peace_modal.visible and not active_peace_war_id.is_empty():
		_refresh_peace_modal()

func refresh() -> void:
	if main == null or not wars_panel.visible:
		return
	var d_var: Variant = main.call("_call_bridge", "getWarsDetails", [show_all_wars], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("hasPlayer", false)):
		return

	var sig := "%s|%s" % [str(show_all_wars), var_to_str(d)]
	if sig == _last_wars_sig and content_box.get_child_count() > 0:
		return
	_last_wars_sig = sig

	main.call("_clear_children", content_box)

	# Pending Incoming Peace Offers
	var offers: Array = d.get("pendingOffers", [])
	if not offers.is_empty():
		content_box.add_child(main.call("_make_label", "Incoming Peace Offers (%d)" % offers.size(), Color(0.98, 0.45, 0.40), 14))
		for offer_v in offers:
			if offer_v is Dictionary:
				_add_pending_offer_card(offer_v)
		content_box.add_child(HSeparator.new())

	# Wars list
	var wars: Array = d.get("wars", [])
	if wars.is_empty():
		content_box.add_child(main.call("_make_label", "No active wars.", Color(0.80, 0.75, 0.66), 13))
	else:
		for war_v in wars:
			if war_v is Dictionary:
				_add_war_card(war_v)
				content_box.add_child(HSeparator.new())

func _add_pending_offer_card(offer: Dictionary) -> void:
	var card := PanelContainer.new()
	content_box.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)

	var arms := TextureRect.new()
	arms.custom_minimum_size = Vector2(24.0, 20.0)
	arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arms.texture = main.call(
		"_get_country_arms_texture",
		str(offer.get("senderTag", "")),
		int(offer.get("senderColorR", 196)),
		int(offer.get("senderColorG", 182)),
		int(offer.get("senderColorB", 150))
	)
	top.add_child(arms)

	top.add_child(main.call("_make_label", "%s proposes peace:" % str(offer.get("senderName", "")), Color(0.97, 0.90, 0.68), 14))

	if bool(offer.get("isWhitePeace", true)):
		v.add_child(main.call("_make_label", "  • White Peace", Color(0.88, 0.86, 0.80), 12))
	else:
		for lbl_v in offer.get("demandLabels", []):
			v.add_child(main.call("_make_label", "  • " + str(lbl_v), Color(0.92, 0.85, 0.74), 12))

	var war_id: String = str(offer.get("warID", ""))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	v.add_child(btns)

	var accept_btn := Button.new()
	accept_btn.text = "Accept Peace"
	accept_btn.modulate = Color(0.75, 1.0, 0.75)
	accept_btn.pressed.connect(func() -> void:
		main.call("_call_bridge", "respondToPendingPeaceOffer", [war_id, true], false)
		main.call("_after_diplomacy_action", true)
	)
	btns.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.modulate = Color(1.0, 0.75, 0.75)
	decline_btn.pressed.connect(func() -> void:
		main.call("_call_bridge", "respondToPendingPeaceOffer", [war_id, false], false)
		main.call("_after_diplomacy_action", false)
	)
	btns.add_child(decline_btn)

func _add_war_card(war: Dictionary) -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	content_box.add_child(card)

	var ws: int = int(war.get("warScorePct", 0))
	var battle_ws: int = int(war.get("battlePct", 0))
	var blk_ws: int = int(war.get("blockadePct", 0))
	var occ_ws: int = int(war.get("occupationPct", 0))
	var tick_ws: int = int(war.get("tickingPct", 0))

	var top := HBoxContainer.new()
	card.add_child(top)
	var wname := main.call("_make_label", str(war.get("name", "War")), Color(0.97, 0.90, 0.68), 15) as Label
	wname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(wname)

	var ws_color := Color(0.45, 0.90, 0.45) if ws >= 0 else Color(0.95, 0.42, 0.38)
	var ws_lbl: Control = main.call("_make_label", "%+d%% WS" % ws, ws_color, 14)
	var ws_war_id: String = str(war.get("warID", ""))
	main.call("bind_breakdown", ws_lbl, func() -> Variant: return main.call("_call_bridge", "getWarScoreBreakdown", [ws_war_id], {}), "War Score Breakdown")
	top.add_child(ws_lbl)

	card.add_child(main.call("_make_label", "Since %s · Goal: %s" % [str(war.get("startDate", "")), str(war.get("warGoal", ""))], Color(0.78, 0.74, 0.66), 12))
	var bd_lbl: Control = main.call("_make_label", "Breakdown: Battles %+d%% · Blockades %+d%% · Occupation %+d%% · Ticking Goal %+d%%" % [battle_ws, blk_ws, occ_ws, tick_ws], Color(0.85, 0.82, 0.74), 12)
	main.call("bind_breakdown", bd_lbl, func() -> Variant: return main.call("_call_bridge", "getWarScoreBreakdown", [ws_war_id], {}), "War Score Breakdown")
	card.add_child(bd_lbl)

	var naval_battles_var: Variant = war.get("recentNavalBattles", [])
	var naval_battles: Array = naval_battles_var if naval_battles_var is Array else []
	if not naval_battles.is_empty():
		card.add_child(main.call("_make_label", "Naval Battles (%d):" % naval_battles.size(), Color(0.65, 0.88, 0.98), 12))
		for nb_v in naval_battles:
			if nb_v is Dictionary:
				var nb: Dictionary = nb_v
				var loser: String = str(nb.get("defenderTag", "")) if str(nb.get("winnerTag", "")) == str(nb.get("attackerTag", "")) else str(nb.get("attackerTag", ""))
				var sunk: int = int(nb.get("attackerShipsLost", 0)) + int(nb.get("defenderShipsLost", 0))
				var cap: int = int(nb.get("shipsCaptured", 0))
				var nb_text: String = "%s (%s): %s beat %s · %dd · %d sunk, %d cap" % [
					str(nb.get("seaZoneName", "Sea")),
					str(nb.get("date", "")),
					str(nb.get("winnerTag", "?")),
					loser,
					int(nb.get("days", 1)),
					sunk,
					cap
				]
				card.add_child(main.call("_make_label", "  • " + nb_text, Color(0.80, 0.90, 0.96), 11))

	_add_side_row(card, "Attackers", war.get("attackers", []))
	_add_side_row(card, "Defenders", war.get("defenders", []))

	# Occupied provinces
	var occupied: Array = war.get("occupiedProvinces", [])
	if not occupied.is_empty():
		var occ_row := HBoxContainer.new()
		occ_row.add_theme_constant_override("separation", 4)
		card.add_child(main.call("_make_label", "Occupied (%d):" % occupied.size(), Color(0.92, 0.78, 0.50), 12))
		var occ_wrap := HFlowContainer.new()
		occ_wrap.add_theme_constant_override("h_separation", 4)
		occ_wrap.add_theme_constant_override("v_separation", 4)
		card.add_child(occ_wrap)
		for occ_v in occupied:
			if not (occ_v is Dictionary):
				continue
			var o: Dictionary = occ_v
			var p_idx: int = int(o.get("provinceIndex", -1))
			var btn := Button.new()
			btn.text = "%s (%s→%s)" % [str(o.get("provinceName", "")), str(o.get("ownerTag", "")), str(o.get("occupierTag", ""))]
			btn.pressed.connect(func() -> void:
				main.call("_focus_and_select_province", p_idx)
			)
			occ_wrap.add_child(btn)

	if bool(war.get("playerIsParticipant", false)):
		var war_id: String = str(war.get("warID", ""))
		var enemy_idx: int = int(war.get("primaryEnemyIndex", -1))
		var enemy_tag: String = str(war.get("primaryEnemyTag", ""))

		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", 6)
		card.add_child(action_row)

		var neg_btn := Button.new()
		neg_btn.text = "Negotiate Peace"
		neg_btn.pressed.connect(func() -> void:
			open_peace_for_war(war_id)
		)
		action_row.add_child(neg_btn)

		if enemy_idx >= 0:
			var dip_btn := Button.new()
			dip_btn.text = "Inspect " + enemy_tag
			dip_btn.pressed.connect(func() -> void:
				main.call("_open_diplomacy_with", enemy_idx)
			)
			action_row.add_child(dip_btn)

		var allies: Array = war.get("uncalledAllies", [])
		for a_v in allies:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v
			var ally_idx: int = int(a.get("countryIndex", -1))
			var ally_row := HBoxContainer.new()
			ally_row.add_theme_constant_override("separation", 6)
			card.add_child(ally_row)

			var a_arms := TextureRect.new()
			a_arms.custom_minimum_size = Vector2(20.0, 16.0)
			a_arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			a_arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			a_arms.texture = main.call("_get_country_arms_texture", str(a.get("tag", "")), int(a.get("colorR", 196)), int(a.get("colorG", 182)), int(a.get("colorB", 150)))
			ally_row.add_child(a_arms)

			var will_acc: bool = bool(a.get("willAccept", false))
			var a_lbl := main.call("_make_label", "%s (%s · %+d)" % [str(a.get("name", "")), "Accepts" if will_acc else "Declines", int(a.get("score", 0))], Color(0.86, 0.84, 0.78), 12) as Label
			a_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			a_lbl.tooltip_text = str(a.get("reasonsText", ""))
			ally_row.add_child(a_lbl)

			var call_btn := Button.new()
			call_btn.text = "Call to War"
			call_btn.pressed.connect(func() -> void:
				var c_var: Variant = main.call("_call_bridge", "callAllyToWar", [ally_idx, war_id], {})
				var c_res: Dictionary = c_var if c_var is Dictionary else {}
				feedback_label.text = str(c_res.get("message", ""))
				feedback_label.visible = not feedback_label.text.is_empty()
				main.call("_after_diplomacy_action", true)
			)
			ally_row.add_child(call_btn)

func _add_side_row(parent: VBoxContainer, title: String, members: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	row.add_child(main.call("_make_label", title + ":", Color(0.80, 0.75, 0.66), 12))

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	row.add_child(flow)
	for m_v in members:
		if not (m_v is Dictionary):
			continue
		var m: Dictionary = m_v
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		flow.add_child(chip)
		var arms := TextureRect.new()
		arms.custom_minimum_size = Vector2(18.0, 14.0)
		arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arms.texture = main.call("_get_country_arms_texture", str(m.get("tag", "")), int(m.get("colorR", 196)), int(m.get("colorG", 182)), int(m.get("colorB", 150)))
		chip.add_child(arms)
		chip.add_child(main.call("_make_label", str(m.get("tag", "")), Color(0.92, 0.90, 0.84), 12))

func _csv_from_dict_keys(dict: Dictionary) -> String:
	var keys := dict.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k in keys:
		parts.append(str(k))
	return ",".join(parts)

func _refresh_peace_modal() -> void:
	if main == null or not peace_modal.visible or active_peace_war_id.is_empty():
		return
	var prov_csv := _csv_from_dict_keys(selected_provinces)
	var rel_csv := _csv_from_dict_keys(selected_releases)
	var ann_csv := _csv_from_dict_keys(selected_annuls)

	var d_var: Variant = main.call(
		"_call_bridge",
		"getPeaceNegotiationDetails",
		[active_peace_war_id, prov_csv, indemnity_amount, include_reparations, subject_mode, rel_csv, ann_csv],
		{}
	)
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("valid", false)):
		peace_modal.visible = false
		active_peace_war_id = ""
		_last_peace_sig = ""
		return

	var sig := "%s|%s" % [peace_feedback, var_to_str(d)]
	if sig == _last_peace_sig and peace_box.get_child_count() > 0:
		return
	_last_peace_sig = sig

	main.call("_clear_children", peace_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	peace_box.add_child(header)

	var l_arms := TextureRect.new()
	l_arms.custom_minimum_size = Vector2(28.0, 22.0)
	l_arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	l_arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	l_arms.texture = main.call(
		"_get_country_arms_texture",
		str(d.get("loserTag", "")),
		int(d.get("loserColorR", 196)),
		int(d.get("loserColorG", 182)),
		int(d.get("loserColorB", 150))
	)
	header.add_child(l_arms)

	var title := main.call("_make_label", "Peace Negotiation — %s (WS %+d%%)" % [str(d.get("loserName", "")), int(d.get("warScorePct", 0))], Color(0.97, 0.90, 0.68), 16) as Label
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func() -> void:
		peace_modal.visible = false
		active_peace_war_id = ""
	)
	header.add_child(close_btn)

	peace_box.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(456.0, 310.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	peace_box.add_child(scroll)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 5)
	scroll.add_child(form)

	# 1. Territorial Demands
	form.add_child(main.call("_make_label", "Territorial Demands (Cede Province)", Color(0.95, 0.85, 0.56), 13))
	for p_v in d.get("cedeProvinces", []):
		if not (p_v is Dictionary):
			continue
		var p: Dictionary = p_v
		var p_idx: int = int(p.get("provinceIndex", -1))
		var tags := PackedStringArray()
		if bool(p.get("isOccupied", false)):
			tags.append("Occupied")
		if bool(p.get("isCore", false)):
			tags.append("Core")
		elif bool(p.get("isClaim", false)):
			tags.append("Claim")
		var suffix: String = " [%s]" % ", ".join(tags) if not tags.is_empty() else ""
		var chk := CheckBox.new()
		chk.text = "%s%s — %d%%" % [str(p.get("name", "")), suffix, int(p.get("cost", 0))]
		chk.button_pressed = selected_provinces.has(p_idx)
		chk.toggled.connect(func(on: bool) -> void:
			if on:
				selected_provinces[p_idx] = true
			else:
				selected_provinces.erase(p_idx)
			_refresh_peace_modal()
		)
		form.add_child(chk)

	form.add_child(HSeparator.new())
	form.add_child(main.call("_make_label", "Gold & Reparations", Color(0.95, 0.85, 0.56), 13))

	var rep_chk := CheckBox.new()
	rep_chk.text = "War Reparations (10%% monthly income, 10 yrs) — %d%%" % int(d.get("reparationsCost", 10))
	rep_chk.button_pressed = include_reparations
	rep_chk.toggled.connect(func(on: bool) -> void:
		include_reparations = on
		_refresh_peace_modal()
	)
	form.add_child(rep_chk)

	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 6)
	form.add_child(gold_row)
	var g_lbl := main.call("_make_label", "Ducats Indemnity: %d (%d%%)" % [int(indemnity_amount), int(d.get("indemnityCost", 0))], Color(0.88, 0.85, 0.78), 12) as Label
	g_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(g_lbl)
	for step_val in [0, 50, 100, 150, 200]:
		var b := Button.new()
		b.text = str(step_val)
		b.disabled = int(indemnity_amount) == step_val
		var amt: float = float(step_val)
		b.pressed.connect(func() -> void:
			indemnity_amount = amt
			_refresh_peace_modal()
		)
		gold_row.add_child(b)

	form.add_child(HSeparator.new())
	form.add_child(main.call("_make_label", "Subject Demands", Color(0.95, 0.85, 0.56), 13))
	var vassal_chk := CheckBox.new()
	vassal_chk.text = "Force Vassalization — %d%%" % int(d.get("vassalCost", 0))
	vassal_chk.button_pressed = (subject_mode == 1)
	vassal_chk.toggled.connect(func(on: bool) -> void:
		subject_mode = 1 if on else 0
		_refresh_peace_modal()
	)
	form.add_child(vassal_chk)

	var trib_chk := CheckBox.new()
	trib_chk.text = "Force Tributary — %d%%" % int(d.get("tributaryCost", 0))
	trib_chk.button_pressed = (subject_mode == 2)
	trib_chk.toggled.connect(func(on: bool) -> void:
		subject_mode = 2 if on else 0
		_refresh_peace_modal()
	)
	form.add_child(trib_chk)

	# Release nations
	var releases: Array = d.get("releaseCandidates", [])
	if not releases.is_empty():
		form.add_child(HSeparator.new())
		form.add_child(main.call("_make_label", "Release Nations", Color(0.95, 0.85, 0.56), 13))
		for r_v in releases:
			if not (r_v is Dictionary):
				continue
			var r: Dictionary = r_v
			var rc_idx: int = int(r.get("countryIndex", -1))
			var rchk := CheckBox.new()
			rchk.text = "Release %s (%d provs) — %d%%" % [str(r.get("name", "")), int(r.get("provinceCount", 0)), int(r.get("cost", 0))]
			rchk.button_pressed = selected_releases.has(rc_idx)
			rchk.toggled.connect(func(on: bool) -> void:
				if on:
					selected_releases[rc_idx] = true
				else:
					selected_releases.erase(rc_idx)
				_refresh_peace_modal()
			)
			form.add_child(rchk)

	# Annul treaties
	var annuls: Array = d.get("annulCandidates", [])
	if not annuls.is_empty():
		form.add_child(HSeparator.new())
		form.add_child(main.call("_make_label", "Annul Treaties", Color(0.95, 0.85, 0.56), 13))
		for a_v in annuls:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v
			var ac_idx: int = int(a.get("countryIndex", -1))
			var achk := CheckBox.new()
			achk.text = "Annul treaties with %s — %d%%" % [str(a.get("name", "")), int(a.get("cost", 10))]
			achk.button_pressed = selected_annuls.has(ac_idx)
			achk.toggled.connect(func(on: bool) -> void:
				if on:
					selected_annuls[ac_idx] = true
				else:
					selected_annuls.erase(ac_idx)
				_refresh_peace_modal()
			)
			form.add_child(achk)

	peace_box.add_child(HSeparator.new())

	# Totals + Evaluation
	var total_cost: int = int(d.get("totalCost", 0))
	var exceeds: bool = bool(d.get("exceedsCost", false))
	var will_accept: bool = bool(d.get("willAccept", false))
	var score: int = int(d.get("score", 0))

	var meta_row := HBoxContainer.new()
	peace_box.add_child(meta_row)
	var cost_lbl := main.call("_make_label", "Cost: %d / 100%%" % total_cost, Color(0.95, 0.42, 0.38) if exceeds else Color(0.92, 0.90, 0.82), 13) as Label
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(cost_lbl)
	meta_row.add_child(main.call("_make_label", "Truce: %d yrs · AE: +%d" % [int(d.get("truceYears", 5)), int(d.get("ae", 0))], Color(0.84, 0.80, 0.72), 12))

	var accept_lbl := main.call("_make_label", "%s (%+d)" % ["They will accept" if will_accept else "They refuse", score], Color(0.45, 0.90, 0.45) if will_accept else Color(0.95, 0.42, 0.38), 14) as Label
	peace_box.add_child(accept_lbl)

	var factors: Array = d.get("factors", [])
	for i in range(mini(5, factors.size())):
		var f_v: Variant = factors[i]
		if f_v is Dictionary:
			var f: Dictionary = f_v
			peace_box.add_child(main.call("_make_label", "  • %s: %s" % [str(f.get("name", "")), str(f.get("scoreText", ""))], Color(0.78, 0.74, 0.66), 12))

	if not peace_feedback.is_empty():
		var pf := main.call("_make_label", peace_feedback, Color(0.95, 0.42, 0.38), 12) as Label
		pf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		peace_box.add_child(pf)

	var btn_row := HBoxContainer.new()
	peace_box.add_child(btn_row)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func() -> void:
		peace_modal.visible = false
		active_peace_war_id = ""
	)
	btn_row.add_child(cancel_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)

	var send_btn := Button.new()
	send_btn.text = "Send Peace Offer"
	send_btn.disabled = (not will_accept) or exceeds
	send_btn.pressed.connect(func() -> void:
		var res_var: Variant = main.call(
			"_call_bridge",
			"proposePeaceOffer",
			[active_peace_war_id, prov_csv, indemnity_amount, include_reparations, subject_mode, rel_csv, ann_csv],
			{}
		)
		var res: Dictionary = res_var if res_var is Dictionary else {}
		if bool(res.get("ok", false)):
			peace_modal.visible = false
			active_peace_war_id = ""
			peace_feedback = ""
			main.call("_after_diplomacy_action", true)
		else:
			peace_feedback = str(res.get("error", "Peace offer refused."))
			_refresh_peace_modal()
	)
	btn_row.add_child(send_btn)
