class_name LaunchView
extends Control
## Cảnh bãi phóng nhìn iso nghiêng (kiểu hoạt hình, viền mực dày), vẽ bằng canvas 2D.
## Chiếm toàn màn hình; các bảng điều khiển nổi lên trên (xem main.gd).
## Không đổi trạng thái trò chơi: hoạt ảnh xong chỉ phát `finished`, main.gd mới gọi Game.finish_launch.
## Chạm vào bệ / công trình / ô trống phát `tapped(kind, key)`.

signal finished(desc: Dictionary)
signal tapped(kind: String, key: Variant)

const TW := 96.0              # bề rộng một ô iso
const TH := 48.0              # bề cao một ô iso (tỉ lệ 2:1)
const MAP := 10.0             # đảo là hình vuông 10×10 ô (lưới), nhìn ra hình thoi
const WORLD_W := 1000.0       # khung thế giới cần hiện vừa màn hình
const WORLD_H := 560.0
const WORLD_CY := 250.0       # tâm khung theo trục dọc (tọa độ thế giới)
const COUNT := 2.4            # giây đếm ngược
const FLIGHT := 9.0           # giây bay
const PAD_SLOTS: Array = [Vector2(5.0, 5.0), Vector2(3.2, 6.8), Vector2(6.8, 3.2)]
const PAD_SIZE := 1.6
const PAD_H := 7.0
const ROCKET_K := 1.9         # hệ số phóng to kích thước tàu (data.gd tính theo 720×400)

# Vị trí công trình trên lưới (góc gx, gy và kích thước ô).
const SHOP_AT := Rect2(0.9, 4.5, 1.4, 1.4)
const WX_AT := Vector2(8.4, 4.7)
const ASM_AT := Rect2(6.3, 0.7, 2.0, 1.6)
const FUEL_AT: Array = [Vector2(7.9, 6.3), Vector2(8.6, 7.0), Vector2(7.2, 7.1)]
const CTRL_AT := Rect2(1.9, 1.9, 1.8, 1.8)

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
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	_disp = SystemFont.new()
	_disp.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Segoe UI"])
	_chip_sb = UIKit.flat(UIKit.PANEL, UIKit.LINE, 2, 8)
	_reduce_motion = ProjectSettings.get_setting("gui/theme/reduce_motion", false)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Cây và bụi rải ở dải cỏ quanh quảng trường, tránh chỗ công trình.
func _make_scenery(rng: RandomNumberGenerator) -> void:
	var core := Rect2(1.2, 1.2, 7.6, 7.6)
	var avoid: Array = [Rect2(5.9, 0.1, 3.5, 2.8), Rect2(0.3, 3.9, 2.6, 2.7)]
	var tries := 0
	while _bushes.size() < 62 and tries < 2000:
		tries += 1
		var g := Vector2(rng.randf() * MAP, rng.randf() * MAP)
		if core.has_point(g):
			continue
		var bad := false
		for a in avoid:
			if (a as Rect2).has_point(g):
				bad = true
		for b in _bushes:
			if (b.g as Vector2).distance_to(g) < 0.62:
				bad = true
		if bad:
			continue
		# Phía trước (gần camera) chỉ bụi thấp để không che quảng trường; cây cao ở phía sau và hai bên.
		var depth: float = g.x + g.y
		var tree: bool = rng.randf() < (0.55 if depth < 9.0 else (0.22 if depth < 13.0 else 0.0))
		var hue: float = rng.randf()
		var col := Color.html("#9fd13f").lerp(Color.html("#6fc24a"), hue)
		_bushes.append({"g": g, "tree": tree, "k": (0.62 + rng.randf() * 0.3) if tree else (0.6 + rng.randf() * 0.35), "col": col})
	for i in 46:
		var g2 := Vector2(rng.randf() * MAP, rng.randf() * MAP)
		if core.has_point(g2):
			continue
		_flowers.append(g2)


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


