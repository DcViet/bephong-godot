class_name UIKit
extends RefCounted
## Bảng màu, theme (dựng bằng mã) và các hàm tạo control nhỏ dùng chung.

# Bảng màu kiểu hoạt hình: nền kem, viền mực đậm dày (cùng ngôn ngữ với cảnh iso).
static var BG := Color.html("#d9cfae")
static var PANEL := Color.html("#fbf6e3")
static var PANEL2 := Color.html("#f0e8cc")
static var LINE := Color.html("#243230")
static var INK := Color.html("#1f2d2a")
static var MUTE := Color.html("#6b6a58")
static var ACCENT := Color.html("#1fa896")
static var ACCENT_INK := Color.html("#ffffff")
static var IGNITE := Color.html("#ff8a3d")
static var IGNITE_INK := Color.html("#2a1204")
static var WARN := Color.html("#c97d12")
static var BAD := Color.html("#d4493b")
static var GOOD := Color.html("#2f8f4e")

static var _theme: Theme


static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 8, mh: int = 0, mv: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mh
	sb.content_margin_right = mh
	sb.content_margin_top = mv
	sb.content_margin_bottom = mv
	return sb


static func _font(names: Array) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	return f


static func _label_var(t: Theme, name: String, color: Color, size: int, font: Font) -> void:
	t.set_type_variation(name, "Label")
	t.set_color("font_color", name, color)
	t.set_font_size("font_size", name, size)
	t.set_font("font", name, font)


static func _button_var(t: Theme, name: String, base: String, bg: Color, border: Color, fg: Color, hover_border: Color, size: int, font: Font, mh: int, mv: int) -> void:
	if name != base:
		t.set_type_variation(name, base)
	var bw: int = 0 if border.a == 0.0 else 2
	t.set_stylebox("normal", name, flat(bg, border, bw, 8, mh, mv))
	t.set_stylebox("hover", name, flat(bg.lightened(0.08), hover_border, 2, 8, mh, mv))
	t.set_stylebox("pressed", name, flat(bg.darkened(0.12), hover_border, 2, 8, mh, mv))
	t.set_stylebox("disabled", name, flat(bg.darkened(0.04), Color(LINE.r, LINE.g, LINE.b, 0.3), 2, 8, mh, mv))
	var focus := flat(Color(0, 0, 0, 0), ACCENT, 2, 8, mh, mv)
	focus.draw_center = false
	t.set_stylebox("focus", name, focus)
	t.set_color("font_color", name, fg)
	t.set_color("font_hover_color", name, fg)
	t.set_color("font_pressed_color", name, fg)
	t.set_color("font_focus_color", name, fg)
	t.set_color("font_disabled_color", name, Color(fg.r, fg.g, fg.b, 0.38))
	t.set_font_size("font_size", name, size)
	t.set_font("font", name, font)


