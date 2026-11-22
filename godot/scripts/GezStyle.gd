class_name GezStyle
extends RefCounted

# Small helpers for the Phase 20 look. The Theme (GezTheme.gd, saved as
# res://assets/ui/gez_theme.tres and set as the project's default theme)
# styles every plain control by itself; use these only for the special
# pieces a Theme can't express: medallion buttons, trait seals, title
# banners, and the colour remap that keeps old hand-coloured text readable
# on the parchment pages.

const MEDALLIONS := "res://assets/ui/medallions/"
const SEALS := "res://assets/ui/seals/"

static var _cache: Dictionary = {}

static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[path] = t
	return t

## Medallion picture for a screen button or indicator, by key (see
## MEDALLIONS in tools/uiart/ui_art_concept.py: "court", "wars",
## "chronicle", "map_religion"...). on = the red "active" enamel.
static func medallion(key: String, on := false) -> Texture2D:
	return tex(MEDALLIONS + key + ("_on" if on else "") + ".png")

## Wax seal for a character trait (seals/trait_<key>.png), or a plain seal.
static func trait_seal(key: String) -> Texture2D:
	var t := tex(SEALS + "trait_" + key + ".png")
	return t if t != null else tex(SEALS + "virtue.png")

## A round gold medallion button with an engraved icon. It lights up on
## hover and presses in when clicked; `size` is its width in pixels.
static func medallion_button(key: String, size := 40.0) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = medallion(key)
	b.texture_pressed = medallion(key, true)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(size, size)
	b.pivot_offset = Vector2(size, size) * 0.5
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.set_meta("gez_medallion", key)
	b.mouse_entered.connect(func() -> void: b.self_modulate = Color(1.22, 1.16, 1.02))
	b.mouse_exited.connect(func() -> void:
		b.self_modulate = Color(1, 1, 1)
		b.scale = Vector2.ONE)
	b.button_down.connect(func() -> void: b.scale = Vector2(0.92, 0.92))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	return b

## Show a medallion button as active (red enamel), e.g. the open screen or
## the current map mode.
static func set_medallion_on(b: TextureButton, on: bool) -> void:
	if b == null or not b.has_meta("gez_medallion"):
		return
	var key: String = b.get_meta("gez_medallion")
	b.texture_normal = medallion(key, on)

## A red cloth title banner (Label with the "Title" theme variation).
static func title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "Title"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

## A small medallion "×" button that closes a window.
static func close_button(on_pressed: Callable) -> TextureButton:
	var b := medallion_button("close", 30.0)
	b.tooltip_text = "Close"
	b.pressed.connect(on_pressed)
	return b

## Remap a colour picked for light-on-dark panels (before Phase 20) to one
## that reads on parchment: keeps its hue (green stays green, red stays
## red) but makes it dark; greys and creams become ink.
static func ink(c: Color) -> Color:
	var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	if lum < 0.45:
		return c
	if c.s < 0.28:
		# cream / white / grey: ink, softer for the dimmer greys
		return GezTheme.INK if lum > 0.80 else GezTheme.INK_SOFT
	var h := c.h
	if h > 0.10 and h < 0.17 and c.s < 0.6:
		# pale gold (the old "names and headings" colour): deep red accent
		return GezTheme.ACCENT
	var out := Color.from_hsv(h, clampf(c.s * 1.1, 0.55, 0.95), 0.42 if (h > 0.2 and h < 0.5) else 0.55, c.a)
	return out

## Turn an existing label into a red cloth title banner (drops the old
## colour and size overrides so the "Title" theme style shows).
static func as_title(l: Label) -> Label:
	if l == null:
		return l
	l.remove_theme_color_override("font_color")
	l.remove_theme_font_size_override("font_size")
	l.theme_type_variation = "Title"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

## A deep-red Cinzel heading on parchment (names, section titles).
static func as_heading(l: Label) -> Label:
	if l == null:
		return l
	l.remove_theme_color_override("font_color")
	l.remove_theme_font_size_override("font_size")
	l.theme_type_variation = "Heading"
	return l

static var _indexes: Dictionary = {}

static func _index(folder: String) -> Dictionary:
	if not _indexes.has(folder):
		var d: Variant = {}
		var path := "res://assets/ui/%s/index.json" % folder
		if FileAccess.file_exists(path):
			d = JSON.parse_string(FileAccess.get_file_as_string(path))
		_indexes[folder] = d if d is Dictionary else {}
	return _indexes[folder]

## Icon of a trade good by its name as the game shows it ("Olive Oil"):
## the good in colour on a small gold roundel (Phase 20 part 2).
static func good_icon(good_name: String) -> Texture2D:
	var key: String = _index("goods").get(good_name, "")
	return null if key.is_empty() else tex("res://assets/ui/goods/%s.png" % key)

## Icon of a building by its name ("Cloth Weavers"): rendered from our 3D
## models on a gold-edged plaque (Phase 20 part 2).
static func building_icon(building_name: String) -> Texture2D:
	var key: String = _index("buildings").get(building_name, "")
	return null if key.is_empty() else tex("res://assets/ui/buildings/%s.png" % key)

## A small TextureRect showing `t` at `size` pixels (null-safe: empty box).
static func icon_rect(t: Texture2D, size := 24.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r

## Font size for text on parchment: EB Garamond looks smaller than the old
## sans-serif at the same size, so small sizes get a little bigger.
static func fs(n: int) -> int:
	return n + 2 if n <= 13 else n + 1

const PAINTINGS := "res://assets/paintings/"
const PAINTING_EXTS := ["png", "jpg", "jpeg", "webp"]

## The owner's painting `name` in assets/paintings/<kind>/ ("menu",
## "events", "portraits"), or null if it hasn't been made yet (the screen
## then shows its placeholder). Works both for imported pictures (exported
## games) and for pictures just dropped into the folder (running from the
## project): docs/ART_PROMPTS.md lists the file names.
static func painting(kind: String, painting_name: String) -> Texture2D:
	if painting_name.is_empty():
		return null
	var ck := "painting:%s/%s" % [kind, painting_name]
	if _cache.has(ck):
		return _cache[ck]
	var t: Texture2D = null
	for ext in PAINTING_EXTS:
		var path := "%s%s/%s.%s" % [PAINTINGS, kind, painting_name, ext]
		if ResourceLoader.exists(path):
			t = load(path) as Texture2D
		elif FileAccess.file_exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img != null and not img.is_empty():
				t = ImageTexture.create_from_image(img)
		if t != null:
			break
	_cache[ck] = t
	return t
