class_name Portrait
extends Control

# Phase 20 part 3: a portrait for every character.
#
# 1. A painting by the owner, if one is in assets/paintings/portraits/
#    named after the character's id (mehmed2.png ...): see docs/ART_PROMPTS.md.
# 2. Otherwise one made from layered parts in the manuscript style (owner's
#    choice): face, eyes, beard, hair, headwear and clothes picked by
#    culture, religion, age, sex and rank; the character's id picks the
#    variant, so a person always looks the same.
# The parts come from tools/uiart/ui_art_concept.py --kit (portrait_art.py).
#
# Use: var p := Portrait.make(character_dict, Vector2(96, 120))

const PARTS_DIR := "res://assets/ui/portrait/"

static var _parts: Dictionary = {}

## Character dictionary keys used (all optional): key, characterIndex,
## female, age, isAlive, cultureFamily, religion, religionFamily, courtTag,
## portraitRank ("ruler", "heir", "court", "common"), isRuler.
static func make(ch: Dictionary, size := Vector2(96, 120)) -> Portrait:
	var p := Portrait.new()
	p.custom_minimum_size = size
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.set_character(ch)
	return p

func set_character(ch: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var window := TextureRect.new()
	window.texture = GezStyle.tex(PARTS_DIR + "mask.png")
	window.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	window.stretch_mode = TextureRect.STRETCH_SCALE
	window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window)
	var painting := GezStyle.painting("portraits", str(ch.get("key", "")))
	if painting != null:
		var pr := TextureRect.new()
		pr.texture = painting
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.add_child(pr)
	else:
		for layer in layers_for(ch):
			_add_part(window, layer[0], layer[1])
		if not bool(ch.get("isAlive", true)):
			window.modulate = Color(0.78, 0.74, 0.70)
	var frame := TextureRect.new()
	frame.texture = GezStyle.tex(PARTS_DIR + "frame.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

func _add_part(parent: Control, part: String, tint: Color) -> void:
	var kinds: Array = _part_kinds().get(part, [])
	if part == "bg":
		kinds = ["color"]
	for kind in ["fill", "color", "ink"]:
		if not kinds.has(kind):
			continue
		var t := TextureRect.new()
		t.texture = GezStyle.tex(PARTS_DIR + ("bg.png" if part == "bg" else "%s_%s.png" % [part, kind]))
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if kind == "fill":
			t.modulate = tint
		parent.add_child(t)

static func _part_kinds() -> Dictionary:
	if _parts.is_empty():
		var path := PARTS_DIR + "parts.json"
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				_parts = d
	return _parts

# ------------------------------------------------------------------ choices

const SKIN := {
	"west": [Color8(238, 204, 176), Color8(232, 194, 164), Color8(226, 186, 154)],
	"orthodox": [Color8(234, 198, 168), Color8(226, 188, 158), Color8(220, 180, 150)],
	"central": [Color8(236, 200, 170), Color8(228, 190, 160)],
	"turk": [Color8(224, 184, 148), Color8(212, 170, 134), Color8(204, 162, 126)],
	"iran": [Color8(214, 170, 130), Color8(200, 156, 116)],
	"arab": [Color8(206, 160, 118), Color8(190, 144, 104), Color8(176, 130, 94)],
	"indian": [Color8(180, 130, 92), Color8(162, 114, 80), Color8(142, 100, 70)],
	"ethiopian": [Color8(136, 94, 64), Color8(120, 82, 56)],
	"african": [Color8(104, 70, 50), Color8(90, 62, 44)],
	"steppe": [Color8(222, 186, 142), Color8(214, 176, 132)],
	"east": [Color8(232, 198, 152), Color8(222, 186, 140)],
}
const HAIR_WEST := [Color8(62, 42, 26), Color8(112, 74, 42), Color8(196, 156, 86), Color8(150, 72, 34), Color8(40, 30, 22)]
const HAIR_DARK := [Color8(40, 30, 22), Color8(30, 24, 20), Color8(58, 40, 26)]
const CLOTH_ROYAL := [Color8(150, 30, 40), Color8(96, 40, 104), Color8(30, 90, 80), Color8(40, 62, 132)]
const CLOTH_MUSLIM_ROYAL := [Color8(40, 110, 70), Color8(40, 62, 132), Color8(150, 30, 40)]
const CLOTH := [Color8(60, 100, 60), Color8(110, 80, 50), Color8(50, 80, 120), Color8(140, 96, 40), Color8(120, 50, 40), Color8(90, 90, 96), Color8(130, 40, 60)]
const ERMINE := Color8(242, 238, 228)
const FUR := Color8(100, 70, 45)
const GOLD := Color8(214, 172, 60)
const WHITE := Color8(240, 236, 226)

## Which way of dressing a person follows, from culture family and faith.
static func look_group(culture_family: String, religion_family: String) -> String:
	var muslim := religion_family == "muslim"
	match culture_family:
		"iberian", "french", "dutch", "british", "gaelic", "german", "nordic", "italian", "finnic", "baltic":
			return "arab" if muslim else "west"
		"west_slavic", "magyar":
			return "central"
		"east_slavic", "south_slavic", "hellenic", "eastern_romance", "kartvelian", "armenian":
			return "turk" if muslim else "orthodox"
		"albanian", "caucasian":
			return "turk" if muslim else "orthodox"
		"turkic":
			return "turk" if muslim else "steppe"
		"volga_ural", "mongolic":
			return "steppe"
		"iranian":
			return "iran"
		"arab", "berber", "jewish":
			return "arab"
		"indo_aryan", "dravidian", "sinhalese", "himalayan":
			return "indian"
		"ethiopian", "cushitic":
			return "arab" if muslim else "ethiopian"
		"nilo_saharan", "bantu":
			return "african"
		"tibeto_burman", "austroasiatic":
			return "east"
	return "arab" if muslim else "west"

static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]

