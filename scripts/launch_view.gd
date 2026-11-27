class_name LaunchView
extends Control
## Cảnh bãi phóng nhìn iso nghiêng (kiểu hoạt hình, viền mực dày), vẽ bằng canvas 2D.
## Chiếm toàn màn hình; các bảng điều khiển nổi lên trên (xem main.gd).
## Không đổi trạng thái trò chơi: hoạt ảnh xong chỉ phát `finished`, main.gd mới gọi Game.finish_launch.
## Chạm vào bệ / công trình / ô trống phát `tapped(kind, key)`.

signal finished(desc: Dictionary)
signal tapped(kind: String, key: Variant)    # kind = "" khi chạm ra khoảng trống

const TW := 96.0              # bề rộng một ô iso
const TH := 48.0              # bề cao một ô iso (tỉ lệ 2:1)
const MAP := 12.0             # đảo là hình vuông 12×12 ô (lưới), nhìn ra hình thoi
const WORLD_W := 1180.0       # khung thế giới cần hiện vừa màn hình
const WORLD_H := 700.0
const WORLD_CY := 260.0       # tâm khung theo trục dọc (tọa độ thế giới)
const COUNT := 2.4            # giây đếm ngược
const FLIGHT := 9.0           # giây bay
const PAD_SLOTS: Array = [Vector2(6.0, 6.0), Vector2(4.2, 7.8), Vector2(7.8, 4.2)]
const PAD_SIZE := 1.6
const PAD_H := 7.0
const ROCKET_K := 1.9         # hệ số phóng to kích thước tàu (data.gd tính theo 720×400)

# Vị trí công trình trên lưới (góc gx, gy và kích thước ô).
const SHOP_AT := Rect2(2.3, 5.2, 1.3, 1.3)
const WX_AT := Vector2(9.3, 5.7)
const ASM_AT := Rect2(6.6, 2.1, 2.0, 1.2)
const FUEL_AT: Array = [Vector2(8.9, 7.3), Vector2(9.6, 8.0), Vector2(8.2, 8.1)]
const CTRL_AT := Rect2(4.1, 4.1, 1.0, 1.0)

# Ba giai đoạn đất (đồng tâm quanh ô giữa): bãi khởi điểm → quảng trường → toàn đảo.
const CORE := Rect2(4, 4, 4, 4)
const PLAZA := Rect2(2, 2, 8, 8)
const FULL := Rect2(1, 1, 10, 10)    # vùng cỏ cuối cùng; một vành đá / bãi cát bao quanh
const RIM := 1.5                     # bề rộng vành đá / bãi cát quanh vùng cỏ (ô lưới)
const CLIFF_H := 85.0                # độ cao vách núi phía sau (px thế giới)

var desc: Dictionary = {}
var running: bool = false
var time_scale: float = 1.0
## Chừa chỗ cho thanh trên / thanh dưới khi căn cảnh vừa màn hình.
var top_inset: float = 64.0
var bottom_inset: float = 84.0
## Bề rộng bị bảng bên phải che (landscape): cảnh căn vào phần còn lại.
var side_inset: float = 0.0

var INK := Color.html("#1c2a27")
var _t := 0.0
var _le := 0.0
var _p := 0.0
var _stage := "idle"
var _ignite := false
var _boom_t := -1.0
var _p_fail := 0.0
var _end_t := -1.0
var _puffs: Array = []
var _boom_parts: Array = []
var _stars: Array = []
var _clouds: Array = []
var _bushes: Array = []
var _flowers: Array = []
var _redraw_acc := 0.0        # cọ trên bãi cát phía trước đảo
var _eff := Rect2(4, 4, 4, 4)  # vùng cỏ đang hiện (nở dần ra khi đang cải tạo)
var _vr := Rect2(4, 4, 4, 4)  # vùng lưới đang được căn khung; thu phóng mượt khi đất mở rộng
var _items: Array = []
var _anchors: Array = []
var _ox := 0.0
var _oy := 0.0
var _sc := 1.0
var _cam := 0.0
var _mono: Font
var _disp: Font
var _chip_sb: StyleBoxFlat
var _reduce_motion := false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 80:
		_stars.append({"x": rng.randf(), "y": rng.randf(), "r": rng.randf() * 1.6 + 0.8, "ph": rng.randf() * 6.0})
	for i in 7:
		_clouds.append({"x": rng.randf(), "y": 0.03 + rng.randf() * 0.3, "s": 0.7 + rng.randf() * 0.9, "v": 4.0 + rng.randf() * 6.0})
	_make_scenery(rng)
	Game.changed.connect(queue_redraw)
	resized.connect(queue_redraw)
	_vr = _vr_target()
	_eff = _eff_target()
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	_disp = SystemFont.new()
	_disp.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Segoe UI"])
	_chip_sb = UIKit.flat(UIKit.PANEL, UIKit.LINE, 2, 8)
	_reduce_motion = ProjectSettings.get_setting("gui/theme/reduce_motion", false)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Vùng đất theo giai đoạn (0 = bãi khởi điểm, 1 = quảng trường, 2 = toàn đảo).
func _region(stage: int) -> Rect2:
	return [CORE, PLAZA, FULL][clampi(stage, 0, 2)]


func _land_stage() -> int:
	return int(Game.s.land.stage)


## Cây, bụi và hoa trên cỏ: rải sẵn khắp khu 10×10 (tránh chỗ công trình); chỉ vẽ cây nằm trên ô đất đã mở.
func _make_scenery(rng: RandomNumberGenerator) -> void:
	var zones: Array = []    # [tâm, bán kính]: chỗ công trình, giữ trống
	for pc in PAD_SLOTS:
		zones.append([pc, 1.7])
	zones.append([CTRL_AT.get_center(), 1.2])
	zones.append([ASM_AT.get_center(), 1.7])
	zones.append([SHOP_AT.get_center(), 1.7])
	zones.append([WX_AT, 1.0])
	zones.append([Vector2(9.2, 7.7), 2.1])
	var area := FULL.grow(-0.55)
	var tries := 0
	while _bushes.size() < 32 and tries < 4000:
		tries += 1
		var g := Vector2(area.position.x + rng.randf() * area.size.x, area.position.y + rng.randf() * area.size.y)
		var bad := false
		for z in zones:
			if (z[0] as Vector2).distance_to(g) < float(z[1]):
				bad = true
		for b in _bushes:
			if (b.g as Vector2).distance_to(g) < 1.15:
				bad = true
		if bad:
			continue
		var tree: bool = rng.randf() < 0.7
		var col := Color.html("#5fb83a").lerp(Color.html("#7ccf45"), rng.randf())
		_bushes.append({"g": g, "tree": tree, "k": (0.6 + rng.randf() * 0.25) if tree else (0.55 + rng.randf() * 0.3), "col": col})
	for i in 60:
		_flowers.append(Vector2(area.position.x + rng.randf() * area.size.x, area.position.y + rng.randf() * area.size.y))


# ======================= Điều khiển phóng =======================

func begin(d: Dictionary) -> void:
	desc = d
	running = true
	time_scale = 1.0
	_le = 0.0
	_p = 0.0
	_stage = "count"
	_ignite = false
	_boom_t = -1.0
	_end_t = -1.0
	_puffs.clear()
	_boom_parts.clear()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if running:
		time_scale = 4.0
		return
	var best: Dictionary = {}
	var bd := 1.0e9
	for a in _anchors:
		var dist: float = (a.pos as Vector2).distance_to(event.position)
		if dist < a.r and dist < bd:
			bd = dist
			best = a
	if not best.is_empty():
		tapped.emit(best.kind, best.key)
	else:
		tapped.emit("", null)


## Vị trí màn hình hiện tại của một điểm chạm (menu nổi bám theo khi khung nhìn thu phóng).
func anchor_pos(kind: String, key: Variant) -> Variant:
	for a in _anchors:
		if a.kind == kind and a.key == key:
			return a.pos
	return null


