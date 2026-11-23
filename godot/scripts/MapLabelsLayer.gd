extends Control

var map_zoom: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
var map_mode: String = "political"

var country_texts: PackedStringArray = PackedStringArray()
var country_metrics: PackedFloat32Array = PackedFloat32Array()
# Phase 20 part 8: [angle, length, bend] per country label (curved names).
var country_curves: PackedFloat32Array = PackedFloat32Array()
var _name_font: Font = null
# Phase 20.6: measured label widths, keyed "font|size|text", so placement
# never guesses (the old len x size x 0.55 guess cut names short).
var _width_cache: Dictionary = {}

var province_texts: PackedStringArray = PackedStringArray()
var province_metrics: PackedFloat32Array = PackedFloat32Array()

var sea_texts: PackedStringArray = PackedStringArray()
var sea_metrics: PackedFloat32Array = PackedFloat32Array()

# World-space label placement cache keyed by exact zoom & map mode so panning
# reuses placed labels with viewport culling instead of re-running overlap checks.
var _cache_dirty: bool = true
var _cached_zoom: float = -1.0
var _cached_mode: String = ""
var _cached_sea: Array = []
var _cached_main: Array = []

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

func set_map_mode(mode_key: String) -> void:
	if map_mode == mode_key:
		return
	map_mode = mode_key
	_cache_dirty = true
	queue_redraw()

func set_country_labels(texts: PackedStringArray, metrics: PackedFloat32Array) -> void:
	country_texts = texts
	country_metrics = metrics
	_cache_dirty = true
	queue_redraw()

func set_country_curves(curves: PackedFloat32Array) -> void:
	country_curves = curves
	_cache_dirty = true
	queue_redraw()

func set_province_labels(texts: PackedStringArray, metrics: PackedFloat32Array) -> void:
	province_texts = texts
	province_metrics = metrics
	_cache_dirty = true
	queue_redraw()

func set_sea_labels(texts: PackedStringArray, metrics: PackedFloat32Array) -> void:
	sea_texts = texts
	sea_metrics = metrics
	_cache_dirty = true
	queue_redraw()

# Width in screen pixels of `txt` at `fsize`, measured once and cached.
# `which`: 0 = plain map font (seas, provinces), 1 = Cinzel (country names).
func _text_width(which: int, txt: String, fsize: int) -> float:
	var key := "%d|%d|%s" % [which, fsize, txt]
	if _width_cache.has(key):
		return _width_cache[key]
	var font: Font = _name_font if which == 1 else ThemeDB.fallback_font
	var w := float(txt.length()) * float(fsize) * 0.6
	if font != null:
		# + a little for the outline drawn around the letters
		w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 4.0
	_width_cache[key] = w
	return w

