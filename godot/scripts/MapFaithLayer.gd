extends Control

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
	visible = (mode == "religion" or mode == "culture")
	if visible:
		queue_redraw()

func _draw() -> void:
	if not visible or overlay_data.is_empty():
		return

	var show_rel := (current_mode == "religion")
	var show_cul := (current_mode == "culture")
	var ink := Color(0.10, 0.08, 0.06, 0.92)
	var font := ThemeDB.fallback_font

	if show_rel:
		# Holy sites: golden diamond with outline
		for hs_v in overlay_data.get("holySites", []):
			if hs_v is Dictionary:
				var hs: Dictionary = hs_v
				var pt := _msv(Vector2(float(hs.get("x", 0.0)), float(hs.get("y", 0.0))))
				if pt.x < -30.0 or pt.x > size.x + 30.0 or pt.y < -30.0 or pt.y > size.y + 30.0:
					continue
				var is_held := bool(hs.get("isHeldByPlayer", false))
				var is_sacred := bool(hs.get("isSacredToPlayer", false))
				if MapScale.look(map_zoom) < 0.75 and not is_sacred:
					continue
				var r := 6.5 if is_held else (5.0 if is_sacred else 3.5)
				var col := Color(0.98, 0.85, 0.28, 0.95) if is_sacred else Color(0.84, 0.80, 0.70, 0.78)
				var pts := PackedVector2Array([
					pt + Vector2(0.0, -r),
					pt + Vector2(r, 0.0),
					pt + Vector2(0.0, r),
					pt + Vector2(-r, 0.0)
				])
				draw_colored_polygon(pts, col)
				var outline := pts.duplicate()
				outline.append(pts[0])
				draw_polyline(outline, ink, 1.2, true)
				if is_held:
					draw_arc(pt, r + 3.0, 0.0, TAU, 16, Color(0.42, 0.95, 0.56, 0.95), 1.6)
				if MapScale.look(map_zoom) >= 1.25 and font != null:
					draw_string(font, pt + Vector2(r + 3.0, 4.0), str(hs.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

		# Active missionaries: amber cross/halo ring
		for m_v in overlay_data.get("missionaries", []):
			if m_v is Dictionary:
				var m: Dictionary = m_v
				var pt := _msv(Vector2(float(m.get("x", 0.0)), float(m.get("y", 0.0))))
				if pt.x < -20.0 or pt.x > size.x + 20.0 or pt.y < -20.0 or pt.y > size.y + 20.0:
					continue
				var m_col := Color(0.35, 0.92, 0.98, 0.96) if bool(m.get("isPlayer", false)) else Color(0.95, 0.70, 0.35, 0.82)
				draw_circle(pt, 5.0, m_col)
				draw_arc(pt, 7.5, 0.0, TAU, 16, ink, 1.3)
				draw_line(pt + Vector2(-3.0, 0.0), pt + Vector2(3.0, 0.0), ink, 1.5)
				draw_line(pt + Vector2(0.0, -3.0), pt + Vector2(0.0, 3.0), ink, 1.5)

		# Centres of Reformation: radiant pulsing circle + label
		for rc_v in overlay_data.get("centres", []):
			if rc_v is Dictionary:
				var rc: Dictionary = rc_v
				var pt := _msv(Vector2(float(rc.get("x", 0.0)), float(rc.get("y", 0.0))))
				if pt.x < -40.0 or pt.x > size.x + 40.0 or pt.y < -40.0 or pt.y > size.y + 40.0:
					continue
				var rc_col := Color(
					float(int(rc.get("colorR", 220))) / 255.0,
					float(int(rc.get("colorG", 120))) / 255.0,
					float(int(rc.get("colorB", 80))) / 255.0,
					0.98
				)
				draw_arc(pt, 10.5, 0.0, TAU, 24, Color(1.0, 0.94, 0.65, 0.95), 2.2)
				draw_circle(pt, 7.0, rc_col)
				draw_arc(pt, 7.0, 0.0, TAU, 20, ink, 1.4)
				if font != null:
					draw_string(font, pt + Vector2(11.0, 4.0), str(rc.get("religion", "")) + " Centre", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.95, 0.78))

	# Net migration ("moving pops") badges in both religion & culture map modes
	if show_rel or show_cul:
		var mig_drawn := 0
		var max_mig := 24 if MapScale.look(map_zoom) < 0.8 else 60
		for mig_v in overlay_data.get("migrations", []):
			if mig_v is Dictionary:
				var mig: Dictionary = mig_v
				var net := float(mig.get("netMigration", 0.0))
				if MapScale.look(map_zoom) < 0.8 and absf(net) < 400.0:
					continue
				if mig_drawn >= max_mig:
					break
				var pt := _msv(Vector2(float(mig.get("x", 0.0)), float(mig.get("y", 0.0))))
				if pt.x < -30.0 or pt.x > size.x + 30.0 or pt.y < -30.0 or pt.y > size.y + 30.0:
					continue
				mig_drawn += 1
				var col := Color(0.45, 0.94, 0.56, 0.92) if net > 0.0 else Color(0.96, 0.42, 0.38, 0.92)
				var arrow := "▲" if net > 0.0 else "▼"
				var badge_pos := pt + Vector2(-14.0, -10.0)
				draw_rect(Rect2(badge_pos - Vector2(2.0, 10.0), Vector2(42.0, 13.0)), Color(0.08, 0.07, 0.06, 0.76), true)
				if font != null:
					draw_string(font, badge_pos, arrow + str(mig.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
