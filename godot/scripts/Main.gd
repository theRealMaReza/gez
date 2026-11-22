extends Control

const Map3DScript := preload("res://scripts/Map3D.gd")
const MapProjectorScript := preload("res://scripts/MapProjector.gd")
const MapModelsScript := preload("res://scripts/MapModels.gd")
const IconsLayerScript := preload("res://scripts/MapIconsLayer.gd")
const LabelsLayerScript := preload("res://scripts/MapLabelsLayer.gd")
const ArmiesLayerScript := preload("res://scripts/MapArmiesLayer.gd")
const FleetsLayerScript := preload("res://scripts/MapFleetsLayer.gd")
const RoutesLayerScript := preload("res://scripts/MapRoutesLayer.gd")
const FaithLayerScript := preload("res://scripts/MapFaithLayer.gd")
const CalamityLayerScript := preload("res://scripts/MapCalamityLayer.gd")
const TechLayerScript := preload("res://scripts/MapTechLayer.gd")
const ArmyPanelScript := preload("res://scripts/ArmyPanel.gd")
const FleetPanelScript := preload("res://scripts/FleetPanel.gd")
const BudgetPanelScript := preload("res://scripts/BudgetPanel.gd")
const TradePanelScript := preload("res://scripts/TradePanel.gd")
const CourtPanelScript := preload("res://scripts/CourtPanel.gd")
const GovernmentPanelScript := preload("res://scripts/GovernmentPanel.gd")
const ReligionPanelScript := preload("res://scripts/ReligionPanel.gd")
const RebelsPanelScript := preload("res://scripts/RebelsPanel.gd")
const TechnologyPanelScript := preload("res://scripts/TechnologyPanel.gd")
const DiplomacyPanelScript := preload("res://scripts/DiplomacyPanel.gd")
const WarsPanelScript := preload("res://scripts/WarsPanel.gd")
const BattleViewScript := preload("res://scripts/BattleView.gd")
const EventPopupScript := preload("res://scripts/EventPopup.gd")
const TooltipManagerScript := preload("res://scripts/TooltipManager.gd")
const AlertsRowScript := preload("res://scripts/AlertsRow.gd")

var bridge: RefCounted = null
var warned_missing_methods: Dictionary = {}

# Hover tracking on map army/fleet counters
var _hover_map_army_id: int = -1
var _hover_map_fleet_id: int = -1

# Game menu audio widgets
var menu_mute_check: CheckBox
var menu_ui_slider: HSlider
var menu_fx_slider: HSlider
var menu_amb_slider: HSlider
var menu_ui_val_lbl: Label
var menu_fx_val_lbl: Label
var menu_amb_val_lbl: Label

var map3d: Node3D
var map_models: Node3D  # 3D towns, forts, ports, armies and fleets (Phase 17 part 2)
var projector: RefCounted = MapProjectorScript.new()
var view_pitch: float = 90.0  # shown camera tilt (eases towards the zoom's pitch)
var map_material: ShaderMaterial
var icons_layer: Control
var labels_layer: Control
var last_town_icons_rev: int = -1
var _last_fps: int = -1
var _last_top_country_str: String = ""
var _last_top_arms_key: String = ""
var _last_ducats_str: String = ""
var _last_stab_str: String = ""
var _last_stab_neg: int = -1
var _last_wars_str: String = ""
var _last_wars_vis: int = -1
var _last_wars_offer: int = -1
var _last_armies_btn_str: String = ""
var _last_fleets_btn_str: String = ""
var _last_date_str: String = ""
var _last_paused_int: int = -1
var _last_speed_int: int = -99
var _last_alerts_sig: String = "__init__"
var _last_armies_sig: int = -999999
var _last_fleets_sig: int = -999999
var _last_prov_sig: String = ""
var _style_img: Image = null
var armies_layer: Control
var fleets_layer: Control
var routes_layer: Control
var faith_layer: Control
var calamity_layer: Control
var tech_layer: Control
var army_ui: Control
var windows_layer: Control   # every window lives here (right of the side column)
var side_bar: PanelContainer
var side_bar_buttons: Dictionary = {}   # screen key -> medallion TextureButton
const SIDEBAR_WIDTH := 70.0
const WINDOWS_TOP_SHIFT := 6.0
var fleet_ui: Control
var budget_ui: Control
var trade_ui: Control
var court_ui: Control
var gov_ui: Control
var religion_ui: Control
var rebels_ui: Control
var tech_ui: Control
var diplomacy_ui: Control
var wars_ui: Control

# Top bar widgets
var top_country_btn: Button
var top_arms_rect: TextureRect
var country_label: Label
var treasury_btn: Button
var trade_btn: Button
var court_btn: Button
var stability_btn: Button
var religion_btn: Button
var rebels_btn: Button
var tech_btn: Button
var _last_rebels_btn_str: String = ""
var _last_rel_btn_str: String = ""
var _last_tech_btn_str: String = ""
var inflation_label: Button
var diplomacy_btn: Button
var wars_btn: Button
var armies_btn: Button
var fleets_btn: Button
var alerts_row: HBoxContainer   # Phase 20 part 5 (AlertsRow.gd)
var recent_events_panel: PanelContainer
var recent_events_toggle_btn: Button
var recent_events_list_box: VBoxContainer
var recent_events_expanded: bool = false
var _last_recent_events_sig: String = "__init__"
var date_label: Label
var selection_label: Label
var fps_label: Label
var top_bar_hbox: HBoxContainer
var top_bar_panel: PanelContainer
var pause_btn: TextureButton
var play_as_btn: Button
var menu_btn: TextureButton
var speed_buttons: Array[Button] = []

# Map mode bar widgets
var map_mode_buttons: Dictionary = {}
var current_map_mode: String = "political"

# Province panel & Sea panel widgets (bottom-left)
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

# Market panel widgets (bottom-right)
var market_panel: PanelContainer
var market_title_label: Label
var market_subtitle_label: Label
var market_cat_box: HBoxContainer
var market_goods_box: VBoxContainer
var open_market_index: int = -1
var current_market_category: String = ""

# Game menu widgets (center modal)
var game_menu_panel: PanelContainer
var menu_playing_label: Label
var menu_playing_arms: TextureRect
var menu_status_label: Label
var save_name_input: LineEdit
var autosave_option_btn: OptionButton
var autosave_keys: Array[String] = []
var menu_pause_events_check: CheckBox
var saves_list_box: VBoxContainer

# Nation picker widgets
var nation_picker_panel: PanelContainer
var picker_featured_flow: HFlowContainer
var picker_search_input: LineEdit
var picker_list_box: VBoxContainer
var picker_arms_rect: TextureRect
var picker_name_label: Label
var picker_meta_label: Label
var picker_ruler_label: Label
var picker_treasury_label: Label
var picker_provinces_label: Label
var picker_ai_option: OptionButton
var picker_ai_keys: Array[String] = []
var picker_ai_descs: Array[String] = []
var picker_ai_desc_label: Label
var selected_picker_tag: String = "TUR"
var cached_all_countries: Array = []

# Tactical battle modal & view (Phase 9)
var battle_choice_panel: PanelContainer
var battle_choice_title: Label
var battle_choice_sub: Label
var battle_choice_details: Label
var battle_view: Control

# Historical & Chronicle Event pop-up modal (Phase 14)
var event_popup: Control

# Heraldry cache (tag -> Texture2D)
var arms_cache: Dictionary = {}
var arms_icon_cache: Dictionary = {}

# Map dimensions & GPU textures
var map_size := Vector2(3936.0, 2384.0)
var style_tex_width: int = 2048
var id_tex: ImageTexture
var sea_tex: ImageTexture
var style_tex: ImageTexture
var terrain_tex: ImageTexture

# Camera state (in viewport points, matching App/Shared/Map/MapCanvasView.swift)
var zoom: float = 0.0
var offset: Vector2 = Vector2.ZERO
var elapsed_time: float = 0.0

# Pointer / drag state
var is_pointer_down: bool = false
var is_dragging: bool = false
var pointer_down_pos: Vector2 = Vector2.ZERO
var drag_start_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_scene_ui()
	_init_bridge_and_map()
	resized.connect(_on_viewport_resized)
	call_deferred("_reset_to_start_camera")

# Safe bridge caller that always checks bridge.has_method() first so an
# out-of-date GDExtension binary logs a clear warning instead of crashing.
func _call_bridge(method_name: String, args: Array = [], fallback: Variant = null) -> Variant:
	if bridge == null:
		return fallback
	if not bridge.has_method(method_name):
		if not warned_missing_methods.has(method_name):
			warned_missing_methods[method_name] = true
			push_warning("GezGodot is missing '%s': run godot/build_mac.sh, then quit (Cmd+Q) and reopen Godot." % method_name)
		return fallback
	return bridge.callv(method_name, args)

func _audio() -> Node:
	return get_node_or_null("/root/AudioManager")

func _tip() -> Node:
	return get_node_or_null("/root/TooltipManager")

func play_sfx(cue: String) -> void:
	var a := _audio()
	if a != null:
		a.call("play_effect", cue)

func play_ui_sfx(cue: String = "ui_wood") -> void:
	var a := _audio()
	if a != null:
		a.call("play_ui", cue)

# A top-bar number and its medallion show the same tooltip.
func _share_tip(ctrl: Control) -> void:
	if ctrl.has_meta("gez_medallion_node"):
		var med: Control = ctrl.get_meta("gez_medallion_node")
		med.set_meta("gez_tip", ctrl.get_meta("gez_tip"))
		med.mouse_filter = Control.MOUSE_FILTER_PASS

func bind_tip(ctrl: Control, title: String, summary: String = "") -> void:
	if ctrl == null:
		return
	if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	TooltipManagerScript.bind_text(ctrl, title, summary)
	_share_tip(ctrl)

func bind_breakdown(ctrl: Control, callback: Callable, fallback_title: String = "") -> void:
	if ctrl == null:
		return
	if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	TooltipManagerScript.bind_breakdown(ctrl, callback, fallback_title)
	_share_tip(ctrl)

func bind_tip_data(ctrl: Control, data: Dictionary) -> void:
	if ctrl == null:
		return
	if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	TooltipManagerScript.bind_data(ctrl, data)
	_share_tip(ctrl)

func _build_scene_ui() -> void:
	# 1. The 3D map (Phase 17): terrain mesh + camera; drawn under every 2D layer.
	map3d = Map3DScript.new()
	add_child(map3d)
	map_material = map3d.terrain_material
	map_models = MapModelsScript.new()
	map_models.set("projector", projector)
	map3d.add_child(map_models)

	# 1b. Town icons layer (towns, capitals, forts, ports — redrawn only on camera or icon change)
	icons_layer = Control.new()
	icons_layer.name = "MapIconsLayer"
	icons_layer.set_script(IconsLayerScript)
	icons_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	icons_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icons_layer)

	# 2. Country / Sea / Province labels overlay
	labels_layer = Control.new()
	labels_layer.name = "LabelsLayer"
	labels_layer.set_script(LabelsLayerScript)
	labels_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	labels_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(labels_layer)

	# 2b. Army & fleet counters / arrows layers (redrawn only when units or camera change)
	armies_layer = Control.new()
	armies_layer.name = "ArmiesLayer"
	armies_layer.set_script(ArmiesLayerScript)
	armies_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	armies_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(armies_layer)

	fleets_layer = Control.new()
	fleets_layer.name = "FleetsLayer"
	fleets_layer.set_script(FleetsLayerScript)
	fleets_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fleets_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fleets_layer)

	# 2c. Player trade routes overlay (visible & redrawn only while Trade window is open)
	routes_layer = Control.new()
	routes_layer.name = "RoutesLayer"
	routes_layer.set_script(RoutesLayerScript)
	routes_layer.visible = false
	routes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	routes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(routes_layer)

	# 2d. Religion & Culture map overlay (visible only in religion/culture map modes)
	faith_layer = Control.new()
	faith_layer.name = "FaithLayer"
	faith_layer.set_script(FaithLayerScript)
	faith_layer.visible = false
	faith_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	faith_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faith_layer)

	# 2e. Plague & Unrest map overlay (visible only in those two map modes)
	calamity_layer = Control.new()
	calamity_layer.name = "CalamityLayer"
	calamity_layer.set_script(CalamityLayerScript)
	calamity_layer.visible = false
	calamity_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	calamity_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(calamity_layer)

	# 2f. Institutions map overlay (visible only in institutions map mode)
	tech_layer = Control.new()
	tech_layer.name = "TechLayer"
	tech_layer.set_script(TechLayerScript)
	tech_layer.visible = false
	tech_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	tech_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tech_layer)

	# 2g. Windows sit right of the side column and just under the top bar
	# (Phase 20). New screens: add them with add_window(node).
	windows_layer = Control.new()
	windows_layer.name = "Windows"
	windows_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	windows_layer.offset_left = SIDEBAR_WIDTH
	windows_layer.offset_top = WINDOWS_TOP_SHIFT
	windows_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(windows_layer)

	# 3. Top bar panel & alerts row
	_build_top_bar()
	_build_alerts_bar()
	_build_recent_events_bar()

	# 4. Map mode bar (top-right, below top bar)
	_build_map_mode_bar()

	# 5. Bottom-right zoom buttons (+, -, Fit)
	_build_zoom_buttons()

	# 6. Province panel & Sea panel (bottom-left)
	_build_province_panel()
	_build_sea_panel()

	# 6b. Army & Fleet panels (Selected inspector & Top-Bar windows)
	army_ui = Control.new()
	army_ui.name = "ArmyUI"
	army_ui.set_script(ArmyPanelScript)
	army_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	army_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows_layer.add_child(army_ui)
	army_ui.call("setup", self)

	fleet_ui = Control.new()
	fleet_ui.name = "FleetUI"
	fleet_ui.set_script(FleetPanelScript)
	fleet_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	fleet_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows_layer.add_child(fleet_ui)
	fleet_ui.call("setup", self)

	# 6c. Economy windows (Budget & Trade)
	budget_ui = Control.new()
	budget_ui.name = "BudgetUI"
	budget_ui.set_script(BudgetPanelScript)
	budget_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	budget_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows_layer.add_child(budget_ui)
	budget_ui.call("setup", self)

	trade_ui = Control.new()
	trade_ui.name = "TradeUI"
	trade_ui.set_script(TradePanelScript)
	trade_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	trade_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows_layer.add_child(trade_ui)
	trade_ui.call("setup", self)

	# 6d. Court & Government windows
	court_ui = Control.new()
	court_ui.name = "CourtUI"
	court_ui.set_script(CourtPanelScript)
	court_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	court_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows_layer.add_child(court_ui)
	court_ui.call("setup", self)

	gov_ui = Control.new()
	gov_ui.name = "GovernmentUI"
	gov_ui.set_script(GovernmentPanelScript)
	gov_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	gov_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows_layer.add_child(gov_ui)
	gov_ui.call("setup", self)

	religion_ui = Control.new()
	religion_ui.name = "ReligionUI"
	religion_ui.set_script(ReligionPanelScript)
	religion_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	religion_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows_layer.add_child(religion_ui)
	religion_ui.call("setup", self)

	rebels_ui = Control.new()
	rebels_ui.name = "RebelsUI"
	rebels_ui.set_script(RebelsPanelScript)
	rebels_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	rebels_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows_layer.add_child(rebels_ui)
	rebels_ui.call("setup", self)

	tech_ui = Control.new()
	tech_ui.name = "TechnologyUI"
	tech_ui.set_script(TechnologyPanelScript)
	tech_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	tech_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	windows_layer.add_child(tech_ui)
	tech_ui.call("setup", self)

	# 6e. Diplomacy & Wars/Peace windows
	diplomacy_ui = PanelContainer.new()
	diplomacy_ui.name = "DiplomacyUI"
	diplomacy_ui.set_script(DiplomacyPanelScript)
	windows_layer.add_child(diplomacy_ui)
	diplomacy_ui.call("setup", self)

	wars_ui = Control.new()
	wars_ui.name = "WarsUI"
	wars_ui.set_script(WarsPanelScript)
	windows_layer.add_child(wars_ui)
	wars_ui.call("setup", self)

	# 7. Market panel (bottom-right, left of zoom buttons)
	_build_market_panel()

	# 8. Nation picker panel (top-left, below top bar so map stays clickable)
	_build_nation_picker_panel()

	# 9. Game menu panel (center)
	_build_game_menu_panel()

	# 10. Battle choice modal & 2D tactical battle view (Phase 9)
	_build_battle_choice_modal()
	battle_view = Control.new()
	battle_view.set_script(BattleViewScript)
	add_child(battle_view)
	battle_view.call("setup", self, bridge)

	# 11. Historical & Chronicle Event pop-up modal (Phase 14)
	event_popup = Control.new()
	event_popup.name = "EventPopupUI"
	event_popup.set_script(EventPopupScript)
	add_child(event_popup)
	event_popup.call("setup", self)

