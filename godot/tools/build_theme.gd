extends SceneTree

# Saves the shared Theme (GezTheme.build()) to res://assets/ui/gez_theme.tres.
# Run after changing GezTheme.gd or the art in assets/ui:
#   godot --headless --path godot --import
#   godot --headless --path godot --script res://tools/build_theme.gd

func _initialize() -> void:
	var theme: Theme = GezTheme.build()
	var err := ResourceSaver.save(theme, "res://assets/ui/gez_theme.tres")
	if err != OK:
		push_error("Could not save gez_theme.tres (error %d)" % err)
		quit(1)
		return
	print("Saved res://assets/ui/gez_theme.tres")
	quit(0)