static func _grey(c: Color, age: int) -> Color:
	if age >= 65:
		return Color8(222, 218, 210)
	if age >= 45:
		return c.lerp(Color8(160, 156, 150), clampf((age - 45) / 20.0, 0.0, 0.85))
	return c

## The list of [part, tint] for a character, bottom layer first.
static func layers_for(ch: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	var seed_text := str(ch.get("key", ""))
	if seed_text.is_empty():
		seed_text = "c%d" % int(ch.get("characterIndex", 0))
	rng.seed = hash(seed_text)
	var female := bool(ch.get("female", false))
	var age := int(ch.get("age", 30))
	var rank := str(ch.get("portraitRank", "ruler" if bool(ch.get("isRuler", false)) else "court"))
	var royal := rank == "ruler"
	var religion_family := str(ch.get("religionFamily", ""))
	var group := look_group(str(ch.get("cultureFamily", "")), religion_family)
	var culture := str(ch.get("cultureFamily", ""))
	var tag := str(ch.get("courtTag", ""))
	var muslim := religion_family == "muslim"
	var skin: Color = _pick(rng, SKIN.get(group, SKIN["west"]))
	var hair_base: Color = _pick(rng, HAIR_WEST if group in ["west", "central", "orthodox"] else HAIR_DARK)
	var hair := _grey(hair_base, age)
	var cloth: Color = _pick(rng, (CLOTH_MUSLIM_ROYAL if muslim else CLOTH_ROYAL) if royal else CLOTH)
	var face: String = _pick(rng, ["face_oval", "face_round", "face_long", "face_square"])
	var eyes: String = "eyes_c" if age >= 50 else _pick(rng, ["eyes_a", "eyes_b", "eyes_a"])
	var brows: String = _pick(rng, ["brows_a", "brows_b", "brows_c"])
	var nose: String = _pick(rng, ["nose_a", "nose_b", "nose_c", "nose_d"])
	var mouth: String = _pick(rng, ["mouth_a", "mouth_b", "mouth_c"])

	var out: Array = [["bg", Color.WHITE]]
	var robe := "west"
	match group:
		"turk", "iran", "arab", "east":
			robe = "kaftan"
		"indian":
			robe = "jama"
		"ethiopian", "african":
			robe = "shamma"
		"steppe":
			robe = "steppe"
	var trim: Color = (ERMINE if group == "west" else GOLD) if royal else (FUR if group in ["orthodox", "central", "steppe", "west"] else GOLD)
	if robe == "shamma":
		cloth = WHITE
		trim = _pick(rng, [Color8(150, 30, 40), Color8(40, 62, 132), GOLD])

	# --- back layers, clothes, face
	var veil := false
	if female:
		if age >= 14:
			veil = true
			var veil_col: Color = WHITE if group in ["west", "orthodox", "central", "ethiopian"] else _pick(rng, [WHITE, Color8(40, 62, 132), Color8(130, 40, 60), Color8(60, 100, 60)])
			out.append(["veil_back", veil_col])
			out.append(["robe_women", cloth])
			out.append(["trim_women", trim])
		else:
			out.append(["hair_f_back", hair])
			out.append(["robe_women", cloth])
			out.append(["trim_women", trim])
		out.append(["pearls", Color.WHITE])
	else:
		if group == "west" and rng.randf() < 0.5 and age < 60:
			out.append(["hair_long_back", hair])
		out.append(["robe_" + robe, cloth])
		out.append(["trim_" + robe, trim])
		if royal and group in ["west", "central"]:
			out.append(["chain", Color.WHITE])
		if royal and group == "indian":
			out.append(["pearls", Color.WHITE])
	out.append(["neck", skin])
	out.append(["ears", skin])
	out.append([face, skin])
	if female or age < 18:
		out.append(["cheeks", Color.WHITE])
	out.append([eyes, Color.WHITE])
	out.append([brows, hair])
	out.append([nose, Color.WHITE])
	if age >= 45:
		out.append(["wrinkles", Color.WHITE])

	# --- beards
	var beard := ""
	var moust := ""
	if not female and age >= 17:
		match group:
			"west":
				if rng.randf() < 0.4:
					beard = _pick(rng, ["beard_short", "beard_full"])
					moust = "moust_thin"
			"central":
				moust = "moust_thick"
				if rng.randf() < 0.4:
					beard = "beard_short"
			"orthodox":
				beard = _pick(rng, ["beard_full", "beard_long", "beard_forked", "beard_full"])
				moust = "moust_thick"
			"turk":
				moust = "moust_thick"
				beard = _pick(rng, ["beard_short", "beard_full", ""])
			"iran", "arab":
				beard = _pick(rng, ["beard_full", "beard_short", "beard_long"])
				moust = "moust_thick"
			"indian":
				moust = "moust_curled"
				if muslim or rng.randf() < 0.4:
					beard = "beard_full"
			"ethiopian", "african":
				beard = _pick(rng, ["beard_short", ""])
				moust = "moust_thin"
			"steppe":
				moust = "moust_thin"
				beard = _pick(rng, ["beard_short", ""])
			"east":
				moust = "moust_thin"
	if tag == "PAP" and royal:
		beard = ""
		moust = ""
	if beard != "":
		out.append([beard, hair])
	out.append([mouth, Color.WHITE])
	if moust != "":
		out.append([moust, hair])

	# --- hair and headwear
	if female:
		if veil:
			out.append(["veil_front", (out[1][1] as Color)])
			if royal:
				out.append(["crown_queen", Color.WHITE])
			elif rank == "heir" or rank == "court":
				if group in ["west", "central", "orthodox"]:
					out.append(["circlet", Color.WHITE])
		else:
			out.append(["hair_f", hair])
		return out

	var hat_col: Color = _pick(rng, CLOTH)
	match group:
		"west", "central":
			if tag == "PAP" and royal:
				out.append(["hair_short", hair])
				out.append(["tiara", WHITE])
			elif royal:
				out.append([_pick(rng, ["hair_bowl", "hair_long"]), hair])
				out.append(["crown_west", Color.WHITE])
			elif group == "central":
				out.append(["hair_short", hair])
				out.append(["kalpak", _pick(rng, [Color8(150, 30, 40), Color8(40, 62, 132), Color8(60, 100, 60)])])
				out.append(["kalpak_band", FUR])
				out.append(["feather", Color.WHITE])
			else:
				var hat: String = _pick(rng, ["chaperon", "bonnet", "none", "none"])
				if hat == "none":
					out.append([("hair_bald" if age >= 55 else _pick(rng, ["hair_bowl", "hair_long", "hair_curly"])), hair])
				else:
					out.append(["hair_bowl", hair])
					out.append([hat, hat_col])
					if hat == "chaperon":
						out.append(["liripipe", hat_col])
		"orthodox":
			out.append(["hair_long", hair])
			if royal:
				if culture == "east_slavic":
					out.append(["monomakh_fur", FUR])
					out.append(["monomakh_cap", Color.WHITE])
				else:
					out.append(["crown_east", Color.WHITE])
			else:
				out.append(["kalpak", Color8(70, 48, 34)])
				out.append(["kalpak_band", FUR])
		"turk":
			out.append(["hair_short", hair])
			out.append(["turban_ottoman", WHITE])
			out.append(["kavuk", Color.WHITE])
			if royal:
				out.append(["aigrette", Color.WHITE])
		"iran":
			out.append(["hair_short", hair])
			out.append(["turban_persian", WHITE])
			out.append(["taj", Color.WHITE])
			if royal:
				out.append(["aigrette", Color.WHITE])
		"arab":
			out.append(["hair_short", hair])
			if royal and tag == "MAM":
				out.append(["turban_mamluk", WHITE])
				out.append(["mamluk_horns", Color.WHITE])
			elif royal or rng.randf() < 0.5:
				out.append(["turban_mamluk", WHITE])
			else:
				out.append(["keffiyeh", WHITE])
				out.append(["agal", Color.WHITE])
		"indian":
			out.append(["hair_short", hair])
			if royal and culture == "dravidian" and not muslim:
				out.append(["crown_india", Color.WHITE])
			else:
				out.append(["turban_indian", _pick(rng, [Color8(200, 120, 40), Color8(170, 40, 50), WHITE, Color8(220, 180, 60)])])
				if royal:
					out.append(["sarpech", Color.WHITE])
		"ethiopian":
			out.append(["hair_curly", hair])
			if royal:
				out.append(["crown_eth", Color.WHITE])
			else:
				out.append(["headwrap", WHITE])
		"african":
			out.append(["hair_curly", hair])
			out.append(["headwrap", _pick(rng, [WHITE, Color8(170, 40, 50), Color8(220, 180, 60)])])
		"steppe":
			out.append(["hair_short", hair])
			out.append(["steppe_hat", _pick(rng, [Color8(150, 30, 40), Color8(40, 62, 132), Color8(190, 150, 60)])])
			out.append(["steppe_brim", FUR])
		"east":
			out.append(["hair_short", hair])
			out.append(["east_hat", Color8(40, 36, 34)])
	return out
