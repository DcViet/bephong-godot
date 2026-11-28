extends Node2D
## Sân thử hệ thống xây dựng: lưới iso 16×16, bảng chọn công trình, bảng thông tin công trình đang chọn.
## Mở bằng phím F9 từ màn chính, hoặc: godot --path . res://scenes/building_sandbox.tscn
## Toàn bộ thao tác đi qua BuildController; file này chỉ là giao diện thử nghiệm, không chứa luật xây dựng.

const GRID := Vector2i(16, 16)
const START_MONEY := 9000
const FAST := 8.0

var controller: BuildController
var camera: Camera2D
var wallet := START_MONEY

var _ground: Node2D
var _money_lbl: Label
var _toast_lbl: Label
var _toast_t := 0.0
var _panel: PanelContainer
var _title_lbl: Label
var _info_lbl: Label
var _stats_lbl: Label
var _bar: ProgressBar
var _btn_rotate: Button
var _btn_upgrade: Button
var _btn_finish: Button
var _btn_demolish: Button
var _drag := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.html("#5ec4cc"))
	_ground = Node2D.new()
	_ground.draw.connect(_draw_ground)
	add_child(_ground)

	controller = BuildController.new()
	controller.grid_size = GRID
	add_child(controller)
	controller.payment = _pay
	controller.refund = func(a: int) -> void: wallet += a
	controller.rejected.connect(_say)
	controller.selection_changed.connect(func(_b: BuildingBase) -> void: _refresh_panel())
	controller.placement_started.connect(func(d: BuildingDef) -> void: _say("Đặt: %s — chuột trái để đặt, R để xoay, Shift giữ để đặt tiếp" % d.display_name))
	_seed_world()

	camera = Camera2D.new()
	camera.position = IsoGrid.grid_to_world(Vector2(GRID) * 0.5) + Vector2(0, 40)
	camera.zoom = Vector2.ONE * 0.8
	add_child(camera)

	_build_ui()


## Vài ô bị chặn và vài công trình đặt sẵn để có cái nhìn ngay.
func _seed_world() -> void:
	for r in [Rect2i(12, 2, 2, 2), Rect2i(1, 12, 3, 2), Rect2i(8, 13, 2, 1)]:
		controller.grid.block_rect(r)
	_place("launch_pad", Vector2i(6, 5), true)
	_place("control_tower", Vector2i(3, 3), true)
	_place("workshop", Vector2i(10, 7), true)
	_place("fuel_depot", Vector2i(3, 8), false)


func _place(id: StringName, cell: Vector2i, ready_now: bool) -> void:
	var d := BuildingCatalog.get_def(id)
	if d != null:
		controller.build_at(d, cell, 0, ready_now)


func _pay(amount: int) -> bool:
	if wallet < amount:
		return false
	wallet -= amount
	return true


# ---------- nền lưới ----------

func _draw_ground() -> void:
	var a := Color.html("#86c24a")
	var b := Color.html("#7ab840")
	for x in GRID.x:
		for y in GRID.y:
			var c := Vector2i(x, y)
			var pts := PackedVector2Array([
				IsoGrid.grid_to_world(Vector2(x, y)), IsoGrid.grid_to_world(Vector2(x + 1, y)),
				IsoGrid.grid_to_world(Vector2(x + 1, y + 1)), IsoGrid.grid_to_world(Vector2(x, y + 1))])
			var col := a if (x + y) % 2 == 0 else b
			if controller.grid.is_blocked(c):
				col = Color.html("#8c7a62")
			_ground.draw_colored_polygon(pts, col)
	var o := PackedVector2Array([
		IsoGrid.grid_to_world(Vector2.ZERO), IsoGrid.grid_to_world(Vector2(GRID.x, 0)),
		IsoGrid.grid_to_world(Vector2(GRID)), IsoGrid.grid_to_world(Vector2(0, GRID.y)), IsoGrid.grid_to_world(Vector2.ZERO)])
	_ground.draw_polyline(o, Color.html("#1f2d2a"), 4.0)