# Every window uses the shared Phase 20 window style (gold frame, leather
# band, parchment page). `bg` is kept so older callers still work.
func _make_panel_style(_bg := Color(0.14, 0.11, 0.08, 0.96)) -> StyleBox:
	return GezTheme.window_style()

func _build_top_bar() -> void:
	# Phase 20: tooled leather bar between gold mouldings; each figure is a
	# gold medallion plus its number (names and breakdowns on hover).
	var top_bar := PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.theme_type_variation = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0.0, 56.0)
	add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	top_bar.add_child(hbox)
	top_bar_hbox = hbox
	top_bar_panel = top_bar
	top_bar.resized.connect(_fit_top_bar)
	get_viewport().size_changed.connect(_fit_top_bar)

	top_arms_rect = TextureRect.new()
	top_arms_rect.custom_minimum_size = Vector2(34.0, 40.0)
	top_arms_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_arms_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bind_tip(top_arms_rect, "National Coat of Arms", "Your realm banner on 30 May 1453 and beyond.")
	hbox.add_child(top_arms_rect)

	top_country_btn = Button.new()
	top_country_btn.text = "Ottoman Empire"
	top_country_btn.theme_type_variation = "BarButton"
	bind_tip(top_country_btn, "Active Realm", "Click to open the Nation Picker or start a new campaign.")
	top_country_btn.pressed.connect(_toggle_nation_picker)
	top_country_btn.clip_text = true
	top_country_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_country_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_country_btn.custom_minimum_size = Vector2(190.0, 34.0)
	hbox.add_child(top_country_btn)

	treasury_btn = _add_bar_indicator(hbox, "treasury", 130.0, _toggle_budget_window)
	bind_breakdown(treasury_btn, func() -> Variant: return _call_bridge("getMonthlyIncomeBreakdown", [], {}), "Treasury & Monthly Net")

	inflation_label = _add_bar_indicator(hbox, "inflation", 54.0, _toggle_budget_window)
	bind_tip(inflation_label, "Currency Inflation", "Each 1% of inflation increases building, unit, technology and stability costs. Reduce it over time or through laws.")
	inflation_label.get_parent().visible = false

	stability_btn = _add_bar_indicator(hbox, "stability", 48.0, _toggle_government_window)
	bind_breakdown(stability_btn, func() -> Variant: return _call_bridge("getStabilityBreakdown", [], {}), "Realm Stability & Government")

	religion_btn = _add_bar_indicator(hbox, "faith", 70.0, _toggle_religion_window)
	bind_tip(religion_btn, "State Religion & Missionaries", "Your state faith and missionaries in use / available. Click for Religion & Cultures.")

	armies_btn = _add_bar_indicator(hbox, "manpower", 62.0, _toggle_armies_window)
	bind_breakdown(armies_btn, func() -> Variant: return _call_bridge("getManpowerBreakdown", [], {}), "Armies & Maximum Manpower")

	fleets_btn = _add_bar_indicator(hbox, "sailors", 66.0, _toggle_fleets_window)
	bind_breakdown(fleets_btn, func() -> Variant: return _call_bridge("getSailorsBreakdown", [], {}), "Fleets & Maximum Sailors")

	selection_label = Label.new()
	selection_label.text = "Click a province to inspect"
	selection_label.theme_type_variation = "BarLabel"
	selection_label.add_theme_font_size_override("font_size", 15)
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# May shrink (with "…") so the date, pause and speed buttons always fit.
	selection_label.clip_text = true
	selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bind_tip(selection_label, "Selected Map Tile", "Click any province or sea zone on the map to inspect its owner, population, terrain and garrison.")
	hbox.add_child(selection_label)

	play_as_btn = Button.new()
	play_as_btn.visible = false
	bind_tip(play_as_btn, "Play As Selected Nation", "Take immediate control of the country owning the currently selected province.")
	play_as_btn.pressed.connect(_on_play_as_pressed)
	hbox.add_child(play_as_btn)

	menu_btn = GezStyle.medallion_button("menu", 36.0)
	bind_tip(menu_btn, "Game Menu (Esc)", "Save/load campaigns, configure autosaves, toggle event pausing, adjust sound effects and quit.")
	menu_btn.pressed.connect(_toggle_game_menu)
	hbox.add_child(menu_btn)

	date_label = Label.new()
	date_label.text = "30 May 1453"
	date_label.theme_type_variation = "BarTitle"
	date_label.custom_minimum_size = Vector2(150.0, 0.0)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bind_tip(date_label, "Campaign Date", "Current calendar date (campaign begins 30 May 1453). Economy, manpower, unrest and sieges tick daily and settle each 1st of the month.")
	hbox.add_child(date_label)

	pause_btn = GezStyle.medallion_button("pause", 38.0)
	bind_tip(pause_btn, "Pause / Resume (Space)", "Red: the game is paused. Pause keeps the simulation and ambient map sound effects silent while still letting you issue orders.")
	pause_btn.pressed.connect(_on_pause_pressed)
	hbox.add_child(pause_btn)

	var speed_box := HBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 0)
	hbox.add_child(speed_box)

	speed_buttons.clear()
	for s in range(1, 6):
		var b := Button.new()
		b.text = "›"
		b.theme_type_variation = "BarButton"
		b.add_theme_font_size_override("font_size", 26)
		b.custom_minimum_size = Vector2(13.0, 34.0)
		bind_tip(b, "Game Speed %d (Key %d)" % [s, s], "Advance time at speed %d. Higher speeds step more days per real second." % s)
		var spd := s
		b.pressed.connect(func() -> void: _on_speed_selected(spd))
		speed_box.add_child(b)
		speed_buttons.append(b)

	# Frame counter sits at the bottom centre of the map, not in the full top bar.
	fps_label = _make_label("60 FPS", Color(0.72, 0.82, 0.72), 12)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fps_label)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 6)

	_build_side_bar()

## One top-bar figure: a medallion and its number. Clicking either opens the
## matching screen. Returns the number (a flat bar button).
func _add_bar_indicator(parent: Control, key: String, min_w: float, on_press: Callable) -> Button:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var med := GezStyle.medallion_button(key, 36.0)
	med.pressed.connect(on_press)
	box.add_child(med)
	var b := Button.new()
	b.theme_type_variation = "BarButton"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(min_w, 34.0)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(on_press)
	box.add_child(b)
	# the medallion shows the same tooltip as the number
	b.set_meta("gez_medallion_node", med)
	return b

# The side column of screens (Phase 20, owner's choice): big gold medallions
# down the left edge. Gemini's Phase 18 screens: add_side_button(...).
const SIDE_SCREENS := [
	["budget", "Budget & Treasury", "Income, expenses, loans and the monthly balance."],
	["trade", "Trade & Markets", "Manage trade routes, merchant capacity, tolls and embargoes across regional markets."],
	["court", "Royal Court & Family", "Inspect the ruler, heir, dynasty, royal council seats, vassals and court chronicle."],
	["government", "Government & Estates", "Laws, reforms, estates and realm stability."],
	["religion", "Religion & Cultures", "Direct missionaries, guard holy sites, watch historical movements and manage accepted cultures."],
	["rebels", "Unrest & Rebel Factions", "Inspect province unrest causes, active rebel factions, uprising progress and countermeasures."],
	["technology", "Technology & Institutions", "Research administrative, diplomatic and military technology; embrace institutions."],
	["diplomacy", "Diplomacy", "Relations, alliances, marriages, rivals and declarations of war."],
	["wars", "Wars & Peace", "Inspect ongoing wars, war score breakdowns, allies and peace offers."],
	["armies", "Armies", "All your armies, regiments, generals and recruitment."],
	["fleets", "Fleets", "All your fleets, ships, admirals and shipbuilding."],
]

func _build_side_bar() -> void:
	side_bar = PanelContainer.new()
	side_bar.name = "SideBar"
	side_bar.theme_type_variation = "SideBar"
	side_bar.anchor_top = 0.0
	side_bar.anchor_bottom = 1.0
	side_bar.offset_left = 0.0
	side_bar.offset_top = 50.0
	side_bar.offset_right = SIDEBAR_WIDTH
	side_bar.offset_bottom = 0.0
	add_child(side_bar)
	move_child(side_bar, top_bar_panel.get_index())   # under the top bar's gold moulding
	var col := VBoxContainer.new()
	col.name = "SideButtons"
	col.add_theme_constant_override("separation", 4)
	side_bar.add_child(col)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	col.add_child(gap)
	var toggles := {
		"budget": _toggle_budget_window, "trade": _toggle_trade_window, "court": _toggle_court_window,
		"government": _toggle_government_window, "religion": _toggle_religion_window,
		"rebels": _toggle_rebels_window, "technology": _toggle_tech_window,
		"diplomacy": _toggle_diplomacy_window, "wars": _toggle_wars_window,
		"armies": _toggle_armies_window, "fleets": _toggle_fleets_window,
	}
	for spec in SIDE_SCREENS:
		add_side_button(spec[0], spec[1], spec[2], toggles[spec[0]])
	# old names, still used by the refresh code
	trade_btn = null
	court_btn = null
	diplomacy_btn = null
	tech_btn = null
	rebels_btn = null
	wars_btn = null

## Add a screen to the side column: `key` picks the medallion picture
## (see GezStyle / tools/uiart MEDALLIONS, e.g. "chronicle", "ledger",
## "timelapse"); on_press opens or closes the screen.
func add_side_button(key: String, title: String, summary: String, on_press: Callable) -> TextureButton:
	var col: Control = side_bar.get_node("SideButtons")
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52.0, 52.0)
	col.add_child(holder)
	var b := GezStyle.medallion_button(key, 50.0)
	b.position = Vector2(1.0, 1.0)
	holder.add_child(b)
	bind_tip(b, title, summary)
	b.pressed.connect(func() -> void:
		on_press.call()
		call_deferred("_sync_side_bar")
	)
	var badge := Label.new()
	badge.name = "Badge"
	badge.visible = false
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.62, 0.10, 0.07)
	bs.border_color = Color(0.95, 0.80, 0.45)
	bs.set_border_width_all(1)
	bs.set_corner_radius_all(9)
	bs.content_margin_left = 5.0
	bs.content_margin_right = 5.0
	badge.add_theme_stylebox_override("normal", bs)
	badge.position = Vector2(34.0, -2.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	side_bar_buttons[key] = b
	return b

## Small red count on a side-column medallion ("" hides it).
func set_side_badge(key: String, text: String) -> void:
	var b: TextureButton = side_bar_buttons.get(key, null)
	if b == null:
		return
	var badge: Label = b.get_parent().get_node("Badge")
	badge.text = text
	badge.visible = not text.is_empty()

var _last_side_sig: String = ""

## Red enamel on the medallion of every open screen.
func _sync_side_bar() -> void:
	var open := {
		"budget": _window_open(budget_ui, "budget_panel"), "trade": _window_open(trade_ui, "trade_panel"),
		"court": _window_open(court_ui, "court_panel"), "government": _window_open(gov_ui, "gov_panel"),
		"religion": _window_open(religion_ui, "rel_panel"), "rebels": _window_open(rebels_ui, "rebels_panel"),
		"technology": _window_open(tech_ui, "tech_panel"), "diplomacy": diplomacy_ui != null and diplomacy_ui.visible,
		"wars": _window_open(wars_ui, "wars_panel"), "armies": _window_open(army_ui, "armies_window_panel"),
		"fleets": _window_open(fleet_ui, "fleets_window_panel"),
	}
	var sig := str(open)
	if sig == _last_side_sig:
		return
	_last_side_sig = sig
	for k in open.keys():
		GezStyle.set_medallion_on(side_bar_buttons.get(k, null), bool(open[k]))

func _window_open(host: Node, panel_prop: String) -> bool:
	if host == null:
		return false
	var p: Variant = host.get(panel_prop)
	return p is Control and (p as Control).visible

func _build_map_mode_bar() -> void:
	var mode_panel := PanelContainer.new()
	mode_panel.name = "MapModeBar"
	mode_panel.theme_type_variation = "Bare"
	add_child(mode_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 1)
	mode_panel.add_child(hbox)

	var modes_spec := [
		{"key": "political", "title": "Political", "shortcut": "Q"},
		{"key": "diplomatic", "title": "Diplomatic", "shortcut": "O"},
		{"key": "states", "title": "States", "shortcut": "W"},
		{"key": "terrain", "title": "Terrain", "shortcut": "E"},
		{"key": "religion", "title": "Religion", "shortcut": "R"},
		{"key": "culture", "title": "Culture", "shortcut": "T"},
		{"key": "development", "title": "Development", "shortcut": "Y"},
		{"key": "goods", "title": "Goods", "shortcut": "U"},
		{"key": "markets", "title": "Markets", "shortcut": "I"},
		{"key": "plague", "title": "Plague", "shortcut": "P"},
		{"key": "unrest", "title": "Unrest", "shortcut": "L"},
		{"key": "institutions", "title": "Institutions", "shortcut": "K"}
	]
	map_mode_buttons.clear()
	for m in modes_spec:
		var k: String = m["key"]
		var title: String = m["title"]
		var sc: String = m["shortcut"]
		var btn := GezStyle.medallion_button("map_" + k, 36.0)
		bind_tip(btn, "%s Map Mode" % title, "Key %s" % sc)
		var mode_key := k
		btn.pressed.connect(func() -> void: _select_map_mode(mode_key))
		hbox.add_child(btn)
		map_mode_buttons[k] = btn

	mode_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	mode_panel.offset_top = 58.0
	_update_map_mode_button_styles()

func _build_zoom_buttons() -> void:
	var zoom_box := VBoxContainer.new()
	zoom_box.name = "ZoomButtons"
	zoom_box.add_theme_constant_override("separation", 4)
	add_child(zoom_box)

	var btn_in := GezStyle.medallion_button("zoom_in", 40.0)
	bind_tip(btn_in, "Zoom In", "Mouse wheel or pinch also zoom.")
	btn_in.pressed.connect(func() -> void: _zoom_by(1.5, size * 0.5))
	zoom_box.add_child(btn_in)

	var btn_out := GezStyle.medallion_button("zoom_out", 40.0)
	bind_tip(btn_out, "Zoom Out", "Mouse wheel or pinch also zoom.")
	btn_out.pressed.connect(func() -> void: _zoom_by(1.0 / 1.5, size * 0.5))
	zoom_box.add_child(btn_out)

	var btn_fit := GezStyle.medallion_button("zoom_fit", 40.0)
	bind_tip(btn_fit, "Show Whole Map (F)", "")
	btn_fit.pressed.connect(_show_whole_map)
	zoom_box.add_child(btn_fit)
	zoom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)

