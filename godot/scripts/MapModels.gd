extends Node3D

# Phase 17 part 2: 3D models on the campaign map, replacing the 2D town icons.
#   towns   houses that multiply with development, a temple from development
#           4, a market from 6, a great building from 8 or in capitals
#   forts   by level: tower (2), stronger tower (3), castle (4+)
#   ports   a pier and a ship, placed on the nearest coast
#   capitals a flag in the owner's colour
#   armies  marching soldiers (riders for steppe armies) with a standard
#   fleets  ships with sails in the owner's colour
# Every model has a regional style (European, Islamic, Indian, East Asian,
# Steppe) from the Swift bridge. Models are drawn with one MultiMesh per mesh
# (one draw call each) and scaled around their group's anchor by the shader,
# so zooming never rebuilds them.

const Lib := preload("res://scripts/ModelLibrary.gd")
const ModelShader := preload("res://shaders/map_model.gdshader")

const TOWN_MIN_ZOOM := 0.6
const UNIT_MIN_ZOOM := 0.75

var material: ShaderMaterial
# Phase 20.6: flags and sails wave. Same shader with cloth_wave set; one
# material per way the cloth flaps (its thin side in model space).
var cloth_z: ShaderMaterial   # flags, square sails
var cloth_x: ShaderMaterial   # lateen and junk sails
var projector: RefCounted = null
var id_image: Image = null
var map_size: Vector2 = Vector2(8304.0, 5112.0)

var _batches: Dictionary = {}     # "layer|mesh" -> {node, items: [20 floats per instance]}
var _town_cache: Dictionary = {}  # town index * 4 + detail tier -> {sig, recs}
var _town_metrics := PackedFloat32Array()
var _town_data := PackedFloat32Array()   # stride 4: style, r, g, b
var _town_tier: int = -1
var _coast_cache: Dictionary = {}
var _zoom: float = 1.0

func _init() -> void:
	name = "MapModels"
	material = ShaderMaterial.new()
	material.shader = ModelShader
	cloth_z = _cloth_material(Vector3(0, 0, 1), 0.06)
	cloth_x = _cloth_material(Vector3(1, 0, 0), 0.05)