func _process(delta: float) -> void:
	_t += delta
	var tgt := _vr_target()
	var w := 1.0 - exp(-3.0 * delta)
	_vr = Rect2(_vr.position.lerp(tgt.position, w), _vr.size.lerp(tgt.size, w))
	var et := _eff_target()
	var we := 1.0 - exp(-2.5 * delta)
	_eff = Rect2(_eff.position.lerp(et.position, we), _eff.size.lerp(et.size, we))
	if running:
		_step(delta * time_scale)
	# Cảnh đứng yên chỉ cần ~24 khung/giây (cây đung đưa, sóng); đang phóng thì vẽ mọi khung.
	_redraw_acc += delta
	if running or _redraw_acc >= 0.04:
		_redraw_acc = 0.0
		queue_redraw()


## Vùng cần hiện: đất hiện có; khi đang thi công thì hiện cả lô đang cải tạo (bản đồ to ra).
func _vr_target() -> Rect2:
	var land: Dictionary = Game.s.land
	if int(land.left) > 0:
		return _region(int(land.target))
	return _region(int(land.stage))


func _step(dt: float) -> void:
	_le += dt
	if _le < COUNT:
		_stage = "count"
		_p = 0.0
		_ignite = _le > 1.7
		return
	_stage = "fly"
	var p := (_le - COUNT) / FLIGHT
	var out: Dictionary = desc.out
	if not out.success and _boom_t < 0.0 and p >= out.fail_at:
		_boom_t = 0.0
		_p_fail = out.fail_at
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var cols := ["#ffb347", "#ff7a45", "#ffe08a", "#9aa7b5", "#ef6b5b"]
		for i in 70:
			var an := rng.randf() * TAU
			var sp := rng.randf_range(0.2, 1.6)
			_boom_parts.append({"vx": cos(an) * sp, "vy": sin(an) * sp - 0.4, "r": rng.randf_range(2.0, 6.0), "c": Color.html(cols[rng.randi() % cols.size()])})
	if _boom_t >= 0.0:
		_boom_t += dt
		_p = _p_fail
		if _boom_t > 2.4:
			_done()
		return
	_p = minf(1.0, p)
	if p >= 1.0:
		if _end_t < 0.0:
			_end_t = 0.0
		else:
			_end_t += dt
			if _end_t > 1.6:
				_done()


func _done() -> void:
	var d := desc
	running = false
	desc = {}
	_stage = "idle"
	finished.emit(d)


# ======================= Phép chiếu & hàm vẽ cơ bản =======================

## Tọa độ lưới (gx, gy) + độ cao h → tọa độ thế giới (chưa qua camera).
func _iso(gx: float, gy: float, h: float = 0.0) -> Vector2:
	return Vector2((gx - gy) * TW * 0.5, (gx + gy) * TH * 0.5 - h)


## Thế giới → pixel màn hình.
func _s(w: Vector2) -> Vector2:
	return Vector2(_ox + w.x * _sc, _oy + w.y * _sc)


func _xf(pos: Vector2 = Vector2.ZERO, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	draw_set_transform_matrix(Transform2D(0.0, Vector2(_sc, _sc), 0.0, Vector2(_ox, _oy)) * Transform2D(rot, sc, 0.0, pos))


func _screen_space() -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Bề dày nét viền: giữ gần cố định theo pixel để cảnh không bị mảnh khi thu nhỏ.
func _ow() -> float:
	return clampf(3.0 / _sc, 3.0, 6.5)


func _poly(pts: Array, fill: Color, ow: float = -1.0) -> void:
	var pv := PackedVector2Array(pts)
	var w: float = _ow() if ow < 0.0 else ow
	draw_colored_polygon(pv, fill)
	var line := pv.duplicate()
	line.append(pv[0])
	draw_polyline(line, INK, w)
	for v in pv:
		draw_circle(v, w * 0.5, INK)


func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	_xf(c, 0.0, Vector2(rx, ry))
	draw_circle(Vector2.ZERO, 1.0, col)
	_xf()


func _curve(p0: Vector2, p1: Vector2, p2: Vector2, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(p0 * (1.0 - t) * (1.0 - t) + p1 * 2.0 * (1.0 - t) * t + p2 * t * t)
	return pts


## Khối hộp iso: mặt trái (hướng +gy), mặt phải (hướng +gx), mặt trên. z = độ cao đáy.
func _box(gx: float, gy: float, w: float, d: float, h: float, top: Color, lc: Color, rc: Color, z: float = 0.0) -> void:
	var b10 := _iso(gx + w, gy, z)
	var b11 := _iso(gx + w, gy + d, z)
	var b01 := _iso(gx, gy + d, z)
	var t00 := _iso(gx, gy, z + h)
	var t10 := _iso(gx + w, gy, z + h)
	var t11 := _iso(gx + w, gy + d, z + h)
	var t01 := _iso(gx, gy + d, z + h)
	_poly([b01, b11, t11, t01], lc)
	_poly([b10, b11, t11, t10], rc)
	_poly([t00, t10, t11, t01], top)


## Ô cửa / vạch trang trí trên mặt trái (u dọc theo gx, v theo chiều cao).
func _wall_l(gx: float, gy: float, w: float, d: float, u0: float, u1: float, v0: float, v1: float, col: Color, z: float = 0.0) -> void:
	_poly([_iso(gx + u0 * w, gy + d, z + v0), _iso(gx + u1 * w, gy + d, z + v0), _iso(gx + u1 * w, gy + d, z + v1), _iso(gx + u0 * w, gy + d, z + v1)], col, _ow() * 0.55)


func _wall_r(gx: float, gy: float, w: float, d: float, u0: float, u1: float, v0: float, v1: float, col: Color, z: float = 0.0) -> void:
	_poly([_iso(gx + w, gy + u0 * d, z + v0), _iso(gx + w, gy + u1 * d, z + v0), _iso(gx + w, gy + u1 * d, z + v1), _iso(gx + w, gy + u0 * d, z + v1)], col, _ow() * 0.55)


func _flat_tile(gx: float, gy: float, w: float, d: float, col: Color, z: float = 0.0) -> void:
	draw_colored_polygon(PackedVector2Array([_iso(gx, gy, z), _iso(gx + w, gy, z), _iso(gx + w, gy + d, z), _iso(gx, gy + d, z)]), col)


# ======================= Vẽ cảnh =======================

func _draw() -> void:
	var wx: String = Game.s.weather
	var p := _p if running else 0.0
	var rise := 0.0
	var rx := 0.0
	var ang := 0.0
	var rsc := 1.0
	_cam = 0.0
	if running:
		rise = 1500.0 * pow(p, 1.8)
		_cam = maxf(0.0, rise - 150.0)
		rx = 90.0 * p * p
		ang = 0.7 * p * p
		rsc = 1.0 - 0.5 * smoothstep(0.4, 1.0, p)
	var a := smoothstep(0.05, 0.65, p) if running else 0.0

	# Căn khung thế giới vừa màn hình (chừa thanh trên/dưới), thu nhỏ theo bề rộng khi màn dọc.
	# Màn thấp (điện thoại nằm ngang): để cảnh lấn dưới HUD một phần cho đỡ nhỏ.
	var ik := 1.0 if size.y > 600.0 else 0.55
	var avail_h := maxf(120.0, size.y - (top_inset + bottom_inset) * ik)
	var avail_w := maxf(160.0, size.x - side_inset)
	var vr := _vr.grow(RIM - 0.2)
	var lx := _iso(vr.position.x, vr.end.y).x
	var rxe := _iso(vr.end.x, vr.position.y).x
	var ty := minf(_iso(vr.position.x, vr.position.y).y - 110.0, 60.0)    # chừa chỗ cho tháp và tàu
	var by := _iso(vr.end.x, vr.end.y).y + 50.0
	var ww := rxe - lx
	if size.x < size.y:
		ww = minf(ww, 780.0)    # màn dọc: cắt bớt hai góc đảo cho đỡ nhỏ
	_sc = minf(minf(avail_w / ww, avail_h / (by - ty)), 1.4)
	_ox = avail_w * 0.5 - (lx + rxe) * 0.5 * _sc
	_oy = top_inset * ik + avail_h * 0.5 - (ty + by) * 0.5 * _sc + _cam * _sc

	_draw_sea(wx)
	_xf()
	_draw_island()

	_items.clear()
	_anchors.clear()
	_build_items()
	_items.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for it in _items:
		(it[1] as Callable).call()
	_xf()
	_draw_reclaim()

	var n: int = Game.s.pads.size()
	if not running:
		_screen_space()
		_draw_labels()

	# Phủ tối dần khi lên cao, rồi sao.
	_screen_space()
	if a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.14, minf(0.97, a * 1.05)))
		for st in _stars:
			var al := clampf(a * 0.95, 0.0, 1.0)
			if not _reduce_motion:
				al *= 0.65 + 0.35 * sin(_t * 1.4 + st.ph)
			draw_circle(Vector2(st.x * size.x, st.y * size.y), st.r, Color(0.92, 0.95, 1.0, al))

	if running:
		_draw_flight(n, rise, rx, ang, rsc)

	_screen_space()
	_draw_clouds(wx, a)
	_draw_weather(wx, a)
	if running:
		_draw_hud()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_sea(wx: String) -> void:
	_screen_space()
	var top := Color.html("#58c4cc")
	var bot := Color.html("#2c8fa6")
	if wx == "storm":
		top = Color.html("#3f8793")
		bot = Color.html("#1f5a6c")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([top, top, bot, bot]))
	# Gợn sóng: các vạch ngắn trôi chậm.
	var drift := 0.0 if _reduce_motion else _t * 14.0
	for i in 46:
		var wx0 := fposmod(float((i * 197) % 1000) / 1000.0 * (size.x + 120.0) + drift * (0.6 + float(i % 4) * 0.25), size.x + 120.0) - 60.0
		var wy0 := float((i * 313) % 1000) / 1000.0 * size.y
		draw_line(Vector2(wx0, wy0), Vector2(wx0 + 26.0, wy0), Color(1, 1, 1, 0.22), 2.0)


