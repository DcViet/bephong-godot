class_name LaunchView
extends Control
## Cảnh bãi phóng: vẽ bằng canvas 2D của Godot trong hệ tọa độ logic 720×400,
## và chạy đồng hồ đếm ngược + chuyến bay. Không thay đổi trạng thái trò chơi:
## khi hoạt ảnh xong chỉ phát `finished`, `main.gd` mới gọi Game.finish_launch.

signal finished(desc: Dictionary)

const W := 720.0
const H := 400.0
const GY := 330.0        # mặt đất
const BASE := 324.0      # đáy tàu khi đứng trên bệ
const COUNT := 2.4       # giây đếm ngược
const FLIGHT := 9.0      # giây bay

var desc: Dictionary = {}
var running: bool = false
var time_scale: float = 1.0

var _t := 0.0
var _le := 0.0           # thời gian đã trôi của chuyến phóng
var _p := 0.0            # tiến độ bay 0..1
var _stage := "idle"
var _ignite := false
var _boom_t := -1.0
var _p_fail := 0.0
var _end_t := -1.0
var _puffs: Array = []
var _boom_parts: Array = []
var _cam_y := 0.0
var _stars: Array = []
var _clouds: Array = []
var _sky: Dictionary = {}
var _space := Color.html("#02040a")
var _mono: Font
var _disp: Font
var _reduce_motion := false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		_stars.append({"x": rng.randf() * W, "y": rng.randf() * H * 0.8, "r": rng.randf() * 1.2 + 0.4, "ph": rng.randf() * 6.0})
	for i in 7:
		_clouds.append({"x": i * 120.0 + rng.randf() * 60.0, "y": 40.0 + rng.randf() * 150.0, "s": 0.7 + rng.randf() * 0.9, "v": 4.0 + rng.randf() * 6.0})
	_sky = {
		"clear": [Color.html("#0e243e"), Color.html("#4a7c9e")],
		"wind": [Color.html("#122234"), Color.html("#546c7c")],
		"storm": [Color.html("#0e121a"), Color.html("#323c48")],
	}
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	_disp = SystemFont.new()
	_disp.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Segoe UI"])
	_reduce_motion = ProjectSettings.get_setting("gui/theme/reduce_motion", false)
	resized.connect(_fit_height)
	_fit_height.call_deferred()
	mouse_filter = Control.MOUSE_FILTER_PASS


## Giữ tỉ lệ 9:5 của cảnh khi cột giữa đổi bề rộng.
func _fit_height() -> void:
	var h := size.x * H / W
	if absf(custom_minimum_size.y - h) > 0.5:
		custom_minimum_size.y = h


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
	if running and event is InputEventMouseButton and event.pressed:
		time_scale = 4.0


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
			_boom_parts.append({"vx": cos(an) * sp, "vy": sin(an) * sp - 0.4, "r": rng.randf_range(1.5, 4.5), "c": Color.html(cols[rng.randi() % cols.size()])})
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


# ======================= Vẽ =======================

## Đặt phép biến đổi: tọa độ logic 720×400 → pixel. cam: hệ số dịch theo camera.
func _xf(pos: Vector2 = Vector2.ZERO, rot: float = 0.0, sc: Vector2 = Vector2.ONE, cam: float = 1.0) -> void:
	var base := Transform2D(0.0, Vector2(size.x / W, size.y / H), 0.0, Vector2.ZERO)
	var camt := Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0.0, _cam_y * cam))
	draw_set_transform_matrix(base * camt * Transform2D(rot, sc, 0.0, pos))


func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)


func _ellipse(x: float, y: float, rx: float, ry: float, c: Color, cam: float = 1.0) -> void:
	_xf(Vector2(x, y), 0.0, Vector2(rx, ry), cam)
	draw_circle(Vector2.ZERO, 1.0, c)
	_xf()


