extends SceneTree

# Phase 20.7: times the map shader on this computer, before and after the
# smooth-border rewrite, on the same camera views. For the owner's M1:
#   cd ~/Developer/Gez && ./godot/build_mac.sh
#   /Applications/Godot.app/Contents/MacOS/Godot --path godot --script res://tools/profile_map.gd
# Prints GPU milliseconds per frame for each view and writes the table to
# godot/profile_map.txt. Close other apps first; keep the window on screen.

const BEFORE := "res://tools/profile/map3d_before.gdshader"
const AFTER := "res://shaders/map3d.gdshader"
const FRAMES := 120
# [name, latitude, longitude, look zoom (0 = whole map)]
const VIEWS := [
	["whole map (chart)", 0.0, 0.0, 0.0],
	["Mediterranean (chart)", 38.0, 22.0, 0.55],
	["Europe (political)", 47.0, 12.0, 1.2],
	["Italy close", 43.0, 11.0, 3.0],
	["Bosporus, tilted", 41.0, 29.0, 6.5],
]

var main_scene: PackedScene = load("res://scenes/Main.tscn")
var root_node: Control
var lines: PackedStringArray = []

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root_node = main_scene.instantiate()
	root_node.set("show_main_menu_at_start", false)
	root.add_child(root_node)
	call_deferred("_run")

func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func _run() -> void:
	await _frames(6)
	for _i in range(300):
		if root_node.get("bridge") != null and root_node.get("title_screens") != null and not root_node.get("title_screens").visible:
			break
		await process_frame
	var bridge = root_node.get("bridge")
	var mat: ShaderMaterial = root_node.get("map_material")
	if bridge == null or mat == null:
		push_error("profile_map: the game did not load (run ./build_mac.sh first)")
		quit(1)
		return
	bridge.call("setSpeed", 0)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var shaders := {"before": load(BEFORE), "after": load(AFTER)}
	var results := {}
	for which in ["before", "after"]:
		mat.shader = shaders[which]
		await _frames(30)   # let the shader compile
		for v in VIEWS:
			if float(v[3]) <= 0.0:
				root_node.call("_reset_to_start_camera")
				root_node.call("focus_map_point", root_node.get("map_size") * 0.5, root_node.call("_fit_zoom"))
			else:
				var pt: Vector2 = bridge.call("getFocusPoint", float(v[1]), float(v[2]))
				root_node.call("focus_map_point", pt, float(v[3]) / MapScale.k)
			await _frames(20)
			var gpu := 0.0
			var cpu := 0.0
			for _i in range(FRAMES):
				await process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			results["%s|%s" % [which, v[0]]] = [gpu / FRAMES, cpu / FRAMES]
	lines.append("Map shader GPU time per frame (ms), 1440x900, %s" % RenderingServer.get_video_adapter_name())
	lines.append("%-24s %10s %10s %8s" % ["view", "before", "after", "change"])
	for v in VIEWS:
		var b: float = results["before|" + v[0]][0]
		var a: float = results["after|" + v[0]][0]
		var pct := (a - b) / maxf(b, 0.001) * 100.0
		lines.append("%-24s %10.2f %10.2f %+7.0f%%" % [v[0], b, a, pct])
	var text := "\n".join(lines)
	print(text)
	var f := FileAccess.open("res://profile_map.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	quit(0)
