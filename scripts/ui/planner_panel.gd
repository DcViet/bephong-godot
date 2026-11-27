class_name PlannerPanel
extends PanelContainer
## Kế hoạch phóng: chọn hợp đồng, tàu, bệ; xem xác suất và bấm Phóng.


func refresh() -> void:
	UIKit.clear(self)
	var s: Dictionary = Game.s
	var box := UIKit.vbox(12)
	add_child(box)
	box.add_child(UIKit.lbl("KẾ HOẠCH PHÓNG", "Key"))

	var acc: Array = Game.accepted()
	if acc.is_empty():
		box.add_child(UIKit.lbl("Chưa có hợp đồng đã nhận. Mở bảng Hợp đồng ở thanh dưới rồi bấm \"Nhận hợp đồng\".", "Muted", true))
		return
	if s.rockets.is_empty():
		box.add_child(UIKit.lbl("Không còn tàu. Mua tàu mới ở bảng Mở rộng.", "Muted", true))
		return

	var pl: Dictionary = Game.eval_plan()

	# --- Ba ô chọn ---
	var row := UIKit.flow(10, 8)
	var c_items: Array = []
	for c in acc:
		c_items.append([c.id, "%s · %.1f t · %s (còn %d ngày)" % [GameData.ORB[c.orbit].label, c.mass, c.name, c.deadline - s.day]])
	var r_items: Array = []
	for r in s.rockets:
		var busy: String = (" · bận %d ngày" % r.busy) if r.busy > 0 else ""
		r_items.append([r.id, "%s (%s) · %d%%%s" % [r.name, GameData.ROCKETS[r.type].name, roundi(Game.avg_c(r)), busy]])
	var p_items: Array = []
	for p in s.pads:
		var pb: String = (" · bận %d ngày" % p.busy) if p.busy > 0 else ""
		p_items.append([p.id, "Bệ %s · cấp %d%s" % [p.name, p.lvl, pb]])
	row.add_child(_field("HỢP ĐỒNG", c_items, s.sel.c, Game.select_contract, 330))
	row.add_child(_field("TÀU", r_items, s.sel.r, Game.select_rocket, 230))
	row.add_child(_field("BỆ PHÓNG", p_items, s.sel.p, Game.select_pad, 190))
	box.add_child(row)

	if pl.c.is_empty() or pl.r.is_empty() or pl.p.is_empty():
		return

	# --- Kiểm tra điều kiện + xác suất ---
	var body := UIKit.flow(24, 12)
	var checks := UIKit.vbox(5)
	checks.custom_minimum_size.x = 300
	for x in pl.checks:
		var line := UIKit.hbox(8)
		line.add_child(UIKit.dot(UIKit.GOOD if x.ok == "ok" else (UIKit.BAD if x.ok == "no" else UIKit.WARN), true, 14))
		line.add_child(UIKit.lbl(x.text, "", true))
		checks.add_child(line)
	body.add_child(checks)

	var ok_pct: int = roundi((1.0 - pl.fail) * 100.0)
	var odds := UIKit.vbox(8)
	odds.custom_minimum_size.x = 280
	odds.add_child(UIKit.lbl("XÁC SUẤT THÀNH CÔNG", "Key"))
	var big := UIKit.hbox(8)
	big.add_child(UIKit.lbl("%d%%" % ok_pct, "Big"))
	var sm := UIKit.lbl("rủi ro %d%%" % roundi(pl.fail * 100.0), "MonoMuted")
	sm.size_flags_vertical = Control.SIZE_SHRINK_END
	big.add_child(sm)
	odds.add_child(big)
	odds.add_child(UIKit.bar(float(ok_pct), 8))
	var chips := UIKit.flow(4, 4)
	for it in pl.items:
		var up: bool = it.v > 0.0
		var col: Color = UIKit.WARN if up else UIKit.GOOD
		var txt := "%s %s%.1f%%" % [it.t, "+" if up else "−", absf(it.v) * 100.0]
		chips.add_child(UIKit.pill(txt, col))
	odds.add_child(chips)
	body.add_child(odds)
	box.add_child(body)

	# --- Bảo hiểm + nút phóng ---
	var R: Dictionary = GameData.ROCKETS[pl.r.type]
	var ins := CheckBox.new()
	ins.text = "Mua bảo hiểm tàu (%s). Nếu mất tàu, hoàn 50%% giá tàu (%s)." % [Game.fmt(pl.ins), Game.fmt(roundi(R.price * 0.5))]
	ins.button_pressed = s.ins
	ins.toggled.connect(Game.set_insurance)
	box.add_child(ins)

	var early: bool = pl.c.deadline - s.day >= 3
	var go := UIKit.hbox(16)
	var cost := UIKit.vbox(2)
	var l1 := "Nhiên liệu −%s" % Game.fmt(pl.fuel)
	if s.ins:
		l1 += ", bảo hiểm −%s" % Game.fmt(pl.ins)
	cost.add_child(UIKit.lbl(l1, "MonoMuted"))
	cost.add_child(UIKit.lbl("Thưởng +%s%s · phạt nếu hỏng %s" % [Game.fmt(pl.c.reward), " (+10% nếu giao sớm)" if early else "", Game.fmt(pl.c.penalty)], "MonoMuted"))
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.add_child(cost)
	go.add_child(UIKit.btn("PHÓNG", "Ignite", Game.start_launch, not pl.valid))
	box.add_child(go)


func _field(title: String, items: Array, selected: int, cb: Callable, min_w: int) -> Control:
	var v := UIKit.vbox(4)
	v.custom_minimum_size.x = min_w
	v.add_child(UIKit.lbl(title, "Key"))
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.clip_text = true
	for it in items:
		ob.add_item(it[1], it[0])
	var idx: int = ob.get_item_index(selected)
	if idx >= 0:
		ob.select(idx)
	ob.item_selected.connect(func(i: int) -> void: cb.call(ob.get_item_id(i)))
	v.add_child(ob)
	return v
