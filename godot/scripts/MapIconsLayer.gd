extends Control

var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
var icon_metrics: PackedFloat32Array = PackedFloat32Array()
var icons_revision: int = -1

func update_camera(new_zoom: float, new_offset: Vector2) -> void:
	if is_equal_approx(map_zoom, new_zoom) and map_offset.is_equal_approx(new_offset):
		return
	map_zoom = new_zoom
	map_offset = new_offset
	queue_redraw()

func set_icons_data(new_metrics: PackedFloat32Array, new_revision: int) -> void:
	if new_revision == icons_revision and new_metrics.size() == icon_metrics.size():
		return
	icons_revision = new_revision
	icon_metrics = new_metrics
	queue_redraw()

func _draw() -> void:
	if map_zoom < 0.7 or icon_metrics.is_empty():
		return

	var bounds := Rect2(Vector2(-20.0, -20.0), size + Vector2(40.0, 40.0))
	var ink := Color(0.16, 0.12, 0.08, 1.0)
	var stone := Color(0.93, 0.88, 0.78, 1.0)
	var roof_col := Color(0.62, 0.25, 0.18, 1.0)
	var gold := Color(0.95, 0.78, 0.20, 1.0)
	var fort_col := Color(0.55, 0.52, 0.48, 1.0)
	var port_col := Color(0.12, 0.25, 0.40, 1.0)

	var min_dev := 5
	if map_zoom >= 1.6:
		min_dev = 1
	elif map_zoom >= 1.1:
		min_dev = 3

	var draw_ports := map_zoom >= 1.1
	var count := icon_metrics.size() / 6
	for idx in range(count):
		var base := idx * 6
		var dev := int(icon_metrics[base + 2])
		var is_cap := icon_metrics[base + 4] >= 0.5
		if dev < min_dev and not is_cap:
			continue

		var px := map_offset.x + icon_metrics[base] * map_zoom
		var py := map_offset.y + icon_metrics[base + 1] * map_zoom
		if not bounds.has_point(Vector2(px, py)):
			continue

		var r := 2.0 + float(dev) * 0.45

		# Town stone base & double-peaked roof
		var town_rect := Rect2(px - r, py - r * 0.8, r * 2.0, r * 1.6)
		draw_rect(town_rect, stone, true)
		draw_rect(town_rect, ink, false, 1.0)

		var roof_pts := PackedVector2Array([
			Vector2(px - r, py - r * 0.1),
			Vector2(px - r * 0.5, py - r * 0.8),
			Vector2(px, py - r * 0.1),
			Vector2(px + r * 0.5, py - r * 0.8),
			Vector2(px + r, py - r * 0.1),
		])
		draw_polyline(roof_pts, roof_col, maxf(1.0, r * 0.35), true)

		# Capital star above town
		if is_cap:
			var sr := r * 0.9
			var cx := px
			var cy := py - r * 1.8
			var star := PackedVector2Array()
			var outline := PackedVector2Array()
			for i in range(10):
				var angle := -PI * 0.5 + float(i) * PI * 0.2
				var rad := sr if (i % 2) == 0 else sr * 0.42
				var pt := Vector2(cx + cos(angle) * rad, cy + sin(angle) * rad)
				star.append(pt)
				outline.append(pt)
			outline.append(star[0])
			draw_colored_polygon(star, gold)
			draw_polyline(outline, ink, 0.8, true)

		# Crenellated fort tower (level >= 2)
		var fort_lvl := int(icon_metrics[base + 3])
		if fort_lvl >= 2:
			var w := 3.0 + float(fort_lvl)
			var h := w * 1.3
			var x0 := px + r + 2.0
			var y0 := py - h * 0.7
			var tower := PackedVector2Array([
				Vector2(x0, y0 + h),
				Vector2(x0, y0),
				Vector2(x0 + w * 0.3, y0),
				Vector2(x0 + w * 0.3, y0 + h * 0.15),
				Vector2(x0 + w * 0.7, y0 + h * 0.15),
				Vector2(x0 + w * 0.7, y0),
				Vector2(x0 + w, y0),
				Vector2(x0 + w, y0 + h),
			])
			var tower_outline := PackedVector2Array(tower)
			tower_outline.append(tower[0])
			draw_colored_polygon(tower, fort_col)
			draw_polyline(tower_outline, ink, 0.8, true)

		# Coastal port anchor at zoom >= 1.1
		var is_port := icon_metrics[base + 5] >= 0.5
		if draw_ports and is_port:
			var ax := px - r - 6.5
			var ay := py
			draw_arc(Vector2(ax, ay - 3.3), 1.4, 0.0, TAU, 10, port_col, 1.1, true)
			draw_line(Vector2(ax, ay - 1.9), Vector2(ax, ay + 4.2), port_col, 1.2, true)
			draw_line(Vector2(ax - 2.6, ay - 0.5), Vector2(ax + 2.6, ay - 0.5), port_col, 1.1, true)
			draw_arc(Vector2(ax, ay + 1.0), 3.3, 0.25, PI - 0.25, 10, port_col, 1.2, true)
