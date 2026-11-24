extends RefCounted

# Phase 17 part 2: the 3D models on the campaign map.
const Lib := preload("res://scripts/ModelLibrary.gd")
const ModelsScript := preload("res://scripts/MapModels.gd")
const ProjScript := preload("res://scripts/MapProjector.gd")

var runner: Object

func test_library_has_every_model_in_every_style() -> void:
	runner.check(Lib.ensure_loaded(), "model library loads")
	for st in Lib.STYLES:
		for kind in ["house_a", "house_b", "temple", "landmark", "market", "fort1", "fort2", "fort3",
				"ship", "sail", "soldier_gear", "rider_gear", "wall", "tower", "gate", "keep", "rubble"]:
			var n: String = kind + "." + st
			var m := Lib.get_mesh(n)
			runner.check(m != null and m.get_surface_count() == 1, "mesh %s exists" % n)
	for n in ["pier", "flag_pole", "flag_cloth", "soldier_body", "rider_body", "trebuchet", "ram", "cannon", "siege_tower", "ladder"]:
		runner.check(Lib.has_mesh(n), "mesh %s exists" % n)

func test_models_stand_on_the_ground_and_have_sensible_sizes() -> void:
	for st in Lib.STYLES:
		var house := Lib.get_mesh("house_a." + st).get_aabb()
		runner.near(house.position.y, 0.0, 0.05, "house %s stands on y=0" % st)
		runner.check(maxf(house.size.x, house.size.z) > 0.6 and maxf(house.size.x, house.size.z) < 1.3, "house %s about one unit wide" % st)
		var castle := Lib.get_mesh("fort3." + st).get_aabb()
		runner.check(castle.size.y > house.size.y * 1.5, "castle %s taller than a house" % st)

func test_towns_grow_with_development() -> void:
	var prev := 0
	for dev in [1, 3, 5, 7, 10]:
		var parts: Array = ModelsScript.town_layout(17, dev, 0, false, "european")
		runner.check(parts.size() >= prev, "dev %d has at least as many buildings" % dev)
		prev = parts.size()
	var small: Array = ModelsScript.town_layout(3, 2, 0, false, "islamic")
	var big: Array = ModelsScript.town_layout(3, 9, 0, false, "islamic")
	runner.check(not _has(small, "temple.islamic") and not _has(small, "landmark.islamic"), "villages have no mosque")
	runner.check(_has(big, "landmark.islamic") and _has(big, "market.islamic"), "great cities have a great mosque and a market")
	runner.check(_has(ModelsScript.town_layout(3, 4, 0, false, "indian"), "temple.indian"), "temple from development 4")
	# Same town, same layout (no reshuffling between refreshes).
	runner.check(str(ModelsScript.town_layout(42, 6, 3, true, "eastasian")) == str(ModelsScript.town_layout(42, 6, 3, true, "eastasian")), "layout is deterministic")

func test_forts_by_level() -> void:
	runner.check(not _has_prefix(ModelsScript.town_layout(1, 5, 1, false, "european"), "fort"), "level 1: no fort model")
	runner.check(_has(ModelsScript.town_layout(1, 5, 2, false, "european"), "fort1.european"), "level 2: tower")
	runner.check(_has(ModelsScript.town_layout(1, 5, 3, false, "european"), "fort2.european"), "level 3: big tower")
	runner.check(_has(ModelsScript.town_layout(1, 5, 6, false, "steppe"), "fort3.steppe"), "level 4+: castle")

func test_army_figures() -> void:
	var small: Array = ModelsScript.army_formation(3000, "european", 0.0, 0.0)
	var big: Array = ModelsScript.army_formation(40000, "european", 0.0, 0.0)
	runner.check(big.size() > small.size(), "bigger armies show more soldiers")
	runner.check(_has(big, "soldier_gear.european") and _has(big, "flag_cloth"), "soldiers carry a standard")
	runner.check(_has(ModelsScript.army_formation(9000, "steppe", 0.0, 0.0), "rider_gear.steppe"), "steppe armies ride")
	var mo := {"moving": true, "nextX": 110.0, "nextY": 100.0, "frac": 0.5}
	runner.near2(ModelsScript.army_draw_point({"x": 100.0, "y": 100.0}, mo), Vector2(105, 100), 0.001, "marching army is half-way to the next stop")

func test_model_scale_and_town_detail_by_zoom() -> void:
	runner.check(ModelsScript.scale_for_zoom(0.7) > ModelsScript.scale_for_zoom(3.0), "models shrink in map units as you zoom in")
	runner.check(ModelsScript.scale_for_zoom(3.0) * 3.0 > ModelsScript.scale_for_zoom(0.7) * 0.7, "...but grow on screen")
	runner.check(ModelsScript.town_tier_for_zoom(0.4) == -1, "no towns on the whole-world view")
	runner.check(ModelsScript.town_tier_for_zoom(2.0) == 2, "every village when zoomed in")

