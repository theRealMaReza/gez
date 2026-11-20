extends RefCounted

# Phase 17 part 1: the 3D map camera maths.
const ProjScript := preload("res://scripts/MapProjector.gd")

var runner: Object

func _proj(z: float, center: Vector2, pitch: float, with_height: bool = false) -> RefCounted:
	var p: RefCounted = ProjScript.new()
	p.set("map_size", Vector2(3936, 2384))
	if with_height:
		# A gentle hill: 0 at the edges, full height in the middle.
		var img := Image.create(64, 40, false, Image.FORMAT_L8)
		for y in range(40):
			for x in range(64):
				var d := Vector2(x - 32, y - 20).length() / 20.0
				img.set_pixel(x, y, Color(clampf(1.0 - d, 0.0, 1.0), 0, 0))
		p.call("set_height_image", img)
	var view := Vector2(1440, 900)
	p.call("update", view, z, view * 0.5 - center * z, pitch)
	return p

# Looking straight down, the 3D camera must match the old 2D camera exactly
# (screen = offset + map * zoom), so nothing moves when Phase 17 lands.
func test_top_down_matches_2d_camera() -> void:
	var z := 0.8
	var center := Vector2(1500, 900)
	var p := _proj(z, center, 90.0)
	var off := Vector2(1440, 900) * 0.5 - center * z
	for m in [Vector2(1500, 900), Vector2(1000, 600), Vector2(2200, 1300), Vector2(800, 1400)]:
		runner.near2(p.call("to_screen", m), off + m * z, 0.05, "top-down to_screen %s" % m)
		runner.near2(p.call("to_map", off + m * z), m, 0.05, "top-down to_map %s" % m)

func test_screen_centre_is_the_target_at_any_tilt() -> void:
	for pitch in [90.0, 75.0, 60.0, 52.0]:
		var p := _proj(3.0, Vector2(2150, 820), pitch)
		runner.near2(p.call("to_screen", Vector2(2150, 820)), Vector2(720, 450), 0.05, "centre at pitch %s" % pitch)

func test_round_trip_with_terrain_and_tilt() -> void:
	var p := _proj(4.0, Vector2(1968, 1192), 55.0, true)
	for m in [Vector2(1968, 1192), Vector2(1900, 1150), Vector2(2050, 1230), Vector2(1800, 1100)]:
		var s: Vector2 = p.call("to_screen", m)
		runner.near2(p.call("to_map", s), m, 0.6, "round trip %s" % m)
	# The hill top stands out: it is drawn higher on screen than flat ground.
	var top := Vector2(1968, 1192)
	var flat: Vector2 = p.call("to_screen_h", top, 0.0)
	var lifted: Vector2 = p.call("to_screen", top)
	runner.check(lifted.y < flat.y - 1.0, "terrain height lifts points on screen")

func test_tilt_eases_in_with_zoom() -> void:
	var fit := 0.366
	var prev := 91.0
	for z in [0.366, 0.5, 0.6, 1.0, 2.0, 4.0, 6.0, 8.0]:
		var pitch: float = ProjScript.pitch_for_zoom(z, fit, 8.0)
		runner.check(pitch <= prev + 0.0001, "pitch never rises when zooming in (z=%s)" % z)
		prev = pitch
	runner.near(ProjScript.pitch_for_zoom(fit, fit, 8.0), 90.0, 0.001, "whole map is seen straight down")
	runner.near(ProjScript.pitch_for_zoom(8.0, fit, 8.0), ProjScript.MIN_PITCH_DEG, 0.001, "fully zoomed in is the most tilted")

func test_visible_rect_covers_screen_corners() -> void:
	var p := _proj(3.0, Vector2(2150, 820), 55.0)
	var r: Rect2 = p.call("visible_rect", 0.0)
	for s in [Vector2(0, 0), Vector2(1440, 0), Vector2(0, 900), Vector2(1440, 900), Vector2(720, 450)]:
		var m: Vector2 = p.call("to_map_flat", s, 0.0)
		runner.check(r.grow(0.5).has_point(m), "visible rect holds screen point %s" % s)
	# Tilted: the far (top) edge covers more map than the near (bottom) edge.
	var top_w: float = (p.call("to_map_flat", Vector2(1440, 0), 0.0) as Vector2).x - (p.call("to_map_flat", Vector2(0, 0), 0.0) as Vector2).x
	var bot_w: float = (p.call("to_map_flat", Vector2(1440, 900), 0.0) as Vector2).x - (p.call("to_map_flat", Vector2(0, 900), 0.0) as Vector2).x
	runner.check(top_w > bot_w * 1.1, "perspective: far edge wider than near edge")

func test_camera_transform_matches_projection() -> void:
	# The real Camera3D must see what the projector computes.
	var p := _proj(2.5, Vector2(1700, 700), 62.0)
	var cam := Camera3D.new()
	cam.fov = ProjScript.FOV_DEG
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.transform = p.call("camera_transform")
	var w := Vector3(1750, 0, 760)
	var proj := Projection.create_perspective(ProjScript.FOV_DEG, 1440.0 / 900.0, 1.0, 100000.0)
	var clip: Vector4 = proj * Vector4((cam.transform.affine_inverse() * w).x, (cam.transform.affine_inverse() * w).y, (cam.transform.affine_inverse() * w).z, 1.0)
	var ndc := Vector2(clip.x / clip.w, clip.y / clip.w)
	var screen := Vector2((ndc.x + 1.0) * 0.5 * 1440.0, (1.0 - ndc.y) * 0.5 * 900.0)
	runner.near2(screen, p.call("world_to_screen", w), 0.05, "Camera3D projection equals projector")
	cam.free()
