class_name GezTheme
extends RefCounted

# Builds the one shared Theme for every screen (Phase 20 part 1).
#
# The art comes from tools/uiart/ui_art_concept.py --kit godot/assets/ui.
# The theme itself is saved as res://assets/ui/gez_theme.tres by
#   godot --headless --path godot --script res://tools/build_theme.gd
# and set as the project's default theme (project.godot, gui/theme/custom),
# so any plain Godot control (including new screens) gets this look
# without per-panel styling. Re-run the tool after changing this file.

const UI := "res://assets/ui/"

# Ink on parchment
const INK := Color(0.20, 0.12, 0.06)
const INK_SOFT := Color(0.42, 0.30, 0.17)
const ACCENT := Color(0.52, 0.11, 0.07)      # deep red: names, headings
const GOOD := Color(0.13, 0.40, 0.12)
const BAD := Color(0.62, 0.13, 0.09)
# Light text on leather (top bar, side column, banners)
const CREAM := Color(0.97, 0.91, 0.75)
const GOLD_TEXT := Color(0.95, 0.80, 0.48)
const ON_GOLD := Color(0.24, 0.13, 0.04)     # text on gold buttons

const WINDOW_MARGIN := 26    # border of window.png (gold + leather + bead)

static func _tex(name: String) -> Texture2D:
	return load(UI + name) as Texture2D