func test_map_models_layer_builds_instances() -> void:
	var models: Node3D = ModelsScript.new()
	var proj: RefCounted = ProjScript.new()
	models.set("projector", proj)
	# Land everywhere except water on the right half.
	var img := Image.create(200, 100, false, Image.FORMAT_RG8)
	img.fill(Color(5.0 / 255.0, 0, 0))
	img.fill_rect(Rect2i(120, 0, 80, 100), Color(0, 0, 0))
	models.set("id_image", img)
	# Two towns: a port capital and an inland village.
	var metrics := PackedFloat32Array([100, 50, 8, 4, 1, 1, 40, 50, 2, 0, 0, 0])
	var data := PackedFloat32Array([0, 0.8, 0.1, 0.1, 1, 0.2, 0.6, 0.2])
	models.call("update_zoom", 2.0)
	models.call("set_towns", metrics, data)
	runner.check(int(models.call("mesh_instance_count", "town", "fort3.european")) == 1, "the capital has a castle")
	runner.check(int(models.call("mesh_instance_count", "town", "flag_cloth")) == 1, "the capital flies a flag")
	runner.check(int(models.call("mesh_instance_count", "town", "pier")) == 1, "the port has a pier")
	runner.check(int(models.call("mesh_instance_count", "town", "ship.european")) == 1, "the port has a ship")
	runner.check(int(models.call("mesh_instance_count", "town", "house_a.islamic")) + int(models.call("mesh_instance_count", "town", "house_b.islamic")) >= 1, "the village has houses in its own style")
	var cp: Variant = models.call("coast_point", Vector2(100, 50))
	runner.check(cp != null and (cp["dir"] as Vector2).x > 0.9, "coast found towards the sea")
	models.call("update_zoom", 0.3)
	runner.check(int(models.call("instance_count", "town")) == 0, "towns hidden on the world view")
	var counters := [{"armyId": 3, "x": 60.0, "y": 50.0, "men": 20000, "colorR": 200, "colorG": 30, "colorB": 30}]
	models.call("update_zoom", 2.0)
	models.call("set_armies", counters, {3: {"style": 4, "moving": true, "nextX": 70.0, "nextY": 50.0, "frac": 0.25}})
	runner.check(int(models.call("mesh_instance_count", "army", "rider_body")) >= 2, "steppe army shows riders")
	models.free()

func _has(parts: Array, mesh_name: String) -> bool:
	for p in parts:
		if p[0] == mesh_name:
			return true
	return false

func _has_prefix(parts: Array, prefix: String) -> bool:
	for p in parts:
		if String(p[0]).begins_with(prefix):
			return true
	return false

# Phase 20.6 part 4 -----------------------------------------------------------

func test_small_provinces_get_small_towns() -> void:
	var free: Array = ModelsScript.town_layout(5, 9, 4, false, "european")
	var cap := ModelsScript.town_radius_cap(120.0, 2)
	var tight: Array = ModelsScript.town_layout(5, 9, 4, false, "european", 2, cap)
	runner.check(tight.size() < free.size(), "a tiny province drops houses")
	runner.check(_has(tight, "landmark.european"), "...but keeps its great building")
	runner.check(_has_prefix(tight, "fort3"), "...and its castle")
	runner.check(not _has(tight, "market.european"), "...and leaves out the market")
	var big := ModelsScript.town_radius_cap(40000.0, 2)
	runner.check(str(ModelsScript.town_layout(5, 9, 4, false, "european", 2, big)) == str(free), "a big province is unchanged")
	runner.check(ModelsScript.town_layout(8, 1, 0, false, "steppe", 2, 0.2).size() >= 1, "every town keeps one building")

func test_cloth_may_move_and_buildings_do_not() -> void:
	var flag := Lib.get_mesh("flag_cloth").surface_get_arrays(0)
	var cols: PackedColorArray = flag[Mesh.ARRAY_COLOR]
	var verts: PackedVector3Array = flag[Mesh.ARRAY_VERTEX]
	var near_pole := 1.0
	var fly_end := 0.0
	for k in range(verts.size()):
		if verts[k].x < 0.05:
			near_pole = minf(near_pole, cols[k].a)
		if verts[k].x > 0.55:
			fly_end = maxf(fly_end, cols[k].a)
	runner.check(near_pole < 0.1 and fly_end > 0.9, "flag: fixed at the pole, free at the end")
	var house: PackedColorArray = Lib.get_mesh("house_a.european").surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var all_one := true
	for c in house:
		all_one = all_one and is_equal_approx(c.a, 1.0)
	runner.check(all_one, "buildings never move")
	var mm = ModelsScript.new()
	runner.check(mm.material_for("flag_cloth") != mm.material and mm.material_for("sail.islamic") != mm.material_for("sail.european"), "flags and sails get their own waving material")
	runner.check(mm.material_for("house_a.european") == mm.material, "houses keep the plain material")
	mm.free()

