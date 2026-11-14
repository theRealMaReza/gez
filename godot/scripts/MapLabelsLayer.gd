extends Control

var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
var map_mode: String = "political"

var country_texts: PackedStringArray = PackedStringArray()
var country_metrics: PackedFloat32Array = PackedFloat32Array()

var province_texts: PackedStringArray = PackedStringArray()
var province_metrics: PackedFloat32Array = PackedFloat32Array()

var sea_texts: PackedStringArray = PackedStringArray()
var sea_metrics: PackedFloat32Array = PackedFloat32Array()

func update_camera(new_zoom: float, new_offset: Vector2) -> void:
	if is_equal_approx(map_zoom, new_zoom) and map_offset.is_equal_approx(new_offset):
		return
	map_zoom = new_zoom
	map_offset = new_offset
	queue_redraw()

func set_map_mode(mode_key: String) -> void:
	if map_mode == mode_key:
		return
	map_mode = mode_key
	queue_redraw()

func set_country_labels(texts: PackedStringArray, metrics: PackedFloat32Array) -> void:
	country_texts = texts
	country_metrics = metrics
	queue_redraw()

func set_province_labels(texts: PackedStringArray, metrics: PackedFloat32Array) -> void:
	province_texts = texts
	province_metrics = metrics
	queue_redraw()

func set_sea_labels(texts: PackedStringArray, metrics: PackedFloat32Array) -> void:
	sea_texts = texts
	sea_metrics = metrics
	queue_redraw()

func _draw() -> void:
	if map_zoom <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var bounds := Rect2(Vector2(-60.0, -20.0), size + Vector2(120.0, 40.0))
	var placed: Array[Rect2] = []
	var z2 := map_zoom * map_zoom

	# 1. Sea names first in pale blue-white so land labels can sit over them.
	var sea_count := sea_texts.size()
	var sea_col := Color(0.86, 0.93, 0.97, 0.82)
	var sea_shadow := Color(0.10, 0.18, 0.24, 0.65)
	for i in range(sea_count):
		var base_idx := i * 3
		if base_idx + 2 >= sea_metrics.size():
			break
		var screen_area := sea_metrics[base_idx + 2] * z2
		if screen_area <= 9000.0:
			continue
		var p := Vector2(
			map_offset.x + sea_metrics[base_idx] * map_zoom,
			map_offset.y + sea_metrics[base_idx + 1] * map_zoom
		)
		if not bounds.has_point(p):
			continue
		var font_size := int(clampf(sqrt(screen_area) / 14.0, 10.0, 16.0))
		var label_text := sea_texts[i]
		var w := float(label_text.length()) * float(font_size) * 0.55
		var h := float(font_size) * 1.4
		var rect := Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h)
		if _overlaps(placed, rect):
			continue
		placed.append(rect)
		var baseline := Vector2(p.x - w * 0.5, p.y + float(font_size) * 0.35)
		draw_string_outline(font, baseline, label_text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 2, sea_shadow)
		draw_string(font, baseline, label_text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, sea_col)

	# 2. Country names when zoomed out (political mode), province names when zoomed in.
	placed.clear()
	var show_provinces := map_zoom >= 1.1
	if not show_provinces and map_mode != "political":
		return
	var texts := province_texts if show_provinces else country_texts
	var metrics := province_metrics if show_provinces else country_metrics
	var count := texts.size()
	var ink := Color(0.14, 0.10, 0.07, 0.88)
	var halo := Color(0.97, 0.94, 0.88, 0.82)

	for i in range(count):
		var base_idx := i * 3
		if base_idx + 2 >= metrics.size():
			break
		var screen_area := metrics[base_idx + 2] * z2
		var min_area := 2200.0 if show_provinces else 1800.0
		if screen_area <= min_area:
			continue
		var p := Vector2(
			map_offset.x + metrics[base_idx] * map_zoom,
			map_offset.y + metrics[base_idx + 1] * map_zoom
		)
		if not bounds.has_point(p):
			continue

		var font_size: int
		var label_text: String
		var w: float
		if show_provinces:
			font_size = int(clampf(sqrt(screen_area) / 9.0, 10.0, 14.0))
			label_text = texts[i]
			w = float(label_text.length()) * float(font_size) * 0.56
		else:
			font_size = int(clampf(sqrt(screen_area) / 7.0, 10.0, 26.0))
			label_text = texts[i].to_upper()
			w = float(label_text.length()) * float(font_size) * 0.68

		var h := float(font_size) * 1.4
		var rect := Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h)
		if _overlaps(placed, rect):
			continue
		placed.append(rect)
		var baseline := Vector2(p.x - w * 0.5, p.y + float(font_size) * 0.35)
		draw_string_outline(font, baseline, label_text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 3, halo)
		draw_string(font, baseline, label_text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, ink)

func _overlaps(placed: Array[Rect2], candidate: Rect2) -> bool:
	for r in placed:
		if r.intersects(candidate):
			return true
	return false