static func _font(file: String, weight: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/" + file) as Font
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	return fv

static func body_font() -> Font:
	return _font("EBGaramond.ttf", 500)

static func bold_font() -> Font:
	return _font("EBGaramond.ttf", 700)

static func italic_font() -> Font:
	return _font("EBGaramond-Italic.ttf", 500)

static func title_font() -> Font:
	return _font("Cinzel.ttf", 700)

static func caps_font() -> Font:
	return _font("Cinzel.ttf", 600)

static func nine(file: String, m: int, content_lr: float, content_tb: float, center := true, tile := false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(file)
	sb.set_texture_margin_all(m)
	sb.content_margin_left = content_lr
	sb.content_margin_right = content_lr
	sb.content_margin_top = content_tb
	sb.content_margin_bottom = content_tb
	sb.draw_center = center
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb

static func window_style() -> StyleBoxTexture:
	return nine("window.png", WINDOW_MARGIN, 32.0, 30.0)

static func card_style() -> StyleBoxTexture:
	return nine("card.png", 3, 10.0, 8.0)

static func tooltip_style() -> StyleBoxTexture:
	return nine("tooltip.png", 6, 12.0, 10.0)

static func banner_style() -> StyleBoxTexture:
	var sb := nine("banner.png", 0, 34.0, 4.0, true, false)
	sb.texture_margin_left = 30
	sb.texture_margin_right = 30
	sb.texture_margin_top = 8
	sb.texture_margin_bottom = 8
	return sb

static func topbar_style() -> StyleBoxTexture:
	var sb := nine("topbar.png", 0, 14.0, 4.0)
	sb.texture_margin_top = 6
	sb.texture_margin_bottom = 12
	sb.content_margin_bottom = 12.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb

static func sidebar_style() -> StyleBoxTexture:
	var sb := nine("sidebar.png", 0, 6.0, 10.0)
	sb.texture_margin_right = 14
	sb.content_margin_right = 18.0
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb

static func _flat(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 3, pad := 4.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 2.0
	s.content_margin_right = pad + 2.0
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s

static func build() -> Theme:
	var t := Theme.new()
	var body := body_font()
	var bold := bold_font()
	var title := title_font()
	var caps := caps_font()
	t.default_font = body
	t.default_font_size = 16

	# --- windows and cards
	var win := window_style()
	for typ in ["PanelContainer", "Panel"]:
		t.set_stylebox("panel", typ, win)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", card_style())
	t.set_type_variation("TopBar", "PanelContainer")
	t.set_stylebox("panel", "TopBar", topbar_style())
	t.set_type_variation("SideBar", "PanelContainer")
	t.set_stylebox("panel", "SideBar", sidebar_style())
	t.set_type_variation("Bare", "PanelContainer")
	t.set_stylebox("panel", "Bare", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TooltipPanel", tooltip_style())
	t.set_stylebox("panel", "PopupPanel", tooltip_style())
	t.set_stylebox("panel", "PopupMenu", tooltip_style())
	t.set_stylebox("hover", "PopupMenu", _flat(Color(0.55, 0.12, 0.08, 0.22), Color(0, 0, 0, 0), 0, 2, 2.0))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_color("font_disabled_color", "PopupMenu", Color(0.45, 0.40, 0.34))
	t.set_color("font_separator_color", "PopupMenu", INK_SOFT)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", body)
	t.set_stylebox("embedded_border", "Window", tooltip_style())
	t.set_stylebox("embedded_unfocused_border", "Window", tooltip_style())
	t.set_color("title_color", "Window", INK)
	t.set_font("title_font", "Window", title)

	# --- text
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", title)
	t.set_font_size("font_size", "Title", 19)
	t.set_color("font_color", "Title", CREAM)
	t.set_color("font_shadow_color", "Title", Color(0.15, 0.02, 0.0, 0.7))
	t.set_constant("shadow_offset_x", "Title", 1)
	t.set_constant("shadow_offset_y", "Title", 1)
	t.set_stylebox("normal", "Title", banner_style())
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", caps)
	t.set_font_size("font_size", "Heading", 16)
	t.set_color("font_color", "Heading", ACCENT)
	t.set_type_variation("BarLabel", "Label")
	t.set_font("font", "BarLabel", bold)
	t.set_font_size("font_size", "BarLabel", 18)
	t.set_color("font_color", "BarLabel", CREAM)
	t.set_color("font_shadow_color", "BarLabel", Color(0, 0, 0, 0.75))
	t.set_constant("shadow_offset_x", "BarLabel", 1)
	t.set_constant("shadow_offset_y", "BarLabel", 1)
	t.set_type_variation("BarTitle", "Label")
	t.set_font("font", "BarTitle", title)
	t.set_font_size("font_size", "BarTitle", 18)
	t.set_color("font_color", "BarTitle", GOLD_TEXT)
	t.set_color("font_shadow_color", "BarTitle", Color(0, 0, 0, 0.8))
	t.set_constant("shadow_offset_x", "BarTitle", 1)
	t.set_constant("shadow_offset_y", "BarTitle", 1)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", body)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font("italics_font", "RichTextLabel", italic_font())

	# --- buttons: bevelled gold
	var bn := nine("button_normal.png", 8, 12.0, 3.0, true, false)
	var bh := nine("button_hover.png", 8, 12.0, 3.0, true, false)
	var bp := nine("button_pressed.png", 8, 12.0, 3.0, true, false)
	var bd := nine("button_disabled.png", 8, 12.0, 3.0, true, false)
	for typ in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", typ, bn)
		t.set_stylebox("hover", typ, bh)
		t.set_stylebox("pressed", typ, bp)
		t.set_stylebox("hover_pressed", typ, bp)
		t.set_stylebox("disabled", typ, bd)
		t.set_stylebox("focus", typ, StyleBoxEmpty.new())
		t.set_font("font", typ, bold)
		t.set_font_size("font_size", typ, 16)
		t.set_color("font_color", typ, ON_GOLD)
		t.set_color("font_hover_color", typ, Color(0.10, 0.05, 0.0))
		t.set_color("font_pressed_color", typ, ACCENT)
		t.set_color("font_hover_pressed_color", typ, ACCENT)
		t.set_color("font_focus_color", typ, ON_GOLD)
		t.set_color("font_disabled_color", typ, Color(0.30, 0.28, 0.25))
		t.set_color("icon_normal_color", typ, Color(1, 1, 1))
	# Leather tabs (toggles, tab rows)
	t.set_type_variation("Tab", "Button")
	t.set_stylebox("normal", "Tab", nine("tab_normal.png", 6, 10.0, 3.0, true, false))
	t.set_stylebox("hover", "Tab", nine("tab_hover.png", 6, 10.0, 3.0, true, false))
	t.set_stylebox("pressed", "Tab", nine("tab_pressed.png", 6, 10.0, 3.0, true, false))
	t.set_stylebox("hover_pressed", "Tab", nine("tab_pressed.png", 6, 10.0, 3.0, true, false))
	t.set_stylebox("disabled", "Tab", nine("tab_disabled.png", 6, 10.0, 3.0, true, false))
	t.set_color("font_color", "Tab", CREAM)
	t.set_color("font_hover_color", "Tab", Color(1, 0.95, 0.82))
	t.set_color("font_pressed_color", "Tab", Color(1, 0.92, 0.70))
	t.set_color("font_hover_pressed_color", "Tab", Color(1, 0.92, 0.70))
	t.set_color("font_disabled_color", "Tab", Color(0.7, 0.66, 0.6))
	# A bar button: no plate, cream text (top bar, side column)
	t.set_type_variation("BarButton", "Button")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(st, "BarButton", StyleBoxEmpty.new())
	t.set_font("font", "BarButton", title)
	t.set_font_size("font_size", "BarButton", 18)
	t.set_color("font_color", "BarButton", GOLD_TEXT)
	t.set_color("font_hover_color", "BarButton", Color(1, 0.93, 0.70))
	t.set_color("font_pressed_color", "BarButton", Color(1, 0.85, 0.5))
	t.set_color("font_hover_pressed_color", "BarButton", Color(1, 0.85, 0.5))
	t.set_color("font_outline_color", "BarButton", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "BarButton", 2)

	# --- checks, inputs, sliders, scroll bars
	for typ in ["CheckBox", "CheckButton"]:
		t.set_icon("checked", typ, _tex("check_on.png"))
		t.set_icon("unchecked", typ, _tex("check_off.png"))
		t.set_icon("checked_disabled", typ, _tex("check_on.png"))
		t.set_icon("unchecked_disabled", typ, _tex("check_off.png"))
		t.set_icon("radio_checked", typ, _tex("check_on.png"))
		t.set_icon("radio_unchecked", typ, _tex("check_off.png"))
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(st, typ, StyleBoxEmpty.new())
		t.set_color("font_color", typ, INK)
		t.set_color("font_hover_color", typ, ACCENT)
		t.set_color("font_pressed_color", typ, INK)
		t.set_color("font_hover_pressed_color", typ, ACCENT)
		t.set_color("font_focus_color", typ, INK)
		t.set_color("font_disabled_color", typ, Color(0.45, 0.40, 0.34))
	var field := _flat(Color(0.99, 0.96, 0.88, 0.95), Color(0.55, 0.40, 0.20), 1, 3, 4.0)
	for typ in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", typ, field)
		t.set_stylebox("focus", typ, _flat(Color(1, 0.98, 0.92, 1), ACCENT, 1, 3, 4.0))
		t.set_stylebox("read_only", typ, field)
		t.set_color("font_color", typ, INK)
		t.set_color("font_placeholder_color", typ, Color(0.45, 0.36, 0.26, 0.7))
		t.set_color("caret_color", typ, INK)
		t.set_color("selection_color", typ, Color(0.75, 0.55, 0.25, 0.45))
	var track := _flat(Color(0.22, 0.13, 0.08, 0.85), Color(0.55, 0.40, 0.20), 1, 4, 2.0)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _flat(Color(0.55, 0.14, 0.09), Color(0, 0, 0, 0), 0, 4, 2.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(Color(0.66, 0.18, 0.11), Color(0, 0, 0, 0), 0, 4, 2.0))
	t.set_icon("grabber", "HSlider", _tex("grabber.png"))
	t.set_icon("grabber_highlight", "HSlider", _tex("grabber_hover.png"))
	for typ in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", typ, _flat(Color(0.30, 0.19, 0.11, 0.22), Color(0, 0, 0, 0), 0, 5, 2.0))
		t.set_stylebox("grabber", typ, _flat(Color(0.70, 0.52, 0.24, 0.9), Color(0.45, 0.30, 0.12), 1, 5, 2.0))
		t.set_stylebox("grabber_highlight", typ, _flat(Color(0.82, 0.64, 0.30, 1.0), Color(0.45, 0.30, 0.12), 1, 5, 2.0))
		t.set_stylebox("grabber_pressed", typ, _flat(Color(0.55, 0.14, 0.09, 1.0), Color(0.45, 0.30, 0.12), 1, 5, 2.0))
	var bar_bg := _flat(Color(0.30, 0.19, 0.11, 0.35), Color(0.55, 0.40, 0.20), 1, 3, 0.0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", _flat(Color(0.62, 0.20, 0.10), Color(0, 0, 0, 0), 0, 3, 0.0))
	t.set_color("font_color", "ProgressBar", INK)
	t.set_color("font_outline_color", "ProgressBar", Color(1, 0.96, 0.86, 0.8))
	t.set_constant("outline_size", "ProgressBar", 2)

	# --- separators: thin gold-brown lines
	for typ in ["HSeparator", "VSeparator"]:
		var ln := StyleBoxLine.new()
		ln.color = Color(0.60, 0.42, 0.18, 0.75)
		ln.thickness = 1
		ln.vertical = typ == "VSeparator"
		ln.grow_begin = -4.0
		ln.grow_end = -4.0
		t.set_stylebox("separator", typ, ln)
		t.set_constant("separation", typ, 8)

	# --- tabs (TabContainer / TabBar)
	for typ in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", typ, nine("tab_pressed.png", 6, 10.0, 3.0, true, false))
		t.set_stylebox("tab_unselected", typ, nine("tab_normal.png", 6, 10.0, 3.0, true, false))
		t.set_stylebox("tab_hovered", typ, nine("tab_hover.png", 6, 10.0, 3.0, true, false))
		t.set_stylebox("tab_disabled", typ, nine("tab_disabled.png", 6, 10.0, 3.0, true, false))
		t.set_color("font_selected_color", typ, Color(1, 0.92, 0.70))
		t.set_color("font_unselected_color", typ, CREAM)
		t.set_color("font_hovered_color", typ, Color(1, 0.95, 0.82))
	t.set_stylebox("panel", "TabContainer", card_style())

	# --- lists
	for typ in ["ItemList", "Tree"]:
		t.set_stylebox("panel", typ, card_style())
		t.set_color("font_color", typ, INK)
		t.set_color("font_selected_color", typ, ACCENT)
		t.set_stylebox("selected", typ, _flat(Color(0.55, 0.12, 0.08, 0.18)))
		t.set_stylebox("selected_focus", typ, _flat(Color(0.55, 0.12, 0.08, 0.25)))
	return t
