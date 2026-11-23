extends RefCounted

# Phase 20.6 part 1 (tests by Gemini, from PR #27): MapLabelsLayer caches measured widths from Font.get_string_size
# so Cinzel country names and fallback province/sea names are never clipped.
const LabelsScript := preload("res://scripts/MapLabelsLayer.gd")

var runner: Object

func test_country_labels_measure_and_cache_cinzel_width() -> void:
	var layer: Control = LabelsScript.new()
	layer.set("map_zoom", 0.5)
	var texts := PackedStringArray(["Hormuz", "Wurttemberg"])
	var metrics := PackedFloat32Array([
		200.0, 200.0, 16000.0,
		800.0, 200.0, 16000.0,
	])
	var placed: Array = layer.call("_place_labels_world", texts, metrics, false, false)
	runner.check(placed.size() == 2, "two well-separated countries placed")
	var cinzel: Font = GezTheme.title_font()
	for entry in placed:
		var w_scr: float = entry[2]
		var fsize: int = entry[3]
		var txt: String = entry[4]
		var measured: float = cinzel.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		runner.check(w_scr >= measured, "cached country width (%f) >= Cinzel width (%f) for %s" % [w_scr, measured, txt])
	layer.free()

func test_crowded_country_labels_use_measured_width_for_overlap() -> void:
	var layer: Control = LabelsScript.new()
	layer.set("map_zoom", 0.5)
	var cinzel: Font = GezTheme.title_font()
	var name_a := "MMMMMMMM"
	var fsize := 10
	var measured_w: float = cinzel.get_string_size(name_a, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	# Place second label outside naive 0.55*8*10 = 44px width, but inside actual Cinzel width.
	var offset_x: float = (measured_w * 0.8) / 0.5
	var texts := PackedStringArray([name_a, name_a])
	var metrics := PackedFloat32Array([
		200.0, 200.0, 8000.0,
		200.0 + offset_x, 200.0, 8000.0,
	])
	var placed: Array = layer.call("_place_labels_world", texts, metrics, false, false)
	runner.check(placed.size() == 1, "crowded Cinzel labels reject overlap using measured width (got %d)" % placed.size())
	layer.free()

func test_province_and_sea_labels_measure_fallback_width() -> void:
	var layer: Control = LabelsScript.new()
	layer.set("map_zoom", 2.0)
	var fb: Font = ThemeDB.fallback_font
	var provs: Array = layer.call("_place_labels_world", PackedStringArray(["Ankara"]), PackedFloat32Array([100.0, 100.0, 4000.0]), false, true)
	runner.check(provs.size() == 1, "province label placed")
	if provs.size() == 1:
		var e: Array = provs[0]
		var mw: float = fb.get_string_size(str(e[4]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(e[3])).x
		runner.check(float(e[2]) >= mw, "province width (%f) >= measured (%f)" % [float(e[2]), mw])
	var seas: Array = layer.call("_place_labels_world", PackedStringArray(["Northern Aegean"]), PackedFloat32Array([300.0, 300.0, 8000.0]), true, false)
	runner.check(seas.size() == 1, "sea label placed")
	if seas.size() == 1:
		var se: Array = seas[0]
		var smw: float = fb.get_string_size(str(se[4]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(se[3])).x
		runner.check(float(se[2]) >= smw, "sea width (%f) >= measured (%f)" % [float(se[2]), smw])
	layer.free()
