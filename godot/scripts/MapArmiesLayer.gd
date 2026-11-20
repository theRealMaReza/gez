extends Control

var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
var selected_army_id: int = -1
var move_mode_army_id: int = -1
var counters: Array = []
var routes: Array = []
var counter_hit_boxes: Array = []

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

func set_armies_data(data: Dictionary) -> void:
	selected_army_id = int(data.get("selectedArmyId", -1))
	move_mode_army_id = int(data.get("moveModeArmyId", -1))
	var c_arr: Variant = data.get("counters", [])
	counters = c_arr if c_arr is Array else []
	var r_arr: Variant = data.get("routes", [])
	routes = r_arr if r_arr is Array else []
	queue_redraw()

func pick_army_at(screen_pos: Vector2) -> int:
	for idx in range(counter_hit_boxes.size() - 1, -1, -1):
		var item: Dictionary = counter_hit_boxes[idx]
		var rect: Rect2 = item["rect"]
		if rect.has_point(screen_pos):
			return int(item["army_id"])
	return -1

func _draw() -> void:
	counter_hit_boxes.clear()
	if map_zoom <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var bounds := Rect2(Vector2(-80.0, -50.0), size + Vector2(160.0, 100.0))
	var gold := Color(0.96, 0.78, 0.20, 0.98)
	var selected_gold := Color(1.0, 0.94, 0.42, 1.0)
	var rebel_red := Color(0.68, 0.14, 0.14, 0.96)
	var enemy_red := Color(0.92, 0.26, 0.22, 0.98)
	var parchment := Color(0.92, 0.87, 0.75, 0.95)
	var ink := Color(0.14, 0.10, 0.07, 0.92)

	# 1. Draw marching arrows along active movement routes.
	for r_item in routes:
		if not (r_item is Dictionary):
			continue
		var r_dict: Dictionary = r_item
		var pts_var: Variant = r_dict.get("points", [])
		if not (pts_var is Array):
			continue
		var pts: Array = pts_var
		if pts.size() < 4:
			continue

		var is_player: bool = bool(r_dict.get("isPlayer", false))
		var is_rebel: bool = bool(r_dict.get("isRebel", false))
		var is_sel: bool = bool(r_dict.get("isSelected", false))
		var line_col: Color = rebel_red if is_rebel else (selected_gold if is_sel else (gold if is_player else parchment))

		var screen_pts := PackedVector2Array()
		var pair_count: int = int(pts.size() / 2)
		for k in range(pair_count):
			var px: float = float(pts[k * 2])
			var py: float = float(pts[k * 2 + 1])
			screen_pts.append(_ms(px, py))

		for k in range(screen_pts.size() - 1):
			var a: Vector2 = screen_pts[k]
			var b: Vector2 = screen_pts[k + 1]
			draw_line(a, b, ink, 4.0, true)
			draw_dashed_line(a, b, line_col, 2.2, 6.0, true)

		var last_a: Vector2 = screen_pts[screen_pts.size() - 2]
		var last_b: Vector2 = screen_pts[screen_pts.size() - 1]
		var dir: Vector2 = last_b - last_a
		if dir.length_squared() > 1.0:
			var angle: float = dir.angle()
			var head_len: float = 8.5
			var p1 := last_b
			var p2 := Vector2(last_b.x - head_len * cos(angle - 0.48), last_b.y - head_len * sin(angle - 0.48))
			var p3 := Vector2(last_b.x - head_len * cos(angle + 0.48), last_b.y - head_len * sin(angle + 0.48))
			var head_poly := PackedVector2Array([p1, p2, p3])
			draw_colored_polygon(head_poly, line_col)
			draw_polyline(PackedVector2Array([p1, p2, p3, p1]), ink, 1.1, true)

	# 2. Draw one counter per living army, readable at every zoom level.
	var scale_factor: float = clampf(sqrt(map_zoom), 0.88, 1.22)
	var font_size: int = int(round(11.0 * scale_factor))
	var h: float = round(16.0 * scale_factor)

	for c_item in counters:
		if not (c_item is Dictionary):
			continue
		var c_dict: Dictionary = c_item
		var aid: int = int(c_dict.get("armyId", -1))
		if aid < 0:
			continue
		var mx: float = float(c_dict.get("x", 0.0))
		var my: float = float(c_dict.get("y", 0.0))
		var stack_idx: int = int(c_dict.get("stackIndex", 0))
		var stack_cnt: int = int(c_dict.get("stackCount", 1))

		var base_p := _ms(mx, my)
		var spread_x: float = (float(stack_idx) - float(stack_cnt - 1) * 0.5) * (34.0 * scale_factor)
		var spread_y: float = 12.0 * scale_factor + float(stack_idx % 2) * (5.0 * scale_factor)
		var p := Vector2(base_p.x + spread_x, base_p.y + spread_y)
		if not bounds.has_point(p):
			continue

		var men_txt: String = str(c_dict.get("menText", "0"))
		var marker: String = str(c_dict.get("marker", ""))
		var label_txt: String = men_txt + (" [" + marker + "]" if not marker.is_empty() else "")
		var w: float = maxf(26.0 * scale_factor, float(label_txt.length()) * float(font_size) * 0.62 + 12.0 * scale_factor)
		var rect := Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h)

		var is_rebel: bool = bool(c_dict.get("isRebel", false))
		var is_player: bool = bool(c_dict.get("isPlayer", false))
		var is_enemy: bool = bool(c_dict.get("isEnemy", false))
		var is_sel: bool = bool(c_dict.get("isSelected", false)) or (aid == selected_army_id)
		var cr: float = float(int(c_dict.get("colorR", 140))) / 255.0
		var cg: float = float(int(c_dict.get("colorG", 120))) / 255.0
		var cb: float = float(int(c_dict.get("colorB", 90))) / 255.0

		var fill_col: Color = rebel_red if is_rebel else Color(cr * 0.72 + 0.08, cg * 0.72 + 0.08, cb * 0.72 + 0.08, 0.96)
		var border_col: Color = selected_gold if is_sel else (gold if is_player else (enemy_red if is_enemy else ink))
		var border_w: float = 2.4 if is_sel else (1.8 if (is_player or is_enemy) else 1.2)

		draw_rect(rect, fill_col, true)
		draw_rect(rect, border_col, false, border_w)

		# Siege / battle status pip on top-left corner of counter
		if marker == "B":
			draw_circle(Vector2(rect.position.x + 3.0, rect.position.y + 3.0), 3.2, Color(0.96, 0.24, 0.20))
		elif marker == "S":
			draw_circle(Vector2(rect.position.x + 3.0, rect.position.y + 3.0), 3.2, Color(0.98, 0.65, 0.18))

		var baseline := Vector2(rect.position.x, p.y + float(font_size) * 0.36)
		draw_string_outline(font, baseline, label_txt, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 2, ink)
		draw_string(font, baseline, label_txt, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, Color.WHITE)

		counter_hit_boxes.append({
			"army_id": aid,
			"rect": rect.grow(3.0)
		})
