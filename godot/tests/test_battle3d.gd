extends RefCounted

# Phase 17 part 3: the 3D battle view (picture only; the rules are Phase 9's).
const B3D := preload("res://scripts/BattleView3D.gd")

var runner: Object

func _state(assault: bool) -> Dictionary:
	var units := []
	var cats := ["infantry", "ranged", "cavalry", "artillery", "infantry"]
	for i in range(5):
		units.append({"index": i, "side": 0 if i < 4 else 1, "category": cats[i], "men": 1200 + i * 400,
			"x": 300.0 + i * 20.0, "y": 150.0 + i * 120.0, "w": 24.0, "h": 60.0, "facing": 0.0,
			"hasMoveOrder": i == 0, "waypoints": [], "isRouting": false, "isOnWall": false, "inMelee": false,
			"siegeEquipment": "ram" if (assault and i == 0) else ("ladders" if (assault and i == 4) else "none"),
			"colorR": 200, "colorG": 40, "colorB": 40})
	var s := {"active": true, "fieldW": 1200.0, "fieldH": 800.0, "terrainKey": "hills", "isAssault": assault,
		"attackerStyle": 1, "defenderStyle": 3, "siteStyle": 2,
		"attDeployX": 50.0, "attDeployY": 50.0, "attDeployW": 350.0, "attDeployH": 700.0,
		"hills": [{"x": 600.0, "y": 400.0, "rx": 150.0, "ry": 100.0, "height": 20.0, "angle": 0.3}],
		"forests": [{"x": 200.0, "y": 650.0, "rx": 80.0, "ry": 60.0, "density": 0.7}],
		"hasRiver": false, "units": units, "structures": []}
	if assault:
		s["structures"] = [
			{"kind": "wall", "x": 760.0, "y": 196.0, "w": 28.0, "h": 192.0, "breached": false},
			{"kind": "tower", "x": 760.0, "y": 312.0, "w": 42.0, "h": 42.0, "breached": false},
			{"kind": "gate", "x": 760.0, "y": 400.0, "w": 32.0, "h": 132.0, "breached": false},
			{"kind": "wall", "x": 760.0, "y": 604.0, "w": 28.0, "h": 192.0, "breached": true},
			{"kind": "keep", "x": 1050.0, "y": 400.0, "w": 150.0, "h": 220.0, "breached": false}]
	return s

func test_camera_shows_the_whole_field_and_round_trips() -> void:
	var v: SubViewportContainer = B3D.new()
	v.call("sync_state", _state(false), Vector2(1440, 700))
	for c in [Vector2(0, 0), Vector2(1200, 0), Vector2(0, 800), Vector2(1200, 800)]:
		var s: Vector2 = v.call("field_to_screen", c)
		runner.check(s.x >= 0.0 and s.x <= 1440.0 and s.y >= 0.0 and s.y <= 700.0, "field corner %s on screen (%s)" % [c, s])
	for f in [Vector2(600, 400), Vector2(100, 700), Vector2(1100, 120), Vector2(640, 380)]:
		runner.near2(v.call("screen_to_field", v.call("field_to_screen", f)), f, 0.5, "screen <-> field round trip %s" % f)
	# Tilted from the south: the far edge looks narrower than the near one.
	var far_w: float = (v.call("field_to_screen", Vector2(1200, 0)) as Vector2).x - (v.call("field_to_screen", Vector2(0, 0)) as Vector2).x
	var near_w: float = (v.call("field_to_screen", Vector2(1200, 800)) as Vector2).x - (v.call("field_to_screen", Vector2(0, 800)) as Vector2).x
	runner.check(far_w < near_w, "perspective: far edge narrower")
	v.free()

func test_hills_raise_the_ground() -> void:
	var v: SubViewportContainer = B3D.new()
	v.call("sync_state", _state(false), Vector2(1200, 700))
	runner.check(float(v.call("height_at", Vector2(600, 400))) > 20.0, "hill top is high")
	runner.near(float(v.call("height_at", Vector2(100, 100))), 0.0, 0.001, "open ground is flat")
	v.free()

func test_regiments_become_soldiers() -> void:
	var v: SubViewportContainer = B3D.new()
	v.call("sync_state", _state(false), Vector2(1200, 700))
	runner.check(int(v.call("count_of", "soldier_body")) > 10, "infantry shows soldiers")
	runner.check(int(v.call("count_of", "archer_gear.islamic")) > 0, "ranged regiment in the attacker's style")
	runner.check(int(v.call("count_of", "rider_gear.islamic")) > 0, "cavalry rides")
	runner.check(int(v.call("count_of", "cannon")) > 0, "artillery has guns")
	runner.check(int(v.call("count_of", "soldier_gear.eastasian")) > 0, "defender in its own style")
	runner.check(int(v.call("count_of", "flag_cloth")) == 5, "one standard per regiment")
	runner.check(int(v.call("count_of", "tree_pine")) + int(v.call("count_of", "tree_leaf")) > 5, "woods have trees")
	v.free()

func test_assault_has_walls_and_siege_engines() -> void:
	var v: SubViewportContainer = B3D.new()
	v.call("sync_state", _state(true), Vector2(1200, 700))
	runner.check(int(v.call("count_of", "wall.indian")) == 1, "standing wall in the site's style")
	runner.check(int(v.call("count_of", "rubble.indian")) == 1, "breached wall is rubble")
	runner.check(int(v.call("count_of", "gate.indian")) == 1 and int(v.call("count_of", "keep.indian")) == 1, "gate and keep")
	runner.check(int(v.call("count_of", "tower.indian")) == 1, "tower")
	runner.check(int(v.call("count_of", "ram")) == 1, "the ram regiment pushes a ram")
	runner.check(int(v.call("count_of", "ladder")) >= 1, "the ladder regiment carries ladders")
	runner.check(int(v.call("count_of", "trebuchet")) >= 1 and int(v.call("count_of", "siege_tower")) == 1, "siege camp")
	v.free()