func _process(delta: float) -> void:
	_t += delta
	if running:
		_step(delta * time_scale)
	queue_redraw()


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
	_sc = minf(avail_w / (WORLD_W if size.x > size.y else 640.0), avail_h / WORLD_H)
	_ox = avail_w * 0.5
	_oy = top_inset * ik + avail_h * 0.5 - WORLD_CY * _sc + _cam * _sc

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


func _draw_island() -> void:
	var ow := _ow()
	var l := _iso(0.0, MAP)
	var r := _iso(MAP, 0.0)
	var b := _iso(MAP, MAP)
	var tp := _iso(0.0, 0.0)
	var depth := 26.0
	# Bóng đảo trên mặt nước.
	draw_colored_polygon(PackedVector2Array([tp + Vector2(0, 22), r + Vector2(40, 36), b + Vector2(0, 58), l + Vector2(-40, 36)]), Color(0.1, 0.35, 0.45, 0.28))
	# Vách đất phía trước.
	_poly([l, b, b + Vector2(0, depth), l + Vector2(0, depth)], Color.html("#a8743f"))
	_poly([r, b, b + Vector2(0, depth), r + Vector2(0, depth)], Color.html("#c58b4a"))
	# Cỏ + viền cát.
	var sand := 0.35
	_poly([_iso(-sand, -sand), _iso(MAP + sand, -sand), _iso(MAP + sand, MAP + sand), _iso(-sand, MAP + sand)], Color.html("#f1de9c"))
	_poly([tp, r, b, l], Color.html("#8fd150"))
	# Quảng trường đá.
	var q0 := 1.0
	var q1 := 9.0
	var qa := Color.html("#f0e7c9")
	var qb := Color.html("#e4d9b3")
	for i in 8:
		for j in 8:
			_flat_tile(q0 + i, q0 + j, 1.0, 1.0, qa if (i + j) % 2 == 0 else qb)
	_poly([_iso(q0, q0), _iso(q1, q0), _iso(q1, q1), _iso(q0, q1)], Color(0, 0, 0, 0), ow)
	# Ô đá mép bị rêu phủ: vài mảng cỏ lấn vào.
	var moss := Color(0.56, 0.82, 0.31, 0.9)
	for m in [[1.0, 1.0, 1.0, 2.0], [8.0, 1.0, 1.0, 1.0], [1.0, 8.0, 2.0, 1.0], [8.0, 7.0, 1.0, 2.0], [4.0, 8.0, 3.0, 1.0]]:
		_flat_tile(m[0], m[1], m[2], m[3], moss)
	# Vòng khắc giữa quảng trường.
	var ring := PackedVector2Array()
	var ring2 := PackedVector2Array()
	for i in 41:
		var th := TAU * float(i) / 40.0
		ring.append(_iso(5.0 + cos(th) * 1.9, 5.0 + sin(th) * 1.9))
		ring2.append(_iso(5.0 + cos(th) * 1.5, 5.0 + sin(th) * 1.5))
	draw_polyline(ring, Color(0.72, 0.66, 0.5, 0.9), 3.0)
	draw_polyline(ring2, Color(0.72, 0.66, 0.5, 0.6), 2.0)


# ---------- danh sách vẽ theo độ sâu ----------

func _build_items() -> void:
	for f in _flowers:
		var fg: Vector2 = f
		_items.append([fg.x + fg.y - 0.5, _draw_flower.bind(fg)])
	for b in _bushes:
		var bg: Vector2 = b.g
		_items.append([bg.x + bg.y, _draw_bush.bind(b)])

	var s: Dictionary = Game.s
	var f_: Dictionary = s.fac
	var cur: Dictionary = {} if running else Game.current_sel()

	# Trung tâm điều khiển (luôn có): chạm để mở hợp đồng.
	var cc := CTRL_AT
	_items.append([cc.position.x + cc.position.y + cc.size.x, _draw_control])
	_reg("contracts", 0, _iso(cc.position.x + cc.size.x * 0.5, cc.position.y + cc.size.y * 0.5, 30.0), 60.0)

	# Nhà lắp ráp.
	_facility_item("asm", f_.asm, ASM_AT)
	# Xưởng sửa chữa.
	_facility_item("shop", f_.shop, SHOP_AT)
	# Trạm thời tiết (cột nhỏ).
	_items.append([WX_AT.x + WX_AT.y, _draw_weather_mast.bind(int(f_.wx))])
	_reg("fac", "wx", _iso(WX_AT.x, WX_AT.y, 40.0), 44.0)
	# Kho nhiên liệu.
	var fuel_lv: int = f_.fuel
	if fuel_lv == 0:
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
	if n < 3:
		var c2: Vector2 = PAD_SLOTS[n]
		var r2 := Rect2(c2.x - PAD_SIZE * 0.5, c2.y - PAD_SIZE * 0.5, PAD_SIZE, PAD_SIZE)
		_items.append([c2.x + c2.y, _draw_marker.bind(r2, "pad")])
		_reg("newpad", n, _iso(c2.x, c2.y, 26.0), 62.0)