func _place_labels_world(texts: PackedStringArray, metrics: PackedFloat32Array, is_sea: bool, show_provinces: bool) -> Array:
	if _name_font == null:
		_name_font = GezTheme.title_font()
	var out: Array = []
	var count := texts.size()
	var z := map_zoom
	var z2 := z * z
	var inv_z := 1.0 / z
	var cell_size := 256.0 * inv_z
	var grid: Dictionary = {}

	for i in range(count):
		var base_idx := i * 3
		if base_idx + 2 >= metrics.size():
			break
		var screen_area := metrics[base_idx + 2] * z2
		var min_area := 9000.0 if is_sea else (2200.0 if show_provinces else 1800.0)
		if screen_area <= min_area:
			continue

		var wx := metrics[base_idx]
		var wy := metrics[base_idx + 1]
		var font_size: int
		var label_text: String
		var w_screen: float
		if is_sea:
			font_size = int(clampf(sqrt(screen_area) / 14.0, 10.0, 16.0))
			label_text = texts[i]
			w_screen = _text_width(0, label_text, font_size)
		elif show_provinces:
			font_size = int(clampf(sqrt(screen_area) / 9.0, 10.0, 14.0))
			label_text = texts[i]
			w_screen = _text_width(0, label_text, font_size)
		else:
			font_size = int(clampf(sqrt(screen_area) / 7.0, 10.0, 26.0))
			label_text = texts[i].to_upper()
			w_screen = _text_width(1, label_text, font_size)

		var h_screen := float(font_size) * 1.4
		var w_world := w_screen * inv_z
		var h_world := h_screen * inv_z
		var rect_world := Rect2(wx - w_world * 0.5, wy - h_world * 0.5, w_world, h_world)
		var curve := Vector3.ZERO   # angle, length, bend (map pixels); zero = straight
		if not is_sea and not show_provinces and country_curves.size() >= base_idx + 3:
			curve = Vector3(country_curves[base_idx], country_curves[base_idx + 1], country_curves[base_idx + 2])
			if curve.y > 0.0:
				# letter-spaced capitals along the country's own curve (old maps)
				var span := curve.y * z * 0.86
				font_size = int(clampf(span / maxf(float(label_text.length()), 1.0) / 1.05, 10.0, 34.0))
				if span < float(label_text.length()) * 7.0:
					curve = Vector3.ZERO
				else:
					w_screen = span
					var dir := Vector2(cos(curve.x), sin(curve.x))
					var perp := Vector2(-dir.y, dir.x)
					var half := dir * curve.y * 0.5
					var pad := float(font_size) * 0.8 * inv_z
					var a := Vector2(wx, wy) - half + perp * curve.z
					var b := Vector2(wx, wy) + half + perp * curve.z
					rect_world = Rect2(Vector2(wx, wy), Vector2.ZERO).expand(a).expand(b).grow(pad)

		var x0 := int(floor(rect_world.position.x / cell_size))
		var y0 := int(floor(rect_world.position.y / cell_size))
		var x1 := int(floor(rect_world.end.x / cell_size))
		var y1 := int(floor(rect_world.end.y / cell_size))
		var overlaps := false
		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				var key := (gx << 16) ^ gy
				if grid.has(key):
					var bucket: Array = grid[key]
					for r in bucket:
						if (r as Rect2).intersects(rect_world):
							overlaps = true
							break
				if overlaps:
					break
			if overlaps:
				break
		if overlaps:
			continue

		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				var key := (gx << 16) ^ gy
				if not grid.has(key):
					grid[key] = []
				(grid[key] as Array).append(rect_world)

		out.append([
			wx,
			wy,
			w_screen,
			font_size,
			label_text,
			rect_world,
			curve
		])
	return out

func _rebuild_cache_if_needed() -> void:
	if not _cache_dirty and is_equal_approx(_cached_zoom, map_zoom) and _cached_mode == map_mode:
		return
	_cached_zoom = map_zoom
	_cached_mode = map_mode
	_cache_dirty = false
	_cached_sea = _place_labels_world(sea_texts, sea_metrics, true, false)
	var show_provinces := MapScale.look(map_zoom) >= 1.1
	if not show_provinces and map_mode != "political":
		_cached_main = []
	elif show_provinces:
		_cached_main = _place_labels_world(province_texts, province_metrics, false, true)
	else:
		_cached_main = _place_labels_world(country_texts, country_metrics, false, false)