func _curve(p0: Vector2, p1: Vector2, p2: Vector2, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(p0 * (1.0 - t) * (1.0 - t) + p1 * 2.0 * (1.0 - t) * t + p2 * t * t)
	return pts


func _draw() -> void:
	var wx: String = Game.s.weather
	var p := _p if running else 0.0
	var rise := 0.0
	var rx := 0.0
	var ang := 0.0
	var sc := 1.0
	_cam_y = 0.0
	if running:
		rise = 1100.0 * pow(p, 1.8)
		_cam_y = maxf(0.0, rise - (BASE - 170.0))
		rx = 70.0 * p * p
		ang = 0.7 * p * p
		sc = 1.0 - 0.5 * smoothstep(0.4, 1.0, p)
	var a := smoothstep(0.05, 0.65, p) if running else 0.0

	# --- Bầu trời ---
	var top: Color = _sky[wx][0].lerp(_space, a)
	var bot: Color = _sky[wx][1].lerp(_space, minf(1.0, a * 1.15))
	_xf(Vector2.ZERO, 0.0, Vector2.ONE, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]), PackedColorArray([top, top, bot, bot]))
	for s in _stars:
		var al := clampf(0.12 + a * 0.9, 0.0, 1.0)
		if not _reduce_motion:
			al *= 0.7 + 0.3 * sin(_t * 1.4 + s.ph)
		_rect(s.x, s.y, s.r, s.r, Color(0.9, 0.93, 1.0, al))
	for c in _clouds:
		var drift: float = 0.0 if _reduce_motion else _t * c.v * (3.0 if wx == "wind" else 1.0)
		var x: float = fposmod(c.x + drift, W + 240.0) - 120.0
		var col := Color(0.86, 0.92, 0.96, 0.16)
		if wx == "wind": col = Color(0.67, 0.75, 0.8, 0.22)
		if wx == "storm": col = Color(0.1, 0.125, 0.165, 0.85)
		col.a *= 1.0 - a
		var k: float = c.s * (1.5 if wx == "storm" else 1.0)
		for e in [[0.0, 0.0, 46.0, 13.0], [-26.0, 5.0, 32.0, 10.0], [28.0, 4.0, 36.0, 11.0]]:
			_ellipse(x + e[0] * k, c.y + e[1] * k, e[2] * k, e[3] * k, col, 0.5)

	# --- Thế giới (dịch theo camera khi tàu bay lên) ---
	_xf()
	_rect(0, 304, W, GY - 304, Color.html("#0f2f44"))
	_rect(0, 304, W, 1, Color(0.59, 0.78, 0.86, 0.25))
	for i in 6:
		var wy := 310.0 + i * 3.6
		var wxp := float((i * 97) % 240) + 220.0
		draw_line(Vector2(wxp, wy), Vector2(wxp + 60.0, wy), Color(0.59, 0.78, 0.86, 0.12), 1.0)
	var g0 := Color.html("#1d2a35")
	var g1 := Color.html("#0e151c")
	draw_polygon(PackedVector2Array([Vector2(0, GY), Vector2(W, GY), Vector2(W, GY + 240), Vector2(0, GY + 240)]), PackedColorArray([g0, g0, g1, g1]))
	_rect(0, GY, W, 1, Color(1, 1, 1, 0.08))
	_draw_buildings()

	var n: int = Game.s.pads.size()
	var cur: Dictionary = {} if running else Game.current_sel()
	for i in n:
		var pad: Dictionary = Game.s.pads[i]
		var x := _pad_x(i, n)
		var sel: bool = (not running) and (not cur.p.is_empty()) and cur.p.id == pad.id
		_draw_pad(x, pad, sel)
		if sel and not cur.r.is_empty():
			_draw_rocket(x, BASE, cur.r.type, 1.0, 0.0, 0.0)

	if running:
		var x0 := _pad_x(desc.pad_index, n)
		if _p < 0.4 and _boom_t < 0.0 and _stage != "count":
			for i in 2:
				_puffs.append({"x": x0 + randf_range(-14, 14), "y": GY - 8.0, "vx": randf_range(-1.6, 1.6), "vy": randf_range(-0.6, -0.1), "r": randf_range(6, 11), "life": 1.0})
		for q in _puffs:
			q.x += q.vx
			q.y += q.vy
			q.r += 0.4
			q.life -= 0.012
		_puffs = _puffs.filter(func(q): return q.life > 0.0)
		for q in _puffs:
			draw_circle(Vector2(q.x, q.y), q.r, Color(0.82, 0.86, 0.9, q.life * 0.35))
		if _boom_t < 0.0:
			if _p < 0.3 and _stage != "count":
				draw_circle(Vector2(x0, GY - 6), 38.0, Color(1.0, 0.65, 0.3, 0.16 * (1.0 - _p / 0.3)))
			_draw_rocket(x0 + rx, BASE - rise, desc.r.type, sc, (0.5 if _ignite else 0.0) if _stage == "count" else 1.0, ang)
		else:
			var bx := x0 + 70.0 * _p_fail * _p_fail
			var by := BASE - 1100.0 * pow(_p_fail, 1.8)
			for q in _boom_parts:
				var px: float = bx + q.vx * _boom_t * 60.0
				var py: float = by + q.vy * _boom_t * 60.0 + 90.0 * _boom_t * _boom_t
				var c: Color = q.c
				c.a = clampf(1.0 - _boom_t / 1.8, 0.0, 1.0)
				draw_circle(Vector2(px, py), q.r * (1.0 + _boom_t), c)
			if _boom_t < 0.25:
				draw_circle(Vector2(bx, by), 50.0 + _boom_t * 200.0, Color(1.0, 0.94, 0.78, 0.9 - _boom_t * 3.4))

	# --- Mưa, sét, HUD (cố định theo màn hình) ---
	_xf(Vector2.ZERO, 0.0, Vector2.ONE, 0.0)
	if wx == "storm" and a < 0.5:
		var off := 0.0 if _reduce_motion else fposmod(_t * 30.0, 40.0)
		for i in 60:
			var rx2 := float((i * 53) % int(W))
			var ry := fposmod(i * 37.0 + off * 6.0, H)
			draw_line(Vector2(rx2, ry), Vector2(rx2 - 4, ry + 12), Color(0.67, 0.78, 0.9, 0.28), 1.0)
		if not _reduce_motion and fposmod(_t, 7.0) < 0.12:
			_rect(0, 0, W, H, Color(0.86, 0.92, 1.0, 0.22))
	if running:
		_draw_hud()
	_xf(Vector2.ZERO, 0.0, Vector2.ONE, 0.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _pad_x(i: int, n: int) -> float:
	return 360.0 + (i - (n - 1) / 2.0) * 105.0


func _draw_rocket(x: float, y: float, type: String, sc: float, flame: float, ang: float) -> void:
	var R: Dictionary = GameData.ROCKETS[type]
	var h: float = R.h * sc
	var w: float = R.w * sc
	var band := Color.html(R.band)
	var body := Color.html("#e6edf5")
	_xf(Vector2(x, y), ang)
	if flame > 0.0:
		var fl := (28.0 + randf() * 16.0) * flame * sc * (w / (12.0 * sc))
		draw_polygon(PackedVector2Array([Vector2(-w * 0.42, 0), Vector2(w * 0.42, 0), Vector2(0, fl)]),
			PackedColorArray([Color.html("#fff3c4"), Color.html("#fff3c4"), Color(1.0, 0.35, 0.16, 0.0)]))
	if type == "condor":
		var bc := Color.html("#c4cfdb")
		_rect(-w / 2.0 - 5.0 * sc, -h * 0.55, 5.0 * sc, h * 0.55, bc)
		_rect(w / 2.0, -h * 0.55, 5.0 * sc, h * 0.55, bc)
	_rect(-w / 2.0, -h * 0.84, w, h * 0.84, body)
	draw_colored_polygon(_curve(Vector2(-w / 2.0, -h * 0.84), Vector2(0, -h * 1.12), Vector2(w / 2.0, -h * 0.84)), body)
	_rect(-w / 2.0, -h * 0.5, w, h * 0.09, band)
	draw_circle(Vector2(0, -h * 0.68), maxf(1.5, w * 0.14), Color.html("#233140"))
	draw_colored_polygon(PackedVector2Array([Vector2(-w / 2.0, 0), Vector2(-w / 2.0 - 7.0 * sc, 0), Vector2(-w / 2.0, -h * 0.25)]), band)
	draw_colored_polygon(PackedVector2Array([Vector2(w / 2.0, 0), Vector2(w / 2.0 + 7.0 * sc, 0), Vector2(w / 2.0, -h * 0.25)]), band)
	_xf()


func _draw_pad(x: float, pad: Dictionary, selected: bool) -> void:
	_rect(x - 28, GY - 6, 56, 6, Color.html("#2a3846"))
	if pad.busy > 0:
		for i in range(-2, 6):
			var x0 := x - 28.0 + i * 10.0
			var pts := PackedVector2Array([Vector2(x0, GY), Vector2(x0 + 6, GY), Vector2(x0 + 12, GY - 6), Vector2(x0 + 6, GY - 6)])
			# Chỉ vẽ trong thân bệ.
			var inside := true
			for v in pts:
				if v.x < x - 28.0 or v.x > x + 28.0: inside = false
			if inside:
				draw_colored_polygon(pts, Color.html("#c99a2e"))
	var th: float = 66.0 + pad.lvl * 22.0
	var tx := x - 38.0
	var lc := Color.html("#5b6d80")
	draw_rect(Rect2(tx - 3, GY - th, 6, th), lc, false, 1.2)
	var yy := GY
	while yy > GY - th + 8.0:
		draw_line(Vector2(tx - 3, yy), Vector2(tx + 3, yy - 10), lc, 1.0)
		draw_line(Vector2(tx + 3, yy), Vector2(tx - 3, yy - 10), lc, 1.0)
		yy -= 10.0
	draw_line(Vector2(tx + 3, GY - th + 12), Vector2(x - 8, GY - th + 12), Color.html("#7e90a4"), 1.2)
	var blink := (int(_t / 0.6) % 2 == 1) and not _reduce_motion
	_rect(tx - 1.5, GY - th - 4, 3, 4, Color.html("#ff5a4a") if blink else Color.html("#7a2c26"))
	var label := "Bệ %s · cấp %d%s" % [pad.name, pad.lvl, (" · %dn" % pad.busy) if pad.busy > 0 else ""]
	draw_string(_mono, Vector2(x - 60, GY + 18), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color.html("#8394a7"))
	if selected:
		var ac := Color.html("#4fd1c5")
		var bx := x - 52.0
		var by := GY - 112.0
		var bw := 104.0
		var bh := 120.0
		var k := 10.0
		for c in [[bx, by, 1.0, 1.0], [bx + bw, by, -1.0, 1.0], [bx, by + bh, 1.0, -1.0], [bx + bw, by + bh, -1.0, -1.0]]:
			draw_polyline(PackedVector2Array([Vector2(c[0], c[1] + c[3] * k), Vector2(c[0], c[1]), Vector2(c[0] + c[2] * k, c[1])]), ac, 1.5)


func _draw_buildings() -> void:
	var f: Dictionary = Game.s.fac
	_rect(24, GY - 34, 58, 34, Color.html("#25313f"))
	_rect(24, GY - 34, 58, 5, Color.html("#334559"))
	var win := Color.html("#4fd1c5")
	_rect(32, GY - 22, 8, 6, win)
	_rect(46, GY - 22, 8, 6, win)
	_rect(60, GY - 22, 8, 6, win)
	draw_line(Vector2(70, GY - 34), Vector2(70, GY - 56), Color.html("#7e90a4"), 1.2)
	if f.asm > 0:
		var w: float = 70.0 + f.asm * 14.0
		var h: float = 38.0 + f.asm * 10.0
		var arch := _curve(Vector2(96, GY - h + 12), Vector2(96 + w / 2.0, GY - h - 8), Vector2(96 + w, GY - h + 12), 10)
		arch.append(Vector2(96 + w, GY))
		arch.append(Vector2(96, GY))
		draw_colored_polygon(arch, Color.html("#2b394a"))
		_rect(96 + w / 2.0 - 14, GY - h * 0.62, 28, h * 0.62, Color.html("#18222d"))
		_rect(96, GY - 4, w, 2, Color.html("#f2b04c"))
	var sx: float = 560.0 + f.fuel * 30.0 + 10.0
	for i in f.fuel:
		var cx: float = 548.0 + i * 30.0
		draw_circle(Vector2(cx, GY - 14), 13.0, Color.html("#aab6c3"))
		_rect(cx - 13, GY - 16, 26, 3, Color.html("#7f8d9c"))
		_rect(cx - 9, GY - 2, 3, 2, Color.html("#2a3846"))
	if f.shop > 0:
		var sw: float = 40.0 + f.shop * 8.0
		var sxx: float = maxf(sx, 600.0)
		_rect(sxx, GY - 30, sw, 30, Color.html("#2d3b4b"))
		draw_colored_polygon(PackedVector2Array([Vector2(sxx - 3, GY - 30), Vector2(sxx + sw / 2.0, GY - 44), Vector2(sxx + sw + 3, GY - 30)]), Color.html("#d5744a"))
		_rect(sxx + 6, GY - 20, 8, 8, Color.html("#f2b04c"))
		_rect(sxx + sw - 14, GY - 20, 8, 8, Color.html("#f2b04c"))
	if f.wx > 0:
		var mh: float = 62.0 + f.wx * 10.0
		draw_line(Vector2(700, GY), Vector2(700, GY - mh), Color.html("#8394a7"), 1.5)
		_xf(Vector2(700, GY - mh), 0.4 if _reduce_motion else _t * 1.1)
		_rect(-9, -1.5, 18, 3, Color.html("#c4cfdb"))
		_xf()
		draw_circle(Vector2(700, GY - mh), 2.5, Color.html("#4fd1c5"))


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
	_rect(10, 10, 232, 82, Color(0.02, 0.03, 0.05, 0.55))
	var ink := Color.html("#dce5ef")
	draw_string(_mono, Vector2(18, 30), "T+ %02d:%02d" % [sec / 60, sec % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	draw_string(_mono, Vector2(18, 48), "ĐỘ CAO %s km" % _thousands(roundi(alt)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	draw_string(_mono, Vector2(18, 66), "VẬN TỐC %.1f km/s" % vel, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	var st := "MẤT TÍN HIỆU" if _boom_t >= 0.0 else _phase(p).to_upper()
	draw_string(_mono, Vector2(18, 84), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.html("#ef6b5b") if _boom_t >= 0.0 else Color.html("#4fd1c5"))
	if _stage == "count":
		var n := ceili(3.0 - _le / 0.8)
		draw_string(_disp, Vector2(0, 160), str(n) if n > 0 else "KHỞI ĐỘNG", HORIZONTAL_ALIGNMENT_CENTER, W, 76, Color(0.86, 0.9, 0.94, 0.92))
	elif _end_t >= 0.0:
		draw_string(_disp, Vector2(0, 150), "VÀO QUỸ ĐẠO " + o.label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color.html("#6fd08c"))
	elif _boom_t >= 0.0:
		draw_string(_disp, Vector2(0, 150), String(desc.out.cause).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color.html("#ef6b5b"))
	if time_scale > 1.0:
		draw_string(_mono, Vector2(W - 70, 24), "x%d" % int(time_scale), HORIZONTAL_ALIGNMENT_RIGHT, 60, 13, Color.html("#8394a7"))
	elif _stage != "idle":
		draw_string(_mono, Vector2(W - 190, 24), "bấm để tua nhanh", HORIZONTAL_ALIGNMENT_RIGHT, 180, 11, Color.html("#8394a7"))


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
