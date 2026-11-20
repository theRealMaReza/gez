extends RefCounted

# Phase 17: the 3D model library (towns, forts, ships, soldiers, siege
# engines), built by tools/models/build_models.py from the free KayKit kits
# plus models made in code. One gzip file, loaded once; meshes are shared by
# the map and the battle view.

const LIB_PATH := "res://assets/models/models.bin"
const STYLES := ["european", "islamic", "indian", "eastasian", "steppe"]

static var _meshes: Dictionary = {}
static var _loaded: bool = false

static func style_name(code: int) -> String:
	return STYLES[clampi(code, 0, STYLES.size() - 1)]

static func ensure_loaded() -> bool:
	if _loaded:
		return not _meshes.is_empty()
	_loaded = true
	var packed := FileAccess.get_file_as_bytes(LIB_PATH)
	if packed.size() < 8 or packed.slice(0, 4).get_string_from_ascii() != "GZMZ":
		push_error("ModelLibrary: missing or bad " + LIB_PATH)
		return false
	var raw_size := packed.decode_u32(4)
	var raw := packed.slice(8).decompress(raw_size, FileAccess.COMPRESSION_GZIP)
	if raw.size() != raw_size:
		push_error("ModelLibrary: could not unpack " + LIB_PATH)
		return false
	var pos := 8
	var count := raw.decode_u32(4)
	for _i in range(count):
		var name_len := raw.decode_u16(pos)
		pos += 2
		var mesh_name := raw.slice(pos, pos + name_len).get_string_from_utf8()
		pos += name_len
		var nv := raw.decode_u32(pos)
		var ni := raw.decode_u32(pos + 4)
		pos += 8
		var verts := raw.slice(pos, pos + nv * 12).to_vector3_array()
		pos += nv * 12
		var normals := raw.slice(pos, pos + nv * 12).to_vector3_array()
		pos += nv * 12
		var colors := raw.slice(pos, pos + nv * 16).to_color_array()
		pos += nv * 16
		var indices := raw.slice(pos, pos + ni * 4).to_int32_array()
		pos += ni * 4
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes[mesh_name] = mesh
	return true

static func get_mesh(mesh_name: String) -> ArrayMesh:
	ensure_loaded()
	return _meshes.get(mesh_name, null)

static func has_mesh(mesh_name: String) -> bool:
	ensure_loaded()
	return _meshes.has(mesh_name)

static func mesh_names() -> Array:
	ensure_loaded()
	var out := _meshes.keys()
	out.sort()
	return out

# Height of a mesh (model units), for stacking flags and labels.
static func mesh_height(mesh_name: String) -> float:
	var m := get_mesh(mesh_name)
	return m.get_aabb().end.y if m != null else 0.0
