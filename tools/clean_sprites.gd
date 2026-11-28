extends SceneTree
## Làm sạch quầng nền còn sót trong sprite công trình:
##   godot --headless --path . -s res://tools/clean_sprites.gd [-- debug] [tên.png ...]
## Đọc bản gốc từ res://assets/spaceport_original/ (không bao giờ bị sửa), ghi bản sạch vào res://assets/spaceport/.
## `debug`: ghi ảnh so sánh (gốc | vùng bị xoá màu tím | sạch) vào user://clean_debug/.
##
## Nguyên lý: gói sprite được tách nền khỏi một nền tối có quầng sáng xanh/cam nên còn sót những mảng quầng:
## nhạt dần, rất mịn, bão hoà thấp (xanh xám hoặc nâu), dính liền thành vùng và tiếp giáp phần trong suốt.
## Công trình thì có cạnh/chi tiết và màu bão hoà hơn. Ba lượt tìm quầng (xem PASSES):
##   - lượt 1 (nghiêm): vùng mịn, đủ lớn  → bắt phần quầng chính;
##   - lượt 2: vùng nhỏ hơn, phải tiếp giáp vùng trống nhiều hơn;
##   - lượt 3 (nới độ mịn): chỉ nhận mảng TỐI, bão hoà thấp, sát vùng trống → mảnh quầng kẹp giữa công trình và vùng trống.
## Sau đó: gặm thêm lớp viền còn dính màu quầng, xoá mảnh vụn của sprite lân cận ở mép ảnh,
## xoá điểm nửa trong suốt bám quanh, rồi làm mềm viền alpha.

const SRC := "res://assets/spaceport_original/"
const DST := "res://assets/spaceport/"

# Dải màu của quầng (HSV, 0..1).
const BLUE_H := Vector2(0.54, 0.67)
const BLUE_S := Vector2(0.16, 0.72)
const BLUE_V := Vector2(0.08, 0.82)
const ORANGE_H := Vector2(0.02, 0.16)
const ORANGE_S := Vector2(0.20, 0.82)
const ORANGE_V := Vector2(0.14, 0.78)
# Đuôi dải quầng: màu trôi dần sang xám lục / xám nâu tối, bão hoà thấp. Chỉ nhận khi điểm MỊN
# (chi tiết công trình tối như giàn thép hay bóng cây thì có cạnh, không mịn).
const MUTED_H := Vector2(0.16, 0.54)
const MUTED_S := Vector2(0.15, 0.45)
const MUTED_V := Vector2(0.15, 0.45)

# smooth = chênh lệch tổng R+G+B tối đa giữa hai điểm kề nhau (coi là mịn),
# min_area = cỡ vùng tối thiểu, min_clear = tỉ lệ chu vi tiếp giáp vùng trống tối thiểu,
# max_v / max_s = trần độ sáng / bão hoà trung bình của vùng (1.0 = không giới hạn).
const PASSES: Array = [
	{"smooth": 30, "min_area": 900, "min_clear": 0.12, "max_v": 1.0, "max_s": 1.0},
	{"smooth": 30, "min_area": 250, "min_clear": 0.35, "max_v": 1.0, "max_s": 1.0},
]
const GROW_PASSES := 14         # quầng còn sót (không mịn) được gặm thêm tối đa bấy nhiêu lớp từ chỗ đã xoá
const SEMI_RADIUS := 3          # điểm nửa trong suốt trong bán kính này quanh chỗ đã xoá cũng bị xoá nốt
const STRAY_DISTANCE := 20      # mảnh vụn cách thân chính xa hơn thế (px) thì xoá
const STRAY_MAX_AREA := 3000

const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const N8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]

var _debug := false


func _init() -> void:
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a == "debug":
			_debug = true
		elif a.ends_with(".png"):
			only.append(a)
	var names: Array = []
	for f in DirAccess.get_files_at(SRC):
		if f.ends_with(".png"):
			names.append(f)
	names.sort()
	for n in names:
		if only.is_empty() or only.has(n):
			_clean(n)
	quit()


func _in_range(v: float, r: Vector2) -> bool:
	return v >= r.x and v <= r.y


