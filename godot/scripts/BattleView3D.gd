extends SubViewportContainer

# Phase 17 part 3: the battle view in 3D.
# Only the picture changes: the battlefield, soldiers, walls and siege
# engines are drawn in 3D under the 2D battle overlay (selection, bars,
# orders, deployment zones). The battle rules, orders and results are the
# Phase 9 ones, untouched: this node only reads the battle state.
#
# Field coordinates (x right, y down, about 1200 x 800) map to the 3D ground
# as world x = field x, world z = field y, y = height. A fixed tilted camera
# looks at the whole field from the south; BattleView converts between the
# screen and the field through field_to_screen() / screen_to_field().

const Lib := preload("res://scripts/ModelLibrary.gd")
const ModelShader := preload("res://shaders/map_model.gdshader")

const FOV_DEG := 32.0
const PITCH_DEG := 56.0
const HILL_SCALE := 1.6        # hill "height" in the battle state -> world units
const GRID := 6.0              # ground mesh cell (field units)
const UNIT_SCALE := 10.0       # model unit -> field units for soldiers and engines
const FIGURE_SPACING := 9.0    # field units between soldiers in a formation
const MEN_PER_FIGURE := 60
const MAX_FIGURES := 40
const WALL_HEIGHT := 34.0      # field units

var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var ground: MeshInstance3D
var unit_mat: ShaderMaterial    # soldiers, engines, trees: scaled by UNIT_SCALE
var static_mat: ShaderMaterial  # walls and towers: sized by their transform

var field_size := Vector2(1200.0, 800.0)
var hills: Array = []
var _ground_sig: String = ""
var _batches: Dictionary = {}   # mesh key -> {node, items: [20 floats per instance]}
var _fit_size := Vector2.ZERO

# Camera frame (kept here so screen <-> field maths needs no rendering).
var cam_pos := Vector3.ZERO
var fwd := Vector3.FORWARD
var right := Vector3.RIGHT
var up := Vector3.UP
var tan_half := tan(deg_to_rad(FOV_DEG * 0.5))
var view_size := Vector2(1200.0, 700.0)

func _init() -> void:
	name = "Battle3D"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.20, 0.22, 0.20)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.80, 0.78, 0.74)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	world.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -140.0, 0.0)
	sun.light_energy = 1.0
	world.add_child(sun)

	camera = Camera3D.new()
	camera.fov = FOV_DEG
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	world.add_child(camera)

	ground = MeshInstance3D.new()
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.vertex_color_is_srgb = true
	gm.roughness = 1.0
	gm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ground.material_override = gm
	world.add_child(ground)

	unit_mat = ShaderMaterial.new()
	unit_mat.shader = ModelShader
	unit_mat.set_shader_parameter("model_scale", UNIT_SCALE)
	unit_mat.set_shader_parameter("march_speed", 9.0)
	unit_mat.set_shader_parameter("march_height", 0.06)
	static_mat = ShaderMaterial.new()
	static_mat.shader = ModelShader
	static_mat.set_shader_parameter("model_scale", 1.0)

func ready_ok() -> bool:
	return Lib.ensure_loaded()

# ---- Camera and coordinates ------------------------------------------------

