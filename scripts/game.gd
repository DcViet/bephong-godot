extends Node
## Trạng thái và luật chơi (autoload "Game"). Không chứa mã giao diện hay mã vẽ.
## Giao diện chỉ đọc `s` và gọi các hàm hành động bên dưới; mọi thay đổi phát tín hiệu `changed`.

signal changed
signal toast(msg: String)
signal launch_started(desc: Dictionary)

const SAVE_PATH := "user://bephong.save"

var s: Dictionary = {}
var rng := RandomNumberGenerator.new()
var launching: bool = false
## Kết quả chuyến bay (hoặc màn kết thúc) đang chờ người chơi bấm "Tiếp tục".
var pending_result: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	if not load_game():
		new_game()


# ======================= Lưu / tải =======================

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Không ghi được file lưu (mã lỗi %d)." % FileAccess.get_open_error())
		return
	f.store_var(s)


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var v: Variant = f.get_var()
	if v is Dictionary and v.get("v", 0) == 1 and v.has("pads"):
		s = v
		launching = false
		pending_result = _over_result() if s.over != "" else {}
		return true
	return false


func commit() -> void:
	save_game()
	changed.emit()


# ======================= Tiện ích =======================

func fmt(k: Variant) -> String:
	var neg: bool = k < 0
	var a: float = absf(float(k))
	var t: String
	if a >= 1000.0:
		t = ("%.2f" % (a / 1000.0)).rstrip("0").rstrip(".") + "M"
	else:
		t = str(roundi(a)) + "k"
	return ("−" if neg else "") + "$" + t


