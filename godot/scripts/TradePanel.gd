extends Control

var main_view: Control = null

var trade_panel: PanelContainer
var capacity_box: VBoxContainer
var routes_box: VBoxContainer
var new_route_box: VBoxContainer
var policy_box: VBoxContainer

var draft_category_key: String = ""
var draft_good_index: int = -1
var draft_from_market_index: int = -1
var draft_to_market_index: int = -1
var draft_volume: float = 25.0
var action_refusal_text: String = ""
var _last_cap_sig: String = ""
var _last_routes_sig: String = ""
var _last_new_route_sig: String = ""
var _last_policy_sig: String = ""

func setup(host: Control) -> void:
	main_view = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_trade_panel()

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

func _build_trade_panel() -> void:
	trade_panel = PanelContainer.new()
	trade_panel.name = "TradePanel"
	trade_panel.visible = false
	trade_panel.custom_minimum_size = Vector2(440.0, 0.0)
	trade_panel.offset_left = 14.0
	trade_panel.offset_top = 56.0
	if main_view != null and main_view.has_method("_make_panel_style"):
		var st: StyleBoxFlat = main_view.call("_make_panel_style")
		trade_panel.add_theme_stylebox_override("panel", st)
	add_child(trade_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	trade_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := _make_label("Trade", Color(0.97, 0.90, 0.68), 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close Trade window"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(414.0, 520.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	scroll.add_child(body)

	capacity_box = VBoxContainer.new()
	capacity_box.add_theme_constant_override("separation", 3)
	body.add_child(capacity_box)

	body.add_child(HSeparator.new())

	routes_box = VBoxContainer.new()
	routes_box.add_theme_constant_override("separation", 4)
	body.add_child(routes_box)

	body.add_child(HSeparator.new())

	new_route_box = VBoxContainer.new()
	new_route_box.add_theme_constant_override("separation", 5)
	body.add_child(new_route_box)

	body.add_child(HSeparator.new())

	policy_box = VBoxContainer.new()
	policy_box.add_theme_constant_override("separation", 4)
	body.add_child(policy_box)

func is_open() -> bool:
	return trade_panel != null and trade_panel.visible

func open_window() -> void:
	if trade_panel == null:
		return
	if main_view != null and main_view.has_method("_close_top_left_windows"):
		main_view.call("_close_top_left_windows", "trade")
	trade_panel.visible = true
	action_refusal_text = ""
	refresh()
	if main_view != null and main_view.has_method("_on_trade_window_visibility_changed"):
		main_view.call("_on_trade_window_visibility_changed", true)

func close_window() -> void:
	var was_open := is_open()
	if trade_panel != null:
		trade_panel.visible = false
	if was_open and main_view != null and main_view.has_method("_on_trade_window_visibility_changed"):
		main_view.call("_on_trade_window_visibility_changed", false)

func toggle_window() -> void:
	if is_open():
		close_window()
	else:
		open_window()

func refresh_if_open() -> void:
	if is_open():
		refresh()

func plan_import(good_idx: int, to_market_idx: int) -> void:
	draft_good_index = good_idx
	draft_to_market_index = to_market_idx
	draft_from_market_index = -1
	draft_volume = 25.0
	action_refusal_text = ""
	# Auto-pick cheapest source suggestion from bridge just like GameSession.planImport
	var d_var: Variant = _call_bridge(
		"getTradeWindowDetails",
		[draft_good_index, -1, draft_to_market_index, draft_volume],
		{}
	)
	var d: Dictionary = d_var if d_var is Dictionary else {}
	var sugs_var: Variant = d.get("sourceSuggestions", [])
	var sugs: Array = sugs_var if sugs_var is Array else []
	if not sugs.is_empty() and sugs[0] is Dictionary:
		draft_from_market_index = int((sugs[0] as Dictionary).get("marketIndex", -1))
	open_window()

func refresh() -> void:
	if trade_panel == null:
		return
	var d_var: Variant = _call_bridge(
		"getTradeWindowDetails",
		[draft_good_index, draft_from_market_index, draft_to_market_index, draft_volume],
		{}
	)
	var d: Dictionary = d_var if d_var is Dictionary else {}
	if not bool(d.get("valid", false)):
		_clear_children(capacity_box)
		capacity_box.add_child(_make_label("No active player country.", Color(0.80, 0.75, 0.66), 13))
		_clear_children(routes_box)
		_clear_children(new_route_box)
		_clear_children(policy_box)
		return

	_refresh_capacity(d)
	_refresh_routes(d)
	_refresh_new_route(d)
	_refresh_policy(d)

func _refresh_capacity(d: Dictionary) -> void:
	var sig := "%s|%s|%s" % [str(d.get("capacityText", "")), str(d.get("capacityRatio", 0.0)), str(d.get("lastMonthText", ""))]
	if sig == _last_cap_sig and capacity_box.get_child_count() > 0:
		return
	_last_cap_sig = sig
	_clear_children(capacity_box)
	var hdr := HBoxContainer.new()
	capacity_box.add_child(hdr)
	var title := _make_label("Merchant capacity", Color(0.96, 0.90, 0.72), 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	hdr.add_child(_make_label(str(d.get("capacityText", "0 / 0")), Color(0.95, 0.92, 0.84), 13))

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(float(d.get("capacityRatio", 0.0)), 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 12.0)
	capacity_box.add_child(bar)

	var last_lbl := _make_label(str(d.get("lastMonthText", "")), Color(0.82, 0.78, 0.70), 12)
	capacity_box.add_child(last_lbl)

	var hint := _make_label("Each route uses 1 + volume/100 capacity. Cancel routes or end wars to free capacity.", Color(0.68, 0.64, 0.56), 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	capacity_box.add_child(hint)

func _refresh_routes(d: Dictionary) -> void:
	var routes_var: Variant = d.get("routes", [])
	var routes: Array = routes_var if routes_var is Array else []
	var sig := var_to_str(routes)
	if sig == _last_routes_sig and routes_box.get_child_count() > 0:
		return
	_last_routes_sig = sig
	_clear_children(routes_box)
	routes_box.add_child(_make_label("Your routes (%d)" % routes.size(), Color(0.96, 0.90, 0.72), 14))

	if routes.is_empty():
		var empty_lbl := _make_label("None. Use New route below or click any good in a market.", Color(0.70, 0.66, 0.58), 12)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		routes_box.add_child(empty_lbl)
		return

	for item in routes:
		if not (item is Dictionary):
			continue
		var r: Dictionary = item
		var route_idx: int = int(r.get("routeIndex", -1))
		var is_blocked: bool = bool(r.get("isBlocked", false))
		var is_losing: bool = bool(r.get("isLosing", false))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		routes_box.add_child(row)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(10.0, 10.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = Color(
			float(r.get("colorR", 200)) / 255.0,
			float(r.get("colorG", 170)) / 255.0,
			float(r.get("colorB", 80)) / 255.0
		)
		row.add_child(swatch)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 1)
		row.add_child(info)

		var title_lbl := _make_label(str(r.get("titleText", "")), Color(0.95, 0.92, 0.84), 12)
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(title_lbl)

		var det_col := Color(0.82, 0.78, 0.70)
		if is_blocked:
			det_col = Color(0.94, 0.36, 0.32)
		elif is_losing:
			det_col = Color(0.95, 0.68, 0.30)
		var det_lbl := _make_label(str(r.get("detailsText", "")), det_col, 11)
		det_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(det_lbl)

		var path_str: String = str(r.get("pathText", ""))
		if not path_str.is_empty():
			var path_lbl := _make_label(path_str, Color(0.68, 0.64, 0.56), 11)
			path_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(path_lbl)

		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var idx_copy := route_idx
		cancel_btn.pressed.connect(func() -> void:
			if bool(_call_bridge("cancelTradeRoute", [idx_copy], false)):
				action_refusal_text = ""
				if main_view != null and main_view.has_method("_after_economy_action"):
					main_view.call("_after_economy_action")
				else:
					refresh()
		)
		row.add_child(cancel_btn)

func _refresh_new_route(d: Dictionary) -> void:
	var cats_var: Variant = d.get("goodCategories", [])
	var cats: Array = cats_var if cats_var is Array else []
	var goods_var: Variant = d.get("goods", [])
	var goods: Array = goods_var if goods_var is Array else []
	var markets_var: Variant = d.get("markets", [])
	var markets: Array = markets_var if markets_var is Array else []
	var sugs_var: Variant = d.get("sourceSuggestions", [])
	var sugs: Array = sugs_var if sugs_var is Array else []
	var est_v: Variant = d.get("estimate", {})
	var sig := "%s|%d|%d|%d|%.1f|%s|%s|%s|%s|%s" % [
		draft_category_key, draft_good_index, draft_from_market_index, draft_to_market_index,
		draft_volume, action_refusal_text, var_to_str(goods), var_to_str(markets),
		var_to_str(sugs), var_to_str(est_v)
	]
	if sig == _last_new_route_sig and new_route_box.get_child_count() > 0:
		return
	_last_new_route_sig = sig
	_clear_children(new_route_box)
	new_route_box.add_child(_make_label("New route", Color(0.96, 0.90, 0.72), 14))

	# 1. Category + Good selectors
	var good_row := HBoxContainer.new()
	good_row.add_theme_constant_override("separation", 6)
	new_route_box.add_child(good_row)
	good_row.add_child(_make_label("Good", Color(0.80, 0.75, 0.66), 12))

	var cat_label := "All"
	for c in cats:
		if c is Dictionary and str((c as Dictionary).get("key", "")) == draft_category_key:
			cat_label = str((c as Dictionary).get("title", "All"))
			break
	var cat_menu := MenuButton.new()
	cat_menu.text = cat_label
	var cat_popup := cat_menu.get_popup()
	var cat_keys: Array[String] = []
	for c in cats:
		if c is Dictionary:
			var ck: String = str((c as Dictionary).get("key", ""))
			cat_keys.append(ck)
			cat_popup.add_item(str((c as Dictionary).get("title", ck)))
	cat_popup.index_pressed.connect(func(idx: int) -> void:
		if idx >= 0 and idx < cat_keys.size():
			draft_category_key = cat_keys[idx]
			action_refusal_text = ""
			refresh()
	)
	good_row.add_child(cat_menu)

	var good_label := "Pick a good..."
	for g in goods:
		if g is Dictionary and int((g as Dictionary).get("goodIndex", -1)) == draft_good_index:
			good_label = str((g as Dictionary).get("name", ""))
			break
	var good_menu := MenuButton.new()
	good_menu.text = good_label
	good_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var good_popup := good_menu.get_popup()
	var good_ids: Array[int] = []
	for g in goods:
		if g is Dictionary:
			var g_cat: String = str((g as Dictionary).get("categoryKey", ""))
			if not draft_category_key.is_empty() and g_cat != draft_category_key:
				continue
			good_ids.append(int((g as Dictionary).get("goodIndex", -1)))
			good_popup.add_item(str((g as Dictionary).get("name", "")))
	good_popup.index_pressed.connect(func(idx: int) -> void:
		if idx >= 0 and idx < good_ids.size():
			draft_good_index = good_ids[idx]
			action_refusal_text = ""
			refresh()
	)
	good_row.add_child(good_menu)

	# 2. From market selector
	var from_row := HBoxContainer.new()
	from_row.add_theme_constant_override("separation", 6)
	new_route_box.add_child(from_row)
	var from_lbl := _make_label("From", Color(0.80, 0.75, 0.66), 12)
	from_lbl.custom_minimum_size = Vector2(36.0, 0.0)
	from_row.add_child(from_lbl)

	var from_label := "Pick source market..."
	for m in markets:
		if m is Dictionary and int((m as Dictionary).get("marketIndex", -1)) == draft_from_market_index:
			from_label = str((m as Dictionary).get("label", ""))
			break
	var from_menu := MenuButton.new()
	from_menu.text = from_label
	from_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var from_popup := from_menu.get_popup()
	var from_ids: Dictionary = {} # item_index -> marketIndex
	if not sugs.is_empty():
		var hdr_idx := from_popup.item_count
		from_popup.add_item("Best sources (cheapest):")
		from_popup.set_item_disabled(hdr_idx, true)
		for s in sugs:
			if s is Dictionary:
				var item_i := from_popup.item_count
				from_ids[item_i] = int((s as Dictionary).get("marketIndex", -1))
				from_popup.add_item("  " + str((s as Dictionary).get("label", "")))
		from_popup.add_separator()
	var all_hdr := from_popup.item_count
	from_popup.add_item("All markets:")
	from_popup.set_item_disabled(all_hdr, true)
	for m in markets:
		if m is Dictionary:
			var item_i := from_popup.item_count
			from_ids[item_i] = int((m as Dictionary).get("marketIndex", -1))
			from_popup.add_item(str((m as Dictionary).get("label", "")))
	from_popup.index_pressed.connect(func(idx: int) -> void:
		if from_ids.has(idx):
			draft_from_market_index = int(from_ids[idx])
			action_refusal_text = ""
			refresh()
	)
	from_row.add_child(from_menu)

	# 3. To market selector
	var to_row := HBoxContainer.new()
	to_row.add_theme_constant_override("separation", 6)
	new_route_box.add_child(to_row)
	var to_lbl := _make_label("To", Color(0.80, 0.75, 0.66), 12)
	to_lbl.custom_minimum_size = Vector2(36.0, 0.0)
	to_row.add_child(to_lbl)

	var to_label := "Pick destination market..."
	for m in markets:
		if m is Dictionary and int((m as Dictionary).get("marketIndex", -1)) == draft_to_market_index:
			to_label = str((m as Dictionary).get("label", ""))
			break
	var to_menu := MenuButton.new()
	to_menu.text = to_label
	to_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var to_popup := to_menu.get_popup()
	var to_ids: Array[int] = []
	for m in markets:
		if m is Dictionary:
			to_ids.append(int((m as Dictionary).get("marketIndex", -1)))
			to_popup.add_item(str((m as Dictionary).get("label", "")))
	to_popup.index_pressed.connect(func(idx: int) -> void:
		if idx >= 0 and idx < to_ids.size():
			draft_to_market_index = to_ids[idx]
			action_refusal_text = ""
			refresh()
	)
	to_row.add_child(to_menu)

	# 4. Volume buttons
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 4)
	new_route_box.add_child(vol_row)
	vol_row.add_child(_make_label("Volume", Color(0.80, 0.75, 0.66), 12))
	var vols_var: Variant = d.get("volumes", [10.0, 25.0, 50.0, 100.0])
	var vols: Array = vols_var if vols_var is Array else [10.0, 25.0, 50.0, 100.0]
	for v_var in vols:
		var v: float = float(v_var)
		var v_btn := Button.new()
		v_btn.text = "%d/yr" % int(round(v))
		v_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_equal_approx(draft_volume, v):
			v_btn.modulate = Color(1.0, 0.88, 0.40)
		var v_copy := v
		v_btn.pressed.connect(func() -> void:
			draft_volume = v_copy
			action_refusal_text = ""
			refresh()
		)
		vol_row.add_child(v_btn)

	# 5. Live estimate + refusal reason + Start route button
	var est_var: Variant = d.get("estimate", {})
	var est: Dictionary = est_var if est_var is Dictionary else {}
	var has_est: bool = bool(est.get("hasEstimate", false))
	var can_create: bool = bool(est.get("canCreate", false))
	var est_refusal: String = str(est.get("refusalReason", ""))
	var refusal: String = action_refusal_text if not action_refusal_text.is_empty() else est_refusal

	if has_est:
		var sum_txt: String = str(est.get("summaryText", ""))
		if not sum_txt.is_empty():
			var sum_lbl := _make_label(sum_txt, Color(0.90, 0.86, 0.78), 12)
			sum_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			new_route_box.add_child(sum_lbl)
		var path_txt: String = str(est.get("pathText", ""))
		if not path_txt.is_empty():
			var p_lbl := _make_label(path_txt, Color(0.68, 0.64, 0.56), 11)
			p_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			new_route_box.add_child(p_lbl)
	else:
		var pick_lbl := _make_label("Pick a good, a source market and a destination market.", Color(0.68, 0.64, 0.56), 11)
		pick_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		new_route_box.add_child(pick_lbl)

	if not refusal.is_empty():
		var ref_lbl := _make_label(refusal, Color(0.96, 0.40, 0.36), 12)
		ref_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		new_route_box.add_child(ref_lbl)

	var start_btn := Button.new()
	start_btn.text = "Start route"
	start_btn.disabled = not (has_est and can_create)
	start_btn.pressed.connect(func() -> void:
		var res_var: Variant = _call_bridge(
			"createTradeRoute",
			[draft_good_index, draft_from_market_index, draft_to_market_index, draft_volume],
			{}
		)
		var res: Dictionary = res_var if res_var is Dictionary else {}
		if bool(res.get("created", false)):
			action_refusal_text = ""
			if main_view != null and main_view.has_method("_after_economy_action"):
				main_view.call("_after_economy_action")
			else:
				refresh()
		else:
			action_refusal_text = str(res.get("refusalReason", "Cannot create route"))
			refresh()
	)
	new_route_box.add_child(start_btn)

func _refresh_policy(d: Dictionary) -> void:
	var sig := "%s|%s|%s" % [str(d.get("tollPolicyKey", "")), var_to_str(d.get("embargoes", [])), var_to_str(d.get("embargoCandidates", []))]
	if sig == _last_policy_sig and policy_box.get_child_count() > 0:
		return
	_last_policy_sig = sig
	_clear_children(policy_box)
	policy_box.add_child(_make_label("Your markets", Color(0.96, 0.90, 0.72), 14))

	# Toll policy selector
	var toll_row := HBoxContainer.new()
	toll_row.add_theme_constant_override("separation", 6)
	policy_box.add_child(toll_row)
	toll_row.add_child(_make_label("Toll policy", Color(0.80, 0.75, 0.66), 12))

	var cur_policy_key: String = str(d.get("tollPolicyKey", ""))
	var policies_var: Variant = d.get("tollPolicies", [])
	var policies: Array = policies_var if policies_var is Array else []
	var policy_opt := OptionButton.new()
	policy_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var policy_keys: Array[String] = []
	var selected_idx := 0
	for i in range(policies.size()):
		var p = policies[i]
		if p is Dictionary:
			var pk: String = str((p as Dictionary).get("key", ""))
			policy_keys.append(pk)
			policy_opt.add_item(str((p as Dictionary).get("title", pk)))
			if pk == cur_policy_key:
				selected_idx = policy_keys.size() - 1
	if not policy_keys.is_empty():
		policy_opt.select(selected_idx)
	policy_opt.item_selected.connect(func(idx: int) -> void:
		if idx >= 0 and idx < policy_keys.size():
			if bool(_call_bridge("setTollPolicy", [policy_keys[idx]], false)):
				if main_view != null and main_view.has_method("_after_economy_action"):
					main_view.call("_after_economy_action")
				else:
					refresh()
	)
	toll_row.add_child(policy_opt)

	# Embargoes
	policy_box.add_child(_make_label("Embargoes", Color(0.84, 0.79, 0.70), 12))
	var emb_var: Variant = d.get("embargoes", [])
	var embargoes: Array = emb_var if emb_var is Array else []
	if embargoes.is_empty():
		policy_box.add_child(_make_label("No active embargoes.", Color(0.68, 0.64, 0.56), 11))
	else:
		for e in embargoes:
			if not (e is Dictionary):
				continue
			var ed: Dictionary = e
			var c_idx: int = int(ed.get("countryIndex", -1))
			var erow := HBoxContainer.new()
			erow.add_theme_constant_override("separation", 6)
			policy_box.add_child(erow)

			var arms := TextureRect.new()
			arms.custom_minimum_size = Vector2(20.0, 15.0)
			arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if main_view != null and main_view.has_method("_get_country_arms_texture"):
				arms.texture = main_view.call(
					"_get_country_arms_texture",
					str(ed.get("tag", "")),
					int(ed.get("colorR", 180)),
					int(ed.get("colorG", 140)),
					int(ed.get("colorB", 80))
				)
			erow.add_child(arms)

			var nl := _make_label(str(ed.get("name", "")), Color(0.95, 0.92, 0.84), 12)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			erow.add_child(nl)

			var lift_btn := Button.new()
			lift_btn.text = "Lift"
			var idx_copy := c_idx
			lift_btn.pressed.connect(func() -> void:
				if bool(_call_bridge("toggleEmbargo", [idx_copy], false)):
					if main_view != null and main_view.has_method("_after_economy_action"):
						main_view.call("_after_economy_action")
					else:
						refresh()
			)
			erow.add_child(lift_btn)

	var cand_var: Variant = d.get("embargoCandidates", [])
	var candidates: Array = cand_var if cand_var is Array else []
	var add_menu := MenuButton.new()
	add_menu.text = "Add embargo..." if not candidates.is_empty() else "No other trading countries"
	add_menu.disabled = candidates.is_empty()
	var add_popup := add_menu.get_popup()
	var cand_ids: Array[int] = []
	for c in candidates:
		if c is Dictionary:
			cand_ids.append(int((c as Dictionary).get("countryIndex", -1)))
			add_popup.add_item(str((c as Dictionary).get("name", "")))
	add_popup.index_pressed.connect(func(idx: int) -> void:
		if idx >= 0 and idx < cand_ids.size():
			if bool(_call_bridge("toggleEmbargo", [cand_ids[idx]], false)):
				if main_view != null and main_view.has_method("_after_economy_action"):
					main_view.call("_after_economy_action")
				else:
					refresh()
	)
	policy_box.add_child(add_menu)
