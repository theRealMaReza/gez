extends RefCounted

# Phase 20 part 1: the shared Theme and the style-kit art.
var runner: Object

func test_project_theme_is_the_gez_theme() -> void:
	var path := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	runner.check(path == "res://assets/ui/gez_theme.tres", "project default theme is gez_theme.tres (got %s)" % path)
	var t: Theme = load(path) as Theme
	runner.check(t != null, "gez_theme.tres loads")
	if t == null:
		return
	for pair in [["panel", "PanelContainer"], ["panel", "Card"], ["panel", "TopBar"], ["panel", "SideBar"],
			["normal", "Button"], ["normal", "Tab"], ["normal", "Title"], ["panel", "TooltipPanel"]]:
		runner.check(t.has_stylebox(pair[0], pair[1]), "theme has %s/%s" % [pair[1], pair[0]])
	runner.check(t.default_font != null, "theme has a default font")

func test_saved_theme_matches_builder() -> void:
	# gez_theme.tres must be re-saved (tools/build_theme.gd) after GezTheme.gd changes.
	var saved: Theme = load("res://assets/ui/gez_theme.tres") as Theme
	var fresh: Theme = GezTheme.build()
	if saved == null:
		runner.check(false, "saved theme loads")
		return
	for typ in fresh.get_type_list():
		for sb in fresh.get_stylebox_list(typ):
			runner.check(saved.has_stylebox(sb, typ), "saved theme has %s/%s (re-run tools/build_theme.gd)" % [typ, sb])
		for c in fresh.get_color_list(typ):
			runner.check(saved.has_color(c, typ) and saved.get_color(c, typ).is_equal_approx(fresh.get_color(c, typ)),
				"saved theme colour %s/%s matches (re-run tools/build_theme.gd)" % [typ, c])

func test_every_medallion_and_seal_exists() -> void:
	for k in ["treasury", "stability", "faith", "manpower", "sailors", "inflation", "menu", "pause", "close",
			"budget", "trade", "court", "government", "religion", "rebels", "technology", "diplomacy",
			"wars", "armies", "fleets", "chronicle", "ledger", "timelapse", "zoom_in", "zoom_out", "zoom_fit",
			"map_political", "map_diplomatic", "map_states", "map_terrain", "map_religion", "map_culture",
			"map_development", "map_goods", "map_markets", "map_plague", "map_unrest", "map_institutions"]:
		runner.check(GezStyle.medallion(k) != null and GezStyle.medallion(k, true) != null, "medallion %s (+ _on)" % k)
	for t in ["brave", "cruel", "scholar", "sickly", "blind", "ambitious"]:
		runner.check(ResourceLoader.exists("res://assets/ui/seals/trait_%s.png" % t), "trait seal %s" % t)

func test_ink_keeps_text_readable_on_parchment() -> void:
	# light colours (made for dark panels) become dark; dark ones stay
	for c in [Color(0.97, 0.90, 0.68), Color(0.95, 0.92, 0.85), Color(0.55, 0.92, 0.55), Color(0.98, 0.55, 0.50), Color(0.72, 0.68, 0.60)]:
		var o := GezStyle.ink(c)
		var lum := 0.299 * o.r + 0.587 * o.g + 0.114 * o.b
		runner.check(lum < 0.45, "ink(%s) is dark enough (lum %f)" % [c, lum])
	runner.check(GezStyle.ink(Color(0.2, 0.1, 0.05)) == Color(0.2, 0.1, 0.05), "dark colours are unchanged")
	var g := GezStyle.ink(Color(0.55, 0.92, 0.55))
	runner.check(g.g > g.r and g.g > g.b, "green stays green")
	var r := GezStyle.ink(Color(0.98, 0.55, 0.50))
	runner.check(r.r > r.g and r.r > r.b, "red stays red")

func test_every_good_and_building_has_an_icon() -> void:
	# Phase 20 part 2: index.json maps names to icons; one icon per good and building.
	for pair in [["goods", 62], ["buildings", 34]]:
		var path := "res://assets/ui/%s/index.json" % pair[0]
		var idx: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		runner.check(idx is Dictionary and (idx as Dictionary).size() == pair[1], "%s index has %d entries" % pair)
		if idx is Dictionary:
			for n in (idx as Dictionary).keys():
				var key: String = idx[n]
				runner.check(ResourceLoader.exists("res://assets/ui/%s/%s.png" % [pair[0], key]), "%s icon for %s" % [pair[0], n])
	runner.check(GezStyle.good_icon("Olive Oil") != null, "good_icon finds Olive Oil")
	runner.check(GezStyle.building_icon("Cloth Weavers") != null, "building_icon finds Cloth Weavers")
	runner.check(GezStyle.good_icon("No Such Good") == null, "unknown good gives no icon")