func _build_province_panel() -> void:
	province_panel = PanelContainer.new()
	province_panel.name = "ProvincePanel"
	province_panel.visible = false
	province_panel.custom_minimum_size = Vector2(330.0, 0.0)
	province_panel.add_theme_stylebox_override("panel", _make_panel_style())
	windows_layer.add_child(province_panel)

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
	close_btn.pressed.connect(_clear_selection)
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
			_open_diplomacy_with(prov_owner_index)
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
			_refresh_province_panel()
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
	windows_layer.add_child(sea_panel)

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
	close_btn.pressed.connect(_clear_selection)
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

func _build_market_panel() -> void:
	market_panel = PanelContainer.new()
	market_panel.name = "MarketPanel"
	market_panel.visible = false
	market_panel.custom_minimum_size = Vector2(390.0, 0.0)
	market_panel.add_theme_stylebox_override("panel", _make_panel_style())
	windows_layer.add_child(market_panel)

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

func _build_nation_picker_panel() -> void:
	nation_picker_panel = PanelContainer.new()
	nation_picker_panel.name = "NationPickerPanel"
	nation_picker_panel.visible = false
	nation_picker_panel.custom_minimum_size = Vector2(470.0, 0.0)
	nation_picker_panel.add_theme_stylebox_override("panel", _make_panel_style())
	windows_layer.add_child(nation_picker_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	nation_picker_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := _make_label("Choose Nation (1453)", Color(0.97, 0.90, 0.68), 18)
	GezStyle.as_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := GezStyle.medallion_button("close", 30.0)
	close_btn.pressed.connect(func() -> void: nation_picker_panel.visible = false)
	header.add_child(close_btn)

	vbox.add_child(_make_label("Click any country on the map, or pick a featured 1453 power below:", Color(0.82, 0.78, 0.68), 12))

	picker_featured_flow = HFlowContainer.new()
	picker_featured_flow.add_theme_constant_override("h_separation", 5)
	picker_featured_flow.add_theme_constant_override("v_separation", 5)
	vbox.add_child(picker_featured_flow)

	picker_search_input = LineEdit.new()
	picker_search_input.placeholder_text = "Search all countries by name or tag..."
	picker_search_input.text_changed.connect(func(_new_text: String) -> void: _refresh_picker_country_list())
	vbox.add_child(picker_search_input)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440.0, 170.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	picker_list_box = VBoxContainer.new()
	picker_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_list_box.add_theme_constant_override("separation", 3)
	scroll.add_child(picker_list_box)

	vbox.add_child(HSeparator.new())

	# Selected country details: name, coat of arms, ruler, treasury, provinces
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 12)
	vbox.add_child(card)

	picker_arms_rect = TextureRect.new()
	picker_arms_rect.custom_minimum_size = Vector2(54.0, 46.0)
	picker_arms_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picker_arms_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bind_tip(picker_arms_rect, "Selected Nation Arms", "Coat of arms of the realm currently previewed below.")
	card.add_child(picker_arms_rect)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 2)
	card.add_child(info_box)

	picker_name_label = _make_label("Ottoman Empire (TUR)", Color(0.98, 0.90, 0.65), 16)
	bind_tip(picker_name_label, "Country & Tag", "Official realm title and three-letter scenario tag.")
	info_box.add_child(picker_name_label)
	picker_meta_label = _make_label("Monarchy · Sunni", Color(0.80, 0.75, 0.65), 12)
	bind_tip(picker_meta_label, "Government & State Religion", "Starting government form and primary state faith on 30 May 1453.")
	info_box.add_child(picker_meta_label)
	picker_ruler_label = _make_label("Ruler: Mehmed II", Color(0.92, 0.89, 0.82), 13)
	bind_tip(picker_ruler_label, "Starting Ruler", "Monarch, Doge, Sultan or council leading this country at scenario start.")
	info_box.add_child(picker_ruler_label)

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 16)
	info_box.add_child(stats_row)
	picker_treasury_label = _make_label("Treasury: 0 ducats", Color(0.96, 0.82, 0.34), 13)
	bind_tip(picker_treasury_label, "Starting Treasury", "Initial ducat reserve available for armies, ships, buildings and trade.")
	stats_row.add_child(picker_treasury_label)
	picker_provinces_label = _make_label("Provinces: 0", Color(0.88, 0.85, 0.78), 13)
	bind_tip(picker_provinces_label, "Starting Realm Size", "Number of owned provinces and combined province development.")
	stats_row.add_child(picker_provinces_label)

	var ai_row := HBoxContainer.new()
	ai_row.add_theme_constant_override("separation", 8)
	vbox.add_child(ai_row)
	var ai_lbl := _make_label("AI behaviour:", Color(0.90, 0.86, 0.76), 13)
	ai_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_tip(ai_lbl, "Campaign AI Behaviour", "Choose Historical (1453-1553 historical objectives) or Free AI (opportunistic sandbox goals).")
	ai_row.add_child(ai_lbl)
	picker_ai_option = OptionButton.new()
	picker_ai_option.custom_minimum_size = Vector2(150.0, 0.0)
	bind_tip(picker_ai_option, "AI Mode Selector", "Applied when starting a new 1453 campaign.")
	picker_ai_option.item_selected.connect(_on_picker_ai_selected)
	ai_row.add_child(picker_ai_option)

	picker_ai_desc_label = _make_label("", Color(0.74, 0.71, 0.64), 11)
	picker_ai_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(picker_ai_desc_label)

	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 10)
	vbox.add_child(actions_row)

	var switch_btn := Button.new()
	switch_btn.text = "Switch Nation Now"
	switch_btn.tooltip_text = "Switch player country in the current campaign"
	switch_btn.pressed.connect(_on_picker_switch_pressed)
	actions_row.add_child(switch_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(spacer)

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.custom_minimum_size = Vector2(120.0, 34.0)
	start_btn.tooltip_text = "Start a new 1453 game as the selected country"
	start_btn.pressed.connect(_on_picker_start_pressed)
	actions_row.add_child(start_btn)

	# Dock top-left below the top bar so the map stays exposed for clicking countries.
	nation_picker_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	nation_picker_panel.offset_top = 60.0

func _build_game_menu_panel() -> void:
	game_menu_panel = PanelContainer.new()
	game_menu_panel.name = "GameMenuPanel"
	game_menu_panel.visible = false
	game_menu_panel.custom_minimum_size = Vector2(460.0, 0.0)
	game_menu_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(game_menu_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	game_menu_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := _make_label("Game Menu", Color(0.97, 0.90, 0.68), 18)
	GezStyle.as_title(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := GezStyle.medallion_button("close", 30.0)
	close_btn.pressed.connect(func() -> void: game_menu_panel.visible = false)
	header.add_child(close_btn)

	var playing_row := HBoxContainer.new()
	playing_row.add_theme_constant_override("separation", 8)
	vbox.add_child(playing_row)
	menu_playing_arms = TextureRect.new()
	menu_playing_arms.custom_minimum_size = Vector2(28.0, 24.0)
	menu_playing_arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_playing_arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	playing_row.add_child(menu_playing_arms)
	menu_playing_label = _make_label("Playing as Ottoman Empire · 30 May 1453", Color(0.90, 0.86, 0.78), 14)
	playing_row.add_child(menu_playing_label)

	menu_status_label = _make_label("", Color(0.96, 0.84, 0.42), 12)
	menu_status_label.visible = false
	vbox.add_child(menu_status_label)

	var new_game_btn := Button.new()
	new_game_btn.text = "New Game / Choose Nation..."
	new_game_btn.custom_minimum_size = Vector2(0.0, 32.0)
	new_game_btn.pressed.connect(func() -> void:
		game_menu_panel.visible = false
		_open_nation_picker()
	)
	vbox.add_child(new_game_btn)

	vbox.add_child(HSeparator.new())

	# Save & Quick Save
	vbox.add_child(_make_label("Save Game", Color(0.95, 0.88, 0.70), 14))
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 6)
	vbox.add_child(save_row)

	save_name_input = LineEdit.new()
	save_name_input.placeholder_text = "Save name (optional)"
	save_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(save_name_input)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	save_row.add_child(save_btn)

	var quick_save_btn := Button.new()
	quick_save_btn.text = "Quick Save"
	quick_save_btn.pressed.connect(_on_quick_save_pressed)
	save_row.add_child(quick_save_btn)

	# Autosave frequency
	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 8)
	vbox.add_child(auto_row)
	var auto_lbl := _make_label("Autosave frequency:", Color(0.84, 0.80, 0.72), 13)
	auto_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_row.add_child(auto_lbl)

	autosave_option_btn = OptionButton.new()
	autosave_option_btn.item_selected.connect(_on_autosave_selected)
	auto_row.add_child(autosave_option_btn)

	menu_pause_events_check = CheckBox.new()
	menu_pause_events_check.text = "Pause game on historical & chronicle events"
	menu_pause_events_check.button_pressed = true
	menu_pause_events_check.toggled.connect(func(enabled: bool) -> void:
		_call_bridge("setPauseOnEvents", [enabled], enabled)
	)
	vbox.add_child(menu_pause_events_check)

	vbox.add_child(HSeparator.new())

	# Load Game list
	var load_hdr := HBoxContainer.new()
	vbox.add_child(load_hdr)
	var load_title := _make_label("Load Game", Color(0.95, 0.88, 0.70), 14)
	load_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_hdr.add_child(load_title)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_game_menu)
	load_hdr.add_child(refresh_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430.0, 180.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	saves_list_box = VBoxContainer.new()
	saves_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saves_list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(saves_list_box)

	vbox.add_child(HSeparator.new())

	# Audio Settings (non-musical sound effects & ambience only)
	var audio_hdr := HBoxContainer.new()
	vbox.add_child(audio_hdr)
	var audio_title := _make_label("Sound Effects & Ambience", Color(0.95, 0.88, 0.70), 14)
	audio_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_tip(audio_title, "Sound Effects Only", "Volume controls for UI clicks, world/battle sound effects and camera-zoom ambience. Strictly no music.")
	audio_hdr.add_child(audio_title)

	menu_mute_check = CheckBox.new()
	menu_mute_check.text = "Mute All"
	bind_tip(menu_mute_check, "Master Mute", "Silence all UI clicks, effects and ambience across the whole game.")
	menu_mute_check.toggled.connect(func(muted: bool) -> void:
		var a := _audio()
		if a != null:
			a.call("set_master_muted", muted)
	)
	audio_hdr.add_child(menu_mute_check)

	var ui_row := HBoxContainer.new()
	ui_row.add_theme_constant_override("separation", 8)
	vbox.add_child(ui_row)
	var ui_lbl := _make_label("UI Clicks", Color(0.84, 0.80, 0.72), 12)
	ui_lbl.custom_minimum_size = Vector2(110.0, 0.0)
	ui_row.add_child(ui_lbl)
	menu_ui_slider = HSlider.new()
	menu_ui_slider.min_value = 0.0
	menu_ui_slider.max_value = 1.0
	menu_ui_slider.step = 0.05
	menu_ui_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_tip(menu_ui_slider, "UI Bus Volume", "Adjusts parchment and wood click volume. Saved in local settings.")
	menu_ui_slider.value_changed.connect(func(v: float) -> void:
		var a := _audio()
		if a != null:
			a.call("set_ui_volume", v)
		if menu_ui_val_lbl != null:
			menu_ui_val_lbl.text = "%d%%" % int(round(v * 100.0))
	)
	ui_row.add_child(menu_ui_slider)
	menu_ui_val_lbl = _make_label("85%", Color(0.92, 0.88, 0.78), 12)
	menu_ui_val_lbl.custom_minimum_size = Vector2(40.0, 0.0)
	menu_ui_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_row.add_child(menu_ui_val_lbl)

	var fx_row := HBoxContainer.new()
	fx_row.add_theme_constant_override("separation", 8)
	vbox.add_child(fx_row)
	var fx_lbl := _make_label("Effects", Color(0.84, 0.80, 0.72), 12)
	fx_lbl.custom_minimum_size = Vector2(110.0, 0.0)
	fx_row.add_child(fx_lbl)
	menu_fx_slider = HSlider.new()
	menu_fx_slider.min_value = 0.0
	menu_fx_slider.max_value = 1.0
	menu_fx_slider.step = 0.05
	menu_fx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_tip(menu_fx_slider, "Effects Bus Volume", "Adjusts coin clinks, marching boots, hoofbeats, construction hammers, cannons, swords and muskets.")
	menu_fx_slider.value_changed.connect(func(v: float) -> void:
		var a := _audio()
		if a != null:
			a.call("set_effects_volume", v)
		if menu_fx_val_lbl != null:
			menu_fx_val_lbl.text = "%d%%" % int(round(v * 100.0))
	)
	fx_row.add_child(menu_fx_slider)
	menu_fx_val_lbl = _make_label("80%", Color(0.92, 0.88, 0.78), 12)
	menu_fx_val_lbl.custom_minimum_size = Vector2(40.0, 0.0)
	menu_fx_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fx_row.add_child(menu_fx_val_lbl)

	var amb_row := HBoxContainer.new()
	amb_row.add_theme_constant_override("separation", 8)
	vbox.add_child(amb_row)
	var amb_lbl := _make_label("Ambience", Color(0.84, 0.80, 0.72), 12)
	amb_lbl.custom_minimum_size = Vector2(110.0, 0.0)
	amb_row.add_child(amb_lbl)
	menu_amb_slider = HSlider.new()
	menu_amb_slider.min_value = 0.0
	menu_amb_slider.max_value = 1.0
	menu_amb_slider.step = 0.05
	menu_amb_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_tip(menu_amb_slider, "Ambience Bus Volume", "Adjusts wind, sea waves and city murmur as camera zoom and focus change.")
	menu_amb_slider.value_changed.connect(func(v: float) -> void:
		var a := _audio()
		if a != null:
			a.call("set_ambience_volume", v)
		if menu_amb_val_lbl != null:
			menu_amb_val_lbl.text = "%d%%" % int(round(v * 100.0))
	)
	amb_row.add_child(menu_amb_slider)
	menu_amb_val_lbl = _make_label("55%", Color(0.92, 0.88, 0.78), 12)
	menu_amb_val_lbl.custom_minimum_size = Vector2(40.0, 0.0)
	menu_amb_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amb_row.add_child(menu_amb_val_lbl)

	vbox.add_child(HSeparator.new())

	var quit_btn := Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.custom_minimum_size = Vector2(0.0, 32.0)
	bind_tip(quit_btn, "Quit Game", "Exit Gez to desktop.")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_btn)

	game_menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