# ---------- giao diện ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UIKit.build_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Góc trái trên: tiền, phím tắt, nút phụ.
	var top := PanelContainer.new()
	top.theme_type_variation = "Plaque"
	top.position = Vector2(12, 12)
	top.custom_minimum_size = Vector2(380, 0)
	root.add_child(top)
	var tv := UIKit.vbox(6)
	top.add_child(tv)
	tv.add_child(UIKit.lbl("Thử nghiệm xây dựng"))
	_money_lbl = UIKit.lbl("")
	tv.add_child(_money_lbl)
	var hint := UIKit.lbl("Trái: đặt / chọn · Phải, Esc: hủy · R: xoay · U: nâng cấp · Del: phá bỏ · WASD hoặc giữ chuột giữa: di chuyển · lăn chuột: thu phóng", "Muted", true)
	tv.add_child(hint)
	var row := UIKit.hbox(6)
	tv.add_child(row)
	var fast := CheckButton.new()
	fast.text = "Tua nhanh"
	fast.toggled.connect(func(on: bool) -> void: controller.time_scale = FAST if on else 1.0)
	row.add_child(fast)
	row.add_child(UIKit.btn("+$5000", "Ghost", func() -> void: wallet += 5000))
	row.add_child(UIKit.btn("Về game", "Ghost", func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn")))

	# Giữa dưới: thông báo ngắn.
	_toast_lbl = UIKit.lbl("")
	_toast_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_lbl.position = Vector2(0, -150)
	root.add_child(_toast_lbl)

	# Dưới: bảng chọn công trình.
	var pal := PanelContainer.new()
	pal.theme_type_variation = "Plaque"
	pal.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pal.offset_left = 12
	pal.offset_right = -12
	pal.offset_top = -92
	pal.offset_bottom = -12
	root.add_child(pal)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pal.add_child(sc)
	var hb := UIKit.hbox(6)
	sc.add_child(hb)
	for d in BuildingCatalog.all():
		var def: BuildingDef = d
		var b := UIKit.btn("%s\n$%dk · %dx%d" % [def.display_name, def.build_cost, def.footprint.x, def.footprint.y], "Ghost", func() -> void: controller.begin_placement(def))
		b.custom_minimum_size = Vector2(124, 52)
		b.tooltip_text = def.description
		hb.add_child(b)

	# Phải: thông tin công trình đang chọn.
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "Plaque"
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_right = -12
	_panel.custom_minimum_size = Vector2(250, 0)
	_panel.visible = false
	root.add_child(_panel)
	var pv := UIKit.vbox(7)
	_panel.add_child(pv)
	_title_lbl = UIKit.lbl("")
	_title_lbl.add_theme_font_size_override("font_size", 18)
	pv.add_child(_title_lbl)
	_info_lbl = UIKit.lbl("", "Muted", true)
	pv.add_child(_info_lbl)
	_bar = UIKit.bar(0.0, 10)
	pv.add_child(_bar)
	_stats_lbl = UIKit.lbl("", "", true)
	pv.add_child(_stats_lbl)
	_btn_rotate = UIKit.btn("Xoay (R)", "Ghost", func() -> void: controller.rotate_selected())
	_btn_upgrade = UIKit.btn("Nâng cấp (U)", "Primary", func() -> void: controller.upgrade_selected())
	_btn_finish = UIKit.btn("Hoàn thành ngay", "Ghost", func() -> void:
		if controller.selected != null:
			controller.selected.complete_now())
	_btn_demolish = UIKit.btn("Phá bỏ (Del)", "Ghost", func() -> void: controller.demolish_selected())
	for b in [_btn_rotate, _btn_upgrade, _btn_finish, _btn_demolish]:
		pv.add_child(b)


func _say(text: String) -> void:
	_toast_lbl.text = text
	_toast_t = 3.0


func _refresh_panel() -> void:
	var b := controller.selected
	_panel.visible = b != null and is_instance_valid(b)
	if not _panel.visible:
		return
	var d := b.def
	_title_lbl.text = d.display_name
	var st := ["", "Đang xây", "Hoạt động", "Đang nâng cấp"][int(b.state)] as String
	_info_lbl.text = "%s · cấp %d/%d · nền %dx%d" % [st, b.level, d.max_level, b.footprint_size().x, b.footprint_size().y]
	var lines: PackedStringArray = []
	lines.append(d.description)
	if not d.level_stats.is_empty():
		var cur: Dictionary = d.level_stats[clampi(b.level - 1, 0, d.level_stats.size() - 1)]
		for k in cur:
			lines.append("%s: %s" % [k, str(cur[k])])
		if b.level < d.max_level and b.level < d.level_stats.size():
			var nx: Dictionary = d.level_stats[b.level]
			for k in nx:
				lines.append("Cấp %d: %s = %s" % [b.level + 1, k, str(nx[k])])
	_stats_lbl.text = "\n".join(lines)
	_bar.visible = b.is_busy()
	_bar.value = b.progress * 100.0
	if b.is_busy():
		_info_lbl.text += " · còn %.0f s" % b.time_left()
	var cost := b.upgrade_cost()
	_btn_upgrade.visible = d.max_level > 1
	_btn_upgrade.text = "Nâng cấp (U) $%dk" % cost if cost >= 0 else ("Đã tối đa" if b.level >= d.max_level else "Nâng cấp (U)")
	_btn_upgrade.disabled = cost < 0 or wallet < cost
	_btn_rotate.visible = d.rotatable
	_btn_rotate.disabled = b.state != BuildingBase.State.READY
	_btn_finish.visible = b.is_busy()
	_btn_demolish.text = "Phá bỏ (Del) +$%dk" % int(float(d.build_cost) * d.demolish_refund)


func _process(delta: float) -> void:
	_money_lbl.text = "Tiền: $%dk" % wallet
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast_lbl.text = ""
	if _panel.visible:
		_refresh_panel()
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	if v != Vector2.ZERO:
		camera.position += v.normalized() * 600.0 * delta / camera.zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * 1.1, 0.35, 2.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x / 1.1, 0.35, 2.0)
	elif event is InputEventMouseMotion and _drag:
		camera.position -= (event as InputEventMouseMotion).relative / camera.zoom.x
