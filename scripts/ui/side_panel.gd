class_name SidePanel
extends VBoxContainer
## Cột phải: đội tàu, mở rộng (tài chính, bệ, công trình, mua tàu) và nhật ký.


func _init() -> void:
	add_theme_constant_override("separation", 10)


func refresh() -> void:
	UIKit.clear(self)
	var tab: String = Game.s.tab
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	for t in [["fleet", "ĐỘI TÀU"], ["grow", "MỞ RỘNG"], ["log", "NHẬT KÝ"]]:
		var b := UIKit.btn(t[1], "TabOn" if tab == t[0] else "Tab", Game.set_tab.bind(t[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	add_child(tabs)

	var panel := PanelContainer.new()
	var box := UIKit.vbox(10)
	panel.add_child(box)
	add_child(panel)
	match tab:
		"fleet": _fleet(box)
		"grow": _grow(box)
		_: _log(box)
	var rs := UIKit.btn("Chơi lại từ đầu", "Ghost", Game.restart)
	rs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(rs)


# ---------------- Đội tàu ----------------

func _fleet(box: VBoxContainer) -> void:
	if Game.s.rockets.is_empty():
		box.add_child(UIKit.lbl("Không còn tàu nào.", "Muted"))
		return
	for r in Game.s.rockets:
		box.add_child(_rocket_card(r))


func _rocket_card(r: Dictionary) -> Control:
	var R: Dictionary = GameData.ROCKETS[r.type]
	var pc := UIKit.card()
	var box: VBoxContainer = pc[1]
	var head := UIKit.hbox(8)
	head.add_child(UIKit.lbl("%s · %s" % [r.name, R.name], "H3"))
	head.add_child(UIKit.spacer())
	if r.busy > 0:
		head.add_child(UIKit.pill("Hồi phục %d ngày" % r.busy, UIKit.WARN))
	else:
		head.add_child(UIKit.pill("Sẵn sàng", UIKit.GOOD))
	box.add_child(head)
	box.add_child(UIKit.lbl("%s t · tới %s · bệ cấp %d+ · %d chuyến · động cơ Mk%d" % [str(R.payload), GameData.ORB[R.reach].label, R.pad_lvl, r.flights, r.eng + 1], "MonoMuted", true))

	for p in GameData.PARTS:
		var v: int = roundi(float(r.parts[p[0]]))
		var line := UIKit.hbox(8)
		var n := UIKit.lbl(p[1], "Muted")
		n.custom_minimum_size.x = 92
		line.add_child(n)
		line.add_child(UIKit.bar(float(v), 6))
		var pct := UIKit.lbl("%d%%" % v, "Mono")
		pct.custom_minimum_size.x = 40
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(pct)
		box.add_child(line)

	var btns := UIKit.flow(6, 6)
	var qc: int = Game.quick_cost(r)
	var fc: int = Game.full_cost(r)
	var qd: int = Game.quick_days()
	btns.add_child(UIKit.btn("Sửa nhanh %s · %s" % [Game.fmt(qc), ("%d ngày" % qd) if qd > 0 else "trong ngày"], "Small",
		Game.repair.bind(r.id, "quick"), r.busy > 0 or Game.quick_need(r) == 0 or Game.s.money < qc or Game.launching))
	btns.add_child(UIKit.btn("Đại tu %s · %d ngày" % [Game.fmt(fc), Game.full_days()], "Small",
		Game.repair.bind(r.id, "full"), r.busy > 0 or Game.full_need(r) == 0 or Game.s.money < fc or Game.launching))
	if r.eng < 3:
		var ec: int = Game.engine_cost(r)
		btns.add_child(UIKit.btn("Động cơ Mk%d %s" % [r.eng + 2, Game.fmt(ec)], "Small", Game.upgrade_engine.bind(r.id), Game.s.money < ec or Game.launching))
	box.add_child(btns)
	box.add_child(UIKit.lbl("Sửa nhanh đưa mỗi bộ phận lên tối thiểu 65%. Đại tu đưa về 100%.", "Muted", true))
	return pc[0]


# ---------------- Mở rộng ----------------

func _grow(box: VBoxContainer) -> void:
	var s: Dictionary = Game.s
	var money: int = s.money

	# Tài chính
	var fin := UIKit.card()
	var fb: VBoxContainer = fin[1]
	var fh := UIKit.hbox(8)
	fh.add_child(UIKit.lbl("Tài chính", "H3"))
	fh.add_child(UIKit.spacer())
	fh.add_child(UIKit.lbl("%s nợ" % Game.fmt(s.debt), "Mono"))
	fb.add_child(fh)
	var fbt := UIKit.flow(6, 6)
	fbt.add_child(UIKit.btn("Trả $250k", "Small", Game.repay.bind(250), s.debt == 0 or money < 1))
	fbt.add_child(UIKit.btn("Trả hết", "Small", Game.repay.bind(0), s.debt == 0 or money < 1))
	fbt.add_child(UIKit.btn("Vay thêm $500k", "Ghost", Game.borrow, s.debt + 500 > GameData.MAX_DEBT))
	fb.add_child(fbt)
	fb.add_child(UIKit.lbl("Lãi 0,25%% mỗi ngày. Nợ tối đa %s. Quỹ tiền dưới −$600k là phá sản." % Game.fmt(GameData.MAX_DEBT), "Muted", true))
	box.add_child(fin[0])

	# Bệ phóng
	var pads := UIKit.card()
	var pb: VBoxContainer = pads[1]
	var ph := UIKit.hbox(8)
	ph.add_child(UIKit.lbl("Bệ phóng", "H3"))
	ph.add_child(UIKit.spacer())
	ph.add_child(UIKit.lbl("%d/3" % s.pads.size(), "Mono"))
	pb.add_child(ph)
	for p in s.pads:
		var row := UIKit.hbox(8)
		var busy: String = (" (bận %d)" % p.busy) if p.busy > 0 else ""
		row.add_child(UIKit.lbl("Bệ %s · cấp %d · chuẩn bị lại %d ngày%s" % [p.name, p.lvl, Game.refurb_days(p), busy], "", true))
		if p.lvl < 3:
			var cost: int = GameData.PAD_UP[p.lvl]
			row.add_child(UIKit.btn("Lên cấp %d %s" % [p.lvl + 1, Game.fmt(cost)], "Small", Game.upgrade_pad.bind(p.id), money < cost or Game.launching))
		else:
			row.add_child(UIKit.pill("Tối đa", UIKit.GOOD))
		pb.add_child(row)
	if s.pads.size() < 3:
		var nc: int = GameData.PAD_NEW[s.pads.size()]
		var nb := UIKit.btn("Xây bệ mới %s" % Game.fmt(nc), "Small", Game.build_pad, money < nc or Game.launching)
		nb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pb.add_child(nb)
	pb.add_child(UIKit.lbl("Cấp 2 cho Kestrel, cấp 3 cho Condor. Cấp cao chuẩn bị lại nhanh hơn.", "Muted", true))
	box.add_child(pads[0])

	# Công trình
	for k in GameData.FAC:
		var f: Dictionary = GameData.FAC[k]
		var lv: int = s.fac[k]
		var fc := UIKit.card()
		var cb: VBoxContainer = fc[1]
		var hr := UIKit.hbox(8)
		hr.add_child(UIKit.lbl(f.name, "H3"))
		hr.add_child(UIKit.spacer())
		hr.add_child(UIKit.lbl("●".repeat(lv) + "○".repeat(3 - lv), "Mono"))
		cb.add_child(hr)
		var d := ""
		if lv > 0: d += "Hiện tại: %s. " % f.fx[lv - 1]
		d += ("Cấp tiếp: %s." % f.fx[lv]) if lv < 3 else "Đã tối đa."
		cb.add_child(UIKit.lbl(d, "Muted", true))
		if lv < 3:
			var c: int = f.cost[lv]
			var ub := UIKit.btn("Nâng cấp %s" % Game.fmt(c), "Small", Game.upgrade_facility.bind(k), money < c or Game.launching)
			ub.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			cb.add_child(ub)
		box.add_child(fc[0])

	# Mua tàu
	var shop := UIKit.card()
	var sb: VBoxContainer = shop[1]
	sb.add_child(UIKit.lbl("Mua tàu", "H3"))
	for k in GameData.ROCKETS:
		var R: Dictionary = GameData.ROCKETS[k]
		var lock: bool = s.rep < R.rep
		var row2 := UIKit.hbox(8)
		row2.add_child(UIKit.lbl("%s  %s t · %s · bệ %d" % [R.name, str(R.payload), GameData.ORB[R.reach].label, R.pad_lvl], "Mono", true))
		var label: String = ("Cần uy tín %d" % R.rep) if lock else ("Mua " + Game.fmt(R.price))
		row2.add_child(UIKit.btn(label, "Small", Game.buy_rocket.bind(k), lock or money < R.price or Game.launching))
		sb.add_child(row2)
	box.add_child(shop[0])


# ---------------- Nhật ký ----------------

func _log(box: VBoxContainer) -> void:
	box.add_child(UIKit.lbl("NHẬT KÝ", "Key"))
	for l in Game.s.log:
		var row := UIKit.hbox(8)
		var d := UIKit.lbl("Ngày %d" % l.d, "MonoMuted")
		d.custom_minimum_size.x = 56
		d.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(d)
		var t := UIKit.lbl(l.t, "", true)
		match l.k:
			"good": t.add_theme_color_override("font_color", UIKit.GOOD)
			"bad": t.add_theme_color_override("font_color", UIKit.BAD)
			"warn": t.add_theme_color_override("font_color", UIKit.WARN)
		row.add_child(t)
		box.add_child(row)