# Place the camera so the whole field fits the view, tilted from the south.
func fit_camera(p_view: Vector2) -> void:
	view_size = Vector2(maxf(p_view.x, 64.0), maxf(p_view.y, 64.0))
	_fit_size = view_size
	var p := deg_to_rad(PITCH_DEG)
	var back := Vector3(0.0, sin(p), cos(p))
	fwd = -back
	right = Vector3.RIGHT
	up = Vector3(0.0, cos(p), -sin(p))
	var target := Vector3(field_size.x * 0.5, 0.0, field_size.y * 0.5)
	var lo := 100.0
	var hi := 20000.0
	for _i in range(40):
		var mid := (lo + hi) * 0.5
		cam_pos = target + back * mid
		if _field_fits(0.96):
			hi = mid
		else:
			lo = mid
	cam_pos = target + back * hi
	# Centre the field vertically (the far edge is shorter than the near one).
	var top := world_to_screen(Vector3(field_size.x * 0.5, 0.0, 0.0)).y
	var bottom := world_to_screen(Vector3(field_size.x * 0.5, 0.0, field_size.y)).y
	var shift_px := ((top + bottom) * 0.5 - view_size.y * 0.5)
	var ground_per_px := field_size.y / maxf(bottom - top, 1.0)
	cam_pos.z += shift_px * ground_per_px * 0.9
	camera.transform = Transform3D(Basis(right, up, -fwd), cam_pos)
	camera.near = 2.0
	camera.far = 20000.0

func _field_fits(margin: float) -> bool:
	for c in [Vector3(0, 0, 0), Vector3(field_size.x, 0, 0), Vector3(0, 0, field_size.y), Vector3(field_size.x, 0, field_size.y)]:
		var s := world_to_screen(c)
		var n := (s / view_size) * 2.0 - Vector2.ONE
		if absf(n.x) > margin or absf(n.y) > margin:
			return false
	return true

func world_to_screen(w: Vector3) -> Vector2:
	var v := w - cam_pos
	var zc := v.dot(fwd)
	if zc <= 0.001:
		return Vector2(-100000.0, -100000.0)
	var aspect := view_size.x / view_size.y
	var nx := v.dot(right) / (zc * tan_half * aspect)
	var ny := v.dot(up) / (zc * tan_half)
	return Vector2((nx + 1.0) * 0.5 * view_size.x, (1.0 - ny) * 0.5 * view_size.y)

func field_to_screen(f: Vector2, lift: float = 0.0) -> Vector2:
	return world_to_screen(Vector3(f.x, height_at(f) + lift, f.y))

func screen_to_field(s: Vector2) -> Vector2:
	var aspect := view_size.x / view_size.y
	var nx := s.x / view_size.x * 2.0 - 1.0
	var ny := 1.0 - s.y / view_size.y * 2.0
	var d := (fwd + right * (nx * tan_half * aspect) + up * (ny * tan_half)).normalized()
	if d.y > -0.0001:
		d.y = -0.0001
	var h := 0.0
	var p := Vector3.ZERO
	for _i in range(5):
		var t := (h - cam_pos.y) / d.y
		p = cam_pos + d * t
		h = height_at(Vector2(p.x, p.z))
	return Vector2(p.x, p.z)

# Screen pixels per field unit around a field point (for sizing 2D marks).
func scale_at(f: Vector2) -> float:
	var a := field_to_screen(f)
	var b := field_to_screen(f + Vector2(10.0, 0.0))
	return a.distance_to(b) / 10.0

# ---- Terrain ---------------------------------------------------------------

func height_at(f: Vector2) -> float:
	var h := 0.0
	for hill in hills:
		var hx := float(hill.get("x", 0.0))
		var hy := float(hill.get("y", 0.0))
		var rx := maxf(float(hill.get("rx", 80.0)), 1.0)
		var ry := maxf(float(hill.get("ry", 70.0)), 1.0)
		var ang := float(hill.get("angle", 0.0))
		var dx := f.x - hx
		var dy := f.y - hy
		var lx := dx * cos(ang) + dy * sin(ang)
		var ly := -dx * sin(ang) + dy * cos(ang)
		var d2 := (lx * lx) / (rx * rx) + (ly * ly) / (ry * ry)
		if d2 < 1.0:
			var k := 1.0 - d2
			h += float(hill.get("height", 15.0)) * HILL_SCALE * k * k * (3.0 - 2.0 * k)
	return h

