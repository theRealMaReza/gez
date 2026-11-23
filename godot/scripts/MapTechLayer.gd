extends Control

# Origin markers drawn over the map in the Institutions map mode (Phase 13).

var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
var current_mode: String = "political"
var overlay_data: Dictionary = {}

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

func set_overlay_data(mode: String, data: Dictionary) -> void:
	current_mode = mode
	overlay_data = data
	visible = (mode == "institutions")
	if visible:
		queue_redraw()

func _screen_point(item: Dictionary) -> Vector2:
	return _msv(Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0))))

func _on_screen(pt: Vector2, margin: float) -> bool:
	return pt.x >= -margin and pt.x <= size.x + margin and pt.y >= -margin and pt.y <= size.y + margin

func _draw() -> void:
	if not visible or overlay_data.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var origins: Array = overlay_data.get("origins", [])
	for o_v in origins:
		if not (o_v is Dictionary):
			continue
		var o: Dictionary = o_v
		var pt: Vector2 = _screen_point(o)
		if not _on_screen(pt, 48.0):
			continue
		var radius: float = clampf(9.0 * sqrt(maxf(map_zoom, 0.35)), 7.0, 14.0)
		draw_circle(pt, radius, Color(0.14, 0.24, 0.16, 0.94))
		draw_arc(pt, radius, 0.0, TAU, 20, Color(0.98, 0.86, 0.42, 0.98), 2.0)
		if font != null:
			draw_string(font, pt + Vector2(-4.0, 4.0), str(o.get("letter", "I")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.99, 0.95, 0.78))
			if MapScale.look(map_zoom) >= 0.75:
				var lbl := "%s (%d)" % [str(o.get("name", "")), int(o.get("year", 1453))]
				draw_string(font, pt + Vector2(radius + 4.0, 4.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.14, 0.12, 0.08))
				draw_string(font, pt + Vector2(radius + 3.0, 3.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.99, 0.96, 0.84))