## Add a window (a new screen) next to the others: right of the side
## column, under the top bar. Use this for new screens.
func add_window(node: Control) -> void:
	windows_layer.add_child(node)

func _make_label(txt: String, col: Color, fsize: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", GezStyle.ink(col))
	lbl.add_theme_font_size_override("font_size", GezStyle.fs(fsize))
	return lbl

func _make_separator() -> VSeparator:
	var sep := VSeparator.new()
	sep.modulate = Color(0.68, 0.55, 0.28, 0.5)
	return sep

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _find_data_dir() -> String:
	var exe_dir := OS.get_executable_path().get_base_dir()
	var candidates := [
		exe_dir.path_join("Resources/data"),
		exe_dir.path_join("../Resources/data"),
		ProjectSettings.globalize_path("res://Resources/data"),
		ProjectSettings.globalize_path("res://../Packages/GezCore/Sources/GezCore/Resources"),
	]
	for dir_path in candidates:
		if FileAccess.file_exists(dir_path.path_join("scenario1453.json")):
			return dir_path
	return candidates[3]

func _find_asset_file(rel_path: String, dev_res_path: String) -> String:
	var exe_dir := OS.get_executable_path().get_base_dir()
	var candidates := [
		exe_dir.path_join("Resources").path_join(rel_path),
		exe_dir.path_join("../Resources").path_join(rel_path),
		ProjectSettings.globalize_path("res://Resources").path_join(rel_path),
		ProjectSettings.globalize_path(dev_res_path),
	]
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""

# Loads arms_<TAG>.png from App/Resources/Heraldry/ (or bundled Resources/Heraldry/) or creates a fallback banner in the country's colour.
func _get_country_arms_texture(tag: String, r: int = 180, g: int = 140, b: int = 80) -> Texture2D:
	var cache_key := tag if not tag.is_empty() else ("rgb_%d_%d_%d" % [r, g, b])
	if arms_cache.has(cache_key):
		return arms_cache[cache_key]

	# Phase 20 part 4: the arms in a gold-framed shield of the country's region
	# (made by tools/uiart/ui_art_concept.py --kit from the Heraldry pictures).
	if not tag.is_empty():
		var shield := GezStyle.tex("res://assets/ui/shields/%s.png" % tag)
		if shield != null:
			arms_cache[cache_key] = shield
			return shield

	if not tag.is_empty():
		var path := _find_asset_file("Heraldry/arms_%s.png" % tag, "res://../App/Resources/Heraldry/arms_%s.png" % tag)
		if not path.is_empty():
			var img := Image.load_from_file(path)
			if img != null:
				var tex := ImageTexture.create_from_image(img)
				arms_cache[cache_key] = tex
				return tex

	# Fallback plain swallow-tailed banner in the country's map colour (matches PlainBannerView)
	var w := 42
	var h := 30
	var fallback_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	fallback_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var fill_col := Color(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0)
	var border_col := Color(0.10, 0.08, 0.06, 0.90)
	var notch_x := float(w) * 0.78
	for y in range(h):
		var yn := absf(float(y) / float(h - 1) - 0.5) * 2.0
		var max_x := int(round(lerpf(notch_x, float(w - 1), yn)))
		for x in range(max_x + 1):
			var is_edge := (y == 0 or y == h - 1 or x == 0 or x >= max_x - 1)
			if is_edge:
				fallback_img.set_pixel(x, y, border_col)
			else:
				var shade := 1.08 - 0.16 * (float(x) / float(w) * 0.5 + float(y) / float(h) * 0.5)
				fallback_img.set_pixel(x, y, Color(
					clampf(fill_col.r * shade, 0.0, 1.0),
					clampf(fill_col.g * shade, 0.0, 1.0),
					clampf(fill_col.b * shade, 0.0, 1.0),
					1.0
				))
	var fallback_tex := ImageTexture.create_from_image(fallback_img)
	arms_cache[cache_key] = fallback_tex
	return fallback_tex

func _get_country_arms_icon(tag: String, r: int = 180, g: int = 140, b: int = 80) -> Texture2D:
	var cache_key := tag if not tag.is_empty() else ("rgb_%d_%d_%d" % [r, g, b])
	if arms_icon_cache.has(cache_key):
		return arms_icon_cache[cache_key]
	var full_tex := _get_country_arms_texture(tag, r, g, b)
	var img := full_tex.get_image()
	if img != null and not img.is_empty():
		var scaled := img.duplicate()
		if scaled.is_compressed():
			scaled.decompress()
		# keep the picture's shape (shields are taller than wide)
		var h := 18
		var w := maxi(1, int(round(float(scaled.get_width()) * h / float(scaled.get_height()))))
		scaled.resize(w, h, Image.INTERPOLATE_BILINEAR)
		var icon_tex := ImageTexture.create_from_image(scaled)
		arms_icon_cache[cache_key] = icon_tex
		return icon_tex
	arms_icon_cache[cache_key] = full_tex
	return full_tex

func _init_bridge_and_map() -> void:
	if not ClassDB.class_exists(&"GezGodotBridge"):
		selection_label.text = "ERROR: GezGodotBridge GDExtension not loaded. Run ./build_mac.sh first."
		push_error("GezGodotBridge class not found. Run ./build_mac.sh inside godot/.")
		return

	bridge = ClassDB.instantiate(&"GezGodotBridge")
	var data_dir := _find_data_dir()
	var ok: bool = bool(_call_bridge("setup", [data_dir, "TUR"], false))
	if not ok:
		selection_label.text = "Failed to load 1453 scenario from " + data_dir
		push_error("GezGodotBridge.setup failed for path: " + data_dir)
		return
	# CI's export jobs look for this line to prove the exported game starts.
	print("Gez: 1453 world loaded from ", data_dir)

	var w: int = int(_call_bridge("getMapWidth", [], 3936))
	var h: int = int(_call_bridge("getMapHeight", [], 2384))
	map_size = Vector2(float(w), float(h))
	style_tex_width = int(_call_bridge("getStyleTextureWidth", [], 2048))

	# Build ID map, sea map, and style textures.
	var id_bytes: PackedByteArray = _call_bridge("getProvinceIDBytes", [], PackedByteArray())
	var id_img := Image.create_from_data(w, h, false, Image.FORMAT_RG8, id_bytes)
	id_tex = ImageTexture.create_from_image(id_img)
	map_models.set("id_image", id_img)
	map_models.set("map_size", map_size)

	var sea_bytes: PackedByteArray = _call_bridge("getSeaIDBytes", [], PackedByteArray())
	var sea_img := Image.create_from_data(w, h, false, Image.FORMAT_RG8, sea_bytes)
	sea_tex = ImageTexture.create_from_image(sea_img)

	var style_bytes: PackedByteArray = _call_bridge("getStyleBytes", [], PackedByteArray())
	var style_img := Image.create_from_data(style_tex_width, 2, false, Image.FORMAT_RGBA8, style_bytes)
	style_tex = ImageTexture.create_from_image(style_img)

	var terrain_path := _find_asset_file("Terrain/terrain.jpg", "res://../App/Resources/Terrain/terrain.jpg")
	if not terrain_path.is_empty():
		var terrain_img := Image.load_from_file(terrain_path)
		if terrain_img != null:
			terrain_tex = ImageTexture.create_from_image(terrain_img)

	map3d.call("set_map_size", map_size)
	projector.set("map_size", map_size)
	var height_path := _find_asset_file("Terrain/height.png", "res://../App/Resources/Terrain/height.png")
	if not height_path.is_empty():
		var height_img := Image.load_from_file(height_path)
		if height_img != null:
			height_img.convert(Image.FORMAT_L8)
			projector.call("set_height_image", height_img)
			map3d.call("set_height_texture", ImageTexture.create_from_image(height_img))
	map_material.set_shader_parameter("map_size", map_size)
	map_material.set_shader_parameter("id_tex", id_tex)
	map_material.set_shader_parameter("sea_tex", sea_tex)
	map_material.set_shader_parameter("style_tex", style_tex)
	if terrain_tex != null:
		map_material.set_shader_parameter("terrain_tex", terrain_tex)

	_refresh_all_labels()
	_refresh_town_icons()
	_populate_autosave_options()
	if battle_view != null:
		battle_view.call("set_bridge", bridge)
	_refresh_top_bar()
	_refresh_armies()

func _refresh_town_icons() -> void:
	if bridge == null or icons_layer == null:
		return
	var rev: int = int(_call_bridge("getTownIconsRevision", [], -1))
	if rev == last_town_icons_rev and rev >= 0:
		return
	last_town_icons_rev = rev
	var packed: PackedFloat32Array = _call_bridge("getTownIconsData", [], PackedFloat32Array())
	icons_layer.call("set_icons_data", packed, rev)
	# Phase 17: 3D towns replace the 2D icons (the 2D layer stays as a fallback
	# if the model library cannot be loaded).
	if map_models != null and bool(map_models.call("ready_ok")):
		icons_layer.visible = false
		var model_data: PackedFloat32Array = _call_bridge("getTownModelData", [], PackedFloat32Array())
		map_models.call("set_towns", packed, model_data)

func _refresh_all_labels() -> void:
	if bridge == null:
		return
	labels_layer.call(
		"set_country_labels",
		_call_bridge("getCountryLabelTexts", [], PackedStringArray()),
		_call_bridge("getCountryLabelMetrics", [], PackedFloat32Array())
	)
	labels_layer.call(
		"set_province_labels",
		_call_bridge("getProvinceLabelTexts", [], PackedStringArray()),
		_call_bridge("getProvinceLabelMetrics", [], PackedFloat32Array())
	)
	labels_layer.call(
		"set_sea_labels",
		_call_bridge("getSeaLabelTexts", [], PackedStringArray()),
		_call_bridge("getSeaLabelMetrics", [], PackedFloat32Array())
	)

func _process(delta: float) -> void:
	elapsed_time += delta
	map_material.set_shader_parameter("time_sec", elapsed_time)
	# Ease the camera tilt towards the pitch for the current zoom.
	if zoom > 0.0:
		var want_pitch := _target_pitch()
		if absf(want_pitch - view_pitch) > 0.05:
			view_pitch = lerpf(view_pitch, want_pitch, clampf(delta * 7.0, 0.0, 1.0))
			_sync_camera_uniforms()
	var cur_fps := int(Engine.get_frames_per_second())
	if cur_fps != _last_fps:
		_last_fps = cur_fps
		fps_label.text = "%d FPS" % cur_fps

	var in_battle := (battle_view != null and battle_view.visible) or (battle_choice_panel != null and battle_choice_panel.visible)
	# The battle view covers the screen: do not draw the 3D map under it.
	if map3d != null:
		map3d.visible = not (battle_view != null and battle_view.visible)

	# Arrow-key panning when no text input is focused
	if not in_battle and not _is_text_input_focused():
		var pan_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT):
			pan_dir.x += 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			pan_dir.x -= 1.0
		if Input.is_key_pressed(KEY_UP):
			pan_dir.y += 1.0
		if Input.is_key_pressed(KEY_DOWN):
			pan_dir.y -= 1.0
		if pan_dir != Vector2.ZERO and zoom > 0.0:
			offset = _clamped_offset(offset + pan_dir.normalized() * 650.0 * delta, zoom)
			_sync_camera_uniforms()

	if bridge == null or in_battle:
		return

	var mask: int = int(_call_bridge("tickFrame", [delta], 0))
	if bool(_call_bridge("hasPendingBattlePrompt", [], false)):
		open_battle_choice_modal()
		_refresh_top_bar()
		_refresh_armies()
		_refresh_fleets()
	if event_popup != null and bool(_call_bridge("hasPendingEvent", [], false)):
		event_popup.call("open_pending_if_new", false)
		_refresh_top_bar()
	if mask != 0:
		_refresh_top_bar()
		if (mask & 1) != 0:
			_refresh_armies()
			_refresh_fleets()
			if province_panel.visible and current_prov_tab == "overview":
				_refresh_province_panel()
			if wars_ui != null:
				wars_ui.call("refresh_if_open")
			var audio_evts: Variant = _call_bridge("consumeAudioEvents", [], [])
			if audio_evts is Array and not (audio_evts as Array).is_empty():
				var a := _audio()
				if a != null:
					a.call("play_events", audio_evts)
		if (mask & 2) != 0:
			_refresh_fleets()
			# Monthly tick updated economy, constructions, populations, or markets
			if province_panel.visible:
				_refresh_province_panel()
			if market_panel.visible:
				_refresh_market_panel()
			if budget_ui != null:
				budget_ui.call("refresh_if_open")
			if trade_ui != null:
				trade_ui.call("refresh_if_open")
				if bool(trade_ui.call("is_open")):
					_refresh_trade_routes()
			if court_ui != null:
				court_ui.call("refresh_if_open")
			if gov_ui != null:
				gov_ui.call("refresh_if_open")
			if religion_ui != null:
				religion_ui.call("refresh_if_open")
			if rebels_ui != null:
				rebels_ui.call("refresh_if_open")
			if tech_ui != null:
				tech_ui.call("refresh_if_open")
			if diplomacy_ui != null:
				diplomacy_ui.call("refresh_if_open")
			if current_map_mode == "religion" or current_map_mode == "culture" or current_map_mode == "plague" or current_map_mode == "unrest" or current_map_mode == "institutions":
				_refresh_styles_and_country_labels()
				_refresh_faith_overlay()
		if (mask & 4) != 0:
			_refresh_styles_and_country_labels()
		if (mask & 6) != 0:
			_refresh_town_icons()
		if (mask & 8) != 0 and game_menu_panel.visible:
			_refresh_game_menu()

func _is_text_input_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit

func _refresh_styles_and_country_labels() -> void:
	if bridge == null:
		return
	var style_bytes: PackedByteArray = _call_bridge("getStyleBytes", [], PackedByteArray())
	if not style_bytes.is_empty():
		if _style_img == null:
			_style_img = Image.create_from_data(style_tex_width, 2, false, Image.FORMAT_RGBA8, style_bytes)
		else:
			_style_img.set_data(style_tex_width, 2, false, Image.FORMAT_RGBA8, style_bytes)
		style_tex.update(_style_img)
	labels_layer.call(
		"set_country_labels",
		_call_bridge("getCountryLabelTexts", [], PackedStringArray()),
		_call_bridge("getCountryLabelMetrics", [], PackedFloat32Array())
	)

# If the top bar's buttons need more room than the window has, shrink the
# whole row a little so the date, pause and speed buttons stay on screen
# (new buttons such as "Fleets" kept pushing them off the right edge).
func _fit_top_bar() -> void:
	if top_bar_hbox == null or top_bar_panel == null:
		return
	var need := top_bar_hbox.get_combined_minimum_size().x + 32.0
	var vw := get_viewport_rect().size.x
	var s := 1.0
	if need > 0.0 and vw > 0.0 and need > vw:
		s = maxf(0.6, vw / need)
	top_bar_panel.anchor_right = 0.0
	top_bar_panel.pivot_offset = Vector2.ZERO
	top_bar_panel.scale = Vector2(s, s)
	if vw > 0.0:
		top_bar_panel.size = Vector2(vw / s, top_bar_panel.size.y)

