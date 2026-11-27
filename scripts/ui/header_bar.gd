class_name HeaderBar
extends PanelContainer
## Thanh trên cùng: tên cảng, ngày, tiền, nợ, uy tín và nút qua ngày.


func _init() -> void:
	theme_type_variation = "TopBar"


func refresh() -> void:
	UIKit.clear(self)
	var s: Dictionary = Game.s
	var row := UIKit.hbox(26)
	add_child(row)

	var brand := UIKit.vbox(0)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(UIKit.lbl("BỆ PHÓNG", "Title"))
	brand.add_child(UIKit.lbl("Cảng vũ trụ ven biển · giai đoạn %s" % Game.stage_name(), "Muted"))
	row.add_child(brand)

	var net: int = Game.upkeep() + Game.interest()
	row.add_child(_stat("NGÀY", str(s.day), "", ""))
	row.add_child(_stat("QUỸ TIỀN", Game.fmt(s.money), "−%s mỗi ngày" % Game.fmt(net), "Bad" if s.money < 0 else "StatValue"))
	row.add_child(_stat("NỢ VAY", Game.fmt(s.debt), "lãi 0,25% mỗi ngày" if s.debt > 0 else "Không nợ", ""))
	row.add_child(_stat("UY TÍN", str(s.rep), "mở GEO ở 8, Mặt Trăng ở 35", ""))

	var blocked: bool = Game.launching or not Game.pending_result.is_empty()
	var nd := UIKit.btn("Qua ngày ▸", "Primary", Game.next_day, blocked)
	nd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nd)


func _stat(key: String, value: String, sub: String, variation: String) -> Control:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.lbl(key, "Key"))
	v.add_child(UIKit.lbl(value, variation if variation != "" else "StatValue"))
	if sub != "":
		v.add_child(UIKit.lbl(sub, "MonoMuted"))
	return v
