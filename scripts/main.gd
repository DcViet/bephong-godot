extends Control
## Cảnh iso toàn màn hình (kiểu Boom Beach): HUD hai góc trên, menu dưới trái, PHÓNG dưới phải,
## menu nổi khi chạm công trình, và bảng trượt chứa các bảng điều khiển chi tiết.
## Landscape: bảng nằm bên phải. Portrait (điện thoại dọc): bảng trượt từ dưới lên.

var header: HeaderBar
var view: LaunchView
var planner: PlannerPanel
var left: ContractsPanel
var right: SidePanel

var _hud: Control
var _top: VBoxContainer
var _dock: HFlowContainer        # menu dưới trái
var _actions: BoxContainer       # PHÓNG + Qua ngày, dưới phải (dọc ở màn ngang, ngang ở màn dọc)
var _wmenu: WorldMenu            # menu nổi cạnh công trình
var _dock_btns: Dictionary = {}
var _go_btn: Button
var _next_btn: Button
var _compact := false
var _sheet: PanelContainer
var _sheet_title: Label
var _sheet_scroll: ScrollContainer
var _sheet_page: VBoxContainer
var _open := ""                    # "", "contracts", "plan", "fleet", "grow", "log"
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _result_layer: Control = null
var _dirty := false
var _last_top := -1.0
var _last_dock := -1.0
var _last_size := Vector2.ZERO

const DOCK: Array = [["contracts", "Hợp đồng"], ["plan", "Kế hoạch"], ["fleet", "Đội tàu"], ["grow", "Mở rộng"], ["log", "Nhật ký"]]


func _ready() -> void:
	theme = UIKit.build_theme()
	_build()
	_apply_ui_scale()
	get_window().size_changed.connect(_apply_ui_scale)
	Game.changed.connect(_mark_dirty)
	Game.toast.connect(_show_toast)
	Game.launch_started.connect(func(d: Dictionary) -> void: view.begin(d))
	view.finished.connect(func(d: Dictionary) -> void: Game.finish_launch(d))
	view.tapped.connect(_on_world_tapped)
	_refresh()


## Phím F9: mở sân thử hệ thống xây dựng (công trình dựng bằng sprite).
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F9:
		get_tree().change_scene_to_file("res://scenes/building_sandbox.tscn")


## Chọn hệ số phóng UI theo kích thước thật (tính cả devicePixelRatio của điện thoại)
## để chữ luôn đọc được: màn nhỏ giữ 1 px logic = 1 px CSS, màn lớn phóng tới 1,5×.
func _apply_ui_scale() -> void:
	var w := get_window()
	if w == null:
		return
	var phys := Vector2(w.size)
	if phys.x < 16.0 or phys.y < 16.0:
		return
	var dpr: float = maxf(1.0, DisplayServer.screen_get_scale())
	var css_min: float = minf(phys.x, phys.y) / dpr
	var k: float = dpr * clampf(css_min / 800.0, 1.0, 1.5)
	var target := Vector2i(roundi(phys.x / k), roundi(phys.y / k))
	if w.content_scale_size != target:
		w.content_scale_size = target


func _ignore(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build() -> void:
	view = LaunchView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)

	_hud = _ignore(Control.new())
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hud)

	# --- Thanh trên ---
	_top = UIKit.vbox(6)
	_ignore(_top)
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = 10
	_top.offset_right = -10
	_top.offset_top = 10
	_hud.add_child(_top)
	header = HeaderBar.new()
	_top.add_child(header)

	# --- Menu dưới trái ---
	_dock = UIKit.flow(8, 8)
	_ignore(_dock)
	_dock.alignment = FlowContainer.ALIGNMENT_BEGIN
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_dock.offset_left = 10
	_dock.offset_right = 400
	_dock.offset_bottom = -10
	_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.add_child(_dock)
	for d in DOCK:
		var b := UIKit.btn(d[1], "Dock", _toggle_sheet.bind(d[0]))
		b.focus_mode = Control.FOCUS_NONE
		_dock_btns[d[0]] = b
		_dock.add_child(b)

	# --- Nút hành động dưới phải (ngón cái phải với tới) ---
	_actions = BoxContainer.new()
	_actions.vertical = true
	_actions.add_theme_constant_override("separation", 8)
	_ignore(_actions)
	_actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_actions.offset_right = -10
	_actions.offset_bottom = -10
	_actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.add_child(_actions)
	_go_btn = UIKit.btn("PHÓNG", "Ignite", Game.start_launch)
	_go_btn.focus_mode = Control.FOCUS_NONE
	_go_btn.custom_minimum_size = Vector2(150, 58)
	_actions.add_child(_go_btn)
	_next_btn = UIKit.btn("Qua ngày »", "Primary", Game.next_day)
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.custom_minimum_size = Vector2(150, 44)
	_actions.add_child(_next_btn)

	# --- Bảng trượt ---
	_sheet = PanelContainer.new()
	_sheet.theme_type_variation = "Sheet"
	_sheet.visible = false
	add_child(_sheet)
	var sv := UIKit.vbox(8)
	_sheet.add_child(sv)
	var head := UIKit.hbox(8)
	_sheet_title = UIKit.lbl("", "H3")
	_sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_sheet_title)
	var close := UIKit.btn("Đóng", "Close", _close_sheet)
	close.focus_mode = Control.FOCUS_NONE
	head.add_child(close)
	sv.add_child(head)
	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_child(_sheet_scroll)
	_sheet_page = UIKit.vbox(0)
	_sheet_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_scroll.add_child(_sheet_page)

	_wmenu = WorldMenu.new()
	_wmenu.want_sheet.connect(func(k: String) -> void:
		_wmenu.close()
		_open_sheet(k))
	add_child(_wmenu)

	planner = PlannerPanel.new()
	left = ContractsPanel.new()
	right = SidePanel.new()
	for n in [planner, left, right]:
		(n as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# --- Thông báo nổi ---
	_toast_panel = PanelContainer.new()
	_toast_panel.theme_type_variation = "Chip"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UIKit.lbl("")
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false
	add_child(_toast_panel)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func() -> void: _toast_panel.visible = false)
	add_child(_toast_timer)


