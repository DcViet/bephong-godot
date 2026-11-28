class_name BuildingBase
extends Node2D
## Logic dùng lại cho MỌI công trình: vị trí trên lưới iso, hướng quay, cấp, vòng đời xây/nâng cấp, chọn.
## Không có một dòng nào về hình ảnh: node con "Visual" (BuildingVisual) và "Ground"/"Hud" (BuildingOverlay)
## tự nghe các tín hiệu bên dưới để vẽ. Muốn công trình có hành vi riêng thì kế thừa lớp này
## và ghi đè các hàm `_on_*`.
##
## Quy ước vị trí: GỐC NODE = tâm hình thoi nền (xem IsoGrid). `cell` là ô góc trên của nền.

signal state_changed(state: int)
signal progress_changed(progress: float)
signal level_changed(level: int)
signal rotation_changed(steps: int)
signal cell_changed(cell: Vector2i)
signal selection_changed(selected: bool)
signal placement_valid_changed(valid: bool)
signal construction_finished
signal upgrade_finished(new_level: int)

## GHOST: bản xem trước khi đang chọn chỗ. CONSTRUCTING: đang xây. READY: hoạt động. UPGRADING: đang nâng cấp.
enum State { GHOST, CONSTRUCTING, READY, UPGRADING }

const GHOST_Z := 1000

@export var def: BuildingDef
## Tự chạy thời gian xây/nâng cấp theo _process. Tắt khi trò chơi tự gọi tick() (vd. theo ngày).
@export var auto_tick := true

var cell := Vector2i.ZERO
var rotation_steps := 0
var level := 1
var state: State = State.GHOST
var progress := 0.0
var selected := false
var placement_valid := true

var _time_total := 0.0
var _time_left := 0.0


func _ready() -> void:
	_apply_position()


func _process(delta: float) -> void:
	if auto_tick and (state == State.CONSTRUCTING or state == State.UPGRADING):
		tick(delta)


# ---------- thiết lập ----------

## Gọi ngay sau instantiate(), trước hoặc sau add_child đều được.
func setup(p_def: BuildingDef, p_cell: Vector2i, p_rotation := 0, p_state: State = State.GHOST) -> void:
	def = p_def
	cell = p_cell
	rotation_steps = posmod(p_rotation, 4) if def.rotatable else 0
	level = 1
	progress = 0.0
	_apply_position()
	rotation_changed.emit(rotation_steps)
	level_changed.emit(level)
	_set_state(p_state)


# ---------- hình học trên lưới ----------

func footprint_size() -> Vector2i:
	return def.footprint_for(rotation_steps)


func footprint_rect() -> Rect2i:
	return Rect2i(cell, footprint_size())


## Nền sẽ chiếm nếu quay thêm `dir` bước (giữ nguyên ô góc trên) — để kiểm tra trước khi xoay.
func footprint_rect_if_rotated(dir: int) -> Rect2i:
	return Rect2i(cell, def.footprint_for(rotation_steps + dir))


func set_cell(c: Vector2i) -> void:
	if c == cell:
		return
	cell = c
	_apply_position()
	cell_changed.emit(cell)


## Xoay 90°. Không kiểm tra va chạm: bên gọi (BuildController) phải kiểm tra trước.
func rotate_step(dir := 1) -> bool:
	if def == null or not def.rotatable:
		return false
	rotation_steps = posmod(rotation_steps + dir, 4)
	_apply_position()
	rotation_changed.emit(rotation_steps)
	return true


func _apply_position() -> void:
	if def == null:
		return
	var r := footprint_rect()
	position = IsoGrid.rect_center(r)
	_apply_depth()


## Khoá sắp xếp chiều sâu giữa các công trình (ô gần camera hơn thì lớn hơn).
func depth() -> int:
	return IsoGrid.front_depth(footprint_rect())


## Vẽ theo chiều sâu bằng z_index = gx + gy của đỉnh nền gần camera nhất (cùng khoá x + y với launch_view),
## đúng cả với nền chữ nhật lớn. Bản xem trước luôn nằm trên cùng.
func _apply_depth() -> void:
	z_index = GHOST_Z if state == State.GHOST else clampi(depth(), 0, GHOST_Z - 1)


# ---------- vòng đời: xây và nâng cấp ----------

func begin_construction() -> void:
	level = 1
	progress = 0.0
	_time_total = def.build_time
	_time_left = def.build_time
	_set_state(State.CONSTRUCTING)
	progress_changed.emit(progress)
	if _time_total <= 0.0:
		_finish()