## Hình chữ nhật bo góc trên lưới → các điểm iso (dùng cho vùng nước nông, bọt sóng).
func _rrect(r: Rect2, rad: float, n: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs: Array = [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var a0: Array = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		var ctr: Vector2 = cs[c]
		for i in n + 1:
			var a: float = float(a0[c]) + PI * 0.5 * float(i) / float(n)
			pts.append(_iso(ctr.x + cos(a) * rad, ctr.y + sin(a) * rad))
	return pts


## Nước nông xanh ngọc quanh đảo + hai vòng bọt sóng vỗ nhẹ (kiểu đảo nhiệt đới).
func _draw_shallows(land: Rect2) -> void:
	var halo := land.grow(1.7)
	draw_colored_polygon(_rrect(halo, 1.3), Color(0.78, 0.98, 0.93, 0.2))
	draw_colored_polygon(_rrect(land.grow(1.0), 0.9), Color(0.8, 1.0, 0.94, 0.30))
	var sw := 0.0 if _reduce_motion else sin(_t * 1.6)
	var foam := land.grow(0.42)
	var l1 := _rrect(foam.grow(0.10 + 0.05 * sw), 0.45)
	l1.append(l1[0])
	draw_polyline(l1, Color(1, 1, 1, 0.82), 5.0)
	var l2 := _rrect(foam.grow(0.46 + 0.09 * sin(_t * 1.6 + 1.7 if not _reduce_motion else 0.0)), 0.6)
	l2.append(l2[0])
	draw_polyline(l2, Color(1, 1, 1, 0.38), 3.0)


## Vùng cỏ đích: vùng của giai đoạn đất hiện tại, nở dần ra vùng đích theo số ngày thi công.
func _eff_target() -> Rect2:
	var cur := _region(_land_stage())
	var land: Dictionary = Game.s.land
	if int(land.left) <= 0:
		return cur
	var tgt := _region(int(land.target))
	var f := float(int(land.total) - int(land.left)) / float(maxi(1, int(land.total)))
	return Rect2(cur.position.lerp(tgt.position, f), cur.size.lerp(tgt.size, f))


func _draw_island() -> void:
	var e := _eff
	var isl := e.grow(RIM)
	_draw_shallows(isl)
	var shadow := _rrect(isl.grow(0.3), 0.9)
	for k in shadow.size():
		shadow[k] += Vector2(0, 30)
	draw_colored_polygon(shadow, Color(0.1, 0.35, 0.45, 0.22))
	# Cỏ: một mảng xanh, thêm vài ô sáng hơn cho đỡ phẳng.
	draw_colored_polygon(PackedVector2Array([_iso(e.position.x, e.position.y), _iso(e.end.x, e.position.y), _iso(e.end.x, e.end.y), _iso(e.position.x, e.end.y)]), Color.html("#7fbf40"))
	var lite := Color.html("#8bc948")
	for i in range(floori(e.position.x), ceili(e.end.x)):
		for j in range(floori(e.position.y), ceili(e.end.y)):
			if (i * 73 + j * 151) % 4 == 0 and e.encloses(Rect2(float(i), float(j), 1.0, 1.0)):
				_flat_tile(float(i), float(j), 1.0, 1.0, lite)
	_draw_beach(e, isl)
	_draw_cliffs(e, isl)


## Bãi cát phía trước (hai cạnh gần camera): thấp, sáng, không che mặt bằng.
func _draw_beach(e: Rect2, isl: Rect2) -> void:
	var top := Color.html("#f1de9c")
	var lc := Color.html("#cdb67e")
	var rc := Color.html("#dfca8f")
	_box(e.position.x, e.end.y, e.size.x, isl.end.y - e.end.y, 5.0, top, lc, rc)
	_box(e.end.x, e.position.y, isl.end.x - e.end.x, isl.end.y - e.position.y, 5.0, top, lc, rc)


## Độ cao sống núi tại điểm thứ k: cao ở phía sau, thấp dần về phía trước (u = 0 → 1) rồi hạ thành bãi cát.
func _ridge_h(u: float, k: int) -> float:
	var taper := 1.0 - smoothstep(0.5, 1.0, u)
	var n := 0.78 + 0.44 * float((k * 37 + 11) % 13) / 13.0
	return 6.0 + CLIFF_H * taper * n


## Vách núi liền khối ở hai cạnh phía sau: mặt vách quay vào bãi cỏ, mặt đỉnh nằm sau lưng, sống núi lởm chởm có tảng tròn.
## Mỗi mặt vẽ bằng các dải tứ giác lồi (một đa giác lớn có thể tự cắt nên không tô được).
func _draw_cliffs(e: Rect2, isl: Rect2) -> void:
	var wall := Color.html("#7d5a42")
	var wall2 := Color.html("#8e6a4d")
	var top := Color.html("#a88360")
	var boulder := Color.html("#b8926c")
	# --- Cạnh sau-trái: x ∈ [isl.x0, e.x0], chạy dọc theo y ---
	var nl := maxi(2, int(ceil((isl.end.y - isl.position.y) / 0.5)))
	var span := maxf(0.1, isl.end.y - e.position.y)
	var in_t := PackedVector2Array()
	var out_t := PackedVector2Array()
	var base := PackedVector2Array()
	var mid := PackedVector2Array()
	var face_t := PackedVector2Array()
	for k in nl + 1:
		var y := isl.position.y + (isl.end.y - isl.position.y) * float(k) / float(nl)
		var h := _ridge_h(clampf((y - e.position.y) / span, 0.0, 1.0), k)
		var it := _iso(e.position.x, y, h)
		in_t.append(it)
		out_t.append(_iso(isl.position.x, y, h))
		if y >= e.position.y - 0.01:
			base.append(_iso(e.position.x, y, 0.0))
			mid.append(_iso(e.position.x, y, h * 0.5))
			face_t.append(it)
	_strip(out_t, in_t, top)
	_strip(base, face_t, wall)
	draw_polyline(mid, Color(0, 0, 0, 0.22), 2.0)
	_edge(out_t, in_t)
	_edge(base, face_t)
	for k in nl + 1:
		_boulder(in_t[k] + Vector2(-5, 2), 8.0 + float((k * 7) % 5) * 1.8, boulder, float(k))
	# --- Cạnh sau-phải: y ∈ [isl.y0, e.y0], chạy dọc theo x ---
	var nr := maxi(2, int(ceil((isl.end.x - e.position.x) / 0.5)))
	var span2 := maxf(0.1, isl.end.x - e.position.x)
	var in_t2 := PackedVector2Array()
	var out_t2 := PackedVector2Array()
	var base2 := PackedVector2Array()
	var mid2 := PackedVector2Array()
	for k in nr + 1:
		var x := e.position.x + span2 * float(k) / float(nr)
		var h2 := _ridge_h(clampf((x - e.position.x) / span2, 0.0, 1.0), k + 5)
		in_t2.append(_iso(x, e.position.y, h2))
		out_t2.append(_iso(x, isl.position.y, h2))
		base2.append(_iso(x, e.position.y, 0.0))
		mid2.append(_iso(x, e.position.y, h2 * 0.5))
	_strip(out_t2, in_t2, top)
	_strip(base2, in_t2, wall2)
	draw_polyline(mid2, Color(0, 0, 0, 0.22), 2.0)
	_edge(out_t2, in_t2)
	_edge(base2, in_t2)
	for k in range(1, nr + 1):
		_boulder(in_t2[k] + Vector2(5, 2), 8.0 + float((k * 5) % 5) * 1.8, boulder, float(k))


## Dải tứ giác giữa hai đường a và b (cùng số điểm).
func _strip(a: PackedVector2Array, b: PackedVector2Array, col: Color) -> void:
	for k in a.size() - 1:
		draw_colored_polygon(PackedVector2Array([a[k], a[k + 1], b[k + 1], b[k]]), col)


## Viền mực quanh một dải: hai cạnh dài và hai đầu.
func _edge(a: PackedVector2Array, b: PackedVector2Array) -> void:
	var ow := _ow()
	draw_polyline(a, INK, ow)
	draw_polyline(b, INK, ow)
	draw_line(a[0], b[0], INK, ow)
	draw_line(a[a.size() - 1], b[b.size() - 1], INK, ow)


## Tảng đá tròn có viền trên sống núi (làm bờ núi bớt vuông vức).
func _boulder(c: Vector2, r: float, col: Color, seed_v: float) -> void:
	var ow := _ow()
	draw_circle(c, r + ow, INK)
	draw_circle(c, r, col.lerp(Color.html("#9c7757"), fposmod(seed_v * 0.37, 1.0) * 0.6))
	draw_circle(c + Vector2(-r * 0.28, -r * 0.32), r * 0.5, col.lightened(0.12))


# ---------- cải tạo đất: dọn đá, phát quang ----------

func _stake(base: Vector2, col: Color) -> void:
	var ow := _ow()
	draw_line(base, base + Vector2(0, -30), INK, ow + 1.5)
	draw_line(base, base + Vector2(0, -30), Color.html("#efe9cc"), 2.0)
	_poly([base + Vector2(0, -30), base + Vector2(17, -24), base + Vector2(0, -18)], col, ow * 0.6)


## Viền nét đứt + cọc cờ quanh lô đang thi công (vẽ sau cùng để không bị vách che).
func _draw_reclaim() -> void:
	var st := _land_stage()
	if st >= 2:
		return
	var land: Dictionary = Game.s.land
	if int(land.left) <= 0:
		return
	var tr := _region(st + 1)
	var ow := _ow()
	var corners := [_iso(tr.position.x, tr.position.y), _iso(tr.end.x, tr.position.y), _iso(tr.end.x, tr.end.y), _iso(tr.position.x, tr.end.y)]
	for e in 4:
		draw_dashed_line(corners[e], corners[(e + 1) % 4], Color.html("#ff8a3d"), ow * 0.9, 10.0)
	for e in 4:
		_stake(corners[e], Color.html("#ff8a3d"))


func _draw_land_marker(cr: Rect2) -> void:
	var c := _iso(cr.end.x + 0.35, cr.end.y + 0.35, 26.0 + (0.0 if _reduce_motion else sin(_t * 3.0) * 4.0))
	draw_circle(c, 19.0 + _ow(), INK)
	draw_circle(c, 19.0, UIKit.IGNITE)
	draw_rect(Rect2(c.x - 9, c.y - 2, 18, 4), INK)
	draw_rect(Rect2(c.x - 2, c.y - 9, 4, 18), INK)


## Chỗ máy ủi đứng: mép phải của vùng cỏ đang nở ra.
func _digger_at() -> Vector2:
	return Vector2(_eff.end.x + 0.1, _eff.position.y + _eff.size.y * 0.55)


## Máy ủi vàng + bụi bốc lên, hoạt động trong lúc cải tạo.
func _draw_digger() -> void:
	var at := _digger_at()
	var gx := at.x
	var gy := at.y - 0.3
	var bob := 0.0 if _reduce_motion else sin(_t * 9.0) * 0.8
	_box(gx, gy, 0.9, 0.6, 7.0, Color.html("#4a5058"), Color.html("#2c3036"), Color.html("#3a3f46"), bob)
	_box(gx + 0.08, gy + 0.1, 0.62, 0.4, 13.0, Color.html("#f2c23c"), Color.html("#c99a22"), Color.html("#deaa2d"), 7.0 + bob)
	_box(gx + 0.12, gy + 0.16, 0.28, 0.26, 12.0, Color.html("#e8eef4"), Color.html("#9db0c6"), Color.html("#b9c8d6"), 20.0 + bob)
	_box(gx - 0.06, gy + 0.05, 0.12, 0.5, 9.0, Color.html("#8a9199"), Color.html("#5d636a"), Color.html("#757c84"), 3.0)
	for k in 7:
		var ph := 0.3 if _reduce_motion else fposmod(_t * 0.9 + float(k) / 7.0, 1.0)
		var pp := _iso(at.x + 0.4 + (float(k % 3) - 1.0) * 0.35, at.y + (float(k % 2) - 0.5) * 0.4, 8.0 + ph * 46.0)
		draw_circle(pp, 9.0 + ph * 12.0, Color(0.78, 0.68, 0.52, 0.55 * (1.0 - ph)))


## Cọ trên bãi cát phía trước đảo.
func _add_palms() -> void:
	var e := _eff
	var pts: Array = []
	for f in [0.25, 0.75]:
		pts.append(Vector2(e.end.x + RIM * 0.55, e.position.y + e.size.y * f))
		pts.append(Vector2(e.position.x + e.size.x * f, e.end.y + RIM * 0.55))
	for i in pts.size():
		var pg: Vector2 = pts[i]
		_items.append([pg.x + pg.y, _draw_palm.bind(_iso(pg.x, pg.y), 0.58 + 0.08 * float(i % 3), float(i) * 1.9)])


# ---------- ô cát dưới công trình ----------

func _plot(r: Rect2) -> void:
	var q := r.intersection(_eff.grow(-0.1))
	if q.size.x < 0.3 or q.size.y < 0.3:
		return
	var pts := _rrect(q, minf(0.3, minf(q.size.x, q.size.y) * 0.4), 3)
	draw_colored_polygon(pts, Color.html("#efdca2"))
	var ln := pts.duplicate()
	ln.append(pts[0])
	draw_polyline(ln, Color(0.55, 0.42, 0.2, 0.75), 2.5)


func _add_plots() -> void:
	var s: Dictionary = Game.s
	var f_: Dictionary = s.fac
	var rects: Array = [CTRL_AT.grow(0.3)]
	for i in s.pads.size():
		var pc: Vector2 = PAD_SLOTS[i]
		rects.append(Rect2(pc.x - PAD_SIZE * 0.5 - 0.35, pc.y - PAD_SIZE * 0.5 - 0.35, PAD_SIZE + 0.7, PAD_SIZE + 0.7))
	if int(f_.asm) > 0:
		rects.append(ASM_AT.grow(0.3))
	if int(f_.shop) > 0:
		rects.append(SHOP_AT.grow(0.3))
	if int(f_.wx) > 0:
		rects.append(Rect2(WX_AT.x - 0.55, WX_AT.y - 0.55, 1.1, 1.1))
	if int(f_.fuel) > 0:
		rects.append(Rect2(8.0, 6.9, 2.0, 1.7))
	for r in rects:
		var c := (r as Rect2).get_center()
		_items.append([c.x + c.y - 8.0, _plot.bind(r)])


# ---------- danh sách vẽ theo độ sâu ----------

func _build_items() -> void:
	var s: Dictionary = Game.s
	var st: int = int(s.land.stage)
	_add_plots()
	_add_palms()
	# Cây, bụi, hoa chỉ mọc trên vùng cỏ đang có.
	var grass := _eff.grow(-0.25)
	for f in _flowers:
		var fg: Vector2 = f
		if grass.has_point(fg):
			_items.append([fg.x + fg.y - 0.5, _draw_flower.bind(fg)])
	for b in _bushes:
		var bg: Vector2 = b.g
		if grass.has_point(bg):
			_items.append([bg.x + bg.y, _draw_bush.bind(b)])

	var f_: Dictionary = s.fac
	var cur: Dictionary = {} if running else Game.current_sel()

	# Trung tâm điều khiển (luôn có): chạm để mở hợp đồng.
	var cc := CTRL_AT
	_items.append([cc.position.x + cc.position.y + cc.size.x, _draw_control])
	_reg("contracts", 0, _iso(cc.position.x + cc.size.x * 0.5, cc.position.y + cc.size.y * 0.5, 30.0), 56.0)

	# Công trình: chỉ có ô trống để xây khi đã cải tạo Lô II.
	_facility_item("asm", f_.asm, ASM_AT)
	_facility_item("shop", f_.shop, SHOP_AT)
	if int(f_.wx) > 0 or st >= 1:
		_items.append([WX_AT.x + WX_AT.y, _draw_weather_mast.bind(int(f_.wx))])
		_reg("fac", "wx", _iso(WX_AT.x, WX_AT.y, 40.0), 44.0)
	var fuel_lv: int = f_.fuel
	if fuel_lv == 0:
		if st >= 1:
			var fr := Rect2(FUEL_AT[0].x - 0.5, FUEL_AT[0].y - 0.5, 1.8, 1.8)
			_items.append([fr.position.x + fr.position.y + 1.8, _draw_marker.bind(fr, "fuel")])
			_reg("fac", "fuel", _iso(fr.position.x + 0.9, fr.position.y + 0.9, 20.0), 56.0)
	else:
		for i in fuel_lv:
			var fp: Vector2 = FUEL_AT[i]
			_items.append([fp.x + fp.y, _draw_tank.bind(fp)])
		var f0: Vector2 = FUEL_AT[0]
		_reg("fac", "fuel", _iso(f0.x + 0.2, f0.y + 0.2, 24.0), 58.0)

	# Bệ phóng + ô bệ mới.
	var n: int = s.pads.size()
	for i in n:
		var pad: Dictionary = s.pads[i]
		var c: Vector2 = PAD_SLOTS[i]
		var sel: bool = (not running) and (not cur.p.is_empty()) and cur.p.id == pad.id
		_items.append([c.x + c.y, _draw_pad.bind(c, pad, sel)])
		_reg("pad", pad.id, _iso(c.x, c.y, PAD_H + 50.0), 76.0)
		if sel and not cur.r.is_empty() and not running:
			_items.append([c.x + c.y + 0.6, _draw_rocket_at.bind(_iso(c.x, c.y, PAD_H), cur.r.type, 1.0, 0.0, 0.0)])
	if n < 3 and st >= 1:
		var c2: Vector2 = PAD_SLOTS[n]
		var r2 := Rect2(c2.x - PAD_SIZE * 0.5, c2.y - PAD_SIZE * 0.5, PAD_SIZE, PAD_SIZE)
		_items.append([c2.x + c2.y, _draw_marker.bind(r2, "pad")])
		_reg("newpad", n, _iso(c2.x, c2.y, 26.0), 62.0)

	# Cải tạo đất: máy ủi khi đang thi công, bong bóng "+" khi còn có thể cải tạo.
	if st < 2:
		if int(s.land.left) > 0:
			var da := _digger_at()
			_items.append([da.x + da.y + 1.0, _draw_digger])
			_reg("land", 0, _iso(da.x + 0.5, da.y, 26.0), 70.0)
		else:
			var cr := _eff
			_items.append([cr.end.x + cr.end.y + 3.0, _draw_land_marker.bind(cr)])
			_reg("land", 0, _iso(cr.end.x + 0.35, cr.end.y + 0.35, 24.0), 62.0)


func _facility_item(key: String, lv: int, r: Rect2) -> void:
	if lv == 0 and _land_stage() < 1:
		return    # chưa có đất để xây: chưa hiện ô trống
	var c := r.get_center()
	if lv == 0:
		_items.append([c.x + c.y, _draw_marker.bind(r, key)])
	elif key == "asm":
		_items.append([c.x + c.y, _draw_hall.bind(r, lv)])
	else:
		_items.append([c.x + c.y, _draw_shop.bind(r, lv)])
	_reg("fac", key, _iso(c.x, c.y, 30.0), 64.0)


func _reg(kind: String, key: Variant, world_pos: Vector2, r_world: float) -> void:
	_anchors.append({"kind": kind, "key": key, "pos": _s(world_pos), "r": maxf(r_world * _sc, 30.0)})


# ---------- cây, bụi, hoa ----------

func _foliage(base: Vector2, circles: Array, col: Color, k: float) -> void:
	_ell(base + Vector2(0, 3), 30.0 * k, 11.0 * k, Color(0.12, 0.3, 0.12, 0.3))
	var ow := _ow()
	for c in circles:
		draw_circle(base + Vector2(c.x, c.y) * k, c.z * k + ow, INK)
	for c in circles:
		draw_circle(base + Vector2(c.x, c.y) * k, c.z * k, col)
	for c in circles:
		draw_circle(base + Vector2(c.x - c.z * 0.22, c.y - c.z * 0.32) * k, c.z * 0.55 * k, col.lightened(0.2))


func _draw_bush(b: Dictionary) -> void:
	var g: Vector2 = b.g
	var base := _iso(g.x, g.y)
	var k: float = b.k
	var col: Color = b.col
	if b.tree:
		var tk := 1.0 * k
		_poly([base + Vector2(-8, 0) * tk, base + Vector2(8, 0) * tk, base + Vector2(5, -46) * tk, base + Vector2(-5, -46) * tk], Color.html("#d99c4e"))
		_foliage(base, [Vector3(0, -78, 34), Vector3(-27, -56, 26), Vector3(27, -58, 27), Vector3(0, -50, 30)], col, tk)
	else:
		_foliage(base, [Vector3(0, -14, 17), Vector3(-17, -8, 13), Vector3(17, -9, 14), Vector3(0, -5, 15)], col, k)


## Cây dừa: thân cong có viền, tán lá cọ xòe đung đưa nhẹ (nhóm cây ven biển).
func _draw_palm(base: Vector2, k: float, ph: float) -> void:
	var ow := _ow()
	_ell(base + Vector2(0, 3), 26.0 * k, 9.0 * k, Color(0.1, 0.25, 0.2, 0.28))
	var sway := 0.0 if _reduce_motion else sin(_t * 1.3 + ph) * 3.0
	var top := base + Vector2((9.0 + sway) * k, -84.0 * k)
	var trunk := _curve(base, base + Vector2(-9.0 * k, -42.0 * k), top, 10)
	draw_polyline(trunk, INK, 10.0 * k + ow * 2.0, true)
	draw_polyline(trunk, Color.html("#d99c4e"), 10.0 * k, true)
	draw_polyline(trunk, Color.html("#eab86e"), 3.0 * k, true)
	var leaf := Color.html("#4fb04a")
	var angs: Array = [-2.75, -2.2, -1.45, -0.7, -0.2, 0.35]
	for i in angs.size():
		var a: float = float(angs[i]) + (0.0 if _reduce_motion else sin(_t * 1.6 + ph + float(i)) * 0.05)
		_palm_frond(top, a, (50.0 if i % 2 == 0 else 42.0) * k, k, leaf if i % 2 == 0 else leaf.lightened(0.14))
	draw_circle(top + Vector2(-5, 5) * k, 5.0 * k + ow * 0.6, INK)
	draw_circle(top + Vector2(-5, 5) * k, 5.0 * k, Color.html("#8a5a2b"))
	draw_circle(top + Vector2(5, 6) * k, 5.0 * k + ow * 0.6, INK)
	draw_circle(top + Vector2(5, 6) * k, 5.0 * k, Color.html("#8a5a2b"))


func _palm_frond(origin: Vector2, a: float, len: float, k: float, col: Color) -> void:
	var dir := Vector2(cos(a), sin(a))
	var tip := origin + dir * len + Vector2(0, 17.0 * k)
	var ctrl := origin + dir * len * 0.55 + Vector2(0, -15.0 * k)
	var c := _curve(origin, ctrl, tip, 8)
	var left: Array = []
	var right: Array = []
	for i in c.size():
		var t := float(i) / float(c.size() - 1)
		var d: Vector2 = (c[mini(i + 1, c.size() - 1)] - c[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-d.y, d.x)
		var w := lerpf(8.0, 0.8, t) * k
		left.append(c[i] + nrm * w)
		right.append(c[i] - nrm * w)
	right.reverse()
	left.append_array(right)
	_poly(left, col)


func _draw_flower(g: Vector2) -> void:
	var c := _iso(g.x, g.y)
	draw_circle(c, 5.5, INK)
	draw_circle(c, 3.8, Color.html("#fffbe8"))
	draw_circle(c, 1.5, Color.html("#f6c33b"))


# ---------- công trình ----------

func _draw_control() -> void:
	var r := CTRL_AT
	_box(r.position.x, r.position.y, r.size.x, r.size.y, 44.0, Color.html("#8fb7d8"), Color.html("#5f89ad"), Color.html("#7aa3c6"))
	var win := Color.html("#fff3b0")
	for i in 3:
		var u0 := 0.12 + i * 0.3
		_wall_l(r.position.x, r.position.y, r.size.x, r.size.y, u0, u0 + 0.2, 0.3, 0.62, win)
		_wall_r(r.position.x, r.position.y, r.size.x, r.size.y, u0, u0 + 0.2, 0.3, 0.62, win)
	# Ăng-ten + đèn báo.
	var top := _iso(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, 44.0)
	draw_line(top, top + Vector2(0, -34), INK, _ow() + 1.5)
	draw_line(top, top + Vector2(0, -34), Color.html("#dfe6ee"), 2.0)
	var blink := (int(_t / 0.6) % 2 == 1) and not _reduce_motion
	draw_circle(top + Vector2(0, -36), 5.0 + _ow() * 0.5, INK)
	draw_circle(top + Vector2(0, -36), 4.0, Color.html("#ff5a4a") if blink else Color.html("#a8483f"))


func _draw_hall(r: Rect2, lv: int) -> void:
	var w := r.size.x + (lv - 1) * 0.2
	var h := 38.0 + lv * 11.0
	_box(r.position.x, r.position.y, w, r.size.y, h, Color.html("#d6dde6"), Color.html("#7f93ab"), Color.html("#9db0c6"))
	# Cổng lớn + vạch cảnh báo.
	_wall_l(r.position.x, r.position.y, w, r.size.y, 0.28, 0.72, 0.0, h * 0.72 / h, Color.html("#32404e"))
	_wall_l(r.position.x, r.position.y, w, r.size.y, 0.0, 1.0, 0.0, 0.1, Color.html("#f2b04c"))
	_wall_r(r.position.x, r.position.y, w, r.size.y, 0.0, 1.0, 0.0, 0.1, Color.html("#e29a30"))
	for i in lv:
		var u := 0.12 + i * 0.12
		_wall_r(r.position.x, r.position.y, w, r.size.y, u, u + 0.07, 0.45, 0.8, Color.html("#fff3b0"))


func _draw_shop(r: Rect2, lv: int) -> void:
	var h := 26.0 + lv * 4.0
	_box(r.position.x, r.position.y, r.size.x, r.size.y, h, Color.html("#f4e2b0"), Color.html("#c9a56b"), Color.html("#dcb97c"))
	_wall_l(r.position.x, r.position.y, r.size.x, r.size.y, 0.2, 0.46, 0.2, 0.62, Color.html("#fff3b0"))
	_wall_l(r.position.x, r.position.y, r.size.x, r.size.y, 0.58, 0.82, 0.0, 0.55, Color.html("#5a3b24"))
	# Mái đỏ nhô ra.
	_box(r.position.x - 0.12, r.position.y - 0.12, r.size.x + 0.24, r.size.y + 0.24, 9.0, Color.html("#ef7b52"), Color.html("#c25a38"), Color.html("#d96b46"), h)


func _draw_weather_mast(lv: int) -> void:
	var base := _iso(WX_AT.x, WX_AT.y)
	_ell(base + Vector2(0, 2), 20.0, 8.0, Color(0.1, 0.25, 0.3, 0.25))
	if lv == 0:
		_draw_marker(Rect2(WX_AT.x - 0.5, WX_AT.y - 0.5, 1.0, 1.0), "wx")
		return
	var mh := 64.0 + lv * 14.0
	var top := base + Vector2(0, -mh)
	draw_line(base, top, INK, _ow() + 3.0)
	draw_line(base, top, Color.html("#e8eef4"), 3.0)
	var rot := 0.4 if _reduce_motion else _t * 1.4
	_xf(top, rot)
	draw_rect(Rect2(-17, -4, 34, 8), INK)
	draw_rect(Rect2(-15, -2.5, 30, 5), Color.html("#f2f6fa"))
	_xf()
	draw_circle(top, 6.0 + _ow() * 0.5, INK)
	draw_circle(top, 5.0, Color.html("#1fa896"))


func _draw_tank(fp: Vector2) -> void:
	var base := _iso(fp.x, fp.y)
	_ell(base + Vector2(0, 2), 32.0, 12.0, Color(0.1, 0.25, 0.3, 0.28))
	# Chân đỡ + thân cầu.
	_poly([base + Vector2(-17, 0), base + Vector2(-9, -18), base + Vector2(9, -18), base + Vector2(17, 0)], Color.html("#8a99a8"))
	var c := base + Vector2(0, -36)
	draw_circle(c, 24.0 + _ow(), INK)
	draw_circle(c, 24.0, Color.html("#e4ebf1"))
	draw_circle(c + Vector2(-6, -7), 13.0, Color.html("#f8fbfd"))
	draw_arc(c, 24.0, 0.2, PI - 0.2, 16, Color(0.55, 0.62, 0.7, 0.9), 5.0)
	draw_rect(Rect2(c.x - 21, c.y - 2, 42, 5), Color.html("#ff8a3d"))


func _draw_marker(r: Rect2, key: String) -> void:
	# Ô trống: viền nét đứt + bong bóng "+" kèm giá.
	var ink := Color(INK.r, INK.g, INK.b, 0.75)
	var pts := [_iso(r.position.x, r.position.y), _iso(r.end.x, r.position.y), _iso(r.end.x, r.end.y), _iso(r.position.x, r.end.y)]
	draw_colored_polygon(PackedVector2Array(pts), Color(1, 1, 1, 0.22))
	for i in 4:
		draw_dashed_line(pts[i], pts[(i + 1) % 4], ink, _ow() * 0.8, 9.0)
	var c := _iso(r.get_center().x, r.get_center().y, 24.0 + (0.0 if _reduce_motion else sin(_t * 3.0) * 4.0))
	draw_circle(c, 17.0 + _ow(), INK)
	draw_circle(c, 17.0, UIKit.ACCENT)
	draw_rect(Rect2(c.x - 8, c.y - 2, 16, 4), Color.WHITE)
	draw_rect(Rect2(c.x - 2, c.y - 8, 4, 16), Color.WHITE)


func _draw_pad(c: Vector2, pad: Dictionary, selected: bool) -> void:
	var gx := c.x - PAD_SIZE * 0.5
	var gy := c.y - PAD_SIZE * 0.5
	if selected:
		var pulse := 1.0 if _reduce_motion else 0.5 + 0.5 * sin(_t * 3.2)
		var e := 0.38
		var ring := PackedVector2Array([_iso(gx - e, gy - e), _iso(gx + PAD_SIZE + e, gy - e), _iso(gx + PAD_SIZE + e, gy + PAD_SIZE + e), _iso(gx - e, gy + PAD_SIZE + e)])
		draw_colored_polygon(ring, Color(0.12, 0.66, 0.59, 0.28 + 0.18 * pulse))
		var rl := ring.duplicate()
		rl.append(ring[0])
		draw_polyline(rl, UIKit.ACCENT, 4.0)
	_box(gx, gy, PAD_SIZE, PAD_SIZE, PAD_H, Color.html("#d4d9dc"), Color.html("#8e99a3"), Color.html("#aab4bd"))
	# Rãnh dẫn lửa.
	var m := 0.42
	_flat_tile(gx + m, gy + m, PAD_SIZE - 2.0 * m, PAD_SIZE - 2.0 * m, Color.html("#4a535b"), PAD_H)
	if pad.busy > 0:
		var ow := _ow()
		var q := [_iso(gx + 0.08, gy + 0.08, PAD_H), _iso(gx + PAD_SIZE - 0.08, gy + 0.08, PAD_H), _iso(gx + PAD_SIZE - 0.08, gy + PAD_SIZE - 0.08, PAD_H), _iso(gx + 0.08, gy + PAD_SIZE - 0.08, PAD_H)]
		for i in 4:
			draw_line(q[i], q[(i + 1) % 4], INK, ow)
			draw_dashed_line(q[i], q[(i + 1) % 4], Color.html("#f6c33b"), ow * 0.8, 8.0)
	# Tháp phóng ở góc sau-phải của bệ.
	var th: float = 90.0 + float(pad.lvl) * 34.0
	var tx := gx + PAD_SIZE - 0.34
	var ty := gy + 0.04
	_box(tx, ty, 0.3, 0.3, th, Color.html("#cfd8e1"), Color.html("#7c8ea1"), Color.html("#9bacbd"), PAD_H)
	var z := PAD_H + 6.0
	while z < PAD_H + th - 10.0:
		draw_line(_iso(tx, ty + 0.3, z), _iso(tx + 0.3, ty + 0.3, z + 14.0), INK, _ow() * 0.55)
		draw_line(_iso(tx + 0.3, ty + 0.3, z), _iso(tx + 0.3, ty, z + 14.0), INK, _ow() * 0.55)
		z += 18.0
	# Cần giàn nối ra thân tàu.
	var arm_a := _iso(tx, ty + 0.15, PAD_H + th * 0.72)
	var arm_b := _iso(c.x + 0.1, c.y - 0.1, PAD_H + th * 0.72)
	draw_line(arm_a, arm_b, INK, _ow() + 3.0)
	draw_line(arm_a, arm_b, Color.html("#b9c8d6"), 3.0)
	var blink := (int(_t / 0.6) % 2 == 1) and not _reduce_motion
	var tt := _iso(tx + 0.15, ty + 0.15, PAD_H + th + 4.0)
	draw_circle(tt, 4.5 + _ow() * 0.5, INK)
	draw_circle(tt, 3.5, Color.html("#ff5a4a") if blink else Color.html("#a8483f"))


# ---------- tên lửa ----------

func _draw_rocket_at(pos: Vector2, type: String, sc: float, flame: float, ang: float) -> void:
	var R: Dictionary = GameData.ROCKETS[type]
	var h: float = R.h * sc * ROCKET_K
	var w: float = R.w * sc * ROCKET_K
	var band := Color.html(R.band)
	var body := Color.html("#fbf7ea")
	var ow := _ow()
	_xf(pos, ang)
	if flame > 0.0:
		var fl := (40.0 + randf() * 22.0) * flame * sc * (w / 22.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.46, 0), Vector2(w * 0.46, 0), Vector2(0, fl)]), Color.html("#ff8a3d"))
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.26, 0), Vector2(w * 0.26, 0), Vector2(0, fl * 0.66)]), Color.html("#ffe08a"))
	if type == "condor":
		var bc := Color.html("#d9dfe6")
		for sx in [-1.0, 1.0]:
			var bx: float = sx * (w * 0.5 + 6.0 * sc)
			_poly([Vector2(bx - 6.0 * sc, 0), Vector2(bx + 6.0 * sc, 0), Vector2(bx + 6.0 * sc, -h * 0.5), Vector2(bx, -h * 0.62), Vector2(bx - 6.0 * sc, -h * 0.5)], bc)
	# Cánh đuôi
	for sx in [-1.0, 1.0]:
		_poly([Vector2(sx * w * 0.5, 0), Vector2(sx * (w * 0.5 + 11.0 * sc), 4.0 * sc), Vector2(sx * w * 0.5, -h * 0.3)], band)
	# Thân + mũi
	var pts := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(-w * 0.5, -h * 0.82)])
	for v in _curve(Vector2(-w * 0.5, -h * 0.82), Vector2(0, -h * 1.22), Vector2(w * 0.5, -h * 0.82), 10):
		pts.append(v)
	pts.append(Vector2(w * 0.5, 0))
	_poly(pts, body)
	# Nửa phải tối hơn (hai tông phẳng).
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.14, -h * 0.02), Vector2(w * 0.46, -h * 0.02), Vector2(w * 0.46, -h * 0.8), Vector2(w * 0.14, -h * 0.9)]), Color(0.78, 0.74, 0.62, 0.55))
	# Đai màu + cửa sổ
	draw_rect(Rect2(-w * 0.5 + ow * 0.4, -h * 0.5, w - ow * 0.8, h * 0.1), band)
	draw_line(Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5), INK, ow * 0.6)
	draw_line(Vector2(-w * 0.5, -h * 0.4), Vector2(w * 0.5, -h * 0.4), INK, ow * 0.6)
	draw_circle(Vector2(0, -h * 0.68), maxf(4.0, w * 0.17) + ow * 0.5, INK)
	draw_circle(Vector2(0, -h * 0.68), maxf(4.0, w * 0.17), Color.html("#7fd6ff"))
	draw_circle(Vector2(-w * 0.04, -h * 0.7), maxf(1.5, w * 0.06), Color(1, 1, 1, 0.8))
	_xf()