func _pick(arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


func log_add(text: String, kind: String = "") -> void:
	s.log.push_front({"d": s.day, "t": text, "k": kind})
	if s.log.size() > 60:
		s.log.pop_back()


func by_id(arr: Array, id: int) -> Dictionary:
	for x in arr:
		if x.id == id:
			return x
	return {}


func stage_name() -> String:
	var rep: int = s.rep
	if rep < 8: return "Khởi nghiệp"
	if rep < 20: return "Ổn định"
	if rep < 40: return "Mở rộng"
	if rep < 70: return "Liên hành tinh"
	return "Đế chế"


func avg_c(r: Dictionary) -> float:
	var t := 0.0
	for p in GameData.PARTS:
		t += float(r.parts[p[0]])
	return t / GameData.PARTS.size()


func min_c(r: Dictionary) -> float:
	var m := 100.0
	for p in GameData.PARTS:
		m = minf(m, float(r.parts[p[0]]))
	return m


func upkeep() -> int:
	var lv: int = s.fac.shop + s.fac.wx + s.fac.fuel + s.fac.asm
	return 10 + 3 * (s.pads.size() - 1) + 2 * lv


func interest() -> int:
	return roundi(float(s.debt) * 0.0025)


func refurb_days(pad: Dictionary) -> int:
	var d: int = 4 - int(pad.lvl) - (1 if s.fac.asm >= 2 else 0) - (1 if s.fac.asm >= 3 else 0)
	return maxi(1, d)


func recover_days(orbit: int) -> int:
	var d: int = int(GameData.ORB[orbit].gap) - (1 if s.fac.asm >= 1 else 0) - (1 if s.fac.asm >= 3 else 0)
	return maxi(1, d)


func fuel_cost(r: Dictionary) -> int:
	return roundi(float(GameData.ROCKETS[r.type].fuel) * (1.0 - 0.08 * float(s.fac.fuel)))


func repair_mult() -> float:
	return 1.0 - 0.15 * float(s.fac.shop)


func quick_need(r: Dictionary) -> int:
	var n := 0
	for p in GameData.PARTS:
		n += maxi(0, 65 - int(r.parts[p[0]]))
	return n


func full_need(r: Dictionary) -> int:
	var n := 0
	for p in GameData.PARTS:
		n += 100 - int(r.parts[p[0]])
	return n


func quick_cost(r: Dictionary) -> int:
	return roundi(quick_need(r) * 0.5 * float(GameData.ROCKETS[r.type].tier) * repair_mult())


func full_cost(r: Dictionary) -> int:
	return roundi(full_need(r) * 0.9 * float(GameData.ROCKETS[r.type].tier) * repair_mult())


func quick_days() -> int:
	return 0 if s.fac.shop >= 2 else 1


func full_days() -> int:
	return 1 if s.fac.shop >= 3 else 2


func engine_cost(r: Dictionary) -> int:
	return roundi([250, 500, 900][r.eng] * float(GameData.ROCKETS[r.type].tier))


func moon_open(day: int) -> bool:
	return (day % 7) < 3


func moon_text() -> String:
	var d: int = s.day
	if moon_open(d):
		return "đang mở, còn %d ngày" % (3 - (d % 7))
	return "mở sau %d ngày" % (7 - (d % 7))


func accepted() -> Array:
	return s.contracts.filter(func(c): return c.accepted)


func open_contracts() -> Array:
	return s.contracts.filter(func(c): return not c.accepted)


func forecast_shown(e: Dictionary, i: int) -> String:
	var base: float = [0.55, 0.75, 0.88, 0.97][s.fac.wx]
	var acc: float = clampf(base - 0.1 * i, 0.3, 0.99)
	if e.r1 < acc:
		return e.real
	var others: Array = ["clear", "wind", "storm"].filter(func(w): return w != e.real)
	return others[0 if e.r2 < 0.5 else 1]


# ======================= Khởi tạo =======================

func _wx_entry() -> Dictionary:
	var r := rng.randf()
	var real := "clear" if r < 0.62 else ("wind" if r < 0.88 else "storm")
	return {"real": real, "r1": rng.randf(), "r2": rng.randf()}


func new_rocket(type: String) -> Dictionary:
	var idx: int = s.name_idx
	s.name_idx = idx + 1
	var id: int = s.next_id
	s.next_id = id + 1
	var nm: String = GameData.NAMES[idx % GameData.NAMES.size()]
	if idx >= GameData.NAMES.size():
		nm += " II"
	return {"id": id, "type": type, "name": nm, "busy": 0, "flights": 0, "repairs": 0, "eng": 0,
		"parts": {"engine": 100, "hull": 100, "shield": 100, "avionics": 100}}


func new_game() -> void:
	launching = false
	pending_result = {}
	s = {"v": 1, "day": 1, "money": 900, "debt": 1500, "rep": 0, "weather": "clear",
		"wxq": [_wx_entry(), _wx_entry(), _wx_entry()],
		"pads": [{"id": 1, "name": "A", "lvl": 1, "busy": 0}], "rockets": [], "contracts": [],
		"fac": {"shop": 0, "wx": 0, "fuel": 0, "asm": 0}, "log": [], "next_id": 10, "name_idx": 0,
		"ok": 0, "fail": 0, "geo": 0, "moon": 0, "debris": false, "price_war": 0, "ins": false,
		"tab": "fleet", "sel": {"c": 0, "r": 0, "p": 0}, "over": ""}
	var r := new_rocket("sparrow")
	r.parts = {"engine": 72, "hull": 68, "shield": 75, "avionics": 70}
	s.rockets.append(r)
	for i in 4:
		s.contracts.append(gen_contract(0))
	s.contracts[0].accepted = true
	log_add("Cảng vũ trụ mở cửa: một tàu Sparrow cũ, một bệ phóng và khoản vay $1.5M.")
	commit()


func gen_contract(force_orbit: int = -1) -> Dictionary:
	var oi: int = force_orbit
	if oi < 0:
		var idxs: Array = []
		var weights := PackedFloat32Array()
		for i in GameData.ORB.size():
			if s.rep >= GameData.ORB[i].unlock:
				idxs.append(i)
				weights.append([6.0, 3.0, 1.0][i])
		oi = idxs[rng.rand_weighted(weights)]
	var o: Dictionary = GameData.ORB[oi]
	var urgent: bool = rng.randf() < 0.18
	var fragile: bool = rng.randf() < 0.2
	var mass: float = snappedf(rng.randf_range(o.mass[0], o.mass[1]), 0.1)
	var reward: float = mass * float(o.per_t) * rng.randf_range(0.85, 1.15)
	if s.price_war > 0: reward *= 0.85
	if fragile: reward *= 1.25
	if urgent: reward *= 1.7
	var rw: int = roundi(reward)
	var span: int = rng.randi_range(3, 5) if urgent else rng.randi_range(6, 14)
	var id: int = s.next_id
	s.next_id = id + 1
	return {"id": id, "orbit": oi, "client": _pick(o.clients), "name": _pick(o.missions), "mass": mass,
		"reward": rw, "penalty": roundi(rw * 0.25), "deadline": int(s.day) + span,
		"urgent": urgent, "fragile": fragile, "accepted": false}


# ======================= Rủi ro và kế hoạch phóng =======================

func fail_chance(r: Dictionary, c: Dictionary, weather: String) -> Dictionary:
	var R: Dictionary = GameData.ROCKETS[r.type]
	var avg: float = avg_c(r)
	var items: Array = []
	var f: float = R.base
	items.append({"t": "Cơ bản", "v": R.base})
	if r.eng > 0:
		var e: float = -0.02 * r.eng
		f += e
		items.append({"t": "Động cơ Mk%d" % (r.eng + 1), "v": e})
	var wear: float = (100.0 - avg) / 100.0 * 0.30
	f += wear
	items.append({"t": "Hao mòn", "v": wear})
	if min_c(r) < 35.0:
		f += 0.08
		items.append({"t": "Bộ phận yếu", "v": 0.08})
	if c.fragile:
		var fr: float = (100.0 - avg) / 100.0 * 0.15
		f += fr
		items.append({"t": "Hàng dễ vỡ", "v": fr})
	var wr: float = GameData.WX[weather].risk
	if wr > 0.0:
		f += wr
		items.append({"t": GameData.WX[weather].label, "v": wr})
	var od: float = 0.02 * c.orbit
	if od > 0.0:
		f += od
		items.append({"t": "Quỹ đạo xa", "v": od})
	return {"fail": clampf(f, 0.02, 0.92), "items": items}


func fits(r: Dictionary, c: Dictionary) -> bool:
	var R: Dictionary = GameData.ROCKETS[r.type]
	return R.payload >= c.mass and R.reach >= c.orbit


func best_rocket(c: Dictionary) -> Dictionary:
	for r in s.rockets:
		if r.busy == 0 and fits(r, c):
			return r
	for r in s.rockets:
		if fits(r, c):
			return r
	return s.rockets[0] if s.rockets.size() > 0 else {}


func best_pad(r: Dictionary) -> Dictionary:
	if r.is_empty():
		return s.pads[0] if s.pads.size() > 0 else {}
	var need: int = GameData.ROCKETS[r.type].pad_lvl
	for p in s.pads:
		if p.busy == 0 and p.lvl >= need:
			return p
	for p in s.pads:
		if p.lvl >= need:
			return p
	return s.pads[0]


func ensure_sel() -> void:
	var acc: Array = accepted()
	if by_id(acc, s.sel.c).is_empty():
		s.sel.c = acc[0].id if acc.size() > 0 else 0
	var c: Dictionary = by_id(acc, s.sel.c)
	if by_id(s.rockets, s.sel.r).is_empty():
		var r: Dictionary = best_rocket(c) if not c.is_empty() else (s.rockets[0] if s.rockets.size() > 0 else {})
		s.sel.r = r.id if not r.is_empty() else 0
	if by_id(s.pads, s.sel.p).is_empty():
		var p: Dictionary = best_pad(by_id(s.rockets, s.sel.r))
		s.sel.p = p.id if not p.is_empty() else 0


## Tàu và bệ đang chọn (dùng để vẽ tàu đứng trên bệ).
func current_sel() -> Dictionary:
	ensure_sel()
	return {"r": by_id(s.rockets, s.sel.r), "p": by_id(s.pads, s.sel.p)}


func _chk(list: Array, ok: Variant, text: String) -> void:
	var st: String = "warn" if ok is String else ("ok" if ok else "no")
	list.append({"ok": st, "text": text})


func eval_plan() -> Dictionary:
	ensure_sel()
	var c: Dictionary = by_id(s.contracts, s.sel.c)
	if not c.is_empty() and not c.accepted:
		c = {}
	var r: Dictionary = by_id(s.rockets, s.sel.r)
	var p: Dictionary = by_id(s.pads, s.sel.p)
	var out: Dictionary = {"c": c, "r": r, "p": p, "checks": [], "valid": false, "fail": 0.0, "items": [], "fuel": 0, "ins": 0}
	if c.is_empty() or r.is_empty() or p.is_empty():
		return out
	var R: Dictionary = GameData.ROCKETS[r.type]
	var O: Dictionary = GameData.ORB[c.orbit]
	var ch: Array = out.checks
	_chk(ch, r.busy == 0, "%s đang hồi phục (%d ngày)" % [r.name, r.busy] if r.busy > 0 else "%s sẵn sàng" % r.name)
	_chk(ch, R.payload >= c.mass, "Tải trọng %.1f t / %s t" % [c.mass, str(R.payload)])
	_chk(ch, R.reach >= c.orbit, "%s %s %s" % [R.name, "tới được" if R.reach >= c.orbit else "không tới được", O.label])
	_chk(ch, p.lvl >= R.pad_lvl, "Bệ %s cấp %d (cần cấp %d)" % [p.name, p.lvl, R.pad_lvl])
	_chk(ch, p.busy == 0, "Bệ %s đang chuẩn bị lại (%d ngày)" % [p.name, p.busy] if p.busy > 0 else "Bệ %s sẵn sàng" % p.name)
	if c.orbit == 2:
		_chk(ch, moon_open(s.day), "Cửa sổ phóng Mặt Trăng %s" % moon_text())
	_chk(ch, not s.debris, "Mảnh vỡ không gian: hoãn phóng hôm nay" if s.debris else "Không có mảnh vỡ trên quỹ đạo")
	var wx: String = s.weather
	var wxt: String = "Thời tiết hôm nay: %s" % GameData.WX[wx].label
	if wx == "storm": wxt += " (rủi ro rất cao)"
	elif wx == "wind": wxt += " (rủi ro tăng)"
	_chk(ch, true if wx == "clear" else "warn", wxt)
	var fuel: int = fuel_cost(r)
	_chk(ch, s.money >= fuel, "Nhiên liệu %s%s" % [fmt(fuel), "" if s.money >= fuel else " (không đủ tiền)"])
	if c.fragile:
		_chk(ch, "warn", "Hàng dễ vỡ: hao mòn ảnh hưởng nhiều hơn")
	var f: Dictionary = fail_chance(r, c, wx)
	out.fail = f.fail
	out.items = f.items
	out.fuel = fuel
	out.ins = roundi(R.price * 0.04)
	var all_ok := true
	for x in ch:
		if x.ok == "no":
			all_ok = false
	out.valid = all_ok and not launching and pending_result.is_empty()
	return out


# ======================= Chọn trong kế hoạch =======================

func select_contract(id: int) -> void:
	s.sel.c = id
	var c: Dictionary = by_id(s.contracts, id)
	if not c.is_empty():
		var r: Dictionary = best_rocket(c)
		if not r.is_empty(): s.sel.r = r.id
	s.sel.p = 0
	commit()


func select_rocket(id: int) -> void:
	s.sel.r = id
	s.sel.p = 0
	commit()


func select_pad(id: int) -> void:
	s.sel.p = id
	commit()


func set_insurance(on: bool) -> void:
	s.ins = on
	commit()


func set_tab(tab: String) -> void:
	s.tab = tab
	commit()


# ======================= Phóng =======================

## Quyết định kết quả chuyến bay ngay lúc bấm Phóng; trạng thái chỉ đổi khi `finish_launch`.
func start_launch() -> void:
	if launching:
		return
	var pl: Dictionary = eval_plan()
	if not pl.valid:
		return
	var c: Dictionary = pl.c
	var r: Dictionary = pl.r
	var success: bool = rng.randf() > pl.fail
	var out: Dictionary = {"success": success, "insured": s.ins, "fuel": pl.fuel, "ins_cost": pl.ins, "fail": pl.fail,
		"fail_at": 0.0, "cause": "", "loss": false, "pad_dmg": false}
	if not success:
		out.fail_at = rng.randf_range(0.15, 0.8)
		out.loss = rng.randf() < 0.55
		out.pad_dmg = rng.randf() < (0.7 if out.fail_at < 0.2 else 0.25)
		var ws := PackedFloat32Array()
		for p in GameData.PARTS:
			ws.append((100.0 - float(r.parts[p[0]])) + 10.0)
		var causes: Array = ["Động cơ trục trặc", "Khoang hàng rò áp", "Chắn nhiệt bong tróc", "Lỗi điện tử dẫn đường"]
		out.cause = causes[rng.rand_weighted(ws)]
		if s.weather == "storm" and rng.randf() < 0.4:
			out.cause = "Sét đánh trúng tàu"
	var pad_index := 0
	for i in s.pads.size():
		if s.pads[i].id == pl.p.id:
			pad_index = i
	launching = true
	launch_started.emit({"c": c, "r": r, "p": pl.p, "out": out, "pad_index": pad_index})
	changed.emit()


func finish_launch(d: Dictionary) -> void:
	var c: Dictionary = d.c
	var r: Dictionary = d.r
	var p: Dictionary = d.p
	var out: Dictionary = d.out
	var R: Dictionary = GameData.ROCKETS[r.type]
	var O: Dictionary = GameData.ORB[c.orbit]
	var lines: Array = []
	s.money -= out.fuel
	lines.append(["Nhiên liệu", fmt(-out.fuel)])
	if out.insured:
		s.money -= out.ins_cost
		lines.append(["Phí bảo hiểm", fmt(-out.ins_cost)])
	r.flights += 1
	p.busy = refurb_days(p)
	s.contracts = s.contracts.filter(func(x): return x.id != c.id)
	var good: bool
	var title: String
	if out.success:
		good = true
		title = "Giao hàng thành công"
		var early: bool = c.deadline - s.day >= 3
		var bonus: int = roundi(c.reward * 0.1) if early else 0
		s.money += c.reward + bonus
		lines.append(["Tiền hợp đồng", "+" + fmt(c.reward)])
		if bonus > 0:
			lines.append(["Thưởng giao sớm", "+" + fmt(bonus)])
		var gain: int = 2 + c.orbit * 3 + (1 if early else 0)
		s.rep += gain
		lines.append(["Uy tín", "+%d" % gain])
		var before: float = avg_c(r)
		for pt in GameData.PARTS:
			var k: String = pt[0]
			var w: int = roundi(rng.randf_range(5.0, 12.0) * (1.0 + 0.3 * c.orbit) * (1.2 if k == "engine" else 1.0))
			r.parts[k] = maxi(0, int(r.parts[k]) - w)
		lines.append(["Hao mòn của " + r.name, "−%d%% (còn %d%%)" % [roundi(before - avg_c(r)), roundi(avg_c(r))]])
		r.busy = recover_days(c.orbit)
		s.ok += 1
		if c.orbit == 1: s.geo += 1
		if c.orbit == 2: s.moon += 1
		log_add("%s giao %s tới %s: %s." % [r.name, c.name, O.label, fmt(c.reward + bonus)], "good")
	else:
		good = false
		title = "Mất tín hiệu: " + out.cause
		s.money -= c.penalty
		lines.append(["Phạt hợp đồng", fmt(-c.penalty)])
		var lost: int = mini(int(s.rep), 3 + c.orbit * 2)
		s.rep -= lost
		lines.append(["Uy tín", "−%d" % lost])
		if out.loss:
			s.rockets = s.rockets.filter(func(x): return x.id != r.id)
			lines.append(["Tàu " + r.name, "Mất hoàn toàn"])
			if out.insured:
				var back: int = roundi(R.price * 0.5)
				s.money += back
				lines.append(["Bảo hiểm chi trả", "+" + fmt(back)])
		else:
			for pt in GameData.PARTS:
				var k2: String = pt[0]
				r.parts[k2] = maxi(5, int(r.parts[k2]) - rng.randi_range(25, 45))
			r.busy = recover_days(c.orbit) + 1
			lines.append(["Tàu " + r.name, "Hỏng nặng, thu hồi được"])
		if out.pad_dmg:
			p.busy += 3
			lines.append(["Bệ %s hư hại" % p.name, "+3 ngày sửa"])
		s.fail += 1
		log_add("%s thất bại (%s)%s." % [r.name, out.cause, ", mất tàu" if out.loss else ", thu hồi được"], "bad")
	s.sel = {"c": 0, "r": 0, "p": 0}
	pending_result = {"good": good, "over": false, "title": title, "sub": "%s · %s" % [c.name, O.label], "lines": lines}
	launching = false
	_check_over()
	commit()


func _over_result() -> Dictionary:
	return {"good": false, "over": true, "title": "Kết thúc", "sub": "",
		"lines": [["Lý do", s.over], ["Chuyến thành công", str(s.ok)], ["Số ngày hoạt động", str(s.day)]]}


func _check_over() -> void:
	if s.over != "":
		return
	if s.money < GameData.BANKRUPT_BELOW:
		s.over = "Phá sản. Quỹ âm quá mức cho phép và chủ nợ tiếp quản cảng."
	elif s.rockets.size() == 0 and s.money < GameData.ROCKETS.sparrow.price:
		s.over = "Hết tàu và không đủ tiền mua tàu mới."
	if s.over != "":
		pending_result = _over_result()


func dismiss_result() -> void:
	if pending_result.get("over", false):
		return
	pending_result = {}
	changed.emit()


func restart() -> void:
	new_game()


# ======================= Qua ngày =======================

func next_day() -> void:
	if launching or not pending_result.is_empty():
		return
	s.day += 1
	var cost: int = upkeep()
	var intr: int = interest()
	s.money -= cost + intr
	log_add("Chi phí vận hành %s%s." % [fmt(-cost), (", lãi vay " + fmt(-intr)) if intr > 0 else ""])
	for p in s.pads:
		if p.busy > 0: p.busy -= 1
	for r in s.rockets:
		if r.busy > 0: r.busy -= 1
	s.weather = s.wxq.pop_front().real
	s.wxq.append(_wx_entry())
	s.debris = false
	if s.price_war > 0: s.price_war -= 1
	if rng.randf() < 0.12:
		var e: int = rng.randi_range(0, 4)
		if e == 0:
			s.debris = true
			log_add("Mảnh vỡ không gian cắt ngang quỹ đạo: hôm nay không phóng được.", "warn")
			toast.emit("Mảnh vỡ không gian: hoãn phóng hôm nay")
		elif e == 1:
			s.money -= 60
			log_add("Thanh tra an toàn đến kiểm tra: phạt %s." % fmt(60), "bad")
			toast.emit("Thanh tra an toàn: −$60k")
		elif e == 2:
			s.money += 120
			log_add("Nhà tài trợ gửi khoản hỗ trợ %s." % fmt(120), "good")
			toast.emit("Tài trợ: +$120k")
		elif e == 3 and s.rockets.size() > 0:
			var r2: Dictionary = _pick(s.rockets)
			var pp: Array = _pick(GameData.PARTS)
			r2.parts[pp[0]] = maxi(0, int(r2.parts[pp[0]]) - 25)
			log_add("Lô linh kiện lỗi: %s của %s −25%%." % [pp[1].to_lower(), r2.name], "bad")
			toast.emit("Lô linh kiện lỗi ảnh hưởng " + r2.name)
		else:
			s.price_war = 5
			log_add("Đối thủ phá giá: hợp đồng mới trả thấp hơn 15% trong 5 ngày.", "warn")
			toast.emit("Đối thủ phá giá thị trường")
	var keep: Array = []
	for c in s.contracts:
		if c.deadline >= s.day:
			keep.append(c)
		elif c.accepted:
			s.money -= c.penalty
			s.rep = maxi(0, int(s.rep) - 3)
			log_add("Quá hạn \"%s\": phạt %s, uy tín −3." % [c.name, fmt(c.penalty)], "bad")
			toast.emit("Quá hạn hợp đồng: phạt " + fmt(c.penalty))
	s.contracts = keep
	var open_n: int = open_contracts().size()
	if open_n < 5 and rng.randf() < 0.6:
		s.contracts.append(gen_contract())
	if open_n < 3:
		s.contracts.append(gen_contract())
	_check_over()
	commit()


# ======================= Hành động của người chơi =======================

func accept_contract(id: int) -> void:
	if launching: return
	var c: Dictionary = by_id(s.contracts, id)
	if c.is_empty() or accepted().size() >= GameData.MAX_ACTIVE:
		return
	c.accepted = true
	s.sel.c = c.id
	s.sel.r = 0
	toast.emit("Đã nhận: " + c.name)
	commit()


func drop_contract(id: int) -> void:
	if launching: return
	var c: Dictionary = by_id(s.contracts, id)
	if c.is_empty():
		return
	s.money -= c.penalty
	s.rep = maxi(0, int(s.rep) - 1)
	s.contracts = s.contracts.filter(func(x): return x.id != id)
	log_add("Từ bỏ \"%s\": phạt %s." % [c.name, fmt(c.penalty)], "bad")
	commit()


func repair(id: int, kind: String) -> void:
	if launching: return
	var r: Dictionary = by_id(s.rockets, id)
	if r.is_empty() or r.busy > 0:
		return
	var cost: int = quick_cost(r) if kind == "quick" else full_cost(r)
	if s.money < cost:
		return
	s.money -= cost
	r.repairs += 1
	for p in GameData.PARTS:
		r.parts[p[0]] = maxi(int(r.parts[p[0]]), 65) if kind == "quick" else 100
	var d: int = quick_days() if kind == "quick" else full_days()
	r.busy = maxi(int(r.busy), d)
	log_add("%s %s: %s%s." % ["Sửa nhanh" if kind == "quick" else "Đại tu", r.name, fmt(-cost), (", %d ngày" % d) if d > 0 else ", xong trong ngày"])
	commit()


func upgrade_engine(id: int) -> void:
	if launching: return
	var r: Dictionary = by_id(s.rockets, id)
	if r.is_empty() or r.eng >= 3 or s.money < engine_cost(r):
		return
	s.money -= engine_cost(r)
	r.eng += 1
	log_add("Nâng động cơ %s lên Mk%d." % [r.name, r.eng + 1], "good")
	commit()


func upgrade_pad(id: int) -> void:
	if launching: return
	var p: Dictionary = by_id(s.pads, id)
	if p.is_empty() or p.lvl >= 3 or s.money < GameData.PAD_UP[p.lvl]:
		return
	s.money -= GameData.PAD_UP[p.lvl]
	p.lvl += 1
	log_add("Nâng bệ %s lên cấp %d." % [p.name, p.lvl], "good")
	commit()


func build_pad() -> void:
	if launching: return
	var n: int = s.pads.size()
	if n >= 3 or s.money < GameData.PAD_NEW[n]:
		return
	s.money -= GameData.PAD_NEW[n]
	var id: int = s.next_id
	s.next_id = id + 1
	s.pads.append({"id": id, "name": "ABC"[n], "lvl": 1, "busy": 0})
	log_add("Xây bệ phóng mới.", "good")
	commit()


func upgrade_facility(key: String) -> void:
	if launching: return
	var f: Dictionary = GameData.FAC[key]
	var lv: int = s.fac[key]
	if lv >= 3 or s.money < f.cost[lv]:
		return
	s.money -= f.cost[lv]
	s.fac[key] = lv + 1
	log_add("Nâng %s lên cấp %d." % [f.name.to_lower(), lv + 1], "good")
	commit()


func buy_rocket(type: String) -> void:
	if launching: return
	var R: Dictionary = GameData.ROCKETS[type]
	if s.rep < R.rep or s.money < R.price:
		return
	s.money -= R.price
	var r: Dictionary = new_rocket(type)
	s.rockets.append(r)
	log_add("Mua tàu %s (%s) giá %s." % [r.name, R.name, fmt(R.price)], "good")
	commit()


func repay(amount: int) -> void:
	if launching: return
	var pay: int = mini(mini(amount if amount > 0 else int(s.debt), int(s.money)), int(s.debt))
	if pay <= 0:
		return
	s.money -= pay
	s.debt -= pay
	log_add("Trả nợ %s." % fmt(pay), "good")
	commit()


func borrow() -> void:
	if launching: return
	if s.debt + 500 > GameData.MAX_DEBT:
		return
	s.debt += 500
	s.money += 500
	log_add("Vay thêm %s." % fmt(500), "warn")
	commit()