# ---------------- Bảng trượt ----------------

func _toggle_sheet(key: String) -> void:
	if _open == key:
		_close_sheet()
		return
	_open_sheet(key)


func _open_sheet(key: String) -> void:
	_wmenu.close()
	if key in ["fleet", "grow", "log"]:
		Game.set_tab(key)
	_open = key
	_sheet_scroll.scroll_vertical = 0
	_refresh()


func _close_sheet() -> void:
	_open = ""
	_refresh()


func _sync_sheet() -> void:
	for c in _sheet_page.get_children():
		_sheet_page.remove_child(c)
	var launching: bool = Game.launching
	if _open == "" or launching:
		_sheet.visible = false
		return
	var title := ""
	var page: Control
	match _open:
		"contracts":
			title = "Hợp đồng"
			page = left
		"plan":
			title = "Kế hoạch phóng"
			page = planner
		_:
			title = {"fleet": "Đội tàu", "grow": "Mở rộng", "log": "Nhật ký"}[_open]
			page = right
	_sheet_title.text = title
	_sheet_page.add_child(page)
	_sheet.visible = true


## Chạm vào cảnh: trung tâm điều khiển → hợp đồng; bệ / công trình / ô trống / đất → menu nổi cạnh vật đó;
## chạm khoảng trống → đóng menu nổi.
func _on_world_tapped(kind: String, key: Variant) -> void:
	match kind:
		"":
			_wmenu.close()
		"contracts":
			_open_sheet("contracts")
		_:
			if kind == "pad":
				Game.select_pad(int(key))
			_open = ""
			_wmenu.open(kind, key)
			_refresh()


# ---------------- Bố cục ----------------

func _is_portrait() -> bool:
	return size.x < size.y * 0.95


## Chiều cao vùng dưới màn hình bị HUD chiếm. Màn dọc: hai nút hành động nằm ngang phía trên hàng menu.
func _bottom_h() -> float:
	if _is_portrait():
		return _dock.size.y + _actions.size.y + 28.0
	return maxf(_dock.size.y, _actions.size.y) + 20.0


func _process(_delta: float) -> void:
	var th: float = _top.size.y + 20.0
	var dh: float = _bottom_h()
	if absf(th - _last_top) > 0.5 or absf(dh - _last_dock) > 0.5 or size != _last_size:
		_layout()
	_place_menu()


## Đặt menu nổi phía trên vật được chạm (bệ cao nên nâng lên), kẹp trong màn hình.
func _place_menu() -> void:
	if not _wmenu.is_open():
		return
	var ap: Variant = view.anchor_pos(_wmenu.kind, _wmenu.key)
	if ap == null:
		return
	var a: Vector2 = ap
	var lift: float = 125.0 if _wmenu.kind == "pad" else 52.0
	_wmenu.size = Vector2.ZERO    # co về kích thước tối thiểu (nội dung vừa đổi)
	var ms: Vector2 = _wmenu.size
	var x: float = clampf(a.x - ms.x * 0.5, 8.0, maxf(8.0, size.x - ms.x - 8.0))
	var y: float = a.y - lift - ms.y
	# Giữa hai cột HUD thì được lên sát mép trên; đè lên một cột thì phải nằm dưới cột đó.
	var clear_of_hud: bool = x > 280.0 and x + ms.x < size.x - 200.0
	var top_lim: float = 10.0 if clear_of_hud else _top.size.y + 16.0
	if y < top_lim:
		y = a.y + 34.0
	y = clampf(y, top_lim, maxf(top_lim, size.y - _bottom_h() - ms.y))
	_wmenu.position = Vector2(x, y)


