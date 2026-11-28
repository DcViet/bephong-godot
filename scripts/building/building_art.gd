class_name BuildingArt
extends Resource
## Phần HÌNH ẢNH của một công trình, tách hẳn khỏi dữ liệu gameplay (BuildingDef).
## Đổi ảnh = đổi một file .tres này; logic xây dựng không đụng tới.

## Ảnh mặc định (cấp 1, hướng gốc).
@export var texture: Texture2D
## Ảnh riêng theo cấp (chỉ số 0 = cấp 1). Trống hoặc thiếu phần tử → dùng `texture`.
@export var level_textures: Array[Texture2D] = []
## Ảnh riêng cho 4 hướng quay (chỉ số = số bước quay). Trống → lật ngang ảnh gốc ở hướng lẻ.
@export var rotation_textures: Array[Texture2D] = []
## Tỉ lệ vẽ so với ảnh gốc (ảnh gốc ~300–400 px, ô iso chỉ rộng 96 px).
@export var art_scale := 1.0
## Điểm ảnh (trong ảnh gốc) nằm đúng TÂM hình thoi nền của công trình. Đây là mốc đặt duy nhất.
@export var anchor := Vector2.ZERO
## Khi chưa có ảnh riêng cho hướng quay lẻ: lật ngang ảnh để có thêm một góc nhìn.
@export var mirror_on_odd_rotation := true


func texture_for(level: int, rotation_steps: int) -> Texture2D:
	if rotation_textures.size() == 4 and rotation_textures[posmod(rotation_steps, 4)] != null:
		return rotation_textures[posmod(rotation_steps, 4)]
	var i := level - 1
	if i >= 0 and i < level_textures.size() and level_textures[i] != null:
		return level_textures[i]
	return texture


func is_mirrored(rotation_steps: int) -> bool:
	if rotation_textures.size() == 4 and rotation_textures[posmod(rotation_steps, 4)] != null:
		return false
	return mirror_on_odd_rotation and posmod(rotation_steps, 2) == 1