func _refresh_top_bar() -> void:
	call_deferred("_fit_top_bar")
	if bridge == null:
		return
	var top_var: Variant = _call_bridge("getPlayerTopBarDetails", [], {})
	var top: Dictionary = top_var if top_var is Dictionary else {}
	var c_name: String = str(top.get("name", "Observer"))
	var c_tag: String = str(top.get("tag", "OBS"))
	var cr: int = int(top.get("colorR", 180))
	var cg: int = int(top.get("colorG", 140))
	var cb: int = int(top.get("colorB", 80))

	var country_str := "%s (%s)" % [c_name, c_tag]
	if country_str != _last_top_country_str:
		_last_top_country_str = country_str
		top_country_btn.text = c_name
		top_country_btn.tooltip_text = "%s · choose or switch nation" % country_str
	var arms_key := "%s|%d|%d|%d" % [c_tag, cr, cg, cb]
	if arms_key != _last_top_arms_key:
		_last_top_arms_key = arms_key
		top_arms_rect.texture = _get_country_arms_texture(c_tag, cr, cg, cb)

	if treasury_btn != null:
		var duc_str := str(top.get("ducatsText", "0 (+0.0/mo)"))
		if duc_str != _last_ducats_str:
			_last_ducats_str = duc_str
			# "417 (+14.0/mo)" -> "417  +14.0"
			treasury_btn.text = duc_str.replace(" (", "  ").replace("/mo)", "")
	if inflation_label != null:
		var infl: int = int(top.get("inflationPercent", 0))
		inflation_label.get_parent().visible = infl >= 1
		inflation_label.text = "%d%%" % infl
	if stability_btn != null:
		var stab: int = int(top.get("stability", 0))
		var stab_str: String = str(top.get("stabilityText", "Stability +0"))
		if stab_str != _last_stab_str:
			_last_stab_str = stab_str
			stability_btn.text = stab_str.replace("Stability", "").strip_edges()
		var stab_neg := 1 if stab < 0 else 0
		if stab_neg != _last_stab_neg:
			_last_stab_neg = stab_neg
			stability_btn.modulate = Color(1.0, 0.55, 0.48) if stab < 0 else Color(1, 1, 1)
	if religion_btn != null:
		var r_str: String = str(top.get("religionButtonText", "Religion"))
		if r_str != _last_rel_btn_str:
			_last_rel_btn_str = r_str
			# "Sunni · 0/1": the faith's name; missionaries in the tooltip
			religion_btn.text = r_str.get_slice(" · ", 0)
			bind_tip(religion_btn, "State Religion: %s" % r_str.get_slice(" · ", 0), "Missionaries in use / available: %s. Click for Religion & Cultures." % (r_str.get_slice(" · ", 1) if r_str.contains(" · ") else "—"))
	var rb_str: String = str(top.get("rebelsButtonText", "Rebels"))
	if rb_str != _last_rebels_btn_str:
		_last_rebels_btn_str = rb_str
		# "Rebels", "Rebels 2" or "Rebels 2!" -> a badge on the side column
		set_side_badge("rebels", rb_str.replace("Rebels", "").strip_edges())
	var t_str: String = str(top.get("techButtonText", "Tech"))
	if t_str != _last_tech_btn_str:
		_last_tech_btn_str = t_str
		var tb: Control = side_bar_buttons.get("technology", null)
		if tb != null:
			bind_breakdown(tb, func() -> Variant: return _call_bridge("getResearchSpeedBreakdown", ["administrative"], {}), "Technology %s" % t_str.replace("Tech", "").strip_edges())
	var wars_cnt: int = int(top.get("activeWarsCount", 0))
	var pending_cnt: int = int(top.get("pendingPeaceOffersCount", 0))
	var wars_str := "%d!" % wars_cnt if pending_cnt > 0 else ("%d" % wars_cnt if wars_cnt > 0 else "")
	if wars_str != _last_wars_str:
		_last_wars_str = wars_str
		set_side_badge("wars", wars_str)
	if armies_btn != null:
		var a_str: String = str(top.get("armiesText", "Armies 0 · MP 0"))
		if a_str != _last_armies_btn_str:
			_last_armies_btn_str = a_str
			# "Armies 24k · MP 39k" -> manpower "39k" (army size on hover)
			armies_btn.text = a_str.get_slice("MP ", 1) if a_str.contains("MP ") else a_str
			var ab: Control = side_bar_buttons.get("armies", null)
			if ab != null:
				bind_tip(ab, "Armies (%s)" % a_str.get_slice(" · ", 0).replace("Armies ", ""), "All your armies, regiments, generals and recruitment.")
	if fleets_btn != null:
		var f_str: String = str(top.get("fleetsText", "Fleets 0"))
		if f_str != _last_fleets_btn_str:
			_last_fleets_btn_str = f_str
			# "Fleets 24 · Sailors 18.7k" -> sailors "18.7k"
			fleets_btn.text = f_str.get_slice("Sailors ", 1) if f_str.contains("Sailors ") else f_str
			var fb: Control = side_bar_buttons.get("fleets", null)
			if fb != null:
				bind_tip(fb, "Fleets (%s ships)" % f_str.get_slice(" · ", 0).replace("Fleets ", ""), "All your fleets, ships, admirals and shipbuilding.")

	var d_str: String = str(top.get("dateText", "30 May 1453"))
	if d_str != _last_date_str:
		_last_date_str = d_str
		date_label.text = d_str

	var paused: bool = bool(top.get("isPaused", true))
	var spd: int = int(top.get("speed", 0))
	var p_int := 1 if paused else 0
	if p_int != _last_paused_int or spd != _last_speed_int:
		_last_paused_int = p_int
		_last_speed_int = spd
		var a := _audio()
		if a != null:
			a.call("set_game_paused", paused)
		GezStyle.set_medallion_on(pause_btn, paused)
		for i in range(speed_buttons.size()):
			# lit chevrons up to the current speed (dim while paused)
			var lit := i < spd
			speed_buttons[i].modulate = (Color(1, 1, 1) if not paused else Color(0.85, 0.72, 0.52)) if lit else Color(0.62, 0.50, 0.38)
	_sync_side_bar()

	var alerts_sig: String = str(top.get("alertsSignature", ""))
	if alerts_sig != _last_alerts_sig:
		_last_alerts_sig = alerts_sig
		_refresh_alerts_bar()

	var recent_sig: String = str(top.get("recentEventsSignature", ""))
	if recent_sig != _last_recent_events_sig:
		_last_recent_events_sig = recent_sig
		_refresh_recent_events()

# MARK: - Map Modes (Q to I)

func _select_map_mode(mode_key: String) -> void:
	if bridge == null:
		return
	var ok: bool = bool(_call_bridge("setMapMode", [mode_key], false))
	if not ok:
		return
	current_map_mode = str(_call_bridge("getMapMode", [], mode_key))
	var shader_mode: int = int(_call_bridge("getShaderModeIndex", [], 0))
	map_material.set_shader_parameter("mode", shader_mode)
	if labels_layer != null and labels_layer.has_method("set_map_mode"):
		labels_layer.call("set_map_mode", current_map_mode)
	_update_map_mode_button_styles()
	_sync_camera_uniforms()
	_refresh_styles_and_country_labels()
	_refresh_faith_overlay()

func _update_map_mode_button_styles() -> void:
	for k in map_mode_buttons.keys():
		GezStyle.set_medallion_on(map_mode_buttons[k], str(k) == current_map_mode)

# MARK: - Game Menu (Esc & Top-Bar Button)

func _populate_autosave_options() -> void:
	if autosave_option_btn == null:
		return
	autosave_option_btn.clear()
	autosave_keys.clear()
	var opts: Array = _call_bridge("getAutosaveOptions", [], [])
	if opts.is_empty():
		opts = [
			{"key": "monthly", "title": "Monthly"},
			{"key": "every_three_months", "title": "Every 3 months"},
			{"key": "every_six_months", "title": "Every 6 months"},
			{"key": "yearly", "title": "Yearly"},
			{"key": "never", "title": "Never"}
		]
	for item in opts:
		if item is Dictionary:
			var k: String = str(item.get("key", ""))
			var t: String = str(item.get("title", k))
			autosave_keys.append(k)
			autosave_option_btn.add_item(t)

func _toggle_game_menu() -> void:
	if game_menu_panel.visible:
		game_menu_panel.visible = false
	else:
		nation_picker_panel.visible = false
		game_menu_panel.visible = true
		_refresh_game_menu()

func _refresh_game_menu() -> void:
	if bridge == null or game_menu_panel == null:
		return
	var c_name: String = str(_call_bridge("getCountryName", [], "Observer"))
	var d_text: String = str(_call_bridge("getDateText", [], "30 May 1453"))
	var ai_name: String = str(_call_bridge("getAISettingDisplayName", [], "Historical"))
	menu_playing_label.text = "Playing as %s · %s · AI: %s" % [c_name, d_text, ai_name]
	# Same coat of arms as the top bar (the Apple game menu shows it too).
	if menu_playing_arms != null and top_arms_rect != null:
		menu_playing_arms.texture = top_arms_rect.texture
		menu_playing_arms.visible = top_arms_rect.texture != null

	var status: String = str(_call_bridge("getLastSaveStatus", [], ""))
	menu_status_label.text = status
	menu_status_label.visible = not status.is_empty()

	var cur_freq: String = str(_call_bridge("getAutosaveFrequency", [], "never"))
	var freq_idx := autosave_keys.find(cur_freq)
	if freq_idx >= 0 and freq_idx < autosave_option_btn.item_count:
		autosave_option_btn.selected = freq_idx

	_sync_pause_on_events_ui()

	var a := _audio()
	if a != null:
		if menu_mute_check != null:
			menu_mute_check.set_pressed_no_signal(bool(a.get("master_muted")))
		if menu_ui_slider != null:
			var uv := float(a.get("ui_volume"))
			menu_ui_slider.set_value_no_signal(uv)
			if menu_ui_val_lbl != null:
				menu_ui_val_lbl.text = "%d%%" % int(round(uv * 100.0))
		if menu_fx_slider != null:
			var fv := float(a.get("effects_volume"))
			menu_fx_slider.set_value_no_signal(fv)
			if menu_fx_val_lbl != null:
				menu_fx_val_lbl.text = "%d%%" % int(round(fv * 100.0))
		if menu_amb_slider != null:
			var av := float(a.get("ambience_volume"))
			menu_amb_slider.set_value_no_signal(av)
			if menu_amb_val_lbl != null:
				menu_amb_val_lbl.text = "%d%%" % int(round(av * 100.0))

	_clear_children(saves_list_box)
	var saves: Array = _call_bridge("getSavedGames", [], [])
	if saves.is_empty():
		saves_list_box.add_child(_make_label("No saved games found yet.", Color(0.75, 0.72, 0.65), 12))
		return

	for entry in saves:
		if not (entry is Dictionary):
			continue
		var idx: int = int(entry.get("index", 0))
		var s_name: String = str(entry.get("name", "Save"))
		var s_date: String = str(entry.get("gameDate", ""))
		var s_player: String = str(entry.get("playerName", "Unknown"))
		var is_auto: bool = bool(entry.get("isAutosave", false))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		saves_list_box.add_child(row)

		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)

		var title_line := s_name + (" [AUTO]" if is_auto else "")
		text_col.add_child(_make_label(title_line, Color(0.96, 0.92, 0.82), 13))
		text_col.add_child(_make_label("%s · %s" % [s_player, s_date], Color(0.78, 0.74, 0.66), 11))

		var load_btn := Button.new()
		load_btn.text = "Load"
		var save_idx := idx
		load_btn.pressed.connect(func() -> void: _on_load_save_pressed(save_idx))
		row.add_child(load_btn)

		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.pressed.connect(func() -> void: _on_delete_save_pressed(save_idx))
		row.add_child(del_btn)

func _on_save_pressed() -> void:
	var custom_name := save_name_input.text
	_call_bridge("saveGame", [custom_name], false)
	save_name_input.text = ""
	_refresh_game_menu()

func _on_quick_save_pressed() -> void:
	_call_bridge("quickSave", [], false)
	_refresh_game_menu()

func _on_autosave_selected(idx: int) -> void:
	if idx >= 0 and idx < autosave_keys.size():
		_call_bridge("setAutosaveFrequency", [autosave_keys[idx]], false)

func _on_load_save_pressed(idx: int) -> void:
	var loaded: bool = bool(_call_bridge("loadSavedGame", [idx], false))
	if loaded:
		_after_world_replaced()
		_refresh_game_menu()

func _on_delete_save_pressed(idx: int) -> void:
	_call_bridge("deleteSavedGame", [idx], false)
	_refresh_game_menu()

func _after_world_replaced() -> void:
	map_material.set_shader_parameter("selected", 0)
	map_material.set_shader_parameter("selected_sea", 0)
	province_panel.visible = false
	sea_panel.visible = false
	open_market_index = -1
	market_panel.visible = false
	if event_popup != null:
		event_popup.visible = false
		event_popup.call("reset_seen")
	_last_alerts_sig = "__init__"
	_last_recent_events_sig = "__init__"
	_close_top_left_windows()
	_refresh_all_labels()
	_refresh_styles_and_country_labels()
	_refresh_town_icons()
	_refresh_top_bar()
	_refresh_recent_events()
	_refresh_play_as_button()
	_refresh_armies()
	_refresh_fleets()
	_refresh_trade_routes()
	_refresh_faith_overlay()

func _refresh_armies(force: bool = false) -> void:
	if bridge == null:
		return
	var sig: int = int(_call_bridge("getMapArmiesSignature", [], -1))
	if not force and sig == _last_armies_sig:
		return
	_last_armies_sig = sig
	var armies_data: Variant = _call_bridge("getMapArmiesData", [], {})
	if armies_data is Dictionary and map_models != null and bool(map_models.call("ready_ok")):
		# Marching figures: where each army is walking and how far along it is.
		var motion: Dictionary = {}
		var mv: Variant = _call_bridge("getMapArmyMotion", [], {})
		if mv is Dictionary:
			for a in (mv as Dictionary).get("armies", []):
				if a is Dictionary:
					motion[int(a.get("armyId", -1))] = a
		var counters: Array = (armies_data as Dictionary).get("counters", [])
		for c in counters:
			if c is Dictionary:
				var dp: Vector2 = MapModelsScript.army_draw_point(c, motion.get(int(c.get("armyId", -1)), {}))
				c["drawX"] = dp.x
				c["drawY"] = dp.y
		map_models.call("set_armies", counters, motion)
	if armies_layer != null:
		armies_layer.call("set_armies_data", armies_data)
	if army_ui != null:
		army_ui.call("refresh_all")

func _refresh_fleets(force: bool = false) -> void:
	if bridge == null:
		return
	var sig: int = int(_call_bridge("getMapFleetsSignature", [], -1))
	if not force and sig == _last_fleets_sig:
		return
	_last_fleets_sig = sig
	var fleets_data: Variant = _call_bridge("getMapFleetsData", [], {})
	if fleets_data is Dictionary and map_models != null and bool(map_models.call("ready_ok")):
		var styles: Dictionary = {}
		var fs: Variant = _call_bridge("getMapFleetStyles", [], {})
		if fs is Dictionary:
			var ids: Array = (fs as Dictionary).get("fleetIds", [])
			var sts: Array = (fs as Dictionary).get("styles", [])
			for k in range(mini(ids.size(), sts.size())):
				styles[int(ids[k])] = int(sts[k])
		map_models.call("set_fleets", (fleets_data as Dictionary).get("counters", []), styles)
	if fleets_layer != null:
		fleets_layer.call("set_fleets_data", fleets_data)
	if fleet_ui != null:
		fleet_ui.call("refresh_all")

