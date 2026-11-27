class_name UIKit
extends RefCounted
## Bảng màu, theme (dựng bằng mã) và các hàm tạo control nhỏ dùng chung.

static var BG := Color.html("#0a1017")
static var PANEL := Color.html("#111a23")
static var PANEL2 := Color.html("#172330")
static var LINE := Color.html("#243445")
static var INK := Color.html("#dce5ef")
static var MUTE := Color.html("#8394a7")
static var ACCENT := Color.html("#4fd1c5")
static var ACCENT_INK := Color.html("#052320")
static var IGNITE := Color.html("#ff7a45")
static var WARN := Color.html("#f2b04c")
static var BAD := Color.html("#ef6b5b")
static var GOOD := Color.html("#6fd08c")

static var _theme: Theme


static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 4, mh: int = 0, mv: int = 0) -> StyleBoxFlat:
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
	t.set_stylebox("normal", name, flat(bg, border, 1, 4, mh, mv))
	t.set_stylebox("hover", name, flat(bg.lightened(0.07), hover_border, 1, 4, mh, mv))
	t.set_stylebox("pressed", name, flat(bg.darkened(0.12), hover_border, 1, 4, mh, mv))
	t.set_stylebox("disabled", name, flat(bg.darkened(0.04), LINE, 1, 4, mh, mv))
	var focus := flat(Color(0, 0, 0, 0), ACCENT, 2, 4, mh, mv)
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

	_button_var(t, "Button", "Button", PANEL2, LINE, INK, MUTE, 13, sans, 12, 7)
	_button_var(t, "OptionButton", "OptionButton", PANEL2, LINE, INK, MUTE, 13, sans, 10, 7)
	_button_var(t, "Primary", "Button", ACCENT, ACCENT, ACCENT_INK, INK, 13, sans, 14, 8)
	_button_var(t, "Ignite", "Button", IGNITE, IGNITE, Color.html("#1d0b03"), INK, 17, disp, 30, 12)
	_button_var(t, "Ghost", "Button", Color(0, 0, 0, 0), LINE, INK, MUTE, 12, sans, 9, 5)
	_button_var(t, "Small", "Button", PANEL2, LINE, INK, MUTE, 12, sans, 9, 5)
	_button_var(t, "SmallPrimary", "Button", ACCENT, ACCENT, ACCENT_INK, INK, 12, sans, 10, 5)
	_button_var(t, "Tab", "Button", PANEL, LINE, MUTE, MUTE, 12, mono, 6, 8)
	_button_var(t, "TabOn", "Button", PANEL2, ACCENT, ACCENT, ACCENT, 12, mono, 6, 8)

	t.set_stylebox("panel", "PopupMenu", flat(PANEL2, LINE, 1, 4, 4, 4))
	t.set_stylebox("hover", "PopupMenu", flat(Color(0.31, 0.82, 0.77, 0.18), Color(0, 0, 0, 0), 0, 3, 4, 3))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_font_size("font_size", "PopupMenu", 13)

	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_focus_color", "CheckBox", INK)
	t.set_font_size("font_size", "CheckBox", 13)

	t.set_stylebox("panel", "PanelContainer", flat(PANEL, LINE, 1, 6, 12, 12))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", flat(PANEL2, LINE, 1, 5, 10, 10))
	t.set_type_variation("TopBar", "PanelContainer")
	t.set_stylebox("panel", "TopBar", flat(PANEL, LINE, 1, 6, 14, 10))
	t.set_type_variation("SceneBox", "PanelContainer")
	var sb := flat(PANEL, LINE, 1, 6, 0, 0)
	sb.content_margin_left = 1
	sb.content_margin_right = 1
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	t.set_stylebox("panel", "SceneBox", sb)
	t.set_type_variation("SiteBar", "PanelContainer")
	t.set_stylebox("panel", "SiteBar", flat(PANEL, Color(0, 0, 0, 0), 0, 0, 12, 8))
	t.set_type_variation("ResultCard", "PanelContainer")
	t.set_stylebox("panel", "ResultCard", flat(PANEL, LINE, 1, 6, 18, 16))

	for v in ["BarGood", "BarWarn", "BarBad"]:
		t.set_type_variation(v, "ProgressBar")
		t.set_stylebox("background", v, flat(BG, LINE, 1, 2))
	t.set_stylebox("fill", "BarGood", flat(GOOD, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("fill", "BarWarn", flat(WARN, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("fill", "BarBad", flat(BAD, Color(0, 0, 0, 0), 0, 2))
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
	return c


## Thẻ có viền. Trả về [panel, box]: thêm nội dung vào box.
static func card(border: Color = Color(0, 0, 0, 0)) -> Array:
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	if border.a > 0.0:
		p.add_theme_stylebox_override("panel", flat(PANEL2, border, 1, 5, 10, 10))
	var box := vbox(7)
	p.add_child(box)
	return [p, box]


static func pill(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(Color(0, 0, 0, 0), color, 1, 3, 6, 2))
	var l := lbl(text.to_upper(), "Key")
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 10)
	p.add_child(l)
	return p


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
