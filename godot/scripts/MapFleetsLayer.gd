extends Control

var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
var selected_fleet_id: int = -1
var move_mode_fleet_id: int = -1
var counters: Array = []
var routes: Array = []
var battles: Array = []
var blockades: Array = []
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

func set_fleets_data(data: Dictionary) -> void:
	selected_fleet_id = int(data.get("selectedFleetId", -1))
	move_mode_fleet_id = int(data.get("moveModeFleetId", -1))
	var c_arr: Variant = data.get("counters", [])
	counters = c_arr if c_arr is Array else []
	var r_arr: Variant = data.get("routes", [])
	routes = r_arr if r_arr is Array else []
	var b_arr: Variant = data.get("battles", [])
	battles = b_arr if b_arr is Array else []
	var bl_arr: Variant = data.get("blockades", [])
	blockades = bl_arr if bl_arr is Array else []
	queue_redraw()

func pick_fleet_at(screen_pos: Vector2) -> int:
	for idx in range(counter_hit_boxes.size() - 1, -1, -1):
		var item: Dictionary = counter_hit_boxes[idx]
		var rect: Rect2 = item["rect"]
		if rect.has_point(screen_pos):
			return int(item["fleet_id"])
	return -1

func _draw() -> void:
	counter_hit_boxes.clear()
	if map_zoom <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var bounds := Rect2(Vector2(-80.0, -50.0), size + Vector2(160.0, 100.0))
	var sea_cyan := Color(0.45, 0.85, 0.96, 0.95)
	var selected_gold := Color(1.0, 0.94, 0.42, 1.0)
	var player_gold := Color(0.95, 0.78, 0.20, 0.98)
	var enemy_red := Color(0.92, 0.26, 0.22, 0.98)
	var ink := Color(0.10, 0.12, 0.16, 0.94)

	# 1. Sea routes
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
		var is_sel: bool = bool(r_dict.get("isSelected", false))
		var line_col: Color = selected_gold if is_sel else (sea_cyan if is_player else Color(0.82, 0.88, 0.94, 0.75))

		var screen_pts := PackedVector2Array()
		var pair_count: int = int(pts.size() / 2)
		for k in range(pair_count):
			screen_pts.append(_ms(float(pts[k * 2]), float(pts[k * 2 + 1])))

		for k in range(screen_pts.size() - 1):
			draw_line(screen_pts[k], screen_pts[k + 1], ink, 3.6, true)
			draw_dashed_line(screen_pts[k], screen_pts[k + 1], line_col, 2.0, 6.0, true)

		var last_a: Vector2 = screen_pts[screen_pts.size() - 2]
		var last_b: Vector2 = screen_pts[screen_pts.size() - 1]
		var dir: Vector2 = last_b - last_a
		if dir.length_squared() > 1.0:
			var angle: float = dir.angle()
			var hl: float = 8.0
			var p1 := last_b
			var p2 := Vector2(last_b.x - hl * cos(angle - 0.48), last_b.y - hl * sin(angle - 0.48))
			var p3 := Vector2(last_b.x - hl * cos(angle + 0.48), last_b.y - hl * sin(angle + 0.48))
			draw_colored_polygon(PackedVector2Array([p1, p2, p3]), line_col)
			draw_polyline(PackedVector2Array([p1, p2, p3, p1]), ink, 1.0, true)

	var scale_factor: float = clampf(sqrt(map_zoom), 0.85, 1.20)
	var font_size: int = int(round(10.0 * scale_factor))
	var h: float = round(15.0 * scale_factor)

	# 2. Blockade markers on ports
	for bl_item in blockades:
		if not (bl_item is Dictionary):
			continue
		var bl: Dictionary = bl_item
		var p := _ms(float(bl.get("x", 0.0)), float(bl.get("y", 0.0)))
		if not bounds.has_point(p):
			continue
		var bw := 26.0 * scale_factor
		var bh := 12.0 * scale_factor
		var brect := Rect2(p.x - bw * 0.5, p.y - bh * 0.5, bw, bh)
		draw_rect(brect, Color(0.58, 0.12, 0.12, 0.94), true)
		draw_rect(brect, Color(0.96, 0.52, 0.25, 0.98), false, 1.4)
		var b_base := Vector2(brect.position.x, p.y + float(font_size - 1) * 0.35)
		draw_string(font, b_base, "BLK", HORIZONTAL_ALIGNMENT_CENTER, bw, max(8, font_size - 1), Color(1.0, 0.90, 0.72))

	# 3. Fleet counters
	for c_item in counters:
		if not (c_item is Dictionary):
			continue
		var c: Dictionary = c_item
		var fid: int = int(c.get("fleetId", -1))
		if fid < 0:
			continue
		var p := _ms(float(c.get("x", 0.0)), float(c.get("y", 0.0)))
		if not bounds.has_point(p):
			continue

		var ship_cnt: int = int(c.get("shipCount", 0))
		var embarked: int = int(c.get("embarkedMen", 0))
		var tag: String = str(c.get("ownerTag", ""))
		var label_txt := "%s %d" % [tag, ship_cnt]
		if embarked > 0:
			label_txt += "+"
		var w: float = maxf(32.0 * scale_factor, float(label_txt.length()) * float(font_size) * 0.62 + 12.0 * scale_factor)
		var rect := Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h)

		var is_player: bool = bool(c.get("isPlayer", false))
		var is_enemy: bool = bool(c.get("isEnemy", false))
		var is_sel: bool = bool(c.get("isSelected", false)) or (fid == selected_fleet_id)
		var in_battle: bool = bool(c.get("inBattle", false))
		var cr: float = float(int(c.get("colorR", 120))) / 255.0
		var cg: float = float(int(c.get("colorG", 140))) / 255.0
		var cb: float = float(int(c.get("colorB", 160))) / 255.0

		var fill_col := Color(cr * 0.68 + 0.08, cg * 0.68 + 0.08, cb * 0.68 + 0.14, 0.96)
		var border_col: Color = selected_gold if is_sel else (player_gold if is_player else (enemy_red if is_enemy else ink))
		var border_w: float = 2.4 if is_sel else (1.8 if (is_player or is_enemy) else 1.2)

		draw_rect(rect, fill_col, true)
		# Naval keel accent stripe along bottom of fleet counter
		draw_rect(Rect2(rect.position.x + 1.0, rect.end.y - 2.5, maxf(2.0, rect.size.x - 2.0), 2.5), sea_cyan, true)
		draw_rect(rect, border_col, false, border_w)

		if in_battle:
			draw_circle(Vector2(rect.position.x + 3.0, rect.position.y + 3.0), 3.0, Color(0.98, 0.30, 0.22))
		elif bool(c.get("isDocked", false)):
			draw_circle(Vector2(rect.position.x + 3.0, rect.position.y + 3.0), 2.5, Color(0.42, 0.88, 0.98))

		var baseline := Vector2(rect.position.x, p.y + float(font_size) * 0.32)
		draw_string_outline(font, baseline, label_txt, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 2, ink)
		draw_string(font, baseline, label_txt, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, Color.WHITE)

		counter_hit_boxes.append({
			"fleet_id": fid,
			"rect": rect.grow(3.0)
		})

	# 4. Naval battle banners on sea zones
	for b_item in battles:
		if not (b_item is Dictionary):
			continue
		var b: Dictionary = b_item
		var bp := _ms(float(b.get("x", 0.0)), float(b.get("y", 0.0)))
		if not bounds.has_point(bp):
			continue
		var txt := "BAT %s v %s d%d" % [str(b.get("attackerTag", "")), str(b.get("defenderTag", "")), int(b.get("dayCount", 1))]
		var bw: float = maxf(64.0 * scale_factor, float(txt.length()) * float(font_size) * 0.60 + 10.0)
		var brect := Rect2(bp.x - bw * 0.5, bp.y - 8.0 * scale_factor, bw, 15.0 * scale_factor)
		draw_rect(brect, Color(0.55, 0.14, 0.10, 0.96), true)
		draw_rect(brect, Color(1.0, 0.78, 0.25, 1.0), false, 1.6)
		var base := Vector2(brect.position.x, bp.y + float(font_size) * 0.30)
		draw_string_outline(font, base, txt, HORIZONTAL_ALIGNMENT_CENTER, bw, font_size, 2, ink)
		draw_string(font, base, txt, HORIZONTAL_ALIGNMENT_CENTER, bw, font_size, Color(1.0, 0.94, 0.78))
