extends Control

var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
var icon_metrics: PackedFloat32Array = PackedFloat32Array()
var icons_revision: int = -1
var _star_unit_pts: PackedVector2Array = PackedVector2Array()

func _init() -> void:
	for i in range(10):
		var angle := -PI * 0.5 + float(i) * PI * 0.2
		var mult := 1.0 if (i % 2) == 0 else 0.42
		_star_unit_pts.append(Vector2(cos(angle) * mult, sin(angle) * mult))

var projector: RefCounted = null
var _cam_rev: int = -1

func update_camera(new_zoom: float, new_offset: Vector2, proj: RefCounted = null, rev: int = -1) -> void:
	if is_equal_approx(map_zoom, new_zoom) and map_offset.is_equal_approx(new_offset) and rev == _cam_rev:
		return
	map_zoom = new_zoom
	map_offset = new_offset
	if proj != null:
		projector = proj
	_cam_rev = rev
	queue_redraw()

# Map pixel -> screen point through the 3D camera (Phase 17), standing on the terrain.
func _ms(wx: float, wy: float) -> Vector2:
	if projector != null:
		return projector.call("to_screen", Vector2(wx, wy))
	return Vector2(map_offset.x + wx * map_zoom, map_offset.y + wy * map_zoom)

func _msv(w: Vector2) -> Vector2:
	return _ms(w.x, w.y)

# Map-space box covering the screen (plus a margin in screen pixels), for culling.
func _visible_map_rect(pad_px: float) -> Rect2:
	if projector != null:
		return projector.call("visible_rect", pad_px)
	var inv_z := 1.0 / maxf(map_zoom, 0.0001)
	return Rect2(Vector2((-map_offset.x - pad_px) * inv_z, (-map_offset.y - pad_px) * inv_z), Vector2((size.x + pad_px * 2.0) * inv_z, (size.y + pad_px * 2.0) * inv_z))

func set_icons_data(new_metrics: PackedFloat32Array, new_revision: int) -> void:
	if new_revision == icons_revision and new_metrics.size() == icon_metrics.size():
		return
	icons_revision = new_revision
	icon_metrics = new_metrics
	queue_redraw()

func _draw() -> void:
	if MapScale.look(map_zoom) < 0.7 or icon_metrics.is_empty():
		return

	var vis := _visible_map_rect(24.0)
	var wx_min := vis.position.x
	var wx_max := vis.end.x
	var wy_min := vis.position.y
	var wy_max := vis.end.y

	var ink := Color(0.16, 0.12, 0.08, 1.0)
	var stone := Color(0.93, 0.88, 0.78, 1.0)
	var roof_col := Color(0.62, 0.25, 0.18, 1.0)
	var gold := Color(0.95, 0.78, 0.20, 1.0)
	var fort_col := Color(0.55, 0.52, 0.48, 1.0)
	var port_col := Color(0.12, 0.25, 0.40, 1.0)

	var min_dev := 5
	if MapScale.look(map_zoom) >= 1.6:
		min_dev = 1
	elif MapScale.look(map_zoom) >= 1.1:
		min_dev = 3

	var draw_ports := MapScale.look(map_zoom) >= 1.1
	var count := icon_metrics.size() / 6
	for idx in range(count):
		var base := idx * 6
		var wx := icon_metrics[base]
		if wx < wx_min or wx > wx_max:
			continue
		var wy := icon_metrics[base + 1]
		if wy < wy_min or wy > wy_max:
			continue
		var dev := int(icon_metrics[base + 2])
		var is_cap := icon_metrics[base + 4] >= 0.5
		if dev < min_dev and not is_cap:
			continue

		var sp := _ms(wx, wy)
		var px := sp.x
		var py := sp.y
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
			for pt_u in _star_unit_pts:
				var pt := Vector2(cx + pt_u.x * sr, cy + pt_u.y * sr)
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
			draw_line(Vector2(ax - 3.5, ay), Vector2(ax + 3.5, ay), port_col, 1.2, true)
			draw_arc(Vector2(ax, ay + 1.2), 3.4, 0.25, PI - 0.25, 10, port_col, 1.2, true)
