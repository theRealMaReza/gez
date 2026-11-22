extends Control

# Phase 20 part 9: the loading screen and the main menu.
#
# Both show the owner's painting of Constantinople in 1453
# (assets/paintings/menu/main_menu.png and loading.png, prompts in
# docs/ART_PROMPTS.md), or a sepia map of the city's surroundings until
# the paintings arrive. The menu sits on a parchment panel at the left
# (owner's choice), where the painting is kept quiet.

var main_view: Control = null
var picture: TextureRect
var shade: TextureRect
var menu_panel: PanelContainer
var loading_card: PanelContainer
var loading_label: Label

func setup(host: Control) -> void:
	main_view = host
	name = "TitleScreens"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.07, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)

	# a soft darkening behind the menu panel
	shade = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.06, 0.04, 0.02, 0.72))
	grad.set_color(1, Color(0.06, 0.04, 0.02, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_bottom = 1.0
	shade.offset_right = 620.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_menu()
	_build_loading()

func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(420.0, 0.0)
	add_child(menu_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	menu_panel.add_child(col)
	var title := GezStyle.title("GEZ")
	title.add_theme_font_size_override("font_size", 40)
	title.custom_minimum_size = Vector2(0.0, 64.0)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Grand strategy from 30 May 1453"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", GezTheme.INK_SOFT)
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	col.add_child(gap)
	for spec in [
		["Continue", "Back to the game.", _on_continue],
		["New Game", "Choose a country of 1453 to play.", _on_new_game],
		["Load Game", "Open a saved game.", _on_load],
		["Settings", "Sound, autosave and event pauses.", _on_settings],
		["Quit", "Leave the game.", _on_quit],
	]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(300.0, 50.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 21)
		if main_view != null:
			main_view.call("bind_tip", b, spec[0], spec[1])
		b.pressed.connect(spec[2])
		col.add_child(b)
	var foot := Control.new()
	foot.custom_minimum_size = Vector2(0.0, 4.0)
	col.add_child(foot)
	# centred on the left edge, 80 px in
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 80)

func _build_loading() -> void:
	loading_card = PanelContainer.new()
	loading_card.theme_type_variation = "Card"
	loading_card.add_theme_stylebox_override("panel", GezTheme.tooltip_style())
	loading_card.anchor_left = 0.5
	loading_card.anchor_right = 0.5
	loading_card.anchor_top = 1.0
	loading_card.anchor_bottom = 1.0
	loading_card.offset_top = -120.0
	loading_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loading_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(loading_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	loading_card.add_child(v)
	var t := Label.new()
	t.text = "GEZ"
	t.theme_type_variation = "Heading"
	t.add_theme_font_size_override("font_size", 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	loading_label = Label.new()
	loading_label.text = "Preparing Europe, Asia and Africa on 30 May 1453…"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 18)
	v.add_child(loading_label)

func _use_picture(painting_name: String) -> void:
	var t := GezStyle.painting("menu", painting_name)
	if t == null and painting_name == "loading":
		t = GezStyle.painting("menu", "main_menu")
	if t == null:
		t = GezStyle.tex("res://assets/ui/menu_placeholder.jpg")
	picture.texture = t

## The loading screen, shown while the world of 1453 is built.
func show_loading() -> void:
	_use_picture("loading")
	shade.visible = false
	menu_panel.visible = false
	loading_card.visible = true
	visible = true

## The main menu over the game.
func show_menu() -> void:
	_use_picture("main_menu")
	shade.visible = true
	menu_panel.visible = true
	loading_card.visible = false
	visible = true

func hide_screens() -> void:
	visible = false

func is_menu_open() -> bool:
	return visible and menu_panel.visible

func _on_continue() -> void:
	hide_screens()

func _on_new_game() -> void:
	hide_screens()
	if main_view != null:
		main_view.call("_open_nation_picker")

func _on_load() -> void:
	hide_screens()
	if main_view != null:
		main_view.call("_toggle_game_menu")

func _on_settings() -> void:
	hide_screens()
	if main_view != null:
		main_view.call("_toggle_game_menu")

func _on_quit() -> void:
	get_tree().quit()
