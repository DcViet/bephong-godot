class_name WorldMenu
extends PanelContainer
## Menu nổi cạnh công trình khi chạm vào cảnh (kiểu Boom Beach): tên, cấp, nút hành động.
## Chỉ đọc dữ liệu từ Game và gọi các hành động có sẵn của Game; không tự tính toán trò chơi.

signal want_sheet(key: String)    # "plan" | "grow": mở bảng chi tiết

var kind := ""
var key: Variant = null


func _init() -> void:
	theme_type_variation = "Plaque"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(k: String, v: Variant) -> void:
	kind = k
	key = v
	refresh()


func close() -> void:
	kind = ""
	key = null
	visible = false


func is_open() -> bool:
	return kind != "" and visible


func refresh() -> void:
	UIKit.clear(self)
	if kind == "":
		visible = false
		return
	var info: Dictionary = _info()
	if info.is_empty():
		close()
		return
	var box := UIKit.vbox(5)
	box.custom_minimum_size.x = 210.0
	add_child(box)
	var head := UIKit.hbox(8)
	box.add_child(head)
	var title := UIKit.lbl(info.title, "H3")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if int(info.level) >= 0:
		head.add_child(UIKit.dots(int(info.level)))
	if info.sub != "":
		box.add_child(UIKit.lbl(info.sub, "Muted", true))
	var row := UIKit.hbox(6)
	for b in info.buttons:
		var bt := UIKit.btn(b.text, b.variation, b.cb, not b.enabled)
		bt.focus_mode = Control.FOCUS_NONE
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bt)
	box.add_child(row)
	if info.note != "":
		var n := UIKit.lbl(info.note, "Bad", true)
		n.add_theme_font_size_override("font_size", 12)
		box.add_child(n)
	visible = true
	reset_size()


func _info() -> Dictionary:
	var s: Dictionary = Game.s
	var money: int = s.money
	match kind:
		"pad":
			var p: Dictionary = Game.by_id(s.pads, int(key))
			if p.is_empty():
				return {}
			var lvl: int = p.lvl
			var sub := "Cấp %d/3" % lvl
			if p.busy > 0:
				sub += " · đang chuẩn bị lại %d ngày" % p.busy
			var btns: Array = [_b("Kế hoạch", "Small", true, func() -> void: want_sheet.emit("plan"))]
			var note := ""
			if lvl < 3:
				var cost: int = GameData.PAD_UP[lvl]
				var blk: String = Game.land_block(lvl + 1)
				btns.append(_b("Nâng cấp · " + Game.fmt(cost), "SmallPrimary", money >= cost and blk == "", func() -> void: Game.upgrade_pad(int(key))))
				note = blk if blk != "" else ("Không đủ tiền" if money < cost else "")
			return {"title": "Bệ phóng %s" % p.name, "level": lvl, "sub": sub, "buttons": btns, "note": note}
		"fac":
			var k: String = String(key)
			var f: Dictionary = GameData.FAC[k]
			var lv: int = s.fac[k]
			var sub2: String = ("Chưa xây · " + String(f.fx[0])) if lv == 0 else String(f.fx[lv - 1])
			var btns2: Array = [_b("Chi tiết", "Small", true, func() -> void: want_sheet.emit("grow"))]
			var note2 := ""
			if lv < 3:
				var cost2: int = f.cost[lv]
				var blk2: String = Game.land_block(lv + 1)
				btns2.append(_b(("Xây · " if lv == 0 else "Nâng cấp · ") + Game.fmt(cost2), "SmallPrimary", money >= cost2 and blk2 == "", func() -> void: Game.upgrade_facility(k)))
				note2 = blk2 if blk2 != "" else ("Không đủ tiền" if money < cost2 else "")
			return {"title": f.name, "level": lv, "sub": sub2, "buttons": btns2, "note": note2}
		"newpad":
			var n: int = s.pads.size()
			if n >= 3:
				return {}
			var cost3: int = GameData.PAD_NEW[n]
			var blk3: String = Game.land_block(1)
			return {"title": "Bệ phóng mới", "level": -1, "sub": "Thêm một bệ để phóng song song nhiều chuyến.",
				"buttons": [_b("Xây · " + Game.fmt(cost3), "SmallPrimary", money >= cost3 and blk3 == "", func() -> void: Game.build_pad())],
				"note": blk3 if blk3 != "" else ("Không đủ tiền" if money < cost3 else "")}
		"land":
			var st: int = int(s.land.stage)
			if st >= 2:
				return {}
			var L: Dictionary = GameData.LAND[st + 1]
			if int(s.land.left) > 0:
				return {"title": "Đang cải tạo %s" % L.short, "level": -1, "sub": "Còn %d ngày thi công (bão thì nghỉ)." % int(s.land.left),
					"buttons": [_b("Chi tiết", "Small", true, func() -> void: want_sheet.emit("grow"))], "note": ""}
			var why: String = Game.reclaim_blocked()
			return {"title": "Mở rộng %s" % L.short, "level": -1, "sub": String(L.fx),
				"buttons": [_b("Chi tiết", "Small", true, func() -> void: want_sheet.emit("grow")),
					_b("Cải tạo · %s · %dn" % [Game.fmt(L.cost), int(L.days)], "SmallPrimary", why == "", func() -> void: Game.start_reclaim())],
				"note": why}
	return {}


func _b(text: String, variation: String, enabled: bool, cb: Callable) -> Dictionary:
	return {"text": text, "variation": variation, "enabled": enabled, "cb": cb}
