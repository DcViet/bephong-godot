class_name BuildGrid
extends RefCounted
## Bảng chiếm chỗ của lưới xây dựng: ô nào được phép xây, ô nào bị chặn, ô nào đã có công trình.
## Không biết gì về hình ảnh; trò chơi tự đặt vùng được phép xây (ví dụ vùng cỏ đã dọn) bằng set_buildable().

enum Reason { OK, OUT_OF_AREA, BLOCKED, OCCUPIED }

var size: Vector2i
var buildable: Rect2i                  # vùng được phép xây (mặc định cả lưới)
var _blocked: Dictionary = {}          # Vector2i -> true (đá, nước, …)
var _occupants: Dictionary = {}        # Vector2i -> BuildingBase


func _init(grid_size: Vector2i = Vector2i(16, 16)) -> void:
	size = grid_size
	buildable = Rect2i(Vector2i.ZERO, grid_size)


func set_buildable(r: Rect2i) -> void:
	buildable = r.intersection(Rect2i(Vector2i.ZERO, size))


func block_cell(c: Vector2i) -> void:
	_blocked[c] = true


func block_rect(r: Rect2i) -> void:
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			_blocked[Vector2i(x, y)] = true


func clear_blocked() -> void:
	_blocked.clear()


func is_blocked(c: Vector2i) -> bool:
	return _blocked.has(c)


## Kiểm tra một hình chữ nhật ô có đặt được không. `ignore` là công trình đang xét (không tự cản chính nó).
func check(rect: Rect2i, ignore: Object = null) -> Reason:
	if not buildable.encloses(rect):
		return Reason.OUT_OF_AREA
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var c := Vector2i(x, y)
			if _blocked.has(c):
				return Reason.BLOCKED
			var o: Object = _occupants.get(c)
			if o != null and o != ignore:
				return Reason.OCCUPIED
	return Reason.OK


static func reason_text(r: Reason) -> String:
	match r:
		Reason.OUT_OF_AREA:
			return "Ngoài vùng được phép xây"
		Reason.BLOCKED:
			return "Vướng chướng ngại vật"
		Reason.OCCUPIED:
			return "Đã có công trình ở đây"
	return ""


func occupy(b: BuildingBase) -> void:
	var r := b.footprint_rect()
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			_occupants[Vector2i(x, y)] = b


func release(b: BuildingBase) -> void:
	var gone: Array = []
	for c in _occupants:
		if _occupants[c] == b:
			gone.append(c)
	for c in gone:
		_occupants.erase(c)


func building_at(c: Vector2i) -> BuildingBase:
	return _occupants.get(c) as BuildingBase


func buildings() -> Array[BuildingBase]:
	var out: Array[BuildingBase] = []
	for c in _occupants:
		var b: BuildingBase = _occupants[c]
		if not out.has(b):
			out.append(b)
	return out
