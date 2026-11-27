extends Control

# Chronicle Book screen (Phase 18):
# Displays a country's regnal history grouped into chapters by ruler,
# rendered in period prose from data/chronicle/templates.txt.
# Uses plain Godot controls so the shared Phase 20 Theme styles them automatically.

var main_view: Control = null

var chronicle_panel: PanelContainer
var country_picker: OptionButton
var kind_filter: OptionButton
var chapters_box: VBoxContainer
var status_label: Label

var _selected_country_index: int = -1
var _selected_kind_group: int = 0
var _country_indices: Array = []
var _last_sig: String = ""

const KIND_GROUPS := [
	{"label": "All Events", "kinds": []},
	{"label": "Wars & Peace", "kinds": ["war_declared", "war_ended", "peace_treaty"]},
	{"label": "Battles & Sieges", "kinds": ["major_battle", "naval_battle", "siege_captured"]},
	{"label": "Laws & Reforms", "kinds": ["law_changed", "reform_adopted", "nation_formed"]},
	{"label": "Plagues, Famines & Rebels", "kinds": ["plague_outbreak", "famine", "rebellion"]},
	{"label": "Dynasty & Rulers", "kinds": ["ruler_crowned", "ruler_died", "marriage", "heir_born"]},
]

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
	chronicle_panel = PanelContainer.new()
	chronicle_panel.name = "ChroniclePanel"
	chronicle_panel.visible = false
	chronicle_panel.custom_minimum_size = Vector2(760.0, 520.0)
	add_child(chronicle_panel)

	var outer := VBoxContainer.new()
	chronicle_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)

	var title := Label.new()
	title.text = "Chronicle Book"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.tooltip_text = "Close Chronicle Book"
	close_btn.pressed.connect(close_window)
	header.add_child(close_btn)

	var filters := HBoxContainer.new()
	outer.add_child(filters)

	var country_lbl := Label.new()
	country_lbl.text = "Realm:"
	filters.add_child(country_lbl)

	country_picker = OptionButton.new()
	country_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	country_picker.item_selected.connect(_on_country_selected)
	filters.add_child(country_picker)

	var kind_lbl := Label.new()
	kind_lbl.text = "Filter:"
	filters.add_child(kind_lbl)

	kind_filter = OptionButton.new()
	for grp in KIND_GROUPS:
		kind_filter.add_item(str(grp["label"]))
	kind_filter.item_selected.connect(_on_kind_selected)
	filters.add_child(kind_filter)

	status_label = Label.new()
	status_label.text = ""
	outer.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(740.0, 420.0)
	outer.add_child(scroll)

	chapters_box = VBoxContainer.new()
	chapters_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(chapters_box)

func is_open() -> bool:
	return chronicle_panel != null and chronicle_panel.visible

func open_window() -> void:
	if chronicle_panel == null:
		return
	chronicle_panel.visible = true
	_position_panel()
	_last_sig = ""
	refresh()

func close_window() -> void:
	if chronicle_panel != null:
		chronicle_panel.visible = false

func toggle_window() -> void:
	if is_open():
		close_window()
	else:
		open_window()

func _position_panel() -> void:
	if chronicle_panel == null:
		return
	var vp := get_viewport_rect().size
	var w := minf(820.0, maxf(540.0, vp.x * 0.62))
	var h := minf(620.0, maxf(420.0, vp.y * 0.72))
	chronicle_panel.position = Vector2(18.0, 56.0)
	chronicle_panel.size = Vector2(w, h)

func _on_country_selected(idx: int) -> void:
	if idx >= 0 and idx < _country_indices.size():
		_selected_country_index = int(_country_indices[idx])
		_last_sig = ""
		refresh()

func _on_kind_selected(idx: int) -> void:
	_selected_kind_group = idx
	_last_sig = ""
	refresh()

func refresh() -> void:
	if not is_open():
		return
	var d: Variant = _call_bridge("getChronicleDetails", [_selected_country_index], {})
	if typeof(d) != TYPE_DICTIONARY or not bool(d.get("hasWorld", false)):
		return

	var sel_idx := int(d.get("selectedCountryIndex", -1))
	var chapters: Array = d.get("chapters", [])
	var sig := "%d|%d|%d" % [sel_idx, _selected_kind_group, chapters.size()]
	for ch in chapters:
		if typeof(ch) == TYPE_DICTIONARY:
			sig += "|%d" % (ch.get("entries", []) as Array).size()
	if sig == _last_sig:
		return
	_last_sig = sig

	# Populate country dropdown if needed
	var countries: Array = d.get("countries", [])
	if country_picker.item_count != countries.size():
		country_picker.clear()
		_country_indices.clear()
		var select_pos := 0
		for i in range(countries.size()):
			var c: Dictionary = countries[i]
			var c_idx := int(c.get("index", 0))
			var c_name := str(c.get("name", ""))
			var c_tag := str(c.get("tag", ""))
			var is_p := bool(c.get("isPlayer", false))
			var label := "%s (%s)%s" % [c_name, c_tag, " [You]" if is_p else ""]
			country_picker.add_item(label)
			_country_indices.append(c_idx)
			if c_idx == sel_idx:
				select_pos = i
		country_picker.select(select_pos)

	_clear_children(chapters_box)
	var allowed_kinds: Array = KIND_GROUPS[_selected_kind_group]["kinds"] if _selected_kind_group >= 0 and _selected_kind_group < KIND_GROUPS.size() else []
	var total_entries := 0

	for ch in chapters:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var ruler_name := str(ch.get("rulerName", "Unknown Ruler"))
		var dynasty_name := str(ch.get("dynastyName", ""))
		var span_text := str(ch.get("spanText", ""))
		var entries: Array = ch.get("entries", [])

		var filtered: Array = []
		for e in entries:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			if allowed_kinds.is_empty() or allowed_kinds.has(str(e.get("kind", ""))):
				filtered.append(e)

		var header_lbl := Label.new()
		var dyn_part := (" of " + dynasty_name) if dynasty_name != "" else ""
		var span_part := (" (" + span_text + ")") if span_text != "" else ""
		header_lbl.text = "Reign of %s%s%s" % [ruler_name, dyn_part, span_part]
		chapters_box.add_child(header_lbl)

		if filtered.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "  No chronicled events recorded in this reign."
			chapters_box.add_child(empty_lbl)
		else:
			for e in filtered:
				var row_lbl := Label.new()
				row_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				row_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row_lbl.text = "  %s — %s" % [str(e.get("date", "")), str(e.get("prose", ""))]
				chapters_box.add_child(row_lbl)
				total_entries += 1

		chapters_box.add_child(HSeparator.new())

	status_label.text = "%s — %d regnal chapters, %d entries" % [str(d.get("selectedCountryName", "")), chapters.size(), total_entries]
