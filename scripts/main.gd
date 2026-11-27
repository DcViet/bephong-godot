extends Control
## Cảnh iso toàn màn hình + HUD nổi (thanh trên, thanh dưới) + bảng trượt chứa các bảng điều khiển.
## Landscape: bảng nằm bên phải. Portrait (điện thoại dọc): bảng trượt từ dưới lên.

var header: HeaderBar
var view: LaunchView
var planner: PlannerPanel
var left: ContractsPanel
var right: SidePanel

var _hud: Control
var _top: VBoxContainer
var _dock: HFlowContainer
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

	# --- Thanh dưới ---
	_dock = UIKit.flow(8, 8)
	_ignore(_dock)
	_dock.alignment = FlowContainer.ALIGNMENT_CENTER
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.offset_left = 10
	_dock.offset_right = -10
	_dock.offset_bottom = -10
	_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.add_child(_dock)
	for d in DOCK:
		var b := UIKit.btn(d[1], "Dock", _toggle_sheet.bind(d[0]))
		b.focus_mode = Control.FOCUS_NONE
		_dock_btns[d[0]] = b
		_dock.add_child(b)
	_go_btn = UIKit.btn("PHÓNG", "Ignite", Game.start_launch)
	_go_btn.focus_mode = Control.FOCUS_NONE
	_dock.add_child(_go_btn)
	_next_btn = UIKit.btn("Qua ngày »", "Primary", Game.next_day)
	_next_btn.focus_mode = Control.FOCUS_NONE
	_dock.add_child(_next_btn)

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


## Chạm vào cảnh: bệ → kế hoạch (chọn bệ đó), công trình / ô trống → bảng Mở rộng.
func _on_world_tapped(kind: String, key: Variant) -> void:
	match kind:
		"pad":
			Game.select_pad(int(key))
			_open_sheet("plan")
		"contracts":
			_open_sheet("contracts")
		_:
			_open_sheet("grow")


# ---------------- Bố cục ----------------

func _process(_delta: float) -> void:
	var th: float = _top.size.y + 20.0
	var dh: float = _dock.size.y + 20.0
	if absf(th - _last_top) > 0.5 or absf(dh - _last_dock) > 0.5 or size != _last_size:
		_layout()


func _layout() -> void:
	var th: float = _top.size.y + 20.0
	var dh: float = _dock.size.y + 20.0
	_last_top = th
	_last_dock = dh
	_last_size = size
	var portrait: bool = size.x < size.y * 0.95
	var narrow: bool = size.x < 640.0
	if narrow != _compact:
		_compact = narrow
		header.compact = narrow
		_mark_dirty()
	view.top_inset = th
	view.bottom_inset = dh
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
	card.custom_minimum_size.x = minf(380.0, size.x - 24.0)
	center.add_child(card)
	var box := UIKit.vbox(10)
	card.add_child(box)
	var kind := "TRÒ CHƠI KẾT THÚC" if res.over else ("KẾT QUẢ CHUYẾN BAY" if res.good else "SỰ CỐ CHUYẾN BAY")
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
		btn = UIKit.btn("Tiếp tục", "Primary", Game.dismiss_result)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(btn)
	add_child(_result_layer)