func _cloth_material(axis: Vector3, amount: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ModelShader
	m.set_shader_parameter("cloth_wave", amount)
	m.set_shader_parameter("cloth_axis", axis)
	return m

## Material for a mesh: the waving cloth material for flags and sails.
func material_for(mesh_name: String) -> ShaderMaterial:
	if mesh_name == "flag_cloth" or mesh_name == "sail.european" or mesh_name == "sail.steppe":
		return cloth_z
	if mesh_name.begins_with("sail."):
		return cloth_x
	return material

func ready_ok() -> bool:
	return Lib.ensure_loaded()

# World units per model unit for a zoom: models grow on screen as you zoom in
# but much less than the map does (a house is ~5 px wide zoomed out and
# ~28 px zoomed right in).
# z is the "look" zoom (MapScale.look); map pixels per model unit grow with
# the map's detail so models keep their size on the ground.
static func scale_for_zoom(z: float) -> float:
	return 6.5 * MapScale.k * pow(maxf(z, 0.05), -0.2)

const ARMY_SIZE := 1.5   # soldiers are drawn larger than the houses
const FLEET_SIZE := 1.25

static func town_tier_for_zoom(z: float) -> int:
	if z < TOWN_MIN_ZOOM:
		return -1
	if z < 1.1:
		return 0
	if z < 1.6:
		return 1
	return 2

func update_zoom(camera_zoom: float) -> void:
	var z := MapScale.look(camera_zoom)
	_zoom = z
	for m in [material, cloth_z, cloth_x]:
		m.set_shader_parameter("model_scale", scale_for_zoom(z))
	var tier := town_tier_for_zoom(z)
	if tier != _town_tier:
		_town_tier = tier
		_rebuild_towns()
	_set_layer_visible("forest", z >= FOREST_MIN_ZOOM)
	_set_layer_visible("army", z >= UNIT_MIN_ZOOM)
	_set_layer_visible("fleet", z >= UNIT_MIN_ZOOM)

# ---- Batches ---------------------------------------------------------------

func _begin(layer: String) -> void:
	for key in _batches.keys():
		if String(key).begins_with(layer + "|"):
			(_batches[key]["items"] as Array).clear()

func _batch(layer: String, mesh_name: String) -> Variant:
	var key := layer + "|" + mesh_name
	if not _batches.has(key):
		var mesh := Lib.get_mesh(mesh_name)
		if mesh == null:
			return null
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		var node := MultiMeshInstance3D.new()
		node.name = key.replace("|", "_").replace(".", "_")
		node.multimesh = mm
		node.material_override = material_for(mesh_name)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The shader moves vertices far from the instance origins; never cull.
		node.custom_aabb = AABB(Vector3(-200, -100, -200), Vector3(map_size.x + 400, 600, map_size.y + 400))
		add_child(node)
		_batches[key] = {"node": node, "items": []}
	return _batches[key]

# One instance as the 20 floats of a MultiMesh buffer: 3x4 transform rows,
# colour, custom data (group anchor and march phase).
static func _instance_floats(xf: Transform3D, anchor: Vector3, color: Color, phase: float) -> PackedFloat32Array:
	var bs := xf.basis
	var o := xf.origin
	return PackedFloat32Array([
		bs.x.x, bs.y.x, bs.z.x, o.x, bs.x.y, bs.y.y, bs.z.y, o.y, bs.x.z, bs.y.z, bs.z.z, o.z,
		color.r, color.g, color.b, color.a, anchor.x, anchor.y, anchor.z, phase])

# While a town is being laid out, instances are recorded here instead of drawn,
# so each town is laid out once and reused until it changes.
var _recording: Variant = null

func _add(layer: String, mesh_name: String, xf: Transform3D, anchor: Vector3, color: Color = Color.WHITE, phase: float = 0.0) -> void:
	var floats := _instance_floats(xf, anchor, color, phase)
	if _recording != null:
		(_recording as Array).append([mesh_name, floats])
		return
	var b: Variant = _batch(layer, mesh_name)
	if b != null:
		(b["items"] as Array).append(floats)

func _commit(layer: String) -> void:
	for key in _batches.keys():
		if not String(key).begins_with(layer + "|"):
			continue
		var b: Dictionary = _batches[key]
		var node: MultiMeshInstance3D = b["node"]
		var items: Array = b["items"]
		var n := items.size()
		var buf := PackedFloat32Array()
		for it in items:
			buf.append_array(it)
		var mm := node.multimesh
		if mm.instance_count != n:
			mm.instance_count = n
		if n > 0:
			mm.buffer = buf
		node.visible = n > 0

func _set_layer_visible(layer: String, vis: bool) -> void:
	for key in _batches.keys():
		if String(key).begins_with(layer + "|"):
			var b: Dictionary = _batches[key]
			(b["node"] as Node3D).visible = vis and not (b["items"] as Array).is_empty()

func instance_count(layer: String) -> int:
	var n := 0
	for key in _batches.keys():
		if String(key).begins_with(layer + "|"):
			n += (_batches[key]["items"] as Array).size()
	return n

func mesh_instance_count(layer: String, mesh_name: String) -> int:
	var key := layer + "|" + mesh_name
	return (_batches[key]["items"] as Array).size() if _batches.has(key) else 0

# ---- Helpers ---------------------------------------------------------------

func _ground(m: Vector2) -> float:
	return float(projector.call("height_at", m)) if projector != null else 0.0

static func _hash01(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xFFFF) / 65535.0

static func _style(code: float) -> String:
	return Lib.style_name(int(code))

func _place(layer: String, mesh_name: String, anchor: Vector3, local: Vector2, yaw: float, color: Color = Color.WHITE, phase: float = 0.0, size: float = 1.0) -> void:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
	var origin := anchor + Vector3(local.x, 0.0, local.y) * size
	_add(layer, mesh_name, Transform3D(basis, origin), anchor, color, phase)

# Province id at a map pixel (0 = water), from the id map the shader uses.
func _id_at(x: int, y: int) -> int:
	if id_image == null or x < 0 or y < 0 or x >= id_image.get_width() or y >= id_image.get_height():
		return -1
	var c := id_image.get_pixel(x, y)
	return int(round(c.r * 255.0)) | (int(round(c.g * 255.0)) << 8)

# First water pixel around a town (direction and coast point), or null.
func coast_point(m: Vector2) -> Variant:
	var key := Vector2i(int(m.x), int(m.y))
	if _coast_cache.has(key):
		return _coast_cache[key]
	var found: Variant = null
	for r in range(3, 40, 2):
		var best := -1.0
		for k in range(24):
			var ang := TAU * float(k) / 24.0
			var p := m + Vector2(cos(ang), sin(ang)) * float(r)
			if _id_at(int(p.x), int(p.y)) == 0:
				found = {"point": p, "dir": Vector2(cos(ang), sin(ang))}
				best = 1.0
				break
		if best > 0.0:
			break
	_coast_cache[key] = found
	return found

# ---- Forests (Phase 20 part 8) ----------------------------------------------

const FOREST_MIN_ZOOM := 0.9

# Little trees scattered over forest provinces (pines in the north, broad
# leaves further south), only on the province's own ground. terrain: key per
# province index; label_metrics: stride 3 [x, y, pixel area] per province.
func set_forests(terrain: PackedStringArray, label_metrics: PackedFloat32Array) -> void:
	set_province_areas(label_metrics)
	_begin("forest")
	var n := mini(terrain.size(), label_metrics.size() / 3)
	for i in range(n):
		if terrain[i] != "forest":
			continue
		var c := Vector2(label_metrics[i * 3], label_metrics[i * 3 + 1])
		var area := label_metrics[i * 3 + 2]
		var want := clampi(int(area / 420.0), 3, 16)
		var radius := sqrt(area) * 0.55
		var placed := 0
		for k in range(want * 3):
			if placed >= want:
				break
			var a := TAU * _hash01(i, k * 2)
			var r := radius * sqrt(_hash01(i, k * 2 + 1))
			var p := c + Vector2(cos(a), sin(a)) * r
			if _id_at(int(p.x), int(p.y)) != i + 2:
				continue
			var mesh := "tree_pine" if (p.y < map_size.y * 0.33 or _hash01(i, k + 99) < 0.3) else "tree_leaf"
			var anchor := Vector3(p.x, _ground(p), p.y)
			_place("forest", mesh, anchor, Vector2.ZERO, TAU * _hash01(k, i), Color.WHITE, 0.0, 0.7 + 0.4 * _hash01(i + 7, k))
			placed += 1
	_commit("forest")
	_set_layer_visible("forest", _zoom >= FOREST_MIN_ZOOM)

# ---- Towns -----------------------------------------------------------------

# Phase 20.6: pixel area per province index (label metrics, stride 3), so a
# town never spreads far past its own province.
var _prov_area := PackedFloat32Array()

func set_province_areas(label_metrics: PackedFloat32Array) -> void:
	var n := label_metrics.size() / 3
	var areas := PackedFloat32Array()
	areas.resize(n)
	for i in range(n):
		areas[i] = label_metrics[i * 3 + 2]
	if areas == _prov_area:
		return
	_prov_area = areas
	if not _town_metrics.is_empty():
		_town_cache.clear()
		_rebuild_towns()

# Largest town radius (model units) for a province of `area` map pixels at a
# detail tier: the radius of a circle of that area, at the tier's smallest
# zoom (where models are largest relative to the map).
static func town_radius_cap(area: float, tier: int) -> float:
	if area <= 0.0:
		return 99.0
	var z := [TOWN_MIN_ZOOM, 1.1, 1.6][clampi(tier, 0, 2)] as float
	return sqrt(area / PI) * 1.1 / scale_for_zoom(z)

func _town_area(m: Vector2) -> float:
	var pidx := _id_at(int(m.x), int(m.y)) - 2
	return _prov_area[pidx] if pidx >= 0 and pidx < _prov_area.size() else 0.0

# How far the province reaches around a town (map pixels): walk out in 12
# directions until the id map shows another province or the sea, and take
# the middle distance. Long thin or coastal provinces (Konstantiniyye) get a
# smaller town than their area alone would give. Cached per town position.
var _reach_cache: Dictionary = {}
const REACH_MAX := 48.0

func _town_reach(m: Vector2) -> float:
	var key := Vector2i(int(m.x), int(m.y))
	if _reach_cache.has(key):
		return _reach_cache[key]
	var own := _id_at(key.x, key.y)
	if own < 2:
		_reach_cache[key] = REACH_MAX * MapScale.k
		return REACH_MAX * MapScale.k
	var dists: Array[float] = []
	for k in range(12):
		var ang := TAU * float(k) / 12.0
		var dir := Vector2(cos(ang), sin(ang))
		var d := 2.0
		while d < REACH_MAX * MapScale.k:
			var p := m + dir * d
			if _id_at(int(p.x), int(p.y)) != own:
				break
			d += 2.0
		dists.append(d)
	dists.sort()
	var r := (dists[5] + dists[6]) * 0.5
	_reach_cache[key] = r
	return r

# Radius cap from that reach, at a tier's smallest zoom (model units).
static func town_reach_cap(reach_px: float, tier: int) -> float:
	var z := [TOWN_MIN_ZOOM, 1.1, 1.6][clampi(tier, 0, 2)] as float
	return maxf(reach_px * 1.25 / scale_for_zoom(z), 1.2)

# metrics: stride 6 [x, y, dev, fort, capital, port]; data: stride 4 [style, r, g, b].
# Phase 20.7: named landmarks, [mesh, latitude, longitude]. A town in the
# province under that point shows the landmark instead of its great
# building. More come one per region (tools/models/landmarks.py).
const LANDMARKS := [
	["hagia_sophia", 41.008, 28.980],       # Konstantiniyye (owner's pick B, 24 Nov 2026)
	["florence_cathedral", 43.770, 11.260], # Florence
	["notre_dame", 48.860, 2.350],          # Paris
	["cologne_cathedral", 50.940, 6.960],   # Cologne (unfinished with crane)
	["westminster_abbey", 51.510, -0.130],  # London
	["alhambra", 37.180, -3.600],           # Granada
	["pyramids_of_giza", 30.040, 31.240],   # Cairo
	["dome_of_the_rock", 31.770, 35.210],   # Jerusalem
	["lalibela", 12.030, 39.040],           # Lalibela
	["gur_e_amir", 39.650, 66.960],         # Samarkand
	["qutb_minar", 28.610, 77.210],         # Delhi
	["virupaksha_temple", 15.340, 76.460],  # Vijayanagara
	["gyantse_kumbum", 28.910, 89.600],     # Gyantse
	["forbidden_city", 39.900, 116.400],    # Beijing
	["kinkaku_ji", 35.010, 135.770],        # Kyoto
	["gyeongbokgung", 37.570, 126.980],     # Hanyang
]
var _landmark_ids: Dictionary = {}   # province id (as in id_image) -> mesh

func landmark_list() -> Array:
	return LANDMARKS

## Main.gd passes map points for LANDMARKS (bridge getFocusPoint) once loaded.
func set_landmark_points(points: Array) -> void:
	_landmark_ids.clear()
	for k in range(mini(points.size(), LANDMARKS.size())):
		var p: Vector2 = points[k]
		var pid := _id_at(int(p.x), int(p.y))
		if pid >= 2 and Lib.has_mesh(LANDMARKS[k][0]):
			_landmark_ids[pid] = LANDMARKS[k][0]
	_town_cache.clear()
	_rebuild_towns()

func set_towns(metrics: PackedFloat32Array, data: PackedFloat32Array) -> void:
	_town_metrics = metrics
	_town_data = data
	_rebuild_towns()

func _rebuild_towns() -> void:
	_begin("town")
	if _town_tier >= 0:
		var min_dev := 5
		if _town_tier == 1:
			min_dev = 3
		elif _town_tier == 2:
			min_dev = 1
		var count := _town_metrics.size() / 6
		for i in range(count):
			var dev := int(_town_metrics[i * 6 + 2])
			var is_cap := _town_metrics[i * 6 + 4] >= 0.5
			if dev < min_dev and not is_cap:
				continue
			var sig := _town_sig(i)
			var cache_key := i * 4 + _town_tier
			var cached: Dictionary = _town_cache.get(cache_key, {})
			if cached.get("sig", "") != sig:
				_recording = []
				_build_town(i)
				cached = {"sig": sig, "recs": _recording}
				_recording = null
				_town_cache[cache_key] = cached
			for rec in cached["recs"]:
				var b: Variant = _batch("town", rec[0])
				if b != null:
					(b["items"] as Array).append(rec[1])
	_commit("town")
	_set_layer_visible("town", _town_tier >= 0)

func _town_sig(i: int) -> String:
	var parts := PackedStringArray([str(_town_tier)])
	for k in range(6):
		parts.append(str(_town_metrics[i * 6 + k]))
	if _town_data.size() >= (i + 1) * 4:
		for k in range(4):
			parts.append(str(_town_data[i * 4 + k]))
	return "|".join(parts)

func _build_town(i: int) -> void:
	var m := Vector2(_town_metrics[i * 6], _town_metrics[i * 6 + 1])
	var dev := int(_town_metrics[i * 6 + 2])
	var fort := int(_town_metrics[i * 6 + 3])
	var is_cap := _town_metrics[i * 6 + 4] >= 0.5
	var is_port := _town_metrics[i * 6 + 5] >= 0.5
	var st := "european"
	var owner_col := Color(0.85, 0.75, 0.4)
	if _town_data.size() >= (i + 1) * 4:
		st = _style(_town_data[i * 4])
		owner_col = Color(_town_data[i * 4 + 1], _town_data[i * 4 + 2], _town_data[i * 4 + 3])
	var anchor := Vector3(m.x, _ground(m) - 0.05, m.y)
	var cap := minf(town_radius_cap(_town_area(m), _town_tier), town_reach_cap(_town_reach(m), _town_tier))
	var landmark: String = _landmark_ids.get(_id_at(int(m.x), int(m.y)), "")
	for part in town_layout(i, dev, fort, is_cap, st, _town_tier, cap, landmark):
		_place("town", part[0], anchor, part[1], part[2])
	if is_cap:
		_place("town", "flag_pole", anchor, Vector2(0.15, -0.35), 0.0)
		_place("town", "flag_cloth", anchor, Vector2(0.15, -0.35), 0.0, owner_col)
	if is_port:
		var cp: Variant = coast_point(m)
		if cp != null:
			var pt: Vector2 = cp["point"]
			var dir: Vector2 = cp["dir"]
			var yaw := atan2(dir.x, dir.y)
			var port_anchor := Vector3(pt.x, 0.02, pt.y)
			_place("town", "pier", port_anchor, Vector2.ZERO, yaw)
			var ship_at := dir * 1.25 + Vector2(dir.y, -dir.x) * 0.45
			_place("town", "ship." + st, port_anchor, ship_at, yaw + PI * 0.5)
			_place("town", "sail." + st, port_anchor, ship_at, yaw + PI * 0.5, Color(0.96, 0.94, 0.88))

# The buildings of one town: [mesh, local offset (model units), yaw].
# Deterministic for a town index, so towns do not reshuffle when they grow.
# detail: 0 zoomed out (main building and castle only), 1 a few houses, 2 everything.
# max_r (Phase 20.6): houses and the market beyond this radius are left out
# and the fort is drawn closer in, so small provinces get small towns.
# landmark (Phase 20.7): a named building (e.g. "hagia_sophia") shown in
# place of the temple or great building, at every detail level.
static func town_layout(i: int, dev: int, fort: int, is_cap: bool, st: String, detail: int = 2, max_r: float = 99.0, landmark: String = "") -> Array:
	var parts: Array = []
	var houses := clampi(1 + int(float(dev) * 0.65), 1, 7)
	if detail == 0:
		houses = 1 if dev < 4 and not is_cap else 0
	elif detail == 1:
		houses = mini(houses, 3)
	var has_temple := dev >= 4 or is_cap
	var has_market := dev >= 6
	var has_landmark := dev >= 8 or (is_cap and dev >= 5)
	if not landmark.is_empty():
		parts.append([landmark, Vector2(0.0, -0.2), 0.0])
	elif has_landmark:
		parts.append(["landmark." + st, Vector2(0.0, -0.2), 0.0])
	elif has_temple:
		parts.append(["temple." + st, Vector2(0.0, -0.1), 0.0])
	if has_market and detail >= 1 and max_r >= 2.2:
		parts.append(["market." + st, Vector2(-1.45, 0.75), 0.4])
	var ring := 1.15 if (has_temple or has_landmark) else 0.0
	if not landmark.is_empty():
		ring = 1.75   # named landmarks are wider than a great mosque
	for h in range(houses):
		var ang := TAU * (float(h) / float(houses)) + _hash01(i, 11) * TAU
		var rad := ring + 0.55 * float(h / 4) + 0.25 * _hash01(i, h)
		if ring == 0.0 and h == 0:
			rad = 0.0
		elif ring == 0.0:
			rad = 0.85 + 0.2 * _hash01(i, h + 40)
		var pos := Vector2(cos(ang), sin(ang)) * rad
		if has_market and pos.distance_to(Vector2(-1.45, 0.75)) < 0.8:
			pos += Vector2(0.9, -0.6)
		if pos.length() + 0.5 > max_r and not (parts.is_empty() and h == houses - 1):
			continue
		var kind := "house_a." if _hash01(i, h + 7) < 0.55 else "house_b."
		parts.append([kind + st, pos, _hash01(i, h + 21) * TAU])
	var fort_mesh := ""
	if detail == 0 and fort < 4:
		return parts
	if fort >= 4:
		fort_mesh = "fort3."
	elif fort == 3:
		fort_mesh = "fort2."
	elif fort == 2:
		fort_mesh = "fort1."
	if not fort_mesh.is_empty():
		var out := 2.2 if fort >= 4 else 1.8
		var reach := (1.3 if fort >= 4 else 0.6) + 0.6
		out = maxf(minf(out, max_r - reach), 1.0)
		if not landmark.is_empty():
			# clear of the wide landmark, or left out where there is no room
			var half := 0.7 if fort >= 4 else 0.4
			out = 1.5 + 0.1 + half
			if out + half > max_r:
				return parts
		parts.append([fort_mesh + st, Vector2(out, -0.6), 0.0])
	return parts

# ---- Armies ----------------------------------------------------------------

# counters: getMapArmiesData()["counters"]; motion: armyId -> {style, moving, nextX, nextY, frac}.
func set_armies(counters: Array, motion: Dictionary) -> void:
	_begin("army")
	for c_item in counters:
		if not (c_item is Dictionary):
			continue
		var c: Dictionary = c_item
		var aid := int(c.get("armyId", -1))
		var mo: Dictionary = motion.get(aid, {})
		var pos := army_draw_point(c, mo)
		var st := _style(float(mo.get("style", 0)))
		var men := int(c.get("men", 1000))
		var owner_col := Color8(int(c.get("colorR", 140)), int(c.get("colorG", 120)), int(c.get("colorB", 90)))
		if bool(c.get("isRebel", false)):
			owner_col = Color(0.62, 0.14, 0.14)
		var moving := bool(mo.get("moving", false))
		var yaw := 0.0
		if moving:
			var d := Vector2(float(mo.get("nextX", pos.x)), float(mo.get("nextY", pos.y))) - pos
			if d.length() > 0.01:
				yaw = atan2(d.x, d.y)
		var stack_idx := int(c.get("stackIndex", 0))
		var stack_cnt := int(c.get("stackCount", 1))
		var anchor := Vector3(pos.x, _ground(pos), pos.y)
		var side := (float(stack_idx) - float(stack_cnt - 1) * 0.5) * 1.9
		for f in army_formation(men, st, side, yaw):
			var phase := 0.0
			if moving:
				phase = 0.05 + 0.9 * _hash01(aid, int(f[3]))
			var col: Color = owner_col if f[4] else Color.WHITE
			_place("army", f[0], anchor, f[1], f[2], col, phase, ARMY_SIZE)
	_commit("army")
	_set_layer_visible("army", _zoom >= UNIT_MIN_ZOOM)

static func army_draw_point(c: Dictionary, mo: Dictionary) -> Vector2:
	var pos := Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0)))
	if bool(mo.get("moving", false)):
		var nxt := Vector2(float(mo.get("nextX", pos.x)), float(mo.get("nextY", pos.y)))
		pos = pos.lerp(nxt, clampf(float(mo.get("frac", 0.0)), 0.0, 1.0))
	return pos

