extends SceneTree

# Headless GDScript tests for the Godot side (Phase 17 onwards). They need no
# Swift extension, so CI runs them right after the Linux export:
#   godot --headless --path godot --script res://tests/run_tests.gd
# Exit code 1 if anything fails.

const ProjScript := preload("res://scripts/MapProjector.gd")

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	var suites: Array = [
		preload("res://tests/test_map_projector.gd"),
	]
	for extra in ["res://tests/test_map_models.gd", "res://tests/test_battle3d.gd", "res://tests/test_style_kit.gd", "res://tests/test_map_labels.gd", "res://tests/test_map_edges.gd"]:
		if ResourceLoader.exists(extra):
			suites.append(load(extra))
	for suite_script in suites:
		var suite: RefCounted = suite_script.new()
		suite.set("runner", self)
		for m in suite.get_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_"):
				suite.call(mname)
	print("GDScript tests: %d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)

func near(a: float, b: float, tol: float, what: String) -> void:
	check(absf(a - b) <= tol, "%s (got %f, want %f ± %f)" % [what, a, b, tol])

func near2(a: Vector2, b: Vector2, tol: float, what: String) -> void:
	check(a.distance_to(b) <= tol, "%s (got %s, want %s ± %f)" % [what, a, b, tol])
