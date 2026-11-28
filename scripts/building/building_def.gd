class_name BuildingDef
extends Resource
## Dữ liệu GAMEPLAY của một loại công trình: kích thước nền, chi phí, thời gian, cấp, chỉ số.
## Không chứa ảnh (xem BuildingArt) và không chứa logic (xem BuildingBase).
## Tiền: nghìn đô la ($k). Thời gian: đơn vị tuỳ trò chơi (giây trong sandbox, ngày trong game chính).

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
## Nhóm hiển thị: launch, operations, logistics, industry, defense, vehicle, space.
@export var category: StringName = &"operations"
## Khoá công trình tương ứng trong game hiện tại (ctrl, pad, shop, wx, fuel, asm); trống nếu chưa có.
@export var game_link: StringName = &""
## Kích thước nền (số ô) ở hướng gốc; hướng quay lẻ sẽ đổi chỗ x và y.
@export var footprint := Vector2i(2, 2)
@export var rotatable := true
@export var art: BuildingArt
@export var max_level := 1
@export var build_cost := 0
@export var build_time := 10.0
## Chi phí / thời gian nâng từ cấp i lên cấp i+1 (chỉ số 0 = cấp 1 → 2).
@export var upgrade_costs := PackedInt32Array()
@export var upgrade_times := PackedFloat32Array()
## Chỉ số theo cấp (chỉ số 0 = cấp 1), từ điển tự do: {"fuel_discount": 0.08, …}.
@export var level_stats: Array[Dictionary] = []
## Tỉ lệ hoàn lại (theo chi phí xây) khi phá bỏ.
@export var demolish_refund := 0.5


static func scene_path_for(def_id: StringName) -> String:
	return "res://scenes/buildings/%s.tscn" % def_id


func scene_path() -> String:
	return scene_path_for(id)


## Kích thước nền sau khi quay `steps` bước 90°.
func footprint_for(rotation_steps: int) -> Vector2i:
	if posmod(rotation_steps, 2) == 1:
		return Vector2i(footprint.y, footprint.x)
	return footprint


## Chi phí nâng từ `level` lên cấp kế tiếp; −1 nếu đã hết cấp.
func upgrade_cost(level: int) -> int:
	if level < 1 or level >= max_level or level - 1 >= upgrade_costs.size():
		return -1
	return upgrade_costs[level - 1]


func upgrade_time(level: int) -> float:
	if level < 1 or level >= max_level or level - 1 >= upgrade_times.size():
		return 0.0
	return upgrade_times[level - 1]


func stat(level: int, key: String, default_value: Variant = 0.0) -> Variant:
	if level_stats.is_empty():
		return default_value
	var i := clampi(level - 1, 0, level_stats.size() - 1)
	return level_stats[i].get(key, default_value)
