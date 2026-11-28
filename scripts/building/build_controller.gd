class_name BuildController
extends Node2D
## Điều khiển việc xây: chọn loại → bản xem trước (ghost) bám con trỏ trên lưới iso → đặt;
## chọn công trình đã có; xoay; nâng cấp; phá bỏ; lưu/tải.
## Tiền bạc nằm NGOÀI lớp này: gán `payment` / `refund` (Callable) để nối với kinh tế của trò chơi.
## Đặt node này làm con của cảnh có Camera2D; toạ độ chuột lấy qua get_global_mouse_position().

signal placement_started(def: BuildingDef)
signal placement_cancelled
signal building_placed(building: BuildingBase)
signal building_removed(building: BuildingBase)
signal selection_changed(building: BuildingBase)
signal ghost_changed(valid: bool, reason: String)
signal rejected(reason: String)

@export var grid_size := Vector2i(16, 16)
## Tự bắt chuột/bàn phím. Tắt khi UI của trò chơi muốn gọi trực tiếp các hàm công khai.
@export var handle_input := true
## Tự đẩy thời gian cho công trình (tắt để game tự gọi tick() theo ngày).
@export var auto_tick := true
@export var time_scale := 1.0
## Bản xem trước bám theo con trỏ chuột. Tắt khi đặt bằng mã/cảm ứng: dùng move_ghost().
@export var ghost_follows_mouse := true

## func(amount: int) -> bool : trừ tiền, trả false nếu không đủ. Trống = miễn phí.
var payment: Callable
## func(amount: int) -> void : hoàn tiền khi phá bỏ.
var refund: Callable

var grid: BuildGrid
var selected: BuildingBase
var placing_def: BuildingDef
var ghost: BuildingBase
var last_reason := BuildGrid.Reason.OK

var _root: Node2D
var _ghost_valid := true
var _ghost_text := ""
var _scenes: Dictionary = {}    # StringName -> PackedScene


func _init() -> void:
	grid = BuildGrid.new()


func _ready() -> void:
	if grid.size != grid_size:
		grid = BuildGrid.new(grid_size)
	_root = Node2D.new()
	_root.name = "Buildings"
	add_child(_root)


func _process(delta: float) -> void:
	if auto_tick:
		for b in grid.buildings():
			b.tick(delta * time_scale)
	if ghost != null:
		_update_ghost()


func buildings() -> Array[BuildingBase]:
	return grid.buildings()


# ---------- đặt công trình ----------

func begin_placement(def: BuildingDef) -> void:
	cancel_placement()
	if def == null:
		return
	deselect()
	placing_def = def
	ghost = _instantiate(def)
	ghost.auto_tick = false
	ghost.setup(def, Vector2i.ZERO, 0, BuildingBase.State.GHOST)
	_root.add_child(ghost)
	_update_ghost()
	placement_started.emit(def)


func cancel_placement() -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
		placing_def = null
		placement_cancelled.emit()


func is_placing() -> bool:
	return ghost != null


func rotate_ghost(dir := 1) -> void:
	if ghost != null and ghost.rotate_step(dir):
		_update_ghost()


## Đặt ghost vào ô góc trên `cell` rồi kiểm tra chỗ (dùng khi ghost_follows_mouse = false).
func move_ghost(cell: Vector2i) -> void:
	if ghost == null:
		return
	ghost.set_cell(cell)
	_validate_ghost()


## Ghost bám chuột: TÂM nền nằm gần con trỏ nhất, rồi kiểm tra chỗ.
func _update_ghost() -> void:
	if ghost_follows_mouse:
		var g := IsoGrid.world_to_grid(get_global_mouse_position())
		var s := Vector2(ghost.footprint_size())
		ghost.set_cell(Vector2i(roundi(g.x - s.x * 0.5), roundi(g.y - s.y * 0.5)))
	_validate_ghost()


func _validate_ghost() -> void:
	var reason := grid.check(ghost.footprint_rect())
	var valid := reason == BuildGrid.Reason.OK
	ghost.set_placement_valid(valid)
	var text := BuildGrid.reason_text(reason)
	if valid != _ghost_valid or text != _ghost_text:
		_ghost_valid = valid
		_ghost_text = text
		ghost_changed.emit(valid, text)


## Xác nhận đặt tại chỗ ghost đang đứng. Trả công trình mới hoặc null nếu bị từ chối.
func confirm_placement() -> BuildingBase:
	if ghost == null:
		return null
	var reason := grid.check(ghost.footprint_rect())
	if reason != BuildGrid.Reason.OK:
		rejected.emit(BuildGrid.reason_text(reason))
		return null
	var def := placing_def
	if not _pay(def.build_cost):
		rejected.emit("Không đủ tiền")
		return null
	var b := build_at(def, ghost.cell, ghost.rotation_steps)
	if b != null and not Input.is_key_pressed(KEY_SHIFT):
		cancel_placement()
	return b