static func ground_color(t_key: String) -> Color:
	match t_key:
		"farmland": return Color(0.47, 0.52, 0.31)
		"plains": return Color(0.42, 0.50, 0.29)
		"hills": return Color(0.45, 0.43, 0.30)
		"mountains": return Color(0.40, 0.38, 0.35)
		"forest": return Color(0.30, 0.40, 0.25)
		"marsh": return Color(0.32, 0.38, 0.31)
		"desert": return Color(0.68, 0.58, 0.40)
		"steppe": return Color(0.53, 0.50, 0.32)
		_: return Color(0.42, 0.48, 0.30)

static func _dist_to_polyline(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

func _build_ground(state: Dictionary) -> void:
	var t_key := str(state.get("terrainKey", "plains"))
	var base := ground_color(t_key)
	var river_pts: Array = []
	for rp in state.get("riverPoints", []):
		if rp is Dictionary:
			river_pts.append(Vector2(float(rp.get("x", 0.0)), float(rp.get("y", 0.0))))
	var river_hw := float(state.get("riverHalfWidth", 26.0)) if bool(state.get("hasRiver", false)) else 0.0
	var fords: Array = state.get("fords", [])
	var forests: Array = state.get("forests", [])
	var pad := 160.0   # ground beyond the field edge, so the view has no hard border
	var nx := int((field_size.x + pad * 2.0) / GRID) + 1
	var nz := int((field_size.y + pad * 2.0) / GRID) + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(nx * nz)
	cols.resize(nx * nz)
	for j in range(nz):
		for i in range(nx):
			var f := Vector2(-pad + float(i) * GRID, -pad + float(j) * GRID)
			var h := height_at(f)
			var c := base
			# A soft noise so the ground is not flat paint (hills show by their light).
			var n := sin(f.x * 0.045) * cos(f.y * 0.037) + sin((f.x + f.y) * 0.11) * 0.5
			c = c.darkened(0.04 + 0.04 * n)
			for fo in forests:
				if fo is Dictionary:
					var dx := (f.x - float(fo.get("x", 0.0))) / maxf(float(fo.get("rx", 60.0)), 1.0)
					var dy := (f.y - float(fo.get("y", 0.0))) / maxf(float(fo.get("ry", 50.0)), 1.0)
					if dx * dx + dy * dy < 1.0:
						c = c.lerp(Color(0.20, 0.30, 0.16), 0.55)
			if river_hw > 0.0 and river_pts.size() >= 2:
				var d := _dist_to_polyline(f, river_pts)
				if d < river_hw:
					c = Color(0.20, 0.40, 0.56)
					h -= 3.0
				elif d < river_hw + 8.0:
					c = c.lerp(Color(0.44, 0.42, 0.30), 0.6)
				for fd in fords:
					if fd is Dictionary:
						var r := Rect2(float(fd.get("x", 0.0)), float(fd.get("y", 0.0)), float(fd.get("w", 40.0)), float(fd.get("h", 60.0)))
						if r.has_point(f):
							c = Color(0.58, 0.54, 0.40)
							h = maxf(h, -0.5)
			# Outside the battlefield: fade a little so the playing area reads clearly.
			if f.x < 0.0 or f.y < 0.0 or f.x > field_size.x or f.y > field_size.y:
				c = c.darkened(0.22)
			verts[j * nx + i] = Vector3(f.x, h, f.y)
			cols[j * nx + i] = c
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var k := 0
	for j in range(nz - 1):
		for i in range(nx - 1):
			var a := j * nx + i
			idx[k] = a
			idx[k + 1] = a + 1
			idx[k + 2] = a + nx
			idx[k + 3] = a + 1
			idx[k + 4] = a + nx + 1
			idx[k + 5] = a + nx
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	ground.mesh = st.commit()

# ---- Instances -------------------------------------------------------------

func _begin() -> void:
	for key in _batches:
		(_batches[key]["items"] as Array).clear()

func _add(mesh_name: String, origin: Vector3, yaw: float, color: Color = Color.WHITE, phase: float = 0.0, scale: Vector3 = Vector3.ONE, static_model: bool = false, tilt: float = 0.0) -> void:
	var key := ("s|" if static_model else "u|") + mesh_name
	if not _batches.has(key):
		var mesh := Lib.get_mesh(mesh_name)
		if mesh == null:
			return
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = static_mat if static_model else unit_mat
		node.custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(field_size.x + 800, 800, field_size.y + 800))
		world.add_child(node)
		_batches[key] = {"node": node, "items": []}
	var b: Dictionary = _batches[key]
	var basis := Basis(Vector3.UP, yaw)
	if tilt != 0.0:
		basis = basis * Basis(Vector3.RIGHT, tilt)
	basis = basis.scaled_local(scale)
	# MultiMesh buffer layout: 3x4 transform rows, colour, custom data.
	(b["items"] as Array).append(PackedFloat32Array([
		basis.x.x, basis.y.x, basis.z.x, origin.x,
		basis.x.y, basis.y.y, basis.z.y, origin.y,
		basis.x.z, basis.y.z, basis.z.z, origin.z,
		color.r, color.g, color.b, color.a,
		origin.x, origin.y, origin.z, phase]))

