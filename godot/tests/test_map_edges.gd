extends RefCounted

# Phase 20.7: the baked border field (App/Resources/Terrain/edges.png, from
# tools/terrain/bake_terrain.py) must match today's province map. If a map
# change forgets to re-bake it, new provinces would show no borders.
const IDMAP := "res://../Packages/GezCore/Sources/GezCore/Resources/provinces1453.idmap"
const EDGES := "res://../App/Resources/Terrain/edges.png"
const EDGE_DMAX := 160.0   # as in edge_field.py and map3d.gdshader

var runner: Object

func _decode(v: float) -> float:
	return EDGE_DMAX * v * v

func test_edge_field_matches_province_map() -> void:
	var raw := FileAccess.get_file_as_bytes(IDMAP)
	runner.check(raw.size() > 16, "province id map found")
	if raw.size() <= 16:
		return
	var w := raw.decode_u32(4)
	var h := raw.decode_u32(8)
	var img := Image.load_from_file(ProjectSettings.globalize_path(EDGES))
	runner.check(img != null and img.get_width() == w and img.get_height() == h,
		"edges.png exists and is the map's size (%dx%d): run tools/terrain/bake_terrain.py" % [w, h])
	if img == null or img.get_width() != w or img.get_height() != h:
		return
	# Every place where the id changes along a row (a run boundary of the
	# run-length map) is an edge: both pixels there must be near it.
	var pos := 0
	var prev := -1
	var checked := 0
	var bad := 0
	var off := 16
	var k := 0
	while off + 4 <= raw.size():
		var val := raw.decode_u16(off)
		var cnt := raw.decode_u16(off + 2)
		off += 4
		var x := pos % w
		if prev >= 0 and val != prev and x > 0:
			k += 1
			if k % 37 == 0:
				var y := pos / w
				checked += 1
				var a := _decode(img.get_pixel(x - 1, y).r)
				var b := _decode(img.get_pixel(x, y).r)
				if a > 1.6 or b > 1.6:
					bad += 1
		prev = val
		pos += cnt
	runner.check(pos == w * h, "id map runs cover the map")
	runner.check(checked > 1000, "enough province edges sampled (%d)" % checked)
	runner.check(bad <= checked / 200, "edges.png is up to date with the province map (%d of %d edge pixels far from an edge): run tools/terrain/bake_terrain.py --edges-only" % [bad, checked])
