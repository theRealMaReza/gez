extends SceneTree

# Phase 20 part 3: generated portraits for people of every region, age and
# rank on one screen (needs no game data). Saves portrait_gallery.png into
# $GEZ_GODOT_SNAPSHOT_DIR (or res://snapshots).

const SAMPLES := [
	{"key": "mehmed2", "name": "Mehmed II", "age": 21, "cultureFamily": "turkic", "religionFamily": "muslim", "portraitRank": "ruler", "courtTag": "TUR"},
	{"key": "ladislaus5", "name": "Ladislaus V", "age": 13, "cultureFamily": "german", "religionFamily": "christian", "portraitRank": "ruler"},
	{"key": "vasily2", "name": "Vasily II", "age": 38, "cultureFamily": "east_slavic", "religionFamily": "christian", "portraitRank": "ruler"},
	{"key": "zara_yaqob", "name": "Zara Yaqob", "age": 54, "cultureFamily": "ethiopian", "religionFamily": "christian", "portraitRank": "ruler"},
	{"key": "durad", "name": "Đurađ Branković", "age": 76, "cultureFamily": "south_slavic", "religionFamily": "christian", "portraitRank": "ruler"},
	{"key": "nicholas5", "name": "Nicholas V", "age": 55, "cultureFamily": "italian", "religionFamily": "christian", "portraitRank": "ruler", "courtTag": "PAP"},
	{"key": "inal", "name": "Inal", "age": 72, "cultureFamily": "arab", "religionFamily": "muslim", "portraitRank": "ruler", "courtTag": "MAM"},
	{"key": "jahan_shah", "name": "Jahan Shah", "age": 56, "cultureFamily": "iranian", "religionFamily": "muslim", "portraitRank": "ruler"},
	{"key": "kumbha", "name": "Rana Kumbha", "age": 36, "cultureFamily": "indo_aryan", "religionFamily": "dharmic", "portraitRank": "ruler"},
	{"key": "mallikarjuna", "name": "Mallikarjuna", "age": 28, "cultureFamily": "dravidian", "religionFamily": "dharmic", "portraitRank": "ruler"},
	{"key": "abulkhayr", "name": "Abu'l-Khayr", "age": 41, "cultureFamily": "mongolic", "religionFamily": "pagan", "portraitRank": "ruler"},
	{"key": "casimir4", "name": "Casimir IV", "age": 25, "cultureFamily": "west_slavic", "religionFamily": "christian", "portraitRank": "ruler"},
	{"key": "hunyadi", "name": "John Hunyadi", "age": 47, "cultureFamily": "magyar", "religionFamily": "christian", "portraitRank": "court"},
	{"key": "gulbahar", "name": "Gülbahar Hatun", "age": 21, "female": true, "cultureFamily": "turkic", "religionFamily": "muslim", "portraitRank": "court"},
	{"key": "margaret_an", "name": "Margaret of Anjou", "age": 23, "female": true, "cultureFamily": "french", "religionFamily": "christian", "portraitRank": "court"},
	{"key": "zoe_p", "name": "Zoe Palaiologina", "age": 4, "female": true, "cultureFamily": "hellenic", "religionFamily": "christian", "portraitRank": "court"},
	{"key": "bayezid2", "name": "Bayezid (5)", "age": 5, "cultureFamily": "turkic", "religionFamily": "muslim", "portraitRank": "heir"},
	{"key": "foscari", "name": "Francesco Foscari", "age": 80, "cultureFamily": "italian", "religionFamily": "christian", "portraitRank": "court"},
	{"key": "x_burgher", "name": "a German burgher", "age": 44, "cultureFamily": "german", "religionFamily": "christian", "portraitRank": "common"},
	{"key": "x_bengal", "name": "a Bengali noble", "age": 33, "cultureFamily": "indo_aryan", "religionFamily": "muslim", "portraitRank": "court"},
	{"key": "x_bantu", "name": "a Swahili lord", "age": 40, "cultureFamily": "bantu", "religionFamily": "muslim", "portraitRank": "court"},
	{"key": "x_tibet", "name": "a Tibetan lord", "age": 50, "cultureFamily": "tibeto_burman", "religionFamily": "dharmic", "portraitRank": "court"},
	{"key": "x_queen", "name": "a queen", "age": 35, "female": true, "cultureFamily": "iberian", "religionFamily": "christian", "portraitRank": "ruler"},
	{"key": "x_dead", "name": "a dead king", "age": 60, "isAlive": false, "cultureFamily": "british", "religionFamily": "christian", "portraitRank": "ruler"},
]

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	bg.add_child(grid)
	for s in SAMPLES:
		var box := VBoxContainer.new()
		box.add_child(Portrait.make(s, Vector2(120, 150)))
		var l := Label.new()
		l.text = s["name"]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 14)
		box.add_child(l)
		grid.add_child(box)
	call_deferred("_shoot")

func _shoot() -> void:
	for _i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("GEZ_GODOT_SNAPSHOT_DIR")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://snapshots")
	DirAccess.make_dir_recursive_absolute(out)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("portrait_gallery.png"))
	print("snapshot: portrait_gallery.png")
	quit(0)