func _halo_color(c: Color) -> bool:
	if _in_range(c.h, BLUE_H) and _in_range(c.s, BLUE_S) and _in_range(c.v, BLUE_V):
		return true
	return _in_range(c.h, ORANGE_H) and _in_range(c.s, ORANGE_S) and _in_range(c.v, ORANGE_V)


func _muted(c: Color) -> bool:
	return _in_range(c.h, MUTED_H) and _in_range(c.s, MUTED_S) and _in_range(c.v, MUTED_V)


func _dist(a: Color, b: Color) -> int:
	return absi(a.r8 - b.r8) + absi(a.g8 - b.g8) + absi(a.b8 - b.b8)


## Điểm (x, y) coi là "trống": trong suốt sẵn, hoặc đã bị xoá ở lượt trước.
func _empty(img: Image, removed: PackedByteArray, w: int, x: int, y: int) -> bool:
	return removed[y * w + x] == 1 or img.get_pixel(x, y).a < 0.5


func _clean(n: String) -> void:
	var img := Image.load_from_file(SRC + n)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var removed := PackedByteArray()
	removed.resize(w * h)

	for ps in PASSES:
		_halo_pass(img, removed, w, h, ps)
	_grow(img, removed, w, h)
	_remove_strays(img, removed, w, h)
	_remove_semi(img, removed, w, h)

	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var gone := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if removed[y * w + x] == 1:
				c.a = 0.0
				gone += 1
			out.set_pixel(x, y, c)
	# Làm mềm viền alpha: điểm đặc sát vùng trống mà gần chỗ đã xoá nhận alpha 0.65 cho đỡ răng cưa.
	var soft := out.duplicate() as Image
	for y in h:
		for x in w:
			var c := out.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var near_empty := false
			for d in N4:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or out.get_pixel(nx, ny).a < 0.05:
					near_empty = true
					break
			if near_empty and _removed_within(removed, w, h, x, y, 1):
				c.a *= 0.65
				soft.set_pixel(x, y, c)
	soft.save_png(DST + n)
	print("%s: bỏ %d điểm (%.1f%% điểm đặc)" % [n, gone, 100.0 * float(gone) / float(maxi(1, _count_opaque(img)))])
	if _debug:
		_debug_sheet(n, img, soft, removed)


## Một lượt: chọn điểm giống quầng và mịn, gom vùng, xoá vùng thoả điều kiện của lượt.
func _halo_pass(img: Image, removed: PackedByteArray, w: int, h: int, ps: Dictionary) -> void:
	var smooth_max: int = ps.smooth
	var cand := PackedByteArray()
	cand.resize(w * h)
	for y in h:
		for x in w:
			if _empty(img, removed, w, x, y):
				continue
			var c := img.get_pixel(x, y)
			if not (_halo_color(c) or _muted(c)):
				continue
			var smooth := true
			for d in N4:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or _empty(img, removed, w, nx, ny):
					continue
				if _dist(c, img.get_pixel(nx, ny)) > smooth_max:
					smooth = false
					break
			if smooth:
				cand[y * w + x] = 1

	var seen := PackedByteArray()
	seen.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			if cand[i] == 0 or seen[i] == 1:
				continue
			var comp: Array[int] = []
			var stack: Array[int] = [i]
			seen[i] = 1
			var edge_total := 0
			var edge_clear := 0
			var sum_v := 0.0
			var sum_s := 0.0
			while not stack.is_empty():
				var p: int = stack.pop_back()
				comp.append(p)
				var px := p % w
				var py := p / w
				var pc := img.get_pixel(px, py)
				sum_v += pc.v
				sum_s += pc.s
				for d in N4:
					var nx: int = px + d.x
					var ny: int = py + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						edge_total += 1
						edge_clear += 1
						continue
					var q := ny * w + nx
					if cand[q] == 1:
						if seen[q] == 0:
							seen[q] = 1
							stack.append(q)
					else:
						edge_total += 1
						if _empty(img, removed, w, nx, ny):
							edge_clear += 1
			var n_px := float(comp.size())
			if comp.size() < int(ps.min_area):
				continue
			if float(edge_clear) / float(maxi(edge_total, 1)) < float(ps.min_clear):
				continue
			if sum_v / n_px > float(ps.max_v) or sum_s / n_px > float(ps.max_s):
				continue
			for p in comp:
				removed[p] = 1