func _facility_item(key: String, lv: int, r: Rect2) -> void:
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
		# Thân cây
		_poly([base + Vector2(-8, 0) * tk, base + Vector2(8, 0) * tk, base + Vector2(5, -46) * tk, base + Vector2(-5, -46) * tk], Color.html("#d99c4e"))
		_foliage(base, [Vector3(0, -78, 34), Vector3(-27, -56, 26), Vector3(27, -58, 27), Vector3(0, -50, 30)], col, tk)
	else:
		_foliage(base, [Vector3(0, -14, 17), Vector3(-17, -8, 13), Vector3(17, -9, 14), Vector3(0, -5, 15)], col, k)


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
	var rc := Rect2(sp.x - tw * 0.5, sp.y - 12.0, tw, 24.0)
	draw_style_box(_chip_sb, rc)
	draw_string(_disp, Vector2(rc.position.x + 9.0, rc.position.y + 17.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col if col.a > 0.0 else UIKit.INK)


func _draw_labels() -> void:
	var s: Dictionary = Game.s
	for i in s.pads.size():
		var pad: Dictionary = s.pads[i]
		var c: Vector2 = PAD_SLOTS[i]
		var txt := "Bệ %s · cấp %d" % [pad.name, pad.lvl]
		if pad.busy > 0:
			txt += " · bận %dn" % pad.busy
		_chip(_s(_iso(c.x + 0.5, c.y + 0.5, 0.0)) + Vector2(0, 30), txt)
	var money: int = s.money
	if _sc < 0.75:
		return    # cảnh nhỏ: nhãn công trình chồng lên nhau, chỉ giữ nhãn bệ; chạm ô để xem chi tiết
	for k in ["shop", "wx", "fuel", "asm"]:
		var lv: int = s.fac[k]
		var f: Dictionary = GameData.FAC[k]
		var at: Vector2
		match k:
			"shop": at = _iso(SHOP_AT.position.x + SHOP_AT.size.x * 0.5, SHOP_AT.end.y, 0.0)
			"wx": at = _iso(WX_AT.x, WX_AT.y + 0.4, 0.0)
			"fuel": at = _iso(FUEL_AT[0].x - 0.2, FUEL_AT[0].y + 1.0, 0.0)
			_: at = _iso(ASM_AT.position.x + ASM_AT.size.x * 0.5, ASM_AT.end.y, 0.0)
		if lv == 0:
			var cost: int = f.cost[0]
			_chip(_s(at) + Vector2(0, 20), "%s · %s" % [f.name, Game.fmt(cost)], UIKit.BAD if money < cost else UIKit.INK)
		else:
			_chip(_s(at) + Vector2(0, 18), "%s · cấp %d/3" % [f.name, lv])
	if s.pads.size() < 3:
		var c2: Vector2 = PAD_SLOTS[s.pads.size()]
		var nc: int = GameData.PAD_NEW[s.pads.size()]
		_chip(_s(_iso(c2.x + 0.4, c2.y + 0.4, 0.0)) + Vector2(0, 26), "Bệ mới · %s" % Game.fmt(nc), UIKit.BAD if money < nc else UIKit.INK)


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
