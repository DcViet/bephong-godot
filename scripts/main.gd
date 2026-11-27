extends Control
## Dựng bố cục chính, nối tín hiệu của Game với các bảng và cảnh bãi phóng.

var header: HeaderBar
var sitebar: HFlowContainer
var view: LaunchView
var planner: PlannerPanel
var left: ContractsPanel
var right: SidePanel

var _left_scroll: ScrollContainer
var _right_scroll: ScrollContainer
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _result_layer: Control = null
var _dirty := false


func _ready() -> void:
	theme = UIKit.build_theme()
	_build()
	Game.changed.connect(_mark_dirty)
	Game.toast.connect(_show_toast)
	Game.launch_started.connect(func(d: Dictionary) -> void: view.begin(d))
	view.finished.connect(func(d: Dictionary) -> void: Game.finish_launch(d))
	_refresh()


func _scroll(min_w: int) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.x = min_w
	return sc


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root_v := UIKit.vbox(12)
	margin.add_child(root_v)

	header = HeaderBar.new()
	root_v.add_child(header)

	var body := UIKit.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(body)

	_left_scroll = _scroll(330)
	body.add_child(_left_scroll)
	left = ContractsPanel.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_scroll.add_child(left)

	var center_scroll := _scroll(0)
	center_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center_scroll)
	var center := UIKit.vbox(12)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_scroll.add_child(center)

	var scene_box := PanelContainer.new()
	scene_box.theme_type_variation = "SceneBox"
	scene_box.clip_contents = true
	center.add_child(scene_box)
	var sv := UIKit.vbox(0)
	scene_box.add_child(sv)
	var sb_panel := PanelContainer.new()
	sb_panel.theme_type_variation = "SiteBar"
	sitebar = UIKit.flow(18, 4)
	sb_panel.add_child(sitebar)
	sv.add_child(sb_panel)
	view = LaunchView.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_child(view)

	planner = PlannerPanel.new()
	center.add_child(planner)

	_right_scroll = _scroll(380)
	body.add_child(_right_scroll)
	right = SidePanel.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_scroll.add_child(right)

	# Thông báo nổi ở đáy màn hình.
	var toast_layer := MarginContainer.new()
	toast_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_theme_constant_override("margin_bottom", 22)
	add_child(toast_layer)
	_toast_panel = PanelContainer.new()
	_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", UIKit.flat(UIKit.PANEL2, UIKit.ACCENT, 1, 5, 14, 9))
	_toast_label = UIKit.lbl("")
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false
	toast_layer.add_child(_toast_panel)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func() -> void: _toast_panel.visible = false)
	add_child(_toast_timer)


func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_panel.visible = true
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
	_refresh_sitebar()
	planner.refresh()
	left.refresh()
	right.refresh()
	_sync_result()
	var locked: bool = Game.launching
	for n in [header, _left_scroll, _right_scroll, planner]:
		n.process_mode = Node.PROCESS_MODE_DISABLED if locked else Node.PROCESS_MODE_INHERIT
		n.modulate.a = 0.55 if locked else 1.0


func _refresh_sitebar() -> void:
	UIKit.clear(sitebar)
	var s: Dictionary = Game.s
	sitebar.add_child(_wx_chip("HÔM NAY", s.weather, true))
	var fc := UIKit.flow(10, 2)
	fc.add_child(UIKit.lbl("DỰ BÁO", "Key"))
	for i in s.wxq.size():
		var w: String = Game.forecast_shown(s.wxq[i], i)
		fc.add_child(_wx_chip("+%d" % (i + 1), w, false))
	sitebar.add_child(fc)
	var mw := UIKit.hbox(6)
	mw.add_child(UIKit.lbl("CỬA SỔ MẶT TRĂNG", "Key"))
	mw.add_child(UIKit.lbl(Game.moon_text(), "Mono"))
	sitebar.add_child(mw)
	if s.price_war > 0:
		sitebar.add_child(UIKit.pill("Đối thủ phá giá · %d ngày" % s.price_war, UIKit.IGNITE))
	if s.debris:
		sitebar.add_child(UIKit.pill("Mảnh vỡ quỹ đạo", UIKit.IGNITE))


func _wx_chip(caption: String, w: String, bold: bool) -> Control:
	var h := UIKit.hbox(6)
	h.add_child(UIKit.lbl(caption, "Key"))
	var col: Color = {"clear": UIKit.GOOD, "wind": UIKit.WARN, "storm": UIKit.BAD}[w]
	var dot := UIKit.lbl("●", "")
	dot.add_theme_color_override("font_color", col)
	h.add_child(dot)
	h.add_child(UIKit.lbl(GameData.WX[w].label, "" if bold else "Mono"))
	return h


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
	dim.color = Color(0.02, 0.03, 0.05, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "ResultCard"
	var accent: Color = UIKit.GOOD if res.good else UIKit.BAD
	card.add_theme_stylebox_override("panel", UIKit.flat(UIKit.PANEL, accent, 1, 6, 18, 16))
	card.custom_minimum_size.x = 380
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
	view.add_child(_result_layer)