func can_upgrade() -> bool:
	return state == State.READY and level < def.max_level


## Chi phí lên cấp kế tiếp; −1 nếu không nâng được.
func upgrade_cost() -> int:
	return def.upgrade_cost(level) if can_upgrade() else -1


func begin_upgrade() -> bool:
	if not can_upgrade():
		return false
	progress = 0.0
	_time_total = def.upgrade_time(level)
	_time_left = _time_total
	_set_state(State.UPGRADING)
	progress_changed.emit(progress)
	if _time_total <= 0.0:
		_finish()
	return true


## Đẩy thời gian đi `dt` (cùng đơn vị với build_time / upgrade_times).
func tick(dt: float) -> void:
	if state != State.CONSTRUCTING and state != State.UPGRADING:
		return
	_time_left -= dt
	progress = clampf(1.0 - _time_left / maxf(_time_total, 0.0001), 0.0, 1.0)
	progress_changed.emit(progress)
	if _time_left <= 0.0:
		_finish()


## Hoàn tất ngay việc đang làm (tua nhanh / mua tăng tốc).
func complete_now() -> void:
	if state == State.CONSTRUCTING or state == State.UPGRADING:
		_finish()


func time_left() -> float:
	return maxf(_time_left, 0.0) if (state == State.CONSTRUCTING or state == State.UPGRADING) else 0.0


func is_busy() -> bool:
	return state == State.CONSTRUCTING or state == State.UPGRADING


func _finish() -> void:
	var was := state
	progress = 1.0
	progress_changed.emit(progress)
	if was == State.UPGRADING:
		level += 1
		level_changed.emit(level)
	_set_state(State.READY)
	if was == State.UPGRADING:
		upgrade_finished.emit(level)
		_on_upgrade_finished(level)
	else:
		construction_finished.emit()
		_on_construction_finished()


func _set_state(s: State) -> void:
	if s == state and s != State.GHOST:
		return
	var old := state
	state = s
	_apply_depth()
	state_changed.emit(state)
	_on_state_changed(old, state)


# ---------- chọn & kiểm tra chỗ đặt ----------

func set_selected(v: bool) -> void:
	if v == selected:
		return
	selected = v
	selection_changed.emit(selected)


func set_placement_valid(v: bool) -> void:
	if v == placement_valid:
		return
	placement_valid = v
	placement_valid_changed.emit(v)


## Điểm (toạ độ thế giới) có trúng công trình không: trong hình thoi nền, hoặc trúng điểm ảnh đặc của sprite.
func hit_test(world_pos: Vector2) -> bool:
	if def == null:
		return false
	var lp := to_local(world_pos)
	if Geometry2D.is_point_in_polygon(lp, IsoGrid.footprint_polygon(footprint_size())):
		return true
	var v := get_node_or_null("Visual")
	if v != null and v.has_method("hit_test"):
		return v.hit_test(world_pos)
	return false


# ---------- chỉ số, lưu/tải ----------

func title() -> String:
	return def.display_name if def != null else "?"


## Chỉ số theo cấp hiện tại (vd. stat("fuel_discount")).
func stat(key: String, default_value: Variant = 0.0) -> Variant:
	return def.stat(level, key, default_value)


func serialize() -> Dictionary:
	return {
		"id": String(def.id),
		"cell": [cell.x, cell.y],
		"rot": rotation_steps,
		"level": level,
		"state": int(state),
		"progress": progress,
		"time_left": _time_left,
		"time_total": _time_total,
	}


## Khôi phục trạng thái đã lưu (sau setup()). JSON trả số nguyên dạng float nên ép kiểu rõ ràng.
func apply_saved(d: Dictionary) -> void:
	level = clampi(int(d.get("level", 1)), 1, def.max_level)
	progress = float(d.get("progress", 0.0))
	_time_left = float(d.get("time_left", 0.0))
	_time_total = float(d.get("time_total", 0.0))
	level_changed.emit(level)
	_set_state(int(d.get("state", State.READY)) as State)
	progress_changed.emit(progress)


# ---------- điểm mở rộng cho lớp con ----------

func _on_state_changed(_old: State, _new: State) -> void:
	pass


func _on_construction_finished() -> void:
	pass


func _on_upgrade_finished(_new_level: int) -> void:
	pass