func _after_army_action() -> void:
	_refresh_armies(true)
	_refresh_fleets(true)
	_refresh_top_bar()
	if province_panel.visible:
		_refresh_province_panel()

func _after_fleet_action() -> void:
	_refresh_fleets(true)
	_refresh_armies(true)
	_refresh_top_bar()
	if province_panel.visible:
		_refresh_province_panel()
	if sea_panel.visible:
		_refresh_sea_panel()

func _select_province_by_index(prov_idx: int) -> void:
	var sel_id: int = int(_call_bridge("selectProvinceByIndex", [prov_idx], 0))
	if sel_id >= 2:
		map_material.set_shader_parameter("selected", sel_id)
		map_material.set_shader_parameter("selected_sea", 0)
		prov_show_build = false
		prov_show_shipbuild = false
		_refresh_province_panel()
		_refresh_play_as_button()

# MARK: - Nation Picker

func _toggle_nation_picker() -> void:
	if nation_picker_panel.visible:
		nation_picker_panel.visible = false
	else:
		_open_nation_picker()

func _open_nation_picker() -> void:
	game_menu_panel.visible = false
	_close_top_left_windows()
	nation_picker_panel.visible = true
	var cur_tag: String = str(_call_bridge("getCountryTag", [], "TUR"))
	if not cur_tag.is_empty() and cur_tag != "OBS":
		selected_picker_tag = cur_tag

	# Populate featured 1453 powers
	_clear_children(picker_featured_flow)
	var featured: Array = _call_bridge("getFeaturedCountries", [], [])
	for item in featured:
		if not (item is Dictionary):
			continue
		var tag: String = str(item.get("tag", ""))
		var cname: String = str(item.get("name", tag))
		var cr: int = int(item.get("colorR", 180))
		var cg: int = int(item.get("colorG", 140))
		var cb: int = int(item.get("colorB", 80))
		var btn := Button.new()
		btn.text = cname
		btn.icon = _get_country_arms_icon(tag, cr, cg, cb)
		var t := tag
		btn.pressed.connect(func() -> void: _select_picker_country(t, true))
		picker_featured_flow.add_child(btn)

	cached_all_countries = _call_bridge("getAllCountries", [], [])
	_populate_ai_setting_options()
	_refresh_picker_country_list()
	_refresh_picker_selected_details()

func _populate_ai_setting_options() -> void:
	if picker_ai_option == null:
		return
	picker_ai_option.clear()
	picker_ai_keys.clear()
	picker_ai_descs.clear()
	var opts: Array = _call_bridge("getAISettingOptions", [], [])
	if opts.is_empty():
		opts = [
			{
				"key": "historical",
				"title": "Historical",
				"description": "AI pursues post-1453 historical goals when feasible, falling back to Free if its list runs out."
			},
			{
				"key": "free",
				"title": "Free",
				"description": "AI evaluates opportunities purely from threats, weak neighbours, wealth, alliances, and ruler traits."
			}
		]
	for item in opts:
		if item is Dictionary:
			var k: String = str(item.get("key", "historical"))
			var t: String = str(item.get("title", k.capitalize()))
			var desc: String = str(item.get("description", ""))
			picker_ai_keys.append(k)
			picker_ai_descs.append(desc)
			picker_ai_option.add_item(t)
	var cur_ai: String = str(_call_bridge("getAISetting", [], "historical"))
	var sel_idx := picker_ai_keys.find(cur_ai)
	if sel_idx < 0:
		sel_idx = 0
	if picker_ai_option.item_count > 0:
		picker_ai_option.select(sel_idx)
		_on_picker_ai_selected(sel_idx)

func _on_picker_ai_selected(idx: int) -> void:
	if picker_ai_desc_label != null and idx >= 0 and idx < picker_ai_descs.size():
		picker_ai_desc_label.text = picker_ai_descs[idx]

func _refresh_picker_country_list() -> void:
	_clear_children(picker_list_box)
	var q := picker_search_input.text.strip_edges().to_lower()
	for item in cached_all_countries:
		if not (item is Dictionary):
			continue
		var tag: String = str(item.get("tag", ""))
		var cname: String = str(item.get("name", ""))
		if not q.is_empty() and not cname.to_lower().contains(q) and not tag.to_lower().contains(q):
			continue
		var provs: int = int(item.get("provinces", 0))
		var dev: int = int(item.get("development", 0))
		var cr: int = int(item.get("colorR", 180))
		var cg: int = int(item.get("colorG", 140))
		var cb: int = int(item.get("colorB", 80))
		var btn := Button.new()
		btn.text = "%s (%s) — %d prov, %d dev" % [cname, tag, provs, dev]
		btn.icon = _get_country_arms_icon(tag, cr, cg, cb)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if tag == selected_picker_tag:
			btn.modulate = Color(1.0, 0.88, 0.42)
		var t := tag
		btn.pressed.connect(func() -> void: _select_picker_country(t, true))
		picker_list_box.add_child(btn)

func _select_picker_country(tag: String, pan_to_country: bool = false) -> void:
	if tag.is_empty():
		return
	selected_picker_tag = tag
	_refresh_picker_country_list()
	var details: Dictionary = _call_bridge("getCountryDetails", [tag], {})
	_apply_picker_details(details)
	if pan_to_country and details.has("focusX") and details.has("focusY") and zoom > 0.0:
		var fx := float(details["focusX"])
		var fy := float(details["focusY"])
		offset = _clamped_offset(Vector2(size.x * 0.5 - fx * zoom, size.y * 0.5 - fy * zoom), zoom)
		_sync_camera_uniforms()

func _refresh_picker_selected_details() -> void:
	var details: Dictionary = _call_bridge("getCountryDetails", [selected_picker_tag], {})
	_apply_picker_details(details)

func _apply_picker_details(details: Dictionary) -> void:
	if details.is_empty():
		return
	var tag: String = str(details.get("tag", selected_picker_tag))
	var cname: String = str(details.get("name", tag))
	var gov: String = str(details.get("government", ""))
	var rel: String = str(details.get("religion", ""))
	var ruler: String = str(details.get("ruler", "Interregnum"))
	var treasury_txt: String = str(details.get("treasuryText", "0 ducats"))
	var provs: int = int(details.get("provinces", 0))
	var dev: int = int(details.get("development", 0))
	var cr: int = int(details.get("colorR", 180))
	var cg: int = int(details.get("colorG", 140))
	var cb: int = int(details.get("colorB", 80))

	picker_arms_rect.texture = _get_country_arms_texture(tag, cr, cg, cb)
	picker_name_label.text = "%s (%s)" % [cname, tag]
	picker_meta_label.text = "%s · %s" % [gov, rel]
	picker_ruler_label.text = "Ruler: %s" % ruler
	picker_treasury_label.text = "Treasury: %s" % treasury_txt
	picker_provinces_label.text = "Provinces: %d (%d dev)" % [provs, dev]

func _on_picker_switch_pressed() -> void:
	var ok: bool = bool(_call_bridge("switchPlayer", [selected_picker_tag], false))
	if ok:
		nation_picker_panel.visible = false
		_refresh_styles_and_country_labels()
		_refresh_top_bar()
		_refresh_play_as_button()
		_refresh_armies()
		_after_economy_action()

func _on_picker_start_pressed() -> void:
	var details: Dictionary = _call_bridge("getCountryDetails", [selected_picker_tag], {})
	var ai_key := "historical"
	if picker_ai_option != null and picker_ai_option.selected >= 0 and picker_ai_option.selected < picker_ai_keys.size():
		ai_key = picker_ai_keys[picker_ai_option.selected]
	var ok: bool = bool(_call_bridge("startNewGameWithAI", [selected_picker_tag, ai_key], false))
	if ok:
		nation_picker_panel.visible = false
		_after_world_replaced()
		if details.has("focusX") and details.has("focusY") and zoom > 0.0:
			var fx := float(details["focusX"])
			var fy := float(details["focusY"])
			offset = _clamped_offset(Vector2(size.x * 0.5 - fx * zoom, size.y * 0.5 - fy * zoom), zoom)
			_sync_camera_uniforms()

# MARK: - Province Panel, Sea Panel & Market Panel

func _clear_selection() -> void:
	_call_bridge("clearSelection")
	map_material.set_shader_parameter("selected", 0)
	map_material.set_shader_parameter("selected_sea", 0)
	province_panel.visible = false
	sea_panel.visible = false
	selection_label.text = "Click a province to inspect"
	_refresh_play_as_button()

func _refresh_province_panel() -> void:
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
	prov_owner_arms.texture = _get_country_arms_texture(owner_tag, cr, cg, cb) if prov_owner_arms.visible else null
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
			if court_ui != null:
				_close_top_left_windows("court")
				court_ui.call("open_window", holder_idx)
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
					_refresh_province_panel()
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
						_refresh_province_panel()
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

	if army_ui != null:
		army_ui.call("append_province_military_sections", prov_content_box, d)

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
			_refresh_province_panel()
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
						_refresh_province_panel()
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
						play_sfx("building_finished")
						_after_economy_action()
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
		m_btn.pressed.connect(func() -> void: _open_market_panel(market_id))
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
		_refresh_province_panel()
	)
	hdr.add_child(btn_prov)

	var btn_state := Button.new()
	btn_state.text = "State"
	btn_state.modulate = Color(1.0, 0.88, 0.40) if prov_people_show_state else Color(0.85, 0.85, 0.85)
	btn_state.pressed.connect(func() -> void:
		prov_people_show_state = true
		_refresh_province_panel()
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
					_refresh_province_panel()
					_refresh_top_bar()
					_refresh_faith_overlay()
					if religion_ui != null:
						religion_ui.call("refresh_if_open")
				)
				prov_content_box.add_child(rec_btn)
			else:
				var send_btn := Button.new()
				send_btn.text = "Send Missionary (0.5/mo)"
				send_btn.disabled = not bool(d.get("canSendMissionary", false))
				send_btn.tooltip_text = str(d.get("missionaryRefusal", ""))
				send_btn.pressed.connect(func() -> void:
					_call_bridge("sendMissionary", [p_idx], {})
					_refresh_province_panel()
					_refresh_top_bar()
					_refresh_faith_overlay()
					if religion_ui != null:
						religion_ui.call("refresh_if_open")
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
			r_btn.pressed.connect(_open_rebels_window)
			prov_content_box.add_child(r_btn)

func _after_calamity_action() -> void:
	_refresh_province_panel()
	_refresh_top_bar()
	_refresh_styles_and_country_labels()
	_refresh_faith_overlay()

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
				_after_fleet_action()
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
			_refresh_province_panel()
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
						play_sfx("building_finished")
						_after_fleet_action()
				)
				prov_content_box.add_child(sbtn)

func _refresh_sea_panel() -> void:
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

func _open_market_panel(market_idx: int) -> void:
	open_market_index = market_idx
	current_market_category = ""
	market_panel.visible = true
	_refresh_market_panel()

func _refresh_market_panel() -> void:
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
				_refresh_market_panel()
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
			if trade_ui != null and good_idx_copy >= 0 and mkt_idx_copy >= 0:
				trade_ui.call("plan_import", good_idx_copy, mkt_idx_copy)
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

# MARK: - Camera & Input (matches App/Shared/Map/MapCanvasView.swift)

func _fit_zoom() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.3
	return minf(size.x / map_size.x, size.y / map_size.y)

func _min_zoom() -> float:
	return _fit_zoom() * 0.9

func _max_zoom() -> float:
	return 8.0

func _reset_to_start_camera() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fit := _fit_zoom()
	zoom = minf(fit * 3.0, _max_zoom())
	var focus: Vector2 = _call_bridge("getFocusPoint", [41.0, 29.0], Vector2(2150.0, 820.0))
	var x := size.x * 0.5 - focus.x * zoom
	var y := size.y * 0.5 - focus.y * zoom
	offset = _clamped_offset(Vector2(x, y), zoom)
	view_pitch = _target_pitch()
	_sync_camera_uniforms()

func _show_whole_map() -> void:
	zoom = _fit_zoom()
	offset = _clamped_offset(Vector2.ZERO, zoom)
	view_pitch = _target_pitch()
	_sync_camera_uniforms()

# Jump the camera to a map point at a zoom, with the tilt already settled
# (screenshots and "go to" buttons).
func focus_map_point(map_pt: Vector2, new_zoom: float) -> void:
	zoom = clampf(new_zoom, _min_zoom(), _max_zoom())
	offset = _clamped_offset(Vector2(size.x * 0.5 - map_pt.x * zoom, size.y * 0.5 - map_pt.y * zoom), zoom)
	view_pitch = _target_pitch()
	_sync_camera_uniforms()

func _clamped_offset(o: Vector2, z: float) -> Vector2:
	var w := map_size.x * z
	var h := map_size.y * z
	var margin := 80.0
	var x := o.x
	var y := o.y
	if w <= size.x:
		x = (size.x - w) * 0.5
	else:
		x = minf(maxf(x, size.x - w - margin), margin)
	if h <= size.y:
		y = (size.y - h) * 0.5
	else:
		y = minf(maxf(y, size.y - h - margin), margin)
	return Vector2(x, y)

func _zoom_by(factor: float, anchor: Vector2) -> void:
	if zoom <= 0.0:
		return
	var new_zoom := clampf(zoom * factor, _min_zoom(), _max_zoom())
	var ratio := new_zoom / zoom
	var new_offset := Vector2(
		anchor.x - (anchor.x - offset.x) * ratio,
		anchor.y - (anchor.y - offset.y) * ratio
	)
	var before: Vector2 = screen_to_map(anchor)
	zoom = new_zoom
	offset = _clamped_offset(new_offset, new_zoom)
	_sync_camera_uniforms()
	# With the camera tilted, keep the map point under the cursor in place.
	if view_pitch < 89.9:
		var after: Vector2 = screen_to_map(anchor)
		offset = _clamped_offset(offset + (after - before) * zoom, zoom)
		_sync_camera_uniforms()

# Tilt for the current zoom (straight down when zoomed out).
func _target_pitch() -> float:
	return float(MapProjectorScript.pitch_for_zoom(zoom, _fit_zoom(), _max_zoom()))

# Screen point -> map pixel, through the 3D camera and the terrain.
func screen_to_map(screen_pos: Vector2) -> Vector2:
	if zoom <= 0.0:
		return Vector2.ZERO
	return projector.call("to_map", screen_pos)

# Map pixel -> screen point, standing on the terrain.
func map_to_screen(map_pt: Vector2) -> Vector2:
	return projector.call("to_screen", map_pt)