func _draw_flight(n: int, rise: float, rx: float, ang: float, rsc: float) -> void:
	var c: Vector2 = PAD_SLOTS[mini(int(desc.pad_index), PAD_SLOTS.size() - 1)]
	var base := _iso(c.x, c.y, PAD_H)
	_xf()
	if _p < 0.4 and _boom_t < 0.0 and _stage != "count":
		for i in 2:
			_puffs.append({"x": base.x + randf_range(-26, 26), "y": base.y - 4.0, "vx": randf_range(-2.4, 2.4), "vy": randf_range(-1.0, -0.2), "r": randf_range(9, 16), "life": 1.0})
	for q in _puffs:
		q.x += q.vx
		q.y += q.vy
		q.r += 0.6
		q.life -= 0.012
	_puffs = _puffs.filter(func(q): return q.life > 0.0)
	for q in _puffs:
		draw_circle(Vector2(q.x, q.y), q.r, Color(1, 1, 1, q.life * 0.7))
	if _boom_t < 0.0:
		if _p < 0.3 and _stage != "count":
			draw_circle(base, 56.0, Color(1.0, 0.7, 0.3, 0.28 * (1.0 - _p / 0.3)))
		_draw_rocket_at(base + Vector2(rx, -rise), desc.r.type, rsc, (0.5 if _ignite else 0.0) if _stage == "count" else 1.0, ang)
	else:
		var bx := base.x + 90.0 * _p_fail * _p_fail
		var by := base.y - 1500.0 * pow(_p_fail, 1.8)
		for q in _boom_parts:
			var px: float = bx + q.vx * _boom_t * 90.0
			var py: float = by + q.vy * _boom_t * 90.0 + 130.0 * _boom_t * _boom_t
			var col: Color = q.c
			col.a = clampf(1.0 - _boom_t / 1.8, 0.0, 1.0)
			draw_circle(Vector2(px, py), q.r * (1.0 + _boom_t), col)
		if _boom_t < 0.25:
			draw_circle(Vector2(bx, by), 70.0 + _boom_t * 280.0, Color(1.0, 0.95, 0.8, 0.9 - _boom_t * 3.4))
	_xf()


