class_name ContractsPanel
extends VBoxContainer
## Cột trái: hợp đồng đã nhận, bảng hợp đồng mới và các mục tiêu.


func _init() -> void:
	add_theme_constant_override("separation", 12)


func refresh() -> void:
	UIKit.clear(self)
	var acc: Array = Game.accepted()
	var open: Array = Game.open_contracts()
	add_child(_section("ĐÃ NHẬN (%d/%d)" % [acc.size(), GameData.MAX_ACTIVE], acc, "Chưa nhận hợp đồng nào."))
	add_child(_section("BẢNG HỢP ĐỒNG (%d)" % open.size(), open, "Chưa có hợp đồng mới. Chờ qua ngày."))
	add_child(_goals())


func _section(title: String, list: Array, empty_text: String) -> Control:
	var panel := PanelContainer.new()
	var box := UIKit.vbox(8)
	panel.add_child(box)
	box.add_child(UIKit.lbl(title, "Key"))
	if list.is_empty():
		box.add_child(UIKit.lbl(empty_text, "Muted", true))
	for c in list:
		box.add_child(_card(c))
	return panel


func _card(c: Dictionary) -> Control:
	var O: Dictionary = GameData.ORB[c.orbit]
	var left: int = c.deadline - Game.s.day
	var pc := UIKit.card(UIKit.ACCENT if c.accepted else Color(0, 0, 0, 0))
	var box: VBoxContainer = pc[1]

	var tags := UIKit.hbox(5)
	var orbit_col: Color = [Color.html("#7fd0ff"), UIKit.ACCENT, Color.html("#d6c3ff")][c.orbit]
	tags.add_child(UIKit.pill(O.label, orbit_col))
	if c.urgent:
		tags.add_child(UIKit.pill("Gấp", UIKit.IGNITE))
	if c.fragile:
		tags.add_child(UIKit.pill("Dễ vỡ", UIKit.WARN))
	tags.add_child(UIKit.spacer())
	tags.add_child(UIKit.lbl("còn %d ngày" % left, "Bad" if left <= 2 else "MonoMuted"))
	box.add_child(tags)

	box.add_child(UIKit.lbl(c.name, "H3", true))
	box.add_child(UIKit.lbl(c.client, "Muted", true))
	var meta := UIKit.hbox(12)
	meta.add_child(UIKit.lbl("%.1f t" % c.mass, "Mono"))
	meta.add_child(UIKit.lbl(Game.fmt(c.reward), "Good"))
	meta.add_child(UIKit.lbl("phạt " + Game.fmt(c.penalty), "MonoMuted"))
	box.add_child(meta)

	var b: Button
	if c.accepted:
		b = UIKit.btn("Từ bỏ (phạt %s)" % Game.fmt(c.penalty), "Ghost", Game.drop_contract.bind(c.id), Game.launching)
	else:
		b = UIKit.btn("Nhận hợp đồng", "SmallPrimary", Game.accept_contract.bind(c.id), Game.launching or Game.accepted().size() >= GameData.MAX_ACTIVE)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(b)
	return pc[0]


func _goal(done: bool, text: String) -> Control:
	var r := UIKit.hbox(8)
	var i := UIKit.lbl("✓" if done else "○", "Good" if done else "MonoMuted")
	i.custom_minimum_size.x = 16
	r.add_child(i)
	r.add_child(UIKit.lbl(text, "" if done else "Muted", true))
	return r


func _goals() -> Control:
	var s: Dictionary = Game.s
	var panel := PanelContainer.new()
	var box := UIKit.vbox(6)
	panel.add_child(box)
	box.add_child(UIKit.lbl("MỤC TIÊU", "Key"))
	box.add_child(_goal(s.debt == 0, "Trả hết nợ vay"))
	box.add_child(_goal(s.ok >= 10, "10 chuyến thành công (%d/10)" % s.ok))
	box.add_child(_goal(s.pads.size() >= 2, "Mở bệ phóng thứ hai"))
	box.add_child(_goal(s.geo >= 1, "Giao hàng tới quỹ đạo địa tĩnh"))
	var lv3 := false
	for p in s.pads:
		if p.lvl >= 3:
			lv3 = true
	box.add_child(_goal(lv3, "Nâng một bệ lên cấp 3"))
	box.add_child(_goal(s.moon >= 1, "Giao hàng tới Mặt Trăng"))
	return panel
