class_name BuildingCatalog
extends RefCounted
## Danh mục loại công trình: quét res://data/buildings/*.tres. Thêm công trình = thêm file .tres + scene, không sửa mã.

const DIR := "res://data/buildings"

static var _defs: Dictionary = {}    # StringName -> BuildingDef
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for f in DirAccess.get_files_at(DIR):
		# Bản xuất (export) đổi tên file thành *.tres.remap.
		var name := f.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var d := load("%s/%s" % [DIR, name]) as BuildingDef
		if d != null:
			_defs[d.id] = d


static func reload() -> void:
	_defs.clear()
	_loaded = false
	_ensure()


static func get_def(id: StringName) -> BuildingDef:
	_ensure()
	return _defs.get(id) as BuildingDef


## Mọi định nghĩa, xếp theo nhóm rồi theo tên.
static func all() -> Array[BuildingDef]:
	_ensure()
	var out: Array[BuildingDef] = []
	for k in _defs:
		out.append(_defs[k])
	out.sort_custom(func(a: BuildingDef, b: BuildingDef) -> bool:
		if a.category != b.category:
			return String(a.category) < String(b.category)
		return a.display_name < b.display_name)
	return out
