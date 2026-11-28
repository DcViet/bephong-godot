class_name BuildingOverlay
extends Node2D
## Lớp vẽ phụ của công trình, dùng hai lần trong một scene:
##  - GROUND (đặt TRƯỚC sprite): hình thoi nền — xanh/đỏ khi đặt, nét đứt khi đang xây, viền sáng khi được chọn.
##  - HUD (đặt SAU sprite): thanh tiến độ xây/nâng cấp và chấm cấp, nằm dưới đỉnh nền gần camera.
## Chỉ đọc BuildingBase (cha) và nghe tín hiệu; không có logic gameplay.

enum Layer { GROUND, HUD }

@export var layer: Layer = Layer.GROUND

const OK_FILL := Color(0.3, 0.9, 0.4, 0.28)
const OK_LINE := Color(0.15, 0.7, 0.25, 0.95)
const BAD_FILL := Color(0.95, 0.25, 0.2, 0.30)
const BAD_LINE := Color(0.85, 0.15, 0.1, 0.95)
const SEL_FILL := Color(1.0, 1.0, 1.0, 0.18)
const SEL_LINE := Color(1.0, 1.0, 1.0, 0.95)
const WORK_LINE := Color(1.0, 0.54, 0.24, 0.95)
const INK := Color(0.12, 0.18, 0.16, 1.0)

var _base: BuildingBase


func _ready() -> void:
	_base = get_parent() as BuildingBase
	if _base == null:
		return
	_base.state_changed.connect(func(_s: int) -> void: queue_redraw())
	_base.level_changed.connect(func(_l: int) -> void: queue_redraw())
	_base.rotation_changed.connect(func(_r: int) -> void: queue_redraw())
	_base.progress_changed.connect(func(_p: float) -> void: queue_redraw())
	_base.selection_changed.connect(func(_s: bool) -> void: queue_redraw())
	_base.placement_valid_changed.connect(func(_v: bool) -> void: queue_redraw())
	queue_redraw()


func _draw() -> void:
	if _base == null or _base.def == null:
		return
	if layer == Layer.GROUND:
		_draw_ground()
	else:
		_draw_hud()


func _draw_ground() -> void:
	var poly := IsoGrid.footprint_polygon(_base.footprint_size())
	var line := PackedVector2Array(poly)
	line.append(poly[0])
	match _base.state:
		BuildingBase.State.GHOST:
			var ok := _base.placement_valid
			draw_colored_polygon(poly, OK_FILL if ok else BAD_FILL)
			draw_polyline(line, OK_LINE if ok else BAD_LINE, 3.0)
		BuildingBase.State.CONSTRUCTING:
			draw_colored_polygon(poly, Color(1.0, 0.54, 0.24, 0.18))
			for i in 4:
				draw_dashed_line(poly[i], poly[(i + 1) % 4], WORK_LINE, 3.0, 10.0)
		_:
			if _base.selected:
				draw_colored_polygon(poly, SEL_FILL)
				draw_polyline(line, SEL_LINE, 3.0)


func _draw_hud() -> void:
	if _base.state == BuildingBase.State.GHOST:
		return
	var y := IsoGrid.front_offset(_base.footprint_size()) + 16.0
	if _base.is_busy():
		var w := 74.0
		var r := Rect2(-w * 0.5, y, w, 10.0)
		draw_rect(r.grow(2.0), INK)
		draw_rect(r, Color(0.85, 0.82, 0.7))
		draw_rect(Rect2(r.position, Vector2(w * _base.progress, r.size.y)), WORK_LINE)
		y += 18.0
	if _base.def.max_level > 1:
		var n := _base.def.max_level
		var gap := 14.0
		var x0 := -gap * float(n - 1) * 0.5
		for i in n:
			var c := Vector2(x0 + gap * float(i), y + 5.0)
			draw_circle(c, 6.0, INK)
			draw_circle(c, 4.2, Color(1.0, 0.82, 0.25) if i < _base.level else Color(0.78, 0.74, 0.62))