static func build_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var sans := _font(["Segoe UI", "Arial", "Noto Sans"])
	var mono := _font(["Cascadia Mono", "Consolas", "Courier New"])
	var disp := _font(["Bahnschrift", "Segoe UI Semibold", "Segoe UI"])
	t.default_font = sans
	t.default_font_size = 14

	t.set_color("font_color", "Label", INK)
	_label_var(t, "Muted", MUTE, 13, sans)
	_label_var(t, "Mono", INK, 13, mono)
	_label_var(t, "MonoMuted", MUTE, 12, mono)
	_label_var(t, "Key", MUTE, 11, mono)
	_label_var(t, "H3", INK, 15, disp)
	_label_var(t, "Title", INK, 22, disp)
	_label_var(t, "Big", INK, 40, disp)
	_label_var(t, "StatValue", INK, 18, mono)
	_label_var(t, "Good", GOOD, 13, mono)
	_label_var(t, "Bad", BAD, 13, mono)
	_label_var(t, "Warn", WARN, 13, mono)

	_button_var(t, "Button", "Button", PANEL2, LINE, INK, ACCENT, 13, sans, 12, 8)
	_button_var(t, "OptionButton", "OptionButton", PANEL2, LINE, INK, ACCENT, 13, sans, 10, 8)
	_button_var(t, "Primary", "Button", ACCENT, LINE, ACCENT_INK, INK, 14, disp, 16, 9)
	_button_var(t, "Ignite", "Button", IGNITE, LINE, IGNITE_INK, INK, 18, disp, 30, 12)
	_button_var(t, "Ghost", "Button", Color(0, 0, 0, 0), LINE, INK, ACCENT, 12, sans, 10, 6)
	_button_var(t, "Small", "Button", PANEL2, LINE, INK, ACCENT, 12, sans, 10, 6)
	_button_var(t, "SmallPrimary", "Button", ACCENT, LINE, ACCENT_INK, INK, 12, sans, 11, 6)
	_button_var(t, "Tab", "Button", PANEL2, Color(LINE.r, LINE.g, LINE.b, 0.35), MUTE, ACCENT, 12, mono, 6, 9)
	_button_var(t, "TabOn", "Button", PANEL, LINE, ACCENT, ACCENT, 12, mono, 6, 9)
	# Nút đáy màn hình (chạm bằng ngón tay): cao, viền dày.
	_button_var(t, "Dock", "Button", PANEL, LINE, INK, ACCENT, 14, disp, 14, 11)
	_button_var(t, "DockOn", "Button", ACCENT, LINE, ACCENT_INK, INK, 14, disp, 14, 11)
	_button_var(t, "Close", "Button", PANEL2, LINE, INK, BAD, 15, disp, 12, 6)

	t.set_stylebox("panel", "PopupMenu", flat(PANEL, LINE, 2, 6, 4, 4))
	t.set_stylebox("hover", "PopupMenu", flat(Color(0.12, 0.66, 0.59, 0.2), Color(0, 0, 0, 0), 0, 4, 4, 3))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_font_size("font_size", "PopupMenu", 13)

	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_focus_color", "CheckBox", INK)
	t.set_font_size("font_size", "CheckBox", 13)

	t.set_stylebox("panel", "PanelContainer", flat(PANEL2, Color(LINE.r, LINE.g, LINE.b, 0.5), 2, 10, 12, 12))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", flat(PANEL, LINE, 2, 10, 10, 10))
	# Ô thông số nổi trên cảnh (kiểu hộp kem viền mực).
	t.set_type_variation("Chip", "PanelContainer")
	t.set_stylebox("panel", "Chip", flat(PANEL, LINE, 2, 12, 11, 5))
	# Bảng trượt chứa các bảng điều khiển.
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", flat(PANEL, LINE, 3, 16, 14, 12))
	t.set_type_variation("ResultCard", "PanelContainer")
	t.set_stylebox("panel", "ResultCard", flat(PANEL, LINE, 3, 16, 20, 18))

	for v in ["BarGood", "BarWarn", "BarBad"]:
		t.set_type_variation(v, "ProgressBar")
		t.set_stylebox("background", v, flat(BG, LINE, 2, 4))
	t.set_stylebox("fill", "BarGood", flat(GOOD, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("fill", "BarWarn", flat(WARN, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("fill", "BarBad", flat(BAD, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("separator", "HSeparator", flat(LINE, Color(0, 0, 0, 0), 0, 0))
	_theme = t
	return t


# ---------------- Hàm tạo control ----------------

static func lbl(text: String, variation: String = "", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func btn(text: String, variation: String, cb: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE if variation.begins_with("Tab") else Control.FOCUS_ALL
	b.pressed.connect(cb)
	return b


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func flow(hsep: int = 6, vsep: int = 6) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", hsep)
	f.add_theme_constant_override("v_separation", vsep)
	return f


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Thẻ có viền. Trả về [panel, box]: thêm nội dung vào box.
static func card(border: Color = Color(0, 0, 0, 0)) -> Array:
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	if border.a > 0.0:
		p.add_theme_stylebox_override("panel", flat(PANEL, border, 3, 10, 10, 10))
	var box := vbox(7)
	p.add_child(box)
	return [p, box]


static func pill(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(Color(0, 0, 0, 0), color, 2, 6, 6, 1))
	var l := lbl(text.to_upper(), "Key")
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 10)
	p.add_child(l)
	return p


## Điểm tròn màu (thay cho ký tự ● ○ ✓ ✕ vì font web không có các glyph này).
static func dot(color: Color, filled: bool = true, diameter: int = 14) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := flat(color if filled else Color(0, 0, 0, 0), LINE if filled else color, 2, diameter / 2)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func dots(level: int, total: int = 3) -> Control:
	var h := hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		h.add_child(dot(ACCENT, i < level, 12))
	return h


static func bar(value: float, height: int = 6) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = 100
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.theme_type_variation = "BarGood" if value >= 70.0 else ("BarWarn" if value >= 40.0 else "BarBad")
	return b


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