# Figures of one army: [mesh, local offset, yaw, id, tinted?]. One figure per
# ~8,000 men (1 to 4), a standard bearer; steppe armies ride.
static func army_formation(men: int, st: String, side: float, yaw: float) -> Array:
	var out: Array = []
	var n := clampi(1 + men / 8000, 1, 4)
	var ride := st == "steppe"
	var body := "rider_body" if ride else "soldier_body"
	var gear := ("rider_gear." if ride else "soldier_gear.") + st
	var spacing := 0.75 if ride else 0.5
	var rot := Basis(Vector3.UP, yaw)
	for k in range(n):
		var row := k / 2
		var col := float(k % 2) - 0.5 if n > 1 else 0.0
		var local := Vector3(side + col * spacing, 0.0, -float(row) * spacing * 1.2)
		var p := rot * (local - Vector3(side, 0, 0)) + Vector3(side, 0, 0)
		out.append([body, Vector2(p.x, p.z), yaw, k, true])
		out.append([gear, Vector2(p.x, p.z), yaw, k, false])
	var fp := rot * Vector3(0.38, 0.0, 0.25) + Vector3(side, 0, 0)
	out.append(["flag_pole", Vector2(fp.x, fp.z), yaw, 9, false])
	out.append(["flag_cloth", Vector2(fp.x, fp.z), yaw, 9, true])
	return out

