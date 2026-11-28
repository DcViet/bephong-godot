class_name IsoGrid
extends RefCounted
## Toán học lưới iso 2:1 dùng chung cho hệ thống xây dựng (và sau này cho cảnh phóng).
##
## Quy ước khớp launch_view.gd: ô (gx, gy), gx tăng về phía dưới-phải, gy tăng về phía dưới-trái.
## Điểm lưới (gx, gy) ở độ cao 0 nằm tại ((gx − gy)·W/2, (gx + gy)·H/2).
## Mọi công trình lấy GỐC NODE = tâm hình thoi nền (footprint), nên đặt/quay/vẽ đều quy về một điểm.

const TILE_W := 96.0   # bề rộng một ô iso (px)
const TILE_H := 48.0   # bề cao một ô iso (px), tỉ lệ 2:1


static func grid_to_world(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * TILE_W * 0.5, (g.x + g.y) * TILE_H * 0.5)


static func world_to_grid(p: Vector2) -> Vector2:
	var u := p.x / (TILE_W * 0.5)
	var v := p.y / (TILE_H * 0.5)
	return Vector2((u + v) * 0.5, (v - u) * 0.5)


static func world_to_cell(p: Vector2) -> Vector2i:
	var g := world_to_grid(p)
	return Vector2i(floori(g.x), floori(g.y))


static func cell_center(c: Vector2i) -> Vector2:
	return grid_to_world(Vector2(c) + Vector2(0.5, 0.5))


## Tâm hình thoi nền của một hình chữ nhật ô (đây là vị trí đặt node công trình).
static func rect_center(r: Rect2i) -> Vector2:
	return grid_to_world(Vector2(r.position) + Vector2(r.size) * 0.5)


## Bốn đỉnh hình thoi nền, tính từ TÂM của nó (đỉnh trên, phải, dưới, trái).
static func footprint_polygon(size: Vector2i) -> PackedVector2Array:
	var h := Vector2(size) * 0.5
	return PackedVector2Array([
		grid_to_world(Vector2(-h.x, -h.y)),
		grid_to_world(Vector2(h.x, -h.y)),
		grid_to_world(Vector2(h.x, h.y)),
		grid_to_world(Vector2(-h.x, h.y)),
	])


## Khoảng cách theo y từ tâm nền xuống đỉnh phía trước (gần camera) của nó.
static func front_offset(size: Vector2i) -> float:
	return float(size.x + size.y) * TILE_H * 0.25


## Khóa sắp xếp chiều sâu: ô càng gần camera (gx + gy càng lớn) càng vẽ sau.
static func front_depth(r: Rect2i) -> int:
	return r.end.x + r.end.y
