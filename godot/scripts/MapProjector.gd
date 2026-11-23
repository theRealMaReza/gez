extends RefCounted

# Phase 17: the maths of the 3D map camera, shared by the 3D view, the 2D
# overlay layers (labels, army counters, routes...) and mouse picking.
#
# The game still keeps its old 2D camera state (`zoom`, `offset`: screen =
# offset + map * zoom). From it we build a real perspective camera that looks
# at the same map point from the same distance, tilted towards the horizon as
# you zoom in. Looking straight down (whole map) the 3D camera shows exactly
# what the 2D camera showed, so nothing jumps when the tilt starts.
#
# World space: x = map x (pixels), z = map y (pixels), y = height (map pixels).

const FOV_DEG := 30.0
const TOP_DOWN_DEG := 90.0
const MIN_PITCH_DEG := 52.0   # most tilted (fully zoomed in)
const HEIGHT_MAX := 34.0      # world units for 6,000 m (strong exaggeration)
const ELEV_MAX_M := 6000.0

var map_size: Vector2 = Vector2(8304.0, 5112.0)
var view_size: Vector2 = Vector2(1440.0, 900.0)
var zoom: float = 1.0
var offset: Vector2 = Vector2.ZERO
var pitch_deg: float = TOP_DOWN_DEG

# Camera frame (rebuilt by update()).
var target: Vector3 = Vector3.ZERO
var cam_pos: Vector3 = Vector3(0.0, 1000.0, 0.0)
var fwd: Vector3 = Vector3.DOWN
var right: Vector3 = Vector3.RIGHT
var up: Vector3 = Vector3.FORWARD
var tan_half: float = tan(deg_to_rad(FOV_DEG * 0.5))
var revision: int = 0

# CPU copy of the height map (L8, sqrt-encoded metres), for picking and for
# standing overlay points on the ground.
var height_img: Image = null
var _hw: int = 0
var _hh: int = 0

func set_height_image(img: Image) -> void:
	height_img = img
	if img != null:
		_hw = img.get_width()
		_hh = img.get_height()