func _commit() -> void:
	for key in _batches:
		var b: Dictionary = _batches[key]
		var node: MultiMeshInstance3D = b["node"]
		var items: Array = b["items"]
		var n := items.size()
		var mm := node.multimesh
		if mm.instance_count != n:
			mm.instance_count = n
		if n > 0:
			var buf := PackedFloat32Array()
			for it in items:
				buf.append_array(it)
			mm.buffer = buf
		node.visible = n > 0

func count_of(mesh_name: String) -> int:
	var n := 0
	for pre in ["u|", "s|"]:
		if _batches.has(pre + mesh_name):
			n += (_batches[pre + mesh_name]["items"] as Array).size()
	return n

# ---- Battle state -> 3D ------------------------------------------------------

func sync_state(state: Dictionary, view: Vector2) -> void:
	if not bool(state.get("active", false)):
		return
	field_size = Vector2(maxf(100.0, float(state.get("fieldW", 1200.0))), maxf(100.0, float(state.get("fieldH", 800.0))))
	hills = state.get("hills", [])
	var sig := "%s|%s|%d|%d|%s|%d" % [field_size, state.get("terrainKey", ""), hills.size(), (state.get("forests", []) as Array).size(), state.get("hasRiver", false), (state.get("riverPoints", []) as Array).size()]
	if sig != _ground_sig:
		_ground_sig = sig
		_build_ground(state)
		_fit_size = Vector2.ZERO
	if not view.is_equal_approx(_fit_size):
		fit_camera(view)
	var site_style := Lib.style_name(int(state.get("siteStyle", 0)))
	var styles := [Lib.style_name(int(state.get("attackerStyle", 0))), Lib.style_name(int(state.get("defenderStyle", 0)))]
	_begin()
	_place_trees(state)
	_place_structures(state, site_style)
	if bool(state.get("isAssault", false)):
		_place_siege_camp(state)
	for u in state.get("units", []):
		if u is Dictionary and int(u.get("men", 0)) > 0:
			_place_unit(u, styles[clampi(int(u.get("side", 0)), 0, 1)], state)
	_commit()

func _place_trees(state: Dictionary) -> void:
	for fo in state.get("forests", []):
		if not (fo is Dictionary):
			continue
		var fx := float(fo.get("x", 0.0))
		var fy := float(fo.get("y", 0.0))
		var rx := float(fo.get("rx", 60.0))
		var ry := float(fo.get("ry", 50.0))
		var density := clampf(float(fo.get("density", 0.6)), 0.2, 1.0)
		var n := int(clampf(rx * ry / 260.0 * density, 6.0, 90.0))
		for k in range(n):
			var a := _hash01(int(fx), k) * TAU
			var r := sqrt(_hash01(int(fy), k + 99))
			var p := Vector2(fx + cos(a) * rx * r, fy + sin(a) * ry * r)
			var kind := "tree_pine" if _hash01(k, int(fx + fy)) < 0.5 else "tree_leaf"
			var s := 1.6 + _hash01(k + 7, int(fx)) * 1.2
			_add(kind, Vector3(p.x, height_at(p), p.y), a, Color.WHITE, 0.0, Vector3.ONE * s)

