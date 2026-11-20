extends Control

# Markers drawn over the map in the Plague and Unrest map modes (Phase 12):
# outbreaks, quarantines and cordons, famine, recent earthquakes, and rebel
# factions with their progress.

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
	visible = (mode == "plague" or mode == "unrest")
	if visible:
		queue_redraw()

func _screen_point(item: Dictionary) -> Vector2:
	return _msv(Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0))))

func _on_screen(pt: Vector2, margin: float) -> bool:
	return pt.x >= -margin and pt.x <= size.x + margin and pt.y >= -margin and pt.y <= size.y + margin

func _draw() -> void:
	if not visible or overlay_data.is_empty():
		return
	var ink: Color = Color(0.10, 0.08, 0.06, 0.92)
	var font: Font = ThemeDB.fallback_font

	if current_mode == "plague":
		# Famine: an empty bowl (ochre ring).
		var famines: Array = overlay_data.get("famines", [])
		for f_v in famines:
			if f_v is Dictionary:
				var f: Dictionary = f_v
				var f_pt: Vector2 = _screen_point(f)
				if not _on_screen(f_pt, 20.0) or map_zoom < 0.6:
					continue
				draw_arc(f_pt + Vector2(0.0, 7.0), 4.5, 0.0, PI, 10, Color(0.42, 0.30, 0.08, 0.95), 2.0)

		# Outbreaks: a dark disc with the disease's first letter, bigger the worse it is.
		var outbreaks: Array = overlay_data.get("outbreaks", [])
		for o_v in outbreaks:
			if o_v is Dictionary:
				var o: Dictionary = o_v
				var o_pt: Vector2 = _screen_point(o)
				if not _on_screen(o_pt, 20.0):
					continue
				var share: float = float(o.get("share", 0.0))
				var radius: float = clampf(4.0 + share * 60.0, 4.0, 9.0)
				if map_zoom < 0.5:
					radius *= 0.7
				draw_circle(o_pt, radius, Color(0.16, 0.05, 0.05, 0.92))
				draw_arc(o_pt, radius, 0.0, TAU, 16, Color(0.98, 0.84, 0.70, 0.95), 1.2)
				if map_zoom >= 0.9 and font != null:
					draw_string(font, o_pt + Vector2(-3.5, 4.0), str(o.get("letter", "P")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.92, 0.82))

		# Quarantine (blue anchor ring) and cordon (white dashed ring).
		var measures: Array = overlay_data.get("measures", [])
		for m_v in measures:
			if m_v is Dictionary:
				var m: Dictionary = m_v
				var m_pt: Vector2 = _screen_point(m)
				if not _on_screen(m_pt, 24.0):
					continue
				if bool(m.get("quarantine", false)):
					draw_arc(m_pt, 12.0, 0.0, TAU, 20, Color(0.30, 0.62, 0.98, 0.95), 2.0)
				if bool(m.get("cordon", false)):
					for k in range(8):
						var a0: float = TAU * float(k) / 8.0
						draw_arc(m_pt, 15.0, a0, a0 + TAU / 16.0, 4, Color(0.98, 0.98, 0.94, 0.95), 2.0)

		# Earthquakes of the last year: broken rings.
		var quakes: Array = overlay_data.get("quakes", [])
		for q_v in quakes:
			if q_v is Dictionary:
				var q: Dictionary = q_v
				var q_pt: Vector2 = _screen_point(q)
				if not _on_screen(q_pt, 40.0):
					continue
				var strength: float = float(q.get("strength", 0.5))
				for ring in range(3):
					var rr: float = 8.0 + float(ring) * 5.0 * (0.6 + strength)
					draw_arc(q_pt, rr, 0.3 + float(ring), 2.4 + float(ring), 10, Color(0.36, 0.22, 0.10, 0.85 - 0.2 * float(ring)), 1.8)
				if map_zoom >= 1.1 and font != null:
					draw_string(font, q_pt + Vector2(12.0, -8.0), str(q.get("name", "Earthquake")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.22, 0.14, 0.08))

	if current_mode == "unrest":
		# Rebel factions: a ring that fills with their progress; a filled flag once risen.
		var rebels: Array = overlay_data.get("rebels", [])
		for r_v in rebels:
			if r_v is Dictionary:
				var r: Dictionary = r_v
				var r_pt: Vector2 = _screen_point(r)
				if not _on_screen(r_pt, 40.0):
					continue
				var progress: float = clampf(float(r.get("progress", 0.0)) / 100.0, 0.0, 1.0)
				var risen: bool = bool(r.get("risen", false))
				var mine: bool = bool(r.get("isPlayer", false))
				if map_zoom < 0.6 and not risen and not mine and progress < 0.5:
					continue
				var col: Color = Color(0.86, 0.20, 0.16, 0.96) if risen else Color(0.98, 0.72, 0.24, 0.96)
				draw_circle(r_pt, 8.0, Color(0.08, 0.07, 0.06, 0.80))
				draw_arc(r_pt, 8.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 24, col, 3.0)
				if risen:
					draw_colored_polygon(PackedVector2Array([
						r_pt + Vector2(-2.0, -5.0), r_pt + Vector2(5.0, -2.5), r_pt + Vector2(-2.0, 0.0)
					]), col)
					draw_line(r_pt + Vector2(-2.0, -5.0), r_pt + Vector2(-2.0, 5.0), col, 1.5)
				if mine:
					draw_arc(r_pt, 11.0, 0.0, TAU, 20, Color(0.96, 0.94, 0.86, 0.9), 1.2)
				if font != null and (map_zoom >= 1.1 or (mine and map_zoom >= 0.7)):
					var label: String = str(r.get("name", "Rebels"))
					if not risen:
						label += " %d%%" % int(float(r.get("progress", 0.0)))
					draw_string(font, r_pt + Vector2(12.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.14, 0.08, 0.06))