# Pitch for a zoom level: straight down up to 1.6x the "fit" zoom, then
# easing towards MIN_PITCH_DEG by the time you reach 70% of the max zoom.
static func pitch_for_zoom(z: float, fit_zoom: float, max_zoom: float) -> float:
	if z <= 0.0 or fit_zoom <= 0.0:
		return TOP_DOWN_DEG
	var lo := log(fit_zoom * 1.6)
	var hi := log(maxf(max_zoom * 0.7, fit_zoom * 2.0))
	var t := clampf((log(z) - lo) / (hi - lo), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(TOP_DOWN_DEG, MIN_PITCH_DEG, t)

func update(p_view: Vector2, p_zoom: float, p_offset: Vector2, p_pitch_deg: float) -> void:
	view_size = Vector2(maxf(p_view.x, 1.0), maxf(p_view.y, 1.0))
	zoom = maxf(p_zoom, 0.0001)
	offset = p_offset
	pitch_deg = clampf(p_pitch_deg, 10.0, TOP_DOWN_DEG)
	var c := (view_size * 0.5 - offset) / zoom
	target = Vector3(c.x, 0.0, c.y)
	# Distance at which the visible height equals view_size.y / zoom map pixels.
	var dist := (view_size.y * 0.5 / zoom) / tan_half
	var p := deg_to_rad(pitch_deg)
	var back := Vector3(0.0, sin(p), cos(p))
	cam_pos = target + back * dist
	fwd = -back
	right = Vector3.RIGHT
	up = Vector3(0.0, cos(p), -sin(p))
	revision += 1

func camera_transform() -> Transform3D:
	return Transform3D(Basis(right, up, -fwd), cam_pos)

func near_far() -> Vector2:
	var dist := cam_pos.distance_to(target)
	return Vector2(maxf(dist * 0.02, 0.5), dist * 6.0 + 4000.0)

# --- Height ---------------------------------------------------------------

static func decode_height(v: float) -> float:
	# v in 0..1, stored as sqrt(h / 6000 m).
	return v * v * HEIGHT_MAX * MapScale.k

func height_at(m: Vector2) -> float:
	if height_img == null or _hw <= 0:
		return 0.0
	var fx := clampf(m.x / map_size.x * float(_hw) - 0.5, 0.0, float(_hw - 1))
	var fy := clampf(m.y / map_size.y * float(_hh) - 0.5, 0.0, float(_hh - 1))
	var x0 := int(fx)
	var y0 := int(fy)
	var x1 := mini(x0 + 1, _hw - 1)
	var y1 := mini(y0 + 1, _hh - 1)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var a := lerpf(height_img.get_pixel(x0, y0).r, height_img.get_pixel(x1, y0).r, tx)
	var b := lerpf(height_img.get_pixel(x0, y1).r, height_img.get_pixel(x1, y1).r, tx)
	return decode_height(lerpf(a, b, ty))

# --- Projection -------------------------------------------------------------

func world_to_screen(w: Vector3) -> Vector2:
	var v := w - cam_pos
	var zc := v.dot(fwd)
	if zc <= 0.001:
		return Vector2(-100000.0, -100000.0)
	var aspect := view_size.x / view_size.y
	var nx := v.dot(right) / (zc * tan_half * aspect)
	var ny := v.dot(up) / (zc * tan_half)
	return Vector2((nx + 1.0) * 0.5 * view_size.x, (1.0 - ny) * 0.5 * view_size.y)

# Map point -> screen, standing on the terrain.
func to_screen(m: Vector2) -> Vector2:
	return world_to_screen(Vector3(m.x, height_at(m), m.y))

# Map point at a given height -> screen.
func to_screen_h(m: Vector2, h: float) -> Vector2:
	return world_to_screen(Vector3(m.x, h, m.y))

# How many screen pixels one map pixel covers at this map point (for sizing).
func scale_at(m: Vector2) -> float:
	var v := Vector3(m.x, height_at(m), m.y) - cam_pos
	var zc := v.dot(fwd)
	if zc <= 0.001:
		return zoom
	return (view_size.y * 0.5) / (zc * tan_half)

func ray_dir(s: Vector2) -> Vector3:
	var aspect := view_size.x / view_size.y
	var nx := s.x / view_size.x * 2.0 - 1.0
	var ny := 1.0 - s.y / view_size.y * 2.0
	return (fwd + right * (nx * tan_half * aspect) + up * (ny * tan_half)).normalized()

# Screen point -> map point on a flat plane at height h (no terrain).
func to_map_flat(s: Vector2, h: float = 0.0) -> Vector2:
	var d := ray_dir(s)
	if d.y > -0.0001:
		d.y = -0.0001
	var t := (h - cam_pos.y) / d.y
	var p := cam_pos + d * t
	return Vector2(p.x, p.z)

# Screen point -> map point on the terrain (a few fixed-point refinements are
# plenty: the relief is low compared with the camera distance).
func to_map(s: Vector2) -> Vector2:
	var m := to_map_flat(s, 0.0)
	if height_img == null:
		return m
	for _i in range(4):
		m = to_map_flat(s, height_at(m))
	return m

# Map-space box that covers everything on screen (for culling).
func visible_rect(pad_px: float = 0.0) -> Rect2:
	var corners := [
		Vector2(-pad_px, -pad_px), Vector2(view_size.x + pad_px, -pad_px),
		Vector2(-pad_px, view_size.y + pad_px), Vector2(view_size.x + pad_px, view_size.y + pad_px),
	]
	var r := Rect2(to_map_flat(corners[0]), Vector2.ZERO)
	for c in corners:
		r = r.expand(to_map_flat(c, 0.0))
		r = r.expand(to_map_flat(c, HEIGHT_MAX * MapScale.k))
	return r