# Walls, towers, the gate and the keep, sized to the structure rectangles.
func _place_structures(state: Dictionary, st: String) -> void:
	for s in state.get("structures", []):
		if not (s is Dictionary):
			continue
		var kind := str(s.get("kind", "wall"))
		var c := Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0)))
		var w := float(s.get("w", 28.0))
		var h := float(s.get("h", 120.0))
		var origin := Vector3(c.x, height_at(c), c.y)
		var along_y := h > w
		var length := maxf(w, h)
		var thick := minf(w, h)
		var yaw := PI * 0.5 if along_y else 0.0
		if bool(s.get("breached", false)):
			_add("rubble." + st, origin, yaw, Color.WHITE, 0.0, Vector3(length, WALL_HEIGHT * 0.35, thick * 1.4), true)
			continue
		match kind:
			"tower":
				_add("tower." + st, origin, 0.0, Color.WHITE, 0.0, Vector3(thick * 1.25, WALL_HEIGHT * 0.85, thick * 1.25), true)
			"gate":
				_add("gate." + st, origin, yaw, Color.WHITE, 0.0, Vector3(length * 0.62, WALL_HEIGHT * 0.95, thick * 2.0), true)
			"keep":
				_add("keep." + st, origin, 0.0, Color.WHITE, 0.0, Vector3(w * 0.75, WALL_HEIGHT * 0.9, h * 0.75), true)
			_:
				_add("wall." + st, origin, yaw, Color.WHITE, 0.0, Vector3(length, WALL_HEIGHT, thick / 0.36), true)

# Trebuchets and a siege tower in the besiegers' camp (scenery only).
func _place_siege_camp(state: Dictionary) -> void:
	var zx := float(state.get("attDeployX", 50.0))
	var zy := float(state.get("attDeployY", 50.0))
	var zw := float(state.get("attDeployW", 350.0))
	var zh := float(state.get("attDeployH", 700.0))
	var spots := [Vector2(zx + zw * 0.25, zy + zh * 0.12), Vector2(zx + zw * 0.3, zy + zh * 0.88), Vector2(zx + zw * 0.12, zy + zh * 0.5)]
	var meshes := ["trebuchet", "trebuchet", "siege_tower"]
	for k in range(spots.size()):
		var p: Vector2 = spots[k]
		_add(meshes[k], Vector3(p.x, height_at(p), p.y), PI * 0.5, Color.WHITE, 0.0, Vector3.ONE * 2.4)

