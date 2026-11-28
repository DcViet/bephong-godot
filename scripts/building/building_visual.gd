class_name BuildingVisual
extends Sprite2D
## Phần VẼ sprite của một công trình. Chỉ đọc BuildingBase (cha) và nghe tín hiệu của nó; không quyết định gì về gameplay.
## Gốc node cha = tâm hình thoi nền, nên ảnh luôn được đặt bằng `art.anchor` + `art.art_scale`.

const GHOST_OK := Color(0.6, 1.0, 0.65, 0.75)
const GHOST_BAD := Color(1.0, 0.45, 0.4, 0.75)
const BUILD_TINT := Color(1.0, 1.0, 1.0, 0.92)
const MIN_REVEAL_PX := 2.0

static var _masks: Dictionary = {}   # Texture2D -> Image (mặt nạ alpha để chọn theo điểm ảnh)

var _base: BuildingBase
var _t := 0.0


func _ready() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_base = get_parent() as BuildingBase
	if _base == null:
		return
	_base.state_changed.connect(func(_s: int) -> void: refresh())
	_base.level_changed.connect(func(_l: int) -> void: refresh())
	_base.rotation_changed.connect(func(_r: int) -> void: refresh())
	_base.progress_changed.connect(func(_p: float) -> void: _update_reveal())
	_base.selection_changed.connect(func(_s: bool) -> void: _update_tint())
	_base.placement_valid_changed.connect(func(_v: bool) -> void: _update_tint())
	refresh()


func _process(delta: float) -> void:
	_t += delta
	_update_tint()


func refresh() -> void:
	if _base == null or _base.def == null or _base.def.art == null:
		return
	var art := _base.def.art
	var tex := art.texture_for(_base.level, _base.rotation_steps)
	texture = tex
	flip_h = art.is_mirrored(_base.rotation_steps)
	scale = Vector2.ONE * art.art_scale
	_update_reveal()
	_update_tint()


## Đang xây: hiện dần ảnh từ dưới lên theo tiến độ. Các trạng thái khác hiện đủ.
func _update_reveal() -> void:
	if _base == null or _base.def == null or _base.def.art == null or texture == null:
		return
	var art := _base.def.art
	var ts := texture.get_size()
	var a := art.anchor
	if flip_h:
		a.x = ts.x - a.x
	if _base.state == BuildingBase.State.CONSTRUCTING:
		var h := maxf(MIN_REVEAL_PX, ts.y * _base.progress)
		region_enabled = true
		region_rect = Rect2(0.0, ts.y - h, ts.x, h)
		offset = Vector2(-a.x, -a.y + (ts.y - h))
	else:
		region_enabled = false
		offset = -a


func _update_tint() -> void:
	if _base == null:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var c := Color.WHITE
	match _base.state:
		BuildingBase.State.GHOST:
			c = GHOST_OK if _base.placement_valid else GHOST_BAD
		BuildingBase.State.CONSTRUCTING:
			c = BUILD_TINT
		BuildingBase.State.UPGRADING:
			c = Color(1.0, 1.0, 1.0).lerp(Color(1.25, 1.2, 0.95), pulse)
	if _base.selected and _base.state != BuildingBase.State.GHOST:
		c = c.lerp(Color(1.3, 1.3, 1.3, c.a), 0.25 + 0.2 * pulse)
	modulate = c
	set_process(_base.selected or _base.state == BuildingBase.State.UPGRADING)


## Điểm thế giới có trúng điểm ảnh đặc (alpha > 0.5) của sprite không. Dùng để chọn công trình bằng cách bấm.
func hit_test(world_pos: Vector2) -> bool:
	if texture == null or region_enabled:
		return false
	var ts := texture.get_size()
	var p := to_local(world_pos) - offset
	if flip_h:
		p.x = ts.x - p.x
	if p.x < 0.0 or p.y < 0.0 or p.x >= ts.x or p.y >= ts.y:
		return false
	var m := _mask_of(texture)
	if m == null:
		return true
	return m.get_pixel(int(p.x), int(p.y)).a > 0.5


static func _mask_of(tex: Texture2D) -> Image:
	if not _masks.has(tex):
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_masks[tex] = img
	return _masks[tex] as Image
