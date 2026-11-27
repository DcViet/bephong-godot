class_name HeaderBar
extends HBoxContainer
## HUD trên cùng kiểu Boom Beach: góc trái là ngày / đất / thời tiết, góc phải là cột tài nguyên (tiền, nợ, uy tín).
## Giữa trên cùng để trống cho cảnh. Mọi container bỏ qua chuột để chạm xuyên xuống cảnh; chỉ ô nhận chuột.


## Màn hẹp (điện thoại dọc): ô gọn hơn, bỏ chữ "DỰ BÁO" và ô Mặt Trăng.
var compact: bool = false


func _init() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	UIKit.clear(self)
	var s: Dictionary = Game.s

	# --- Cột trái ---
	var left := UIKit.vbox(5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	var row1 := UIKit.hbox(6)
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(row1)
	row1.add_child(_stat("NGÀY", str(s.day), "StatValue", ""))
	var land: Dictionary = s.land
	var lt: String = GameData.LAND[int(land.stage)].short
	if int(land.left) > 0:
		# Màn hẹp: chỉ ghi lô đang thi công và số ngày còn lại.
		lt = ("%s · %dn" % [GameData.LAND[int(land.target)].short, int(land.left)]) if compact else ("%s » %s · %dn" % [lt, GameData.LAND[int(land.target)].short, int(land.left)])
	row1.add_child(_stat("ĐẤT", lt, "StatValue", GameData.LAND[int(land.stage)].name))
	left.add_child(_aligned(_weather_chip()))
	if not compact:
		var moon := _chip([UIKit.lbl("MẶT TRĂNG", "Key"), UIKit.lbl(Game.moon_text(), "Mono")])
		moon.tooltip_text = "Cửa sổ phóng tới Mặt Trăng mở theo chu kỳ 7 ngày"
		left.add_child(_aligned(moon))
	if s.price_war > 0:
		left.add_child(_aligned(_chip([UIKit.pill("Đối thủ phá giá · %d ngày" % s.price_war, UIKit.IGNITE)])))
	if s.debris:
		left.add_child(_aligned(_chip([UIKit.pill("Mảnh vỡ quỹ đạo", UIKit.IGNITE)])))

	# --- Cột phải: ba thanh tài nguyên xếp dọc ---
	var net: int = Game.upkeep() + Game.interest()
	var w := 128.0 if compact else 168.0
	var right := UIKit.vbox(5)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	right.add_child(_bar("TIỀN", Game.fmt(s.money), "Bad" if s.money < 0 else "StatValue", "Chi phí vận hành −%s mỗi ngày" % Game.fmt(net), w))
	right.add_child(_bar("NỢ", Game.fmt(s.debt), "StatValue", "Lãi 0,25%% mỗi ngày" if s.debt > 0 else "Không nợ", w))
	right.add_child(_bar("UY TÍN", str(s.rep), "StatValue", "Mở GEO ở 8, Mặt Trăng ở 35", w))


func _aligned(c: Control) -> Control:
	# Bọc trong HBox để ô giữ đúng kích thước thay vì bị kéo giãn theo cột.
	var h := UIKit.hbox(0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(c)
	return h


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


## Thanh tài nguyên: nhãn bên trái, giá trị căn phải, bề rộng cố định để ba thanh thẳng hàng.
func _bar(key: String, value: String, variation: String, tip: String, w: float) -> PanelContainer:
	var v := UIKit.lbl(value, variation)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p := _chip([UIKit.lbl(key, "Key"), v])
	p.custom_minimum_size.x = w
	p.tooltip_text = tip
	return p


func _dot(w: String) -> Control:
	var col: Color = {"clear": UIKit.GOOD, "wind": UIKit.WARN, "storm": UIKit.BAD}[w]
	return UIKit.dot(col, true, 14)


func _weather_chip() -> PanelContainer:
	var s: Dictionary = Game.s
	var content: Array = []
	if not compact:
		content.append(UIKit.lbl("HÔM NAY", "Key"))
	content.append(_dot(s.weather))
	content.append(UIKit.lbl(GameData.WX[s.weather].label, ""))
	if not compact:
		content.append(UIKit.lbl("DỰ BÁO", "Key"))
	else:
		content.append(UIKit.lbl("»", "Muted"))
	var tip := ""
	for i in s.wxq.size():
		var w: String = Game.forecast_shown(s.wxq[i], i)
		content.append(_dot(w))
		tip += "+%d ngày: %s\n" % [i + 1, GameData.WX[w].label]
	var chip := _chip(content)
	chip.tooltip_text = tip.strip_edges()
	return chip