## Gặm thêm từ chỗ đã xoá vào các điểm liền kề cùng màu quầng (phần không đủ mịn để vào vùng).
func _grow(img: Image, removed: PackedByteArray, w: int, h: int) -> void:
	for pass_i in GROW_PASSES:
		var add: Array[int] = []
		for y in h:
			for x in w:
				var i := y * w + x
				if removed[i] == 1 or img.get_pixel(x, y).a < 0.5:
					continue
				for d in N4:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and removed[ny * w + nx] == 1:
						var c := img.get_pixel(x, y)
						if _halo_color(c) or (_muted(c) and _dist(c, img.get_pixel(nx, ny)) <= PASSES[0].smooth):
							add.append(i)
						break
		if add.is_empty():
			return
		for i in add:
			removed[i] = 1


## Xoá mảnh vụn của sprite lân cận còn sót ở mép ảnh: mảnh nhỏ nằm xa thân chính (bbox thân chính nới STRAY_DISTANCE).
func _remove_strays(img: Image, removed: PackedByteArray, w: int, h: int) -> void:
	var label := PackedInt32Array()
	label.resize(w * h)
	var comps: Array = []    # mỗi phần tử: {area, box, cells}
	for y in h:
		for x in w:
			var i := y * w + x
			if label[i] != 0 or _empty(img, removed, w, x, y):
				continue
			var id := comps.size() + 1
			var cells: Array[int] = []
			var stack: Array[int] = [i]
			label[i] = id
			var box := Rect2i(x, y, 1, 1)
			while not stack.is_empty():
				var p: int = stack.pop_back()
				cells.append(p)
				var px := p % w
				var py := p / w
				box = box.expand(Vector2i(px, py))
				for d in N8:
					var nx: int = px + d.x
					var ny: int = py + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var q := ny * w + nx
					if label[q] == 0 and not _empty(img, removed, w, nx, ny):
						label[q] = id
						stack.append(q)
			comps.append({"area": cells.size(), "box": box, "cells": cells})
	if comps.size() < 2:
		return
	var main_i := 0
	for k in comps.size():
		if int(comps[k].area) > int(comps[main_i].area):
			main_i = k
	var zone: Rect2i = (comps[main_i].box as Rect2i).grow(STRAY_DISTANCE)
	for k in comps.size():
		if k == main_i or int(comps[k].area) > STRAY_MAX_AREA:
			continue
		if not zone.intersects(comps[k].box as Rect2i):
			for p in comps[k].cells:
				removed[p] = 1


## Điểm nửa trong suốt (viền mờ của quầng) còn bám quanh vùng đã xoá.
func _remove_semi(img: Image, removed: PackedByteArray, w: int, h: int) -> void:
	var extra: Array[int] = []
	for y in h:
		for x in w:
			var i := y * w + x
			if removed[i] == 1 or img.get_pixel(x, y).a >= 0.5:
				continue
			if _removed_within(removed, w, h, x, y, SEMI_RADIUS):
				extra.append(i)
	for i in extra:
		removed[i] = 1


func _removed_within(removed: PackedByteArray, w: int, h: int, x: int, y: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and ny >= 0 and nx < w and ny < h and removed[ny * w + nx] == 1:
				return true
	return false


func _count_opaque(img: Image) -> int:
	var k := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				k += 1
	return k


func _debug_sheet(n: String, orig: Image, clean: Image, removed: PackedByteArray) -> void:
	var w := orig.get_width()
	var h := orig.get_height()
	var sheet := Image.create(w * 3, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.5, 0.8, 0.35))
	sheet.blend_rect(orig, Rect2i(0, 0, w, h), Vector2i(0, 0))
	var mid := orig.duplicate() as Image
	for y in h:
		for x in w:
			if removed[y * w + x] == 1:
				mid.set_pixel(x, y, Color(1, 0, 1, 1))
	sheet.blend_rect(mid, Rect2i(0, 0, w, h), Vector2i(w, 0))
	sheet.blend_rect(clean, Rect2i(0, 0, w, h), Vector2i(w * 2, 0))
	DirAccess.make_dir_recursive_absolute("user://clean_debug")
	sheet.save_png("user://clean_debug/" + n)
