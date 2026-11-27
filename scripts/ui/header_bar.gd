class_name HeaderBar
extends HBoxContainer
## Thanh trên nổi trên cảnh: ô thông số (ngày, tiền, nợ, uy tín), thời tiết, cửa sổ Mặt Trăng và nút Qua ngày.
## Mọi container ở đây bỏ qua chuột để chạm xuyên xuống cảnh; chỉ ô và nút nhận chuột.


## Màn hẹp (điện thoại dọc): bỏ ô tên cảng và rút gọn ô thời tiết.
var compact: bool = false


func _init() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	UIKit.clear(self)
	var s: Dictionary = Game.s
	var flow := UIKit.flow(8, 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flow)

	var net: int = Game.upkeep() + Game.interest()
	if not compact:
		flow.add_child(_chip([UIKit.lbl("BỆ PHÓNG", "H3"), UIKit.lbl(Game.stage_name(), "Muted")]))
	flow.add_child(_stat("NGÀY", str(s.day), "StatValue", ""))
	flow.add_child(_stat("TIỀN", Game.fmt(s.money), "Bad" if s.money < 0 else "StatValue", "Chi phí vận hành −%s mỗi ngày" % Game.fmt(net)))
	flow.add_child(_stat("NỢ", Game.fmt(s.debt), "StatValue", "Lãi 0,25%% mỗi ngày" if s.debt > 0 else "Không nợ"))
	flow.add_child(_stat("UY TÍN", str(s.rep), "StatValue", "Mở GEO ở 8, Mặt Trăng ở 35"))
	flow.add_child(_weather_chip())
	var moon := _chip([UIKit.lbl("MẶT TRĂNG", "Key"), UIKit.lbl(Game.moon_text(), "Mono")])
	moon.tooltip_text = "Cửa sổ phóng tới Mặt Trăng mở theo chu kỳ 7 ngày"
	flow.add_child(moon)
	if s.price_war > 0:
		flow.add_child(_chip([UIKit.pill("Đối thủ phá giá · %d ngày" % s.price_war, UIKit.IGNITE)]))
	if s.debris:
		flow.add_child(_chip([UIKit.pill("Mảnh vỡ quỹ đạo", UIKit.IGNITE)]))


func _chip(content: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Chip"
	var h := UIKit.hbox(7)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in content:
		h.add_child(c)
	p.add_child(h)
	return p


func _stat(key: String, value: String, variation: String, tip: String) -> PanelContainer:
	var p := _chip([UIKit.lbl(key, "Key"), UIKit.lbl(value, variation)])
	p.tooltip_text = tip
	return p


func _dot(w: String) -> Control:
	var col: Color = {"clear": UIKit.GOOD, "wind": UIKit.WARN, "storm": UIKit.BAD}[w]
	return UIKit.dot(col, true, 14)


func _weather_chip() -> PanelContainer:
	var s: Dictionary = Game.s
	var content: Array = [UIKit.lbl("HÔM NAY", "Key"), _dot(s.weather), UIKit.lbl(GameData.WX[s.weather].label, "")]
	if not compact:
		content.append(UIKit.lbl("DỰ BÁO", "Key"))
	var tip := ""
	for i in s.wxq.size():
		var w: String = Game.forecast_shown(s.wxq[i], i)
		content.append(_dot(w))
		tip += "+%d ngày: %s\n" % [i + 1, GameData.WX[w].label]
	var chip := _chip(content)
	chip.tooltip_text = tip.strip_edges()
	return chip
