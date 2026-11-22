extends SceneTree

# Phase 20 part 2: renders one picture per building from our 3D models
# (tools/models/build_models.py --icons -> tools/models/icon_models.bin).
# The art script then frames them (ui_art_concept.py --buildings).
#   python3 tools/models/build_models.py --icons
#   xvfb-run godot --rendering-driver opengl3 --path godot --script res://tools/render_building_icons.gd
# Env: GEZ_ICON_MODELS (the .bin), GEZ_ICON_OUT (folder for raw PNGs).

const ModelLib := preload("res://scripts/ModelLibrary.gd")
const SIZE := 256

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var src := OS.get_environment("GEZ_ICON_MODELS")
	var out := OS.get_environment("GEZ_ICON_OUT")
	if src.is_empty() or out.is_empty():
		push_error("set GEZ_ICON_MODELS and GEZ_ICON_OUT")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var meshes: Dictionary = ModelLib.read_library(src)
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.80, 0.72)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.85
	mi.material_override = mat
	vp.add_child(mi)
	var names := meshes.keys()
	names.sort()
	for n in names:
		var mesh: ArrayMesh = meshes[n]
		mi.mesh = mesh
		var aabb := mesh.get_aabb()
		var c := aabb.get_center()
		# three-quarter view from the front-right, a little from above
		var dir := Vector3(0.85, 0.75, 1.0).normalized()
		cam.position = c + dir * 10.0
		cam.look_at(c, Vector3.UP)
		cam.size = aabb.size.length() * 0.95
		for _i in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(out.path_join("%s.png" % n))
		print("icon: " + n)
	quit(0)
