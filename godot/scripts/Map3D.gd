extends Node3D

# Phase 17 part 1: the 3D campaign map.
# One terrain mesh (a flat grid lifted by the height map in the vertex
# shader) painted by shaders/map3d.gdshader, a perspective camera driven by
# MapProjector, light for the 3D models, and a background in the deep-sea
# colour. The 2D overlay layers (labels, counters, routes) stay on top.

const Map3DShader := preload("res://shaders/map3d.gdshader")
const SEA_COLOR := Color(0.16, 0.25, 0.33)

# Grid cells: ~6 map pixels each on a 3936 x 2384 map (about 250k vertices).
const GRID_CELL_PX := 6.0

var terrain_material: ShaderMaterial
var terrain: MeshInstance3D
var camera: Camera3D
var sun: DirectionalLight3D
var env: WorldEnvironment
var map_size: Vector2 = Vector2(3936.0, 2384.0)

func _init() -> void:
	name = "Map3D"
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = Map3DShader

	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = SEA_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.76, 0.72)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	# From the north-west and high, like the baked hill shading.
	sun.rotation_degrees = Vector3(-52.0, -135.0, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	add_child(sun)

	camera = Camera3D.new()
	camera.name = "MapCamera"
	camera.fov = 30.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	add_child(camera)

	terrain = MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.material_override = terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain.extra_cull_margin = 64.0
	add_child(terrain)
	set_map_size(map_size)

func set_map_size(s: Vector2) -> void:
	map_size = s
	var plane := PlaneMesh.new()
	plane.size = s
	plane.subdivide_width = maxi(1, int(s.x / GRID_CELL_PX))
	plane.subdivide_depth = maxi(1, int(s.y / GRID_CELL_PX))
	plane.center_offset = Vector3(s.x * 0.5, 0.0, s.y * 0.5)
	terrain.mesh = plane
	terrain_material.set_shader_parameter("map_size", s)

func set_height_texture(tex: Texture2D) -> void:
	terrain_material.set_shader_parameter("height_tex", tex)

# Copy the projector's camera into the real Camera3D.
func apply_projector(p: RefCounted) -> void:
	camera.global_transform = p.call("camera_transform")
	var nf: Vector2 = p.call("near_far")
	camera.near = nf.x
	camera.far = nf.y
	var pitch: float = float(p.get("pitch_deg"))
	# Relief light fades in as the camera tilts.
	var tilt := clampf((90.0 - pitch) / 30.0, 0.0, 1.0)
	terrain_material.set_shader_parameter("relief_light", 0.45 * tilt)