# ---------- nhãn, mây, thời tiết ----------

func _chip(sp: Vector2, text: String, col: Color = Color(0, 0, 0, 0)) -> void:
	var fs := 13
	var tw := _disp.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
	var rc := Rect2(clampf(sp.x - tw * 0.5, 4.0, maxf(4.0, size.x - tw - 4.0)), sp.y - 12.0, tw, 24.0)
	draw_style_box(_chip_sb, rc)
	draw_string(_disp, Vector2(rc.position.x + 9.0, rc.position.y + 17.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col if col.a > 0.0 else UIKit.INK)


func _draw_labels() -> void:
	var s: Dictionary = Game.s
	var st: int = int(s.land.stage)
	for i in s.pads.size():
		var pad: Dictionary = s.pads[i]
		var c: Vector2 = PAD_SLOTS[i]
		var txt := "Bệ %s · cấp %d" % [pad.name, pad.lvl]
		if pad.busy > 0:
			txt += " · bận %dn" % pad.busy
		_chip(_s(_iso(c.x + 0.5, c.y + 0.5, 0.0)) + Vector2(0, 30), txt)
	# Nhãn cải tạo đất (luôn hiện khi còn lô để cải tạo).
	if st < 2:
		var L: Dictionary = GameData.LAND[st + 1]
		if int(s.land.left) > 0:
			var da := _digger_at()
			_chip(_s(_iso(da.x + 0.5, da.y + 0.8, 0.0)) + Vector2(0, 30), "Cải tạo %s · còn %dn" % [L.short, int(s.land.left)], UIKit.WARN)
		else:
			var blk: String = Game.reclaim_blocked()
			var cr := _eff
			_chip(_s(_iso(cr.end.x + 0.35, cr.end.y + 0.35, 0.0)) + Vector2(0, 34), "Mở rộng %s" % L.short, UIKit.BAD if blk != "" else UIKit.INK)
	# Công trình / ô trống: không dán nhãn lên cảnh, chạm vào sẽ hiện menu nổi (tên, cấp, giá).


func _draw_clouds(wx: String, a: float) -> void:
	if a > 0.85:
		return
	var drift := 0.0 if _reduce_motion else _t * (3.0 if wx == "wind" else 1.0)
	for c in _clouds:
		var x: float = fposmod(c.x * (size.x + 300.0) + drift * c.v, size.x + 300.0) - 150.0
		var y: float = c.y * size.y
		var col := Color(1, 1, 1, 0.6)
		if wx == "wind":
			col = Color(0.93, 0.96, 0.98, 0.6)
		if wx == "storm":
			col = Color(0.4, 0.46, 0.54, 0.92)
		col.a *= 1.0 - a
		var k: float = c.s * (1.45 if wx == "storm" else 1.0)
		for e in [[0.0, 0.0, 60.0, 18.0], [-34.0, 7.0, 40.0, 14.0], [36.0, 6.0, 44.0, 15.0]]:
			draw_set_transform_matrix(Transform2D(0.0, Vector2(e[2] * k, e[3] * k), 0.0, Vector2(x + e[0] * k, y + e[1] * k)))
			draw_circle(Vector2.ZERO, 1.0, col)
		_screen_space()


func _draw_weather(wx: String, a: float) -> void:
	if wx == "storm" and a < 0.6:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.1, 0.18, 0.3 * (1.0 - a)))
		var off := 0.0 if _reduce_motion else fposmod(_t * 30.0, 40.0)
		for i in 70:
			var rx2 := float((i * 53) % int(maxf(size.x, 1.0)))
			var ry := fposmod(i * 37.0 + off * 8.0, size.y)
			draw_line(Vector2(rx2, ry), Vector2(rx2 - 5, ry + 15), Color(0.75, 0.85, 0.95, 0.4), 1.6)
		if not _reduce_motion and fposmod(_t, 7.0) < 0.12:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.95, 1.0, 0.24))
	elif wx == "wind" and a < 0.6 and not _reduce_motion:
		for i in 16:
			var x: float = fposmod(float(i * 211) + _t * 260.0, size.x + 200.0) - 100.0
			var y: float = fposmod(float(i * 137), size.y)
			draw_line(Vector2(x, y), Vector2(x + 46.0, y), Color(1, 1, 1, 0.3), 2.0)