func _draw() -> void:
	if map_zoom <= 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	_rebuild_cache_if_needed()

	var vis_world := _visible_map_rect(160.0)

	var sea_col := Color(0.86, 0.93, 0.97, 0.82)
	var sea_shadow := Color(0.10, 0.18, 0.24, 0.65)
	for entry in _cached_sea:
		var wr: Rect2 = entry[5]
		if not vis_world.intersects(wr):
			continue
		var sp := _ms(float(entry[0]), float(entry[1]))
		var sx := sp.x
		var sy := sp.y
		var w_scr: float = entry[2]
		var fsize: int = entry[3]
		var txt: String = entry[4]
		var baseline := Vector2(sx - w_scr * 0.5, sy + float(fsize) * 0.35)
		draw_string_outline(font, baseline, txt, HORIZONTAL_ALIGNMENT_CENTER, w_scr, fsize, 2, sea_shadow)
		draw_string(font, baseline, txt, HORIZONTAL_ALIGNMENT_CENTER, w_scr, fsize, sea_col)

	var ink := Color(0.14, 0.10, 0.07, 0.88)
	var halo := Color(0.97, 0.94, 0.88, 0.82)
	if _name_font == null:
		_name_font = GezTheme.title_font()
	for entry in _cached_main:
		var wr: Rect2 = entry[5]
		if not vis_world.intersects(wr):
			continue
		var cv: Vector3 = entry[6]
		if cv.y > 0.0:
			_draw_curved_name(str(entry[4]), Vector2(float(entry[0]), float(entry[1])), cv, int(entry[3]), ink, halo)
			continue
		var sp := _ms(float(entry[0]), float(entry[1]))
		var sx := sp.x
		var sy := sp.y
		var w_scr: float = entry[2]
		var fsize: int = entry[3]
		var txt: String = entry[4]
		var baseline := Vector2(sx - w_scr * 0.5, sy + float(fsize) * 0.35)
		var lf: Font = font if MapScale.look(map_zoom) >= 1.1 else _name_font
		draw_string_outline(lf, baseline, txt, HORIZONTAL_ALIGNMENT_CENTER, w_scr, fsize, 3, halo)
		draw_string(lf, baseline, txt, HORIZONTAL_ALIGNMENT_CENTER, w_scr, fsize, ink)

# Phase 20 part 8: a country name in letter-spaced capitals along the curve
# C + dir*t*L/2 + perp*bend*t^2 (t from -1 to 1, map pixels), projected
# through the 3D camera so it lies on the tilted map too.
func _draw_curved_name(txt: String, c: Vector2, cv: Vector3, fsize: int, ink: Color, halo: Color) -> void:
	var font := _name_font
	var dir := Vector2(cos(cv.x), sin(cv.x))
	var perp := Vector2(-dir.y, dir.x)
	const N := 24
	var pts: Array[Vector2] = []
	var acc: Array[float] = [0.0]
	for k in range(N + 1):
		var t := -1.0 + 2.0 * float(k) / float(N)
		var mp := c + dir * (t * cv.y * 0.5) + perp * (cv.z * t * t)
		pts.append(_msv(mp))
		if k > 0:
			acc.append(acc[k - 1] + pts[k].distance_to(pts[k - 1]))
	var arc := acc[N]
	if arc < 4.0:
		return
	var n := txt.length()
	var widths: Array[float] = []
	var text_w := 0.0
	for i in range(n):
		var w := font.get_string_size(txt[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		widths.append(w)
		text_w += w
	var gap := 0.0
	if n > 1:
		gap = clampf((arc * 0.86 - text_w) / float(n - 1), 0.0, float(fsize) * 0.9)
	var d := (arc - (text_w + gap * float(n - 1))) * 0.5
	var seg := 0
	for i in range(n):
		var mid := d + widths[i] * 0.5
		while seg < N - 1 and acc[seg + 1] < mid:
			seg += 1
		var seg_len := maxf(acc[seg + 1] - acc[seg], 0.0001)
		var f := clampf((mid - acc[seg]) / seg_len, 0.0, 1.0)
		var p := pts[seg].lerp(pts[seg + 1], f)
		var tang := (pts[seg + 1] - pts[seg]).angle()
		draw_set_transform(p, tang, Vector2.ONE)
		var at := Vector2(-widths[i] * 0.5, float(fsize) * 0.36)
		draw_string_outline(font, at, txt[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 4, halo)
		draw_string(font, at, txt[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, ink)
		d += widths[i] + gap
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