# ---- Fleets ----------------------------------------------------------------

# counters: getMapFleetsData()["counters"]; styles: fleetId -> style code.
func set_fleets(counters: Array, styles: Dictionary) -> void:
	_begin("fleet")
	for c_item in counters:
		if not (c_item is Dictionary):
			continue
		var c: Dictionary = c_item
		var fid := int(c.get("fleetId", -1))
		var pos := Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0)))
		var st := _style(float(styles.get(fid, 0)))
		var owner_col := Color8(int(c.get("colorR", 140)), int(c.get("colorG", 120)), int(c.get("colorB", 90)))
		var sail_col := owner_col.lerp(Color.WHITE, 0.35)
		var ships := clampi(1 + int(c.get("shipCount", 1)) / 6, 1, 3)
		var yaw := 0.35
		if bool(c.get("isDocked", false)):
			# Docked: moor off the port's coast instead of on the town square.
			var cp: Variant = coast_point(pos)
			if cp != null:
				var dir: Vector2 = cp["dir"]
				pos = (cp["point"] as Vector2) + dir * 2.0
				yaw = atan2(dir.x, dir.y) + PI * 0.5
		var anchor := Vector3(pos.x, 0.02, pos.y)
		for k in range(ships):
			var local := Vector2((float(k) - float(ships - 1) * 0.5) * 1.1, 0.35 * float(k % 2))
			_place("fleet", "ship." + st, anchor, local, yaw, Color.WHITE, 0.0, FLEET_SIZE)
			_place("fleet", "sail." + st, anchor, local, yaw, sail_col, 0.0, FLEET_SIZE)
	_commit("fleet")
	_set_layer_visible("fleet", _zoom >= UNIT_MIN_ZOOM)