## Dựng công trình thẳng vào lưới (không trừ tiền): dùng cho nạp ván lưu, hoặc đặt sẵn lúc bắt đầu.
## `ready_now` = true thì xây xong luôn.
func build_at(def: BuildingDef, cell: Vector2i, rotation_steps := 0, ready_now := false) -> BuildingBase:
	var b := _instantiate(def)
	b.auto_tick = false
	b.setup(def, cell, rotation_steps, BuildingBase.State.GHOST)
	last_reason = grid.check(b.footprint_rect())
	if last_reason != BuildGrid.Reason.OK:
		b.free()
		return null
	_root.add_child(b)
	grid.occupy(b)
	if ready_now:
		b.begin_construction()
		b.complete_now()
	else:
		b.begin_construction()
	building_placed.emit(b)
	return b


# ---------- chọn / xoay / nâng cấp / phá bỏ ----------

## Công trình dưới điểm thế giới `p`; nhiều cái chồng nhau thì lấy cái gần camera nhất.
func building_at_world(p: Vector2) -> BuildingBase:
	var best: BuildingBase = null
	for b in grid.buildings():
		if b.hit_test(p) and (best == null or b.depth() > best.depth()):
			best = b
	return best


func select(b: BuildingBase) -> void:
	if b == selected:
		return
	if selected != null and is_instance_valid(selected):
		selected.set_selected(false)
	selected = b
	if selected != null:
		selected.set_selected(true)
	selection_changed.emit(selected)


func deselect() -> void:
	select(null)


## Xoay công trình đang chọn quanh ô góc trên; chỉ khi đã xây xong và nền mới còn vừa chỗ.
func rotate_selected(dir := 1) -> bool:
	var b := selected
	if b == null:
		return false
	if not b.def.rotatable:
		rejected.emit("Công trình này không xoay được")
		return false
	if b.state != BuildingBase.State.READY:
		rejected.emit("Chỉ xoay khi đã xây xong")
		return false
	var reason := grid.check(b.footprint_rect_if_rotated(dir), b)
	if reason != BuildGrid.Reason.OK:
		rejected.emit("Không đủ chỗ để xoay: " + BuildGrid.reason_text(reason))
		return false
	grid.release(b)
	b.rotate_step(dir)
	grid.occupy(b)
	return true


func upgrade_selected() -> bool:
	return upgrade(selected)


func upgrade(b: BuildingBase) -> bool:
	if b == null:
		return false
	if not b.can_upgrade():
		rejected.emit("Không nâng cấp được lúc này")
		return false
	if not _pay(b.upgrade_cost()):
		rejected.emit("Không đủ tiền")
		return false
	return b.begin_upgrade()


func demolish_selected() -> void:
	demolish(selected)


func demolish(b: BuildingBase) -> void:
	if b == null:
		return
	if b == selected:
		deselect()
	grid.release(b)
	var back := int(float(b.def.build_cost) * b.def.demolish_refund)
	if refund.is_valid() and back > 0:
		refund.call(back)
	building_removed.emit(b)
	b.queue_free()


func clear() -> void:
	cancel_placement()
	deselect()
	for b in grid.buildings():
		grid.release(b)
		b.queue_free()


# ---------- lưu / tải ----------

func serialize() -> Array:
	var out: Array = []
	for b in grid.buildings():
		out.append(b.serialize())
	return out


func restore(data: Array) -> void:
	clear()
	for item in data:
		var d: Dictionary = item
		var def := BuildingCatalog.get_def(StringName(String(d.get("id", ""))))
		if def == null:
			continue
		var c: Array = d.get("cell", [0, 0])
		var b := build_at(def, Vector2i(int(c[0]), int(c[1])), int(d.get("rot", 0)))
		if b != null:
			b.apply_saved(d)


# ---------- nội bộ ----------

func _pay(amount: int) -> bool:
	if amount <= 0 or not payment.is_valid():
		return true
	return bool(payment.call(amount))


func _instantiate(def: BuildingDef) -> BuildingBase:
	if not _scenes.has(def.id):
		_scenes[def.id] = load(def.scene_path())
	var ps: PackedScene = _scenes[def.id]
	return ps.instantiate() as BuildingBase


func _unhandled_input(event: InputEvent) -> void:
	if not handle_input:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if is_placing():
				_update_ghost()
				confirm_placement()
			else:
				var hit := building_at_world(get_global_mouse_position())
				select(hit)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if is_placing():
				cancel_placement()
			else:
				deselect()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_R:
				if is_placing():
					rotate_ghost(-1 if k.shift_pressed else 1)
				else:
					rotate_selected(-1 if k.shift_pressed else 1)
			KEY_ESCAPE:
				if is_placing():
					cancel_placement()
				else:
					deselect()
			KEY_U:
				upgrade_selected()
			KEY_DELETE, KEY_X:
				demolish_selected()