# One regiment: its soldiers laid out in its formation rectangle, with a
# standard, ladders or a ram if it carries them, guns for artillery.
func _place_unit(u: Dictionary, st: String, state: Dictionary) -> void:
	var idx := int(u.get("index", 0))
	var c := Vector2(float(u.get("x", 0.0)), float(u.get("y", 0.0)))
	var facing := float(u.get("facing", 0.0))
	var fwd2 := Vector2(cos(facing), sin(facing))
	var side2 := Vector2(-fwd2.y, fwd2.x)
	var depth := maxf(float(u.get("w", 24.0)), 6.0)
	var front := maxf(float(u.get("h", 44.0)), 6.0)
	var cat := str(u.get("category", "infantry"))
	var routing := bool(u.get("isRouting", false))
	var moving := bool(u.get("hasMoveOrder", false)) or not (u.get("waypoints", []) as Array).is_empty()
	var fighting := bool(u.get("inMelee", false))
	var on_wall := bool(u.get("isOnWall", false))
	var col := Color8(int(u.get("colorR", 180)), int(u.get("colorG", 120)), int(u.get("colorB", 80)))
	if routing:
		col = col.darkened(0.45)
	var yaw := atan2(fwd2.x, fwd2.y)
	if routing:
		yaw += PI
	var lift := WALL_HEIGHT * 0.95 if on_wall else 0.0
	var spacing := FIGURE_SPACING * (1.5 if cat == "cavalry" else 1.0)
	var body := "soldier_body"
	var gear := "soldier_gear." + st
	if cat == "cavalry":
		body = "rider_body"
		gear = "rider_gear." + st
	elif cat == "ranged":
		gear = "archer_gear." + st
	var men := int(u.get("men", 0))
	var figures := clampi(men / MEN_PER_FIGURE, 1, MAX_FIGURES)
	if cat == "artillery":
		figures = clampi(men / 300 + 1, 1, 6)
		spacing = FIGURE_SPACING * 2.2
	# Fill the regiment's rectangle: as many soldiers as fit (one per
	# MEN_PER_FIGURE men), at least `spacing * 0.55` apart.
	var min_cell := spacing * 0.55
	figures = mini(figures, maxi(1, int((front + min_cell) * (depth + min_cell) / (min_cell * min_cell))))
	var cell := sqrt(maxf(front * depth, 1.0) / float(figures))
	var nf := clampi(int(round(front / cell)), 1, figures)
	var nr := maxi(1, int(ceil(float(figures) / float(nf))))
	var step_f := front / float(nf) if nf > 1 else 0.0
	var step_r := depth / float(nr) if nr > 1 else 0.0
	for k in range(figures):
		var row := k / nf
		var colk := k % nf
		var lx := (float(row) - float(nr - 1) * 0.5) * -step_r      # ranks behind the front
		var ly := (float(colk) - float(nf - 1) * 0.5) * step_f
		var jit := Vector2(_hash01(idx, k) - 0.5, _hash01(k, idx + 5) - 0.5) * (spacing * (0.9 if routing else 0.15))
		var p := c + fwd2 * lx + side2 * ly + jit
		var origin := Vector3(p.x, height_at(p) + lift, p.y)
		var phase := (0.05 + 0.9 * _hash01(idx * 31, k)) if (moving or fighting or routing) else 0.0
		if cat == "artillery":
			_add("cannon", origin, yaw, Color.WHITE, 0.0, Vector3.ONE * 1.5)
			var crew := origin + Vector3(side2.x, 0.0, side2.y) * 7.0 - Vector3(fwd2.x, 0.0, fwd2.y) * 6.0
			_add("soldier_body", crew, yaw, col, phase)
			_add("soldier_gear." + st, crew, yaw, Color.WHITE, phase)
			continue
		_add(body, origin, yaw, col, phase)
		_add(gear, origin, yaw, Color.WHITE, phase)
		if str(u.get("siegeEquipment", "none")) == "ladders" and colk % 3 == 0 and row == 0:
			var lp := origin + Vector3(side2.x, 0, side2.y) * 4.0
			_add("ladder", lp, yaw + PI * 0.5, Color.WHITE, phase, Vector3.ONE * 0.9, false, -1.25)
	# Standard bearer at the front centre.
	var fp := c + fwd2 * (depth * 0.5 + 3.0)
	var forigin := Vector3(fp.x, height_at(fp) + lift, fp.y)
	_add("flag_pole", forigin, yaw, Color.WHITE, 0.0, Vector3.ONE * 1.3)
	_add("flag_cloth", forigin, yaw, col, 0.0, Vector3.ONE * 1.3)
	if str(u.get("siegeEquipment", "none")) == "ram":
		var rp := c + fwd2 * (depth * 0.5 + 9.0)
		_add("ram", Vector3(rp.x, height_at(rp), rp.y), yaw, Color.WHITE, 0.0, Vector3.ONE * 1.4)

static func _hash01(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xFFFF) / 65535.0
