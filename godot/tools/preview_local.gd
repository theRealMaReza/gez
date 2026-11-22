extends SceneTree
# Local look check without the Swift extension: opens the main screen and
# a few windows with empty data. Saves preview_*.png into $GEZ_GODOT_SNAPSHOT_DIR.
var main_node: Control
func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	main_node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main_node)
	call_deferred("_run")
func _shot(n: String) -> void:
	for _i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("GEZ_GODOT_SNAPSHOT_DIR")
	if out.is_empty():
		out = "/tmp"
	root.get_viewport().get_texture().get_image().save_png(out.path_join(n))
	print("snapshot: " + n)
func _run() -> void:
	await _shot("preview_main.png")
	var which := OS.get_environment("GEZ_PREVIEW").split(",", false)
	for w in which:
		main_node.call(w)
		await _shot("preview_%s.png" % w.trim_prefix("_toggle_").trim_suffix("_window"))
		main_node.call(w)
	quit(0)