func _layout() -> void:
	var th: float = _top.size.y + 20.0
	var dh: float = _bottom_h()
	_last_top = th
	_last_dock = dh
	_last_size = size
	var portrait: bool = _is_portrait()
	var narrow: bool = size.x < 640.0
	if narrow != _compact:
		_compact = narrow
		header.compact = narrow
		_mark_dirty()
	# Hai góc HUD nằm cạnh cảnh nên màn ngang chỉ cần chừa một phần chiều cao.
	_actions.vertical = not portrait
	_actions.move_child(_next_btn, 0 if portrait else 1)
	if portrait:
		_dock.offset_right = size.x - 10.0
		_actions.offset_bottom = -(_dock.size.y + 18.0)
	else:
		_dock.offset_right = maxf(140.0, size.x - _actions.get_combined_minimum_size().x - 20.0)
		_actions.offset_bottom = -10.0
	view.top_inset = th if portrait else minf(th, 74.0)
	view.bottom_inset = dh if portrait else dh * 0.6
	view.side_inset = 0.0
	if portrait:
		var sh: float = clampf(size.y * 0.52, 240.0, size.y - th - dh - 60.0)
		_sheet.position = Vector2(10, size.y - dh - sh)
		_sheet.size = Vector2(size.x - 20.0, sh)
		if _sheet.visible:
			view.bottom_inset = dh + sh
	else:
		var w: float = clampf(size.x * 0.42, 360.0, 520.0)
		_sheet.position = Vector2(size.x - w - 10.0, th)
		_sheet.size = Vector2(w, maxf(120.0, size.y - th - dh))
		if _sheet.visible:
			view.side_inset = w + 10.0
	_toast_panel.position = Vector2(maxf(10.0, (size.x - _toast_panel.size.x) * 0.5), size.y - dh - 54.0)


# ---------------- Làm mới ----------------

func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_panel.visible = true
	_toast_panel.reset_size()
	_layout()
	_toast_timer.start(3.2)


# Gộp nhiều tín hiệu `changed` trong cùng khung hình thành một lần dựng lại.
func _mark_dirty() -> void:
	if _dirty:
		return
	_dirty = true
	_refresh.call_deferred()


func _refresh() -> void:
	_dirty = false
	header.refresh()
	planner.refresh()
	left.refresh()
	right.refresh()
	_refresh_dock()
	if Game.launching:
		_wmenu.close()
	else:
		_wmenu.refresh()
	_sync_sheet()
	_sync_result()
	_hud.visible = not Game.launching
	_layout()


func _refresh_dock() -> void:
	var acc: Array = Game.accepted()
	var open_n: int = Game.open_contracts().size()
	for d in DOCK:
		var b: Button = _dock_btns[d[0]]
		var label: String = d[1]
		if d[0] == "contracts":
			label = "Hợp đồng · %d/%d" % [acc.size(), GameData.MAX_ACTIVE] if open_n == 0 else "Hợp đồng · %d/%d · +%d" % [acc.size(), GameData.MAX_ACTIVE, open_n]
		b.text = label
		b.theme_type_variation = "DockOn" if _open == d[0] and not Game.launching else "Dock"
	var valid := false
	var ok_pct := 0
	if not acc.is_empty() and not Game.s.rockets.is_empty():
		var pl: Dictionary = Game.eval_plan()
		valid = pl.valid
		ok_pct = roundi((1.0 - pl.fail) * 100.0)
	_go_btn.visible = valid
	_go_btn.text = "PHÓNG · %d%%" % ok_pct
	_go_btn.disabled = Game.launching
	_next_btn.disabled = Game.launching or not Game.pending_result.is_empty()


# ---------------- Bảng kết quả chuyến bay ----------------

func _sync_result() -> void:
	var res: Dictionary = Game.pending_result
	if res.is_empty():
		if _result_layer != null:
			_result_layer.queue_free()
			_result_layer = null
		return
	if _result_layer != null:
		return
	_result_layer = Control.new()
	_result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.1, 0.12, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_layer.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "ResultCard"
	var accent: Color = UIKit.GOOD if res.good else UIKit.BAD
	card.add_theme_stylebox_override("panel", UIKit.flat(UIKit.PANEL, accent, 4, 16, 20, 18))
	card.custom_minimum_size.x = maxf(260.0, minf(420.0, get_viewport_rect().size.x - 24.0))
	center.add_child(card)
	var box := UIKit.vbox(10)
	card.add_child(box)
	var intro: bool = res.get("intro", false)
	var kind := "TRÒ CHƠI KẾT THÚC" if res.over else ("GIỚI THIỆU DỰ ÁN" if intro else ("KẾT QUẢ CHUYẾN BAY" if res.good else "SỰ CỐ CHUYẾN BAY"))
	box.add_child(UIKit.lbl(kind, "Key"))
	var title := UIKit.lbl(res.title, "Title", true)
	title.add_theme_font_size_override("font_size", 21)
	box.add_child(title)
	if res.sub != "":
		box.add_child(UIKit.lbl(res.sub, "Muted", true))
	for ln in res.lines:
		var row := UIKit.hbox(12)
		row.add_child(UIKit.lbl(ln[0], "", true))
		var v := UIKit.lbl(str(ln[1]), "Mono")
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		box.add_child(row)
		box.add_child(HSeparator.new())
	var btn: Button
	if res.over:
		btn = UIKit.btn("Chơi lại", "Primary", Game.restart)
	else:
		btn = UIKit.btn("Bắt đầu" if intro else "Tiếp tục", "Primary", Game.dismiss_result)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(btn)
	add_child(_result_layer)