# ---------- HUD khi bay ----------

func _phase(p: float) -> String:
	var ph := [[0.0, "Cất cánh"], [0.12, "Max-Q"], [0.3, "Tách tầng 1"], [0.5, "Thả mũ chắn"], [0.72, "Đốt đưa lên quỹ đạo"], [0.95, "Tách tải trọng"]]
	var s: String = ph[0][1]
	for x in ph:
		if p >= x[0]:
			s = x[1]
	return s


func _draw_hud() -> void:
	var o: Dictionary = GameData.ORB[desc.c.orbit]
	var p := _p
	var sec := roundi(p * (540.0 + desc.c.orbit * 900.0))
	var alt: float = o.alt * pow(p, 2.2)
	var vel: float = o.vel * smoothstep(0.0, 1.0, pow(p, 0.8))
	var ink := UIKit.INK
	draw_style_box(_chip_sb, Rect2(12, 12, 250, 108))
	draw_string(_mono, Vector2(24, 36), "T+ %02d:%02d" % [sec / 60, sec % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_string(_mono, Vector2(24, 58), "ĐỘ CAO %s km" % _thousands(roundi(alt)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_string(_mono, Vector2(24, 80), "VẬN TỐC %.1f km/s" % vel, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	var st := "MẤT TÍN HIỆU" if _boom_t >= 0.0 else _phase(p).to_upper()
	draw_string(_mono, Vector2(24, 104), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIKit.BAD if _boom_t >= 0.0 else UIKit.ACCENT)
	var big := clampf(size.y * 0.13, 40.0, 84.0)
	var mid := size.y * 0.32
	if _stage == "count":
		var n := ceili(3.0 - _le / 0.8)
		_outlined(str(n) if n > 0 else "KHỞI ĐỘNG", Vector2(0, mid), big, Color.WHITE)
	elif _end_t >= 0.0:
		_outlined("VÀO QUỸ ĐẠO " + o.label.to_upper(), Vector2(0, mid), big * 0.4, Color.html("#7ee08f"))
	elif _boom_t >= 0.0:
		_outlined(String(desc.out.cause).to_upper(), Vector2(0, mid), big * 0.4, Color.html("#ff7a65"))
	var note := ("x%d" % int(time_scale)) if time_scale > 1.0 else "chạm để tua nhanh"
	draw_string(_mono, Vector2(size.x - 220, 30), note, HORIZONTAL_ALIGNMENT_RIGHT, 208, 14, Color(1, 1, 1, 0.9))


func _outlined(text: String, pos: Vector2, fs: float, col: Color) -> void:
	var o := 3
	for d in [Vector2(o, 0), Vector2(-o, 0), Vector2(0, o), Vector2(0, -o), Vector2(o, o), Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o)]:
		draw_string(_disp, pos + d + Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(fs), INK)
	draw_string(_disp, pos + Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(fs), col)


func _thousands(v: int) -> String:
	var s := str(v)
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "." + out
	return out