func _sync_camera_uniforms() -> void:
	if map_material == null:
		return
	map_material.set_shader_parameter("zoom", zoom)
	projector.call("update", size, zoom, offset, view_pitch)
	map3d.call("apply_projector", projector)
	if map_models != null:
		map_models.call("update_zoom", zoom)
	var cam_rev: int = int(projector.get("revision"))
	var default_tint := clampf(0.72 - 0.2 * zoom, 0.38, 0.66)
	var tint: float = float(_call_bridge("getTintForZoom", [zoom], default_tint))
	map_material.set_shader_parameter("tint", tint)

	if bridge != null and zoom > 0.0:
		var center_map_x := int(round((size.x * 0.5 - offset.x) / zoom))
		var center_map_y := int(round((size.y * 0.5 - offset.y) / zoom))
		var amb_v: Variant = _call_bridge("getAmbienceContext", [center_map_x, center_map_y, zoom], {})
		if amb_v is Dictionary:
			var amb: Dictionary = amb_v
			var a := _audio()
			if a != null:
				a.call("update_ambience_weights",
					float(amb.get("seaWeight", 0.0)),
					float(amb.get("windWeight", 0.45)),
					float(amb.get("cityWeight", 0.0)))
	if icons_layer != null:
		icons_layer.call("update_camera", zoom, offset, projector, cam_rev)
	if labels_layer != null:
		labels_layer.call("update_camera", zoom, offset, projector, cam_rev)
	if armies_layer != null:
		armies_layer.call("update_camera", zoom, offset, projector, cam_rev)
	if fleets_layer != null:
		fleets_layer.call("update_camera", zoom, offset, projector, cam_rev)
	if routes_layer != null:
		routes_layer.call("update_camera", zoom, offset, projector, cam_rev)
	if faith_layer != null:
		faith_layer.call("update_camera", zoom, offset, projector, cam_rev)
	if calamity_layer != null:
		calamity_layer.call("update_camera", zoom, offset, projector, cam_rev)
	if tech_layer != null:
		tech_layer.call("update_camera", zoom, offset, projector, cam_rev)

func _on_viewport_resized() -> void:
	if zoom <= 0.0:
		_reset_to_start_camera()
	else:
		offset = _clamped_offset(offset, zoom)
		_sync_camera_uniforms()

func _unhandled_input(event: InputEvent) -> void:
	if (battle_view != null and battle_view.visible) or (battle_choice_panel != null and battle_choice_panel.visible):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if int(_call_bridge("getMoveModeArmyId", [], -1)) >= 0:
				_call_bridge("setMoveModeForArmy", [-1], false)
				_after_army_action()
			elif int(_call_bridge("getMoveModeFleetId", [], -1)) >= 0:
				_call_bridge("setMoveModeForFleet", [-1], false)
				_after_fleet_action()
			else:
				_toggle_game_menu()
			get_viewport().set_input_as_handled()
			return

		if _is_text_input_focused():
			return

		match event.keycode:
			KEY_SPACE:
				_on_pause_pressed()
				get_viewport().set_input_as_handled()
			KEY_1:
				_on_speed_selected(1)
				get_viewport().set_input_as_handled()
			KEY_2:
				_on_speed_selected(2)
				get_viewport().set_input_as_handled()
			KEY_3:
				_on_speed_selected(3)
				get_viewport().set_input_as_handled()
			KEY_4:
				_on_speed_selected(4)
				get_viewport().set_input_as_handled()
			KEY_5:
				_on_speed_selected(5)
				get_viewport().set_input_as_handled()
			KEY_EQUAL, KEY_KP_ADD:
				_zoom_by(1.25, size * 0.5)
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_by(1.0 / 1.25, size * 0.5)
				get_viewport().set_input_as_handled()
			KEY_F:
				_show_whole_map()
				get_viewport().set_input_as_handled()
			KEY_Q:
				_select_map_mode("political")
				get_viewport().set_input_as_handled()
			KEY_O:
				_select_map_mode("diplomatic")
				get_viewport().set_input_as_handled()
			KEY_W:
				_select_map_mode("states")
				get_viewport().set_input_as_handled()
			KEY_E:
				_select_map_mode("terrain")
				get_viewport().set_input_as_handled()
			KEY_R:
				_select_map_mode("religion")
				get_viewport().set_input_as_handled()
			KEY_T:
				_select_map_mode("culture")
				get_viewport().set_input_as_handled()
			KEY_Y:
				_select_map_mode("development")
				get_viewport().set_input_as_handled()
			KEY_U:
				_select_map_mode("goods")
				get_viewport().set_input_as_handled()
			KEY_I:
				_select_map_mode("markets")
				get_viewport().set_input_as_handled()
			KEY_P:
				_select_map_mode("plague")
				get_viewport().set_input_as_handled()
			KEY_L:
				_select_map_mode("unrest")
				get_viewport().set_input_as_handled()
			KEY_K:
				_select_map_mode("institutions")
				get_viewport().set_input_as_handled()
		return

	# macOS trackpad two-finger scroll pan
	if event is InputEventPanGesture:
		offset = _clamped_offset(offset - event.delta * 18.0, zoom)
		_sync_camera_uniforms()
		get_viewport().set_input_as_handled()
		return

	# macOS trackpad pinch-to-zoom
	if event is InputEventMagnifyGesture:
		_zoom_by(event.factor, get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.12, event.position)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / 1.12, event.position)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var sel_army: int = int(_call_bridge("getSelectedArmyId", [], -1))
			if sel_army >= 0 and zoom > 0.0:
				var r_map: Vector2 = screen_to_map(event.position)
				var r_map_x := int(floor(r_map.x))
				var r_map_y := int(floor(r_map.y))
				if bool(_call_bridge("orderArmyMoveAt", [sel_army, r_map_x, r_map_y], false)):
					play_sfx("march_boots")
					_after_army_action()
				get_viewport().set_input_as_handled()
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pointer_down = true
				is_dragging = false
				pointer_down_pos = event.position
				drag_start_offset = offset
			else:
				if is_pointer_down and not is_dragging:
					_handle_map_click(event.position)
				is_pointer_down = false
				is_dragging = false
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		if is_pointer_down:
			var delta_pos: Vector2 = event.position - pointer_down_pos
			if not is_dragging and delta_pos.length() >= 3.0:
				is_dragging = true
			if is_dragging:
				offset = _clamped_offset(drag_start_offset + delta_pos, zoom)
				_sync_camera_uniforms()
			var t_drag := _tip()
			if t_drag != null:
				t_drag.call("clear_canvas_tip", "map_unit")
			_hover_map_army_id = -1
			get_viewport().set_input_as_handled()
		elif not nation_picker_panel.visible and armies_layer != null and bridge != null:
			var t := _tip()
			if t != null:
				var hit_army: int = int(armies_layer.call("pick_army_at", event.position))
				if hit_army >= 0:
					if hit_army != _hover_map_army_id:
						_hover_map_army_id = hit_army
						var morale_d: Variant = _call_bridge("getArmyMoraleBreakdown", [hit_army], {})
						if morale_d is Dictionary and bool((morale_d as Dictionary).get("valid", false)):
							t.call("set_canvas_tip", "map_unit", morale_d)
				elif _hover_map_army_id >= 0:
					_hover_map_army_id = -1
					t.call("clear_canvas_tip", "map_unit")

func _handle_map_click(screen_pos: Vector2) -> void:
	if bridge == null or zoom <= 0.0:
		return
	var click_map: Vector2 = screen_to_map(screen_pos)
	var map_x := int(floor(click_map.x))
	var map_y := int(floor(click_map.y))

	# 1. If an army or fleet is in Move target-picking mode, clicking a province/sea orders a move there.
	var move_army_id: int = int(_call_bridge("getMoveModeArmyId", [], -1))
	if move_army_id >= 0:
		if bool(_call_bridge("orderArmyMoveAt", [move_army_id, map_x, map_y], false)):
			play_sfx("march_boots")
		_call_bridge("setMoveModeForArmy", [-1], false)
		_after_army_action()
		return
	var move_fleet_id: int = int(_call_bridge("getMoveModeFleetId", [], -1))
	if move_fleet_id >= 0:
		_call_bridge("orderFleetMoveAt", [move_fleet_id, map_x, map_y], false)
		_call_bridge("setMoveModeForFleet", [-1], false)
		_after_fleet_action()
		return

	# 2. Check if the click hit an army or fleet counter on the map.
	if not nation_picker_panel.visible and armies_layer != null:
		var hit_army: int = int(armies_layer.call("pick_army_at", screen_pos))
		if hit_army >= 0:
			_call_bridge("clearSelectedFleet", [])
			_call_bridge("selectArmy", [hit_army], false)
			_after_army_action()
			return
	if not nation_picker_panel.visible and fleets_layer != null:
		var hit_fleet: int = int(fleets_layer.call("pick_fleet_at", screen_pos))
		if hit_fleet >= 0:
			_call_bridge("clearSelectedArmy", [])
			_call_bridge("selectFleet", [hit_fleet], false)
			_after_fleet_action()
			return

	var sel_id: int = int(_call_bridge("selectAt", [map_x, map_y], 0))
	var sel_sea: int = int(_call_bridge("getSelectedSeaValue", [], 0))
	map_material.set_shader_parameter("selected", sel_id)
	map_material.set_shader_parameter("selected_sea", sel_sea)
	var summary: String = str(_call_bridge("getProvinceSummaryAt", [map_x, map_y], ""))
	selection_label.text = summary if not summary.is_empty() else "Deep Sea"
	_refresh_play_as_button()

	# If Nation Picker is open, clicking any country on the map selects it in the Nation Picker.
	if nation_picker_panel.visible and sel_id >= 2:
		var clicked_tag: String = str(_call_bridge("getSelectedProvinceOwnerTag", [], ""))
		if not clicked_tag.is_empty():
			_select_picker_country(clicked_tag, false)
		return

	if sel_id >= 2:
		prov_show_build = false
		prov_show_shipbuild = false
		_refresh_province_panel()
	elif sel_sea > 0:
		_refresh_sea_panel()
	else:
		province_panel.visible = false
		sea_panel.visible = false

func _refresh_play_as_button() -> void:
	if bridge == null or play_as_btn == null:
		return
	var owner_name: String = str(_call_bridge("getSelectedOwnerName", [], ""))
	play_as_btn.visible = not owner_name.is_empty()
	play_as_btn.text = "Play as " + owner_name

func _on_play_as_pressed() -> void:
	var switched: bool = bool(_call_bridge("playAsSelectedOwner", [], false))
	if switched:
		_refresh_styles_and_country_labels()
		_refresh_top_bar()
		_refresh_play_as_button()
		_refresh_armies()
		_refresh_fleets(true)
		_after_economy_action()

func _on_pause_pressed() -> void:
	_call_bridge("togglePause")
	_refresh_top_bar()

func _on_speed_selected(spd: int) -> void:
	_call_bridge("setSpeed", [spd])
	_refresh_top_bar()

func _close_top_left_windows(except_key: String = "") -> void:
	if except_key != "budget" and budget_ui != null:
		budget_ui.call("close_window")
	if except_key != "trade" and trade_ui != null:
		trade_ui.call("close_window")
	if except_key != "court" and court_ui != null:
		court_ui.call("close_window")
	if except_key != "government" and gov_ui != null:
		gov_ui.call("close_window")
	if except_key != "religion" and religion_ui != null:
		religion_ui.call("close_window")
	if except_key != "rebels" and rebels_ui != null:
		rebels_ui.call("close_window")
	if except_key != "tech" and tech_ui != null:
		tech_ui.call("close_window")
	if except_key != "diplomacy" and diplomacy_ui != null:
		diplomacy_ui.call("close_window")
	if except_key != "wars" and wars_ui != null:
		wars_ui.call("close_window")
	if except_key != "armies" and army_ui != null:
		var aw: Variant = army_ui.get("armies_window_panel")
		if aw is Control:
			(aw as Control).visible = false
	if except_key != "fleets" and fleet_ui != null:
		var fw: Variant = fleet_ui.get("fleets_window_panel")
		if fw is Control:
			(fw as Control).visible = false

func _toggle_budget_window() -> void:
	if budget_ui == null:
		return
	var opening: bool = not bool(budget_ui.call("is_open"))
	if opening:
		_close_top_left_windows("budget")
	budget_ui.call("toggle_window")

func _toggle_trade_window() -> void:
	if trade_ui == null:
		return
	var opening: bool = not bool(trade_ui.call("is_open"))
	if opening:
		_close_top_left_windows("trade")
	trade_ui.call("toggle_window")

func _toggle_court_window() -> void:
	if court_ui == null:
		return
	var opening: bool = not bool(court_ui.call("is_open"))
	if opening:
		_close_top_left_windows("court")
	court_ui.call("toggle_window")

func _toggle_government_window() -> void:
	if gov_ui == null:
		return
	var opening: bool = not bool(gov_ui.call("is_open"))
	if opening:
		_close_top_left_windows("government")
	gov_ui.call("toggle_window")

func _toggle_religion_window() -> void:
	if religion_ui == null:
		return
	var opening: bool = not bool(religion_ui.call("is_open"))
	if opening:
		_close_top_left_windows("religion")
	religion_ui.call("toggle_window")

func _toggle_rebels_window() -> void:
	if rebels_ui == null:
		return
	var opening: bool = not bool(rebels_ui.call("is_open"))
	if opening:
		_close_top_left_windows("rebels")
	rebels_ui.call("toggle_window")

func _open_rebels_window() -> void:
	if rebels_ui == null:
		return
	_close_top_left_windows("rebels")
	rebels_ui.call("open_window")

func _toggle_tech_window() -> void:
	if tech_ui == null:
		return
	var opening: bool = not bool(tech_ui.call("is_open"))
	if opening:
		_close_top_left_windows("tech")
	tech_ui.call("toggle_window")

func _open_tech_window() -> void:
	if tech_ui == null:
		return
	_close_top_left_windows("tech")
	tech_ui.call("open_window")

# Markers for the Plague, Unrest and Institutions map modes (called with the faith overlay).
func _refresh_calamity_overlay() -> void:
	if calamity_layer != null and bridge != null:
		if current_map_mode == "plague" or current_map_mode == "unrest":
			var data_v: Variant = _call_bridge("getCalamityOverlayData", [], {})
			var data: Dictionary = data_v if data_v is Dictionary else {}
			calamity_layer.call("set_overlay_data", current_map_mode, data)
			calamity_layer.call("update_camera", zoom, offset, projector, int(projector.get("revision")))
		else:
			calamity_layer.call("set_overlay_data", current_map_mode, {})
	if tech_layer != null and bridge != null:
		if current_map_mode == "institutions":
			var td_v: Variant = _call_bridge("getTechOverlayData", [], {})
			var td: Dictionary = td_v if td_v is Dictionary else {}
			tech_layer.call("set_overlay_data", current_map_mode, td)
			tech_layer.call("update_camera", zoom, offset, projector, int(projector.get("revision")))
		else:
			tech_layer.call("set_overlay_data", current_map_mode, {})

func _refresh_faith_overlay() -> void:
	_refresh_calamity_overlay()
	if faith_layer == null or bridge == null:
		return
	if current_map_mode == "religion" or current_map_mode == "culture":
		var data_v: Variant = _call_bridge("getFaithOverlayData", [], {})
		var data: Dictionary = data_v if data_v is Dictionary else {}
		faith_layer.call("set_overlay_data", current_map_mode, data)
		faith_layer.call("update_camera", zoom, offset, projector, int(projector.get("revision")))
	else:
		faith_layer.call("set_overlay_data", current_map_mode, {})

func _toggle_diplomacy_window() -> void:
	if diplomacy_ui == null:
		return
	var opening: bool = not bool(diplomacy_ui.call("is_open"))
	if opening:
		_close_top_left_windows("diplomacy")
	diplomacy_ui.call("toggle_window")