func test_town_reach_follows_the_province_shape() -> void:
	var img := Image.create(200, 200, false, Image.FORMAT_RG8)
	img.fill(Color(0, 0, 0))   # sea
	for y in range(90, 110):   # a thin strip of land, id 5
		for x in range(20, 180):
			img.set_pixel(x, y, Color(5.0 / 255.0, 0, 0))
	var mm = ModelsScript.new()
	mm.id_image = img
	var r: float = mm._town_reach(Vector2(100, 100))
	runner.check(r <= 20.0, "a thin coastal strip limits the town (%.0f px)" % r)
	runner.check(ModelsScript.town_reach_cap(r, 2) < ModelsScript.town_reach_cap(48.0, 2), "...to a smaller radius than open land")
	mm.free()
func test_battle_smoke_from_stance_and_ammo() -> void:
	var B3 := preload("res://scripts/BattleView3D.gd")
	var gun := {"men": 500, "ammo": 5, "stance": "volley", "category": "ranged", "key": "handgunners"}
	runner.check(B3.makes_smoke(gun), "handgunners shooting make smoke")
	var dry := gun.duplicate(); dry["ammo"] = 0
	runner.check(not B3.makes_smoke(dry), "no ammunition, no smoke")
	var quiet := gun.duplicate(); quiet["stance"] = "holdFire"
	runner.check(not B3.makes_smoke(quiet), "hold fire, no smoke")
	var bows := gun.duplicate(); bows["key"] = "archers"
	runner.check(not B3.makes_smoke(bows), "archers make no smoke")
	runner.check(B3.makes_smoke({"men": 300, "ammo": 10, "stance": "hold", "category": "artillery"}), "guns with shot make smoke")

func test_battle_figures_fill_the_rules_rectangle() -> void:
	var B3 := preload("res://scripts/BattleView3D.gd")
	var v = B3.new()
	var st: Dictionary = preload("res://scripts/BattleShowcase.gd").state()
	v.field_size = Vector2(1200, 800)
	v._begin()
	var u: Dictionary = st["units"][1]   # line infantry, 1,000 men
	v._place_unit(u, "european", st)
	var items: Array = v._batches["u|soldier_body"]["items"]
	var c := Vector2(float(u["x"]), float(u["y"]))
	var far := 0.0
	for it in items:
		far = maxf(far, absf(float(it[11]) - c.y))
	var half_front := float(u["h"]) * 0.5
	runner.check(items.size() >= 6 and items.size() <= 30, "a full regiment shows 6-30 soldiers (%d)" % items.size())
	runner.check(far <= half_front and far >= half_front * 0.5, "soldiers reach out to the regiment's ends, not past them")
	v.free()

# Phase 20.7: named landmarks (Hagia Sophia, the owner's pick B).
func test_named_landmark_replaces_the_great_building() -> void:
	runner.check(Lib.has_mesh("hagia_sophia"), "mesh hagia_sophia exists")
	var hs := Lib.get_mesh("hagia_sophia").get_aabb()
	runner.near(hs.position.y, 0.0, 0.05, "Hagia Sophia stands on y=0")
	runner.check(maxf(hs.size.x, hs.size.z) > 2.5 and maxf(hs.size.x, hs.size.z) < 3.4, "Hagia Sophia about 2.8 units wide")
	runner.check(hs.size.y > 1.8, "its minaret rises above the dome")
	for detail in [0, 1, 2]:
		var parts: Array = ModelsScript.town_layout(3, 12, 4, true, "islamic", detail, 99.0, "hagia_sophia")
		runner.check(_has(parts, "hagia_sophia") and not _has(parts, "landmark.islamic"), "landmark shown at detail %d" % detail)
		for p in parts:
			if p[0] != "hagia_sophia" and String(p[0]).begins_with("house"):
				runner.check((p[1] as Vector2).length() > 1.5, "houses stand clear of the landmark")
	var roomy: Array = ModelsScript.town_layout(3, 12, 4, true, "islamic", 2, 99.0, "hagia_sophia")
	for p in roomy:
		if String(p[0]).begins_with("fort"):
			runner.check((p[1] as Vector2).x >= 2.2, "castle stands clear of the landmark")
	var tight: Array = ModelsScript.town_layout(3, 12, 4, true, "islamic", 2, 2.5, "hagia_sophia")
	runner.check(not _has_prefix(tight, "fort") and _has(tight, "hagia_sophia"), "no room: landmark kept, castle left out")
	runner.check(ModelsScript.LANDMARKS.size() >= 1 and ModelsScript.LANDMARKS[0][0] == "hagia_sophia", "Hagia Sophia is in the landmark list")
