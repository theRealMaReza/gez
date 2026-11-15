extends Control

var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO

var last_signature: String = ""
var has_data: bool = false
var markets: Array = []
var routes: Array = []

func set_active(active: bool) -> void:
	if visible == active:
		return
	visible = active
	if visible and has_data:
		queue_redraw()

func update_camera(new_zoom: float, new_offset: Vector2) -> void:
	if is_equal_approx(map_zoom, new_zoom) and map_offset.is_equal_approx(new_offset):
		return
	map_zoom = new_zoom
	map_offset = new_offset
	if visible and has_data:
		queue_redraw()

func set_routes_data(data: Dictionary) -> void:
	var sig: String = str(data.get("signature", ""))
	if has_data and sig == last_signature:
		return
	last_signature = sig
	has_data = true
	var m_arr = data.get("markets", [])
	markets = m_arr if m_arr is Array else []
	var r_arr = data.get("routes", [])
	routes = r_arr if r_arr is Array else []
	if visible:
		queue_redraw()

func _world_to_screen(wx: float, wy: float) -> Vector2:
	return Vector2(map_offset.x + wx * map_zoom, map_offset.y + wy * map_zoom)

func _draw() -> void:
	if not visible or map_zoom <= 0.0:
		return
	var bounds := Rect2(Vector2(-80.0, -80.0), size + Vector2(160.0, 160.0))

	# 1. Trade route curves
	for r in routes:
		if not (r is Dictionary):
			continue
		var is_blocked: bool = bool(r.get("isBlocked", false))
		var is_losing: bool = bool(r.get("isLosing", false))
		var value: float = float(r.get("value", 0.0))
		var stroke_w: float = clampf(2.0 + sqrt(maxf(0.0, value)) * 0.28, 2.2, 6.0)
		var cr: float = float(r.get("colorR", 220)) / 255.0
		var cg: float = float(r.get("colorG", 180)) / 255.0
		var cb: float = float(r.get("colorB", 80)) / 255.0
		var col := Color(0.88, 0.24, 0.20, 0.92) if (is_blocked or is_losing) else Color(cr, cg, cb, 0.92)

		var pts_raw: Array = r.get("points", []) if r.get("points", []) is Array else []
		if is_blocked or pts_raw.size() < 4:
			var from_p := _world_to_screen(float(r.get("fromX", 0.0)), float(r.get("fromY", 0.0)))
			var to_p := _world_to_screen(float(r.get("toX", 0.0)), float(r.get("toY", 0.0)))
			if from_p.distance_to(to_p) > 2.0:
				_draw_dashed_segment(from_p, to_p, Color(0.08, 0.06, 0.05, 0.65), stroke_w + 2.0, 8.0, 6.0)
				_draw_dashed_segment(from_p, to_p, col, stroke_w, 8.0, 6.0)
				_draw_arrowhead(from_p, to_p, col, stroke_w)
			continue

		var hops: int = int(pts_raw.size() / 2)
		var curve_pts := PackedVector2Array()
		var last_ctrl := Vector2.ZERO
		var last_end := Vector2.ZERO
		for h in range(hops - 1):
			var a := _world_to_screen(float(pts_raw[h * 2]), float(pts_raw[h * 2 + 1]))
			var b := _world_to_screen(float(pts_raw[h * 2 + 2]), float(pts_raw[h * 2 + 3]))
			var seg := b - a
			var seg_len := seg.length()
			if seg_len < 1.0:
				continue
			var perp := Vector2(-seg.y, seg.x) / seg_len
			var arch := minf(48.0, seg_len * 0.14)
			var ctrl := (a + b) * 0.5 + perp * arch
			last_ctrl = ctrl
			last_end = b
			var steps := 14
			var start_i := 0 if curve_pts.is_empty() else 1
			for s_idx in range(start_i, steps + 1):
				var t := float(s_idx) / float(steps)
				var omt := 1.0 - t
				var pt := omt * omt * a + 2.0 * omt * t * ctrl + t * t * b
				curve_pts.append(pt)

		if curve_pts.size() >= 2:
			_draw_dashed_polyline(curve_pts, Color(0.08, 0.06, 0.05, 0.65), stroke_w + 2.0, 10.0, 5.0)
			_draw_dashed_polyline(curve_pts, col, stroke_w, 10.0, 5.0)
			_draw_arrowhead(last_ctrl, last_end, col, stroke_w)

	# 2. Market hubs (dots + labels, emphasizing player endpoints)
	var font: Font = ThemeDB.fallback_font
	for m in markets:
		if not (m is Dictionary):
			continue
		var p := _world_to_screen(float(m.get("x", 0.0)), float(m.get("y", 0.0)))
		if not bounds.has_point(p):
			continue
		var is_endpoint: bool = bool(m.get("isPlayerEndpoint", false))
		var radius: float = 5.5 if is_endpoint else 3.5
		var dot_col := Color(0.95, 0.80, 0.30, 0.95) if is_endpoint else Color(0.75, 0.72, 0.66, 0.75)
		draw_circle(p, radius + 1.5, Color(0.10, 0.08, 0.06, 0.85))
		draw_circle(p, radius, dot_col)
		if font != null and (is_endpoint or map_zoom >= 0.85):
			var label: String = str(m.get("name", ""))
			if not label.is_empty():
				var font_size: int = 12 if is_endpoint else 10
				var pos := p + Vector2(radius + 5.0, float(font_size) * 0.35)
				draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color(0.08, 0.06, 0.04, 0.88))
				var text_col := Color(0.98, 0.94, 0.84, 0.96) if is_endpoint else Color(0.84, 0.80, 0.74, 0.82)
				draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

func _draw_arrowhead(from_p: Vector2, tip_p: Vector2, col: Color, stroke_w: float) -> void:
	var dir := tip_p - from_p
	if dir.length() < 1.0:
		return
	var u := dir.normalized()
	var back := Vector2(-u.y, u.x)
	var head_len := maxf(8.0, stroke_w * 2.6)
	var half_w := maxf(4.5, stroke_w * 1.4)
	var base := tip_p - u * head_len
	var tri := PackedVector2Array([tip_p, base + back * half_w, base - back * half_w])
	draw_colored_polygon(tri, col)

func _draw_dashed_segment(a: Vector2, b: Vector2, col: Color, width: float, dash_len: float, gap_len: float) -> void:
	_draw_dashed_polyline(PackedVector2Array([a, b]), col, width, dash_len, gap_len)

func _draw_dashed_polyline(pts: PackedVector2Array, col: Color, width: float, dash_len: float, gap_len: float) -> void:
	var pattern_len := dash_len + gap_len
	var dist_acc := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := b - a
		var seg_len := seg.length()
		if seg_len < 0.01:
			continue
		var dir := seg / seg_len
		var pos := 0.0
		while pos < seg_len:
			var mod := fmod(dist_acc + pos, pattern_len)
			var step_end: float
			if mod < dash_len:
				step_end = minf(seg_len, pos + (dash_len - mod))
				draw_line(a + dir * pos, a + dir * step_end, col, width, true)
			else:
				step_end = minf(seg_len, pos + (pattern_len - mod))
			pos = step_end
		dist_acc += seg_len