func _toggle_wars_window() -> void:
	if wars_ui == null:
		return
	var opening: bool = not bool(wars_ui.call("is_open"))
	if opening:
		_close_top_left_windows("wars")
	wars_ui.call("toggle_window")

func _open_diplomacy_with(country_idx: int = -1) -> void:
	if diplomacy_ui == null:
		return
	_close_top_left_windows("diplomacy")
	diplomacy_ui.call("open_with_country", country_idx)

func _open_wars_and_peace(war_id: String = "") -> void:
	if wars_ui == null:
		return
	_close_top_left_windows("wars")
	wars_ui.call("open_wars_window")
	if not war_id.is_empty():
		wars_ui.call("open_peace_for_war", war_id)

# Phase 20 part 5: glowing medallions centred under the top bar (AlertsRow.gd).
func _build_alerts_bar() -> void:
	alerts_row = AlertsRowScript.new()
	alerts_row.call("setup", self)
	add_child(alerts_row)
	alerts_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	alerts_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alerts_row.offset_top = 54.0

func _refresh_alerts_bar() -> void:
	if alerts_row == null or bridge == null:
		return
	var alerts: Array = _call_bridge("getActiveAlerts", [], [])
	alerts_row.call("show_alerts", alerts)
	_layout_recent_events_bar()

func _build_recent_events_bar() -> void:
	recent_events_panel = PanelContainer.new()
	recent_events_panel.name = "RecentEventsPanel"
	recent_events_panel.position = Vector2(12.0, 88.0)
	recent_events_panel.custom_minimum_size = Vector2(360.0, 0.0)
	var st := _make_panel_style(Color(0.12, 0.10, 0.08, 0.90))
	st.content_margin_left = 8.0
	st.content_margin_right = 8.0
	st.content_margin_top = 4.0
	st.content_margin_bottom = 4.0
	recent_events_panel.add_theme_stylebox_override("panel", st)
	recent_events_panel.visible = false
	windows_layer.add_child(recent_events_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	recent_events_panel.add_child(vbox)

	recent_events_toggle_btn = Button.new()
	recent_events_toggle_btn.text = "Recent Events"
	recent_events_toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	recent_events_toggle_btn.modulate = Color(0.95, 0.86, 0.58)
	recent_events_toggle_btn.pressed.connect(func() -> void:
		recent_events_expanded = not recent_events_expanded
		_refresh_recent_events()
	)
	vbox.add_child(recent_events_toggle_btn)

	recent_events_list_box = VBoxContainer.new()
	recent_events_list_box.add_theme_constant_override("separation", 3)
	recent_events_list_box.visible = false
	vbox.add_child(recent_events_list_box)

func _layout_recent_events_bar() -> void:
	if recent_events_panel == null:
		return
	recent_events_panel.position = Vector2(12.0, 52.0)

func _refresh_recent_events() -> void:
	if recent_events_panel == null or recent_events_list_box == null or bridge == null:
		return
	_clear_children(recent_events_list_box)
	var items: Array = _call_bridge("getRecentEvents", [], [])
	if items.is_empty():
		recent_events_panel.visible = false
		return
	recent_events_panel.visible = true
	_layout_recent_events_bar()
	var latest: Dictionary = items[0] if items[0] is Dictionary else {}
	var arrow := "v" if recent_events_expanded else ">"
	recent_events_toggle_btn.text = "%s Recent Events (%d): %s" % [
		arrow,
		items.size(),
		str(latest.get("title", ""))
	]
	recent_events_list_box.visible = recent_events_expanded
	if not recent_events_expanded:
		return
	for item_v in items:
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v
		var title_s: String = str(item.get("title", ""))
		var date_s: String = str(item.get("dateText", ""))
		var choice_s: String = str(item.get("chosenLabel", ""))
		var eff_s: String = str(item.get("effectSummary", ""))
		var row_lbl := _make_label("%s · %s (%s)" % [date_s, title_s, choice_s], Color(0.92, 0.87, 0.74), 11)
		row_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_lbl.custom_minimum_size = Vector2(340.0, 0.0)
		recent_events_list_box.add_child(row_lbl)
		if not eff_s.is_empty():
			var eff_lbl := _make_label("   " + eff_s, Color(0.72, 0.82, 0.66), 10)
			eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			eff_lbl.custom_minimum_size = Vector2(340.0, 0.0)
			recent_events_list_box.add_child(eff_lbl)

func _open_event_popup() -> void:
	if event_popup != null:
		event_popup.call("open_pending_if_new", true)

func _sync_pause_on_events_ui() -> void:
	if menu_pause_events_check != null and bridge != null:
		var enabled: bool = bool(_call_bridge("getPauseOnEvents", [], true))
		menu_pause_events_check.set_pressed_no_signal(enabled)

func _on_event_resolved() -> void:
	_last_alerts_sig = "__init__"
	_last_recent_events_sig = "__init__"
	_refresh_top_bar()
	_refresh_recent_events()
	_refresh_styles_and_country_labels()
	_refresh_faith_overlay()
	_refresh_armies(true)
	_refresh_fleets(true)
	if province_panel.visible:
		_refresh_province_panel()
	if event_popup != null and bool(_call_bridge("hasPendingEvent", [], false)):
		event_popup.call("open_pending_if_new", false)

func _on_alert_pressed(alert: Dictionary) -> void:
	var kind: String = str(alert.get("kind", ""))
	var p_idx: int = int(alert.get("provinceIndex", -1))
	var war_id: String = str(alert.get("warID", ""))
	match kind:
		"event":
			_open_event_popup()
		"peaceOffer":
			_open_wars_and_peace(war_id)
		"breach", "underSiege", "blockadedPort", "plague", "famine", "earthquake":
			if p_idx >= 0:
				_focus_and_select_province(p_idx)
		"rebels":
			if p_idx >= 0:
				_focus_and_select_province(p_idx)
			_open_rebels_window()
		"techLevel":
			_open_tech_window()
		"institution":
			if p_idx >= 0:
				_focus_and_select_province(p_idx)
			_open_tech_window()
		"navalBattle":
			var sz_idx: int = int(alert.get("seaZoneIndex", -1))
			if sz_idx >= 0 and zoom > 0.0:
				var fp_v: Variant = _call_bridge("getSeaZoneFocusPoint", [sz_idx], Vector2.ZERO)
				if fp_v is Vector2:
					var fp := fp_v as Vector2
					if fp != Vector2.ZERO:
						var x: float = size.x * 0.5 - fp.x * zoom
						var y: float = size.y * 0.5 - fp.y * zoom
						offset = _clamped_offset(Vector2(x, y), zoom)
						_sync_camera_uniforms()
			_open_wars_and_peace(war_id)
		"coalition":
			_open_diplomacy_with(-1)
		"lowStability", "disloyalEstate":
			_close_top_left_windows("government")
			if gov_ui != null:
				gov_ui.call("open_window")
		"refusingVassal":
			_close_top_left_windows("court")
			if court_ui != null:
				court_ui.call("open_window")
		"bankrupt", "highInflation":
			_close_top_left_windows("budget")
			if budget_ui != null:
				budget_ui.call("open_window")

func _focus_and_select_province(prov_idx: int) -> void:
	if prov_idx < 0:
		return
	_select_province_by_index(prov_idx)
	var fp_var: Variant = _call_bridge("getProvinceFocusPoint", [prov_idx], {})
	var fp: Dictionary = fp_var if fp_var is Dictionary else {}
	if bool(fp.get("hasCenter", false)) and zoom > 0.0:
		var fx: float = float(fp.get("x", 0.0))
		var fy: float = float(fp.get("y", 0.0))
		var x: float = size.x * 0.5 - fx * zoom
		var y: float = size.y * 0.5 - fy * zoom
		offset = _clamped_offset(Vector2(x, y), zoom)
		_sync_camera_uniforms()

func _after_diplomacy_action(refresh_map: bool = false) -> void:
	if refresh_map:
		_refresh_styles_and_country_labels()
		_refresh_town_icons()
	_refresh_top_bar()
	if diplomacy_ui != null:
		diplomacy_ui.call("refresh_if_open")
	if wars_ui != null:
		wars_ui.call("refresh_if_open")
	if gov_ui != null:
		gov_ui.call("refresh_if_open")
	if court_ui != null:
		court_ui.call("refresh_if_open")
	if budget_ui != null:
		budget_ui.call("refresh_if_open")
	if trade_ui != null:
		trade_ui.call("refresh_if_open")
	if province_panel.visible:
		_refresh_province_panel()
	if army_ui != null:
		_refresh_armies()
	if fleet_ui != null:
		_refresh_fleets()

func _toggle_armies_window() -> void:
	if army_ui == null:
		return
	var aw: Variant = army_ui.get("armies_window_panel")
	var was_open: bool = (aw is Control) and (aw as Control).visible
	if not was_open:
		_close_top_left_windows("armies")
	army_ui.call("toggle_armies_window")

func _toggle_fleets_window() -> void:
	if fleet_ui == null:
		return
	var fw: Variant = fleet_ui.get("fleets_window_panel")
	var was_open: bool = (fw is Control) and (fw as Control).visible
	if not was_open:
		_close_top_left_windows("fleets")
	fleet_ui.call("toggle_fleets_window")

func _on_trade_window_visibility_changed(is_now_open: bool) -> void:
	if routes_layer != null:
		routes_layer.call("set_active", is_now_open)
		if is_now_open:
			_refresh_trade_routes()

func _refresh_trade_routes() -> void:
	if bridge == null or routes_layer == null:
		return
	if trade_ui == null or not bool(trade_ui.call("is_open")):
		return
	var d_var: Variant = _call_bridge("getMapTradeRoutesData", [], {})
	var d: Dictionary = d_var if d_var is Dictionary else {}
	routes_layer.call("set_routes_data", d)

func _after_economy_action() -> void:
	_refresh_top_bar()
	if budget_ui != null:
		budget_ui.call("refresh_if_open")
	if trade_ui != null:
		trade_ui.call("refresh_if_open")
		_refresh_trade_routes()
	if court_ui != null:
		court_ui.call("refresh_if_open")
	if gov_ui != null:
		gov_ui.call("refresh_if_open")
	if tech_ui != null:
		tech_ui.call("refresh_if_open")
	if province_panel.visible:
		_refresh_province_panel()
	if market_panel.visible:
		_refresh_market_panel()

func _after_court_or_gov_action() -> void:
	_refresh_top_bar()
	if court_ui != null:
		court_ui.call("refresh_if_open")
	if gov_ui != null:
		gov_ui.call("refresh_if_open")
	if tech_ui != null:
		tech_ui.call("refresh_if_open")
	if province_panel.visible:
		_refresh_province_panel()

func _build_battle_choice_modal() -> void:
	battle_choice_panel = PanelContainer.new()
	battle_choice_panel.name = "BattleChoiceModal"
	battle_choice_panel.visible = false
	battle_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_choice_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.14, 0.11, 0.08, 0.98)))
	battle_choice_panel.custom_minimum_size = Vector2(490.0, 260.0)
	add_child(battle_choice_panel)
	battle_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	battle_choice_panel.offset_left = -245.0
	battle_choice_panel.offset_right = 245.0
	battle_choice_panel.offset_top = -135.0
	battle_choice_panel.offset_bottom = 135.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	battle_choice_panel.add_child(vbox)

	battle_choice_title = _make_label("Battle Imminent!", Color(0.98, 0.88, 0.48), 18)
	battle_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(battle_choice_title)

	battle_choice_sub = _make_label("", Color(0.90, 0.86, 0.78), 13)
	battle_choice_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(battle_choice_sub)

	vbox.add_child(HSeparator.new())

	battle_choice_details = _make_label("", Color(0.94, 0.91, 0.84), 13)
	battle_choice_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_choice_details.custom_minimum_size = Vector2(440.0, 72.0)
	vbox.add_child(battle_choice_details)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var lead_btn := Button.new()
	lead_btn.text = "Lead Battle in Person"
	lead_btn.custom_minimum_size = Vector2(210.0, 46.0)
	lead_btn.modulate = Color(0.75, 1.0, 0.78)
	bind_tip(lead_btn, "Command Tactical Battle", "Switch to the real-time tactical battlefield to position regiments, give orders and fire artillery or storm forts.")
	lead_btn.pressed.connect(func() -> void:
		battle_choice_panel.visible = false
		if bool(_call_bridge("chooseLeadBattleInPerson", [], false)):
			if battle_view != null:
				battle_view.call("open_battle")
		_refresh_top_bar()
	)
	btn_row.add_child(lead_btn)

	var auto_btn := Button.new()
	auto_btn.text = "Auto-Resolve"
	auto_btn.custom_minimum_size = Vector2(180.0, 46.0)
	auto_btn.modulate = Color(0.96, 0.84, 0.56)
	bind_tip(auto_btn, "Resolve on Strategic Map", "Let commanders resolve the engagement automatically using strength, terrain, leaders and morale.")
	auto_btn.pressed.connect(func() -> void:
		battle_choice_panel.visible = false
		_call_bridge("chooseAutoResolveBattle", [], {})
		_after_army_action()
		_refresh_styles_and_country_labels()
	)
	btn_row.add_child(auto_btn)

func open_battle_choice_modal() -> void:
	if bridge == null or battle_choice_panel == null:
		return
	var prompt: Dictionary = _call_bridge("getPendingBattlePrompt", [], {})
	if not bool(prompt.get("active", false)):
		battle_choice_panel.visible = false
		return
	var prov_name: String = str(prompt.get("provinceName", "Province"))
	var terr_name: String = str(prompt.get("terrainName", "Plains"))
	var is_assault := bool(prompt.get("isAssault", false))
	var is_river := bool(prompt.get("isRiverCrossing", false))
	var att_ambushed := bool(prompt.get("attackerAmbushed", false)) and str(prompt.get("playerSide", "attacker")) == "attacker"

	battle_choice_title.text = ("Storm Assault at %s" % prov_name) if is_assault else ("Battle at %s" % prov_name)
	var extra := ""
	if is_assault:
		extra = " · Fort Lv %d (Walls Breached)" % int(prompt.get("fortLevel", 1))
	elif is_river:
		extra = " · River Crossing" + (" (Ambushed!)" if att_ambushed else "")
	battle_choice_sub.text = "Terrain: %s%s" % [terr_name, extra]

	var att_str := "%s (%s) — %d men · Cmdr: %s (Martial %d)" % [
		str(prompt.get("attackerName", "Attacker")),
		str(prompt.get("attackerTag", "")),
		int(prompt.get("attackerMen", 0)),
		str(prompt.get("attackerCommander", "Field Captain")),
		int(prompt.get("attackerMartial", 0))
	]
	var def_str := "%s (%s) — %d men · Cmdr: %s (Martial %d)" % [
		str(prompt.get("defenderName", "Defender")),
		str(prompt.get("defenderTag", "")),
		int(prompt.get("defenderMen", 0)),
		str(prompt.get("defenderCommander", "Castellan")),
		int(prompt.get("defenderMartial", 0))
	]
	battle_choice_details.text = "Attacker: %s\nDefender: %s" % [att_str, def_str]
	battle_choice_panel.visible = true

func _on_tactical_battle_closed() -> void:
	_after_army_action()
	_refresh_styles_and_country_labels()
	_refresh_town_icons()
	_refresh_top_bar()
	if wars_ui != null:
		wars_ui.call("refresh_if_open")
