extends SceneTree
## Sinh dữ liệu công trình từ bảng bên dưới:
##   godot --headless --path . -s res://tools/gen_buildings.gd
## Ghi ra:
##   res://data/building_art/<id>.tres   (BuildingArt: ảnh, tỉ lệ, mốc đặt)
##   res://data/buildings/<id>.tres      (BuildingDef: nền, chi phí, cấp, chỉ số)
##   res://scenes/buildings/building_base.tscn và <id>.tscn (kế thừa building_base, chỉ khác `def`)
## Muốn thêm công trình: thêm một dòng vào ROWS (ảnh đã nằm trong res://assets/spaceport/), rồi chạy lại.
## Giá và thời gian dưới đây là SỐ MẪU để thử hệ thống, chưa nối vào cân bằng của game chính
## (trừ các khoá game_link đã khớp bảng giá FAC / PAD_UP trong data.gd).

const ART_DIR := "res://assets/spaceport/"
const SCENE_DIR := "res://scenes/buildings/"

## id, tên, nhóm, nền (x, y), độ phủ ảnh so với nền, y đáy ảnh (px ảnh gốc; -1 = tự đo điểm đặc thấp nhất theo alpha),
## cấp tối đa, giá xây, [giá nâng cấp], thời gian xây, [thời gian nâng cấp], game_link, mô tả, [chỉ số theo cấp]
const ROWS: Array = [
	["launch_pad", "Bệ phóng", "launch", Vector2i(3, 3), 1.0, -1, 3, 1200, [1200, 3500], 12.0, [10.0, 16.0], "pad",
		"Giàn phóng và tên lửa. Cấp cao hơn phóng được tàu nặng hơn.", [{"payload_t": 2.5}, {"payload_t": 6.0}, {"payload_t": 12.0}]],
	["control_tower", "Trung tâm điều khiển", "operations", Vector2i(2, 2), 1.35, -1, 3, 600, [900, 1800], 9.0, [12.0, 18.0], "ctrl",
		"Điều phối các chuyến phóng và hợp đồng.", [{"contracts": 2}, {"contracts": 3}, {"contracts": 4}]],
	["hangar", "Nhà lắp ráp", "launch", Vector2i(3, 3), 1.1, -1, 3, 500, [1100, 2300], 10.0, [12.0, 18.0], "asm",
		"Lắp ráp và chuẩn bị tàu giữa các chuyến.", [{"turnaround_days_saved": 1}, {"turnaround_days_saved": 2}, {"turnaround_days_saved": 3}]],
	["research_lab", "Phòng thí nghiệm", "industry", Vector2i(3, 3), 1.1, -1, 3, 900, [1400, 2800], 14.0, [16.0, 24.0], "",
		"Nghiên cứu công nghệ mới cho tàu và động cơ.", [{"research_points": 1}, {"research_points": 2}, {"research_points": 4}]],
	["fuel_depot", "Kho nhiên liệu", "logistics", Vector2i(3, 2), 1.15, -1, 3, 400, [900, 1900], 8.0, [10.0, 16.0], "fuel",
		"Chứa nhiên liệu, giảm tiền mua nhiên liệu.", [{"fuel_discount": 0.08}, {"fuel_discount": 0.16}, {"fuel_discount": 0.24}]],
	["communications_center", "Trạm thông tin", "operations", Vector2i(2, 2), 1.3, -1, 3, 300, [700, 1500], 7.0, [10.0, 14.0], "wx",
		"Thu phát tín hiệu, dự báo thời tiết chính xác hơn.", [{"forecast_accuracy": 0.75}, {"forecast_accuracy": 0.88}, {"forecast_accuracy": 0.97}]],
	["cargo_hub", "Trung tâm hàng hóa", "logistics", Vector2i(3, 2), 1.15, -1, 3, 700, [1200, 2400], 10.0, [12.0, 18.0], "",
		"Tiếp nhận và phân loại hàng cho hợp đồng.", [{"cargo_slots": 2}, {"cargo_slots": 4}, {"cargo_slots": 6}]],
	["workshop", "Xưởng sửa chữa", "industry", Vector2i(3, 2), 1.1, -1, 3, 350, [800, 1700], 8.0, [10.0, 16.0], "shop",
		"Sửa tàu sau chuyến phóng, giảm chi phí sửa.", [{"repair_discount": 0.15}, {"repair_discount": 0.30}, {"repair_discount": 0.45}]],
	["power_plant", "Nhà máy điện", "industry", Vector2i(3, 3), 1.1, -1, 3, 800, [1300, 2600], 12.0, [14.0, 20.0], "",
		"Cấp điện cho toàn bãi phóng.", [{"power_mw": 10}, {"power_mw": 22}, {"power_mw": 40}]],
	["operations_center", "Trung tâm vận hành", "operations", Vector2i(3, 2), 1.2, -1, 3, 650, [1000, 2000], 10.0, [12.0, 18.0], "",
		"Quản lý nhân sự và lịch vận hành.", [{"staff": 6}, {"staff": 12}, {"staff": 20}]],
	["storage_hangar", "Kho chứa", "logistics", Vector2i(3, 3), 1.1, -1, 3, 450, [800, 1600], 9.0, [10.0, 14.0], "",
		"Chứa phụ tùng và vật tư.", [{"storage_t": 20}, {"storage_t": 45}, {"storage_t": 80}]],
	["defense_turret", "Tháp phòng thủ", "defense", Vector2i(2, 2), 1.3, -1, 3, 500, [900, 1700], 8.0, [10.0, 14.0], "",
		"Bảo vệ bãi phóng khỏi mối đe dọa.", [{"damage": 10}, {"damage": 22}, {"damage": 40}]],
	["space_shuttle", "Tàu con thoi", "vehicle", Vector2i(3, 2), 1.2, -1, 1, 1500, [], 12.0, [], "",
		"Tàu vận tải có cánh, đỗ trên nền.", [{"crew": 4}]],
	["utility_rover", "Xe tự hành", "vehicle", Vector2i(1, 1), 1.5, -1, 1, 120, [], 4.0, [], "",
		"Xe đa dụng chạy quanh bãi phóng.", [{"speed": 1.0}]],
	["communications_satellite", "Vệ tinh thông tin", "space", Vector2i(2, 2), 1.2, -1, 1, 1000, [], 10.0, [], "",
		"Mô hình vệ tinh trưng bày trên bệ.", [{"coverage": 1.0}]],
	["forklift", "Xe nâng", "vehicle", Vector2i(1, 1), 1.5, -1, 1, 80, [], 3.0, [], "",
		"Chuyển hàng trong kho và bãi.", [{"load_t": 2.0}]],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/building_art")
	DirAccess.make_dir_recursive_absolute("res://data/buildings")
	DirAccess.make_dir_recursive_absolute(SCENE_DIR)
	_write_base_scene()
	for row in ROWS:
		_write_row(row)
	print("Đã sinh %d công trình." % ROWS.size())
	quit()


func _write_row(r: Array) -> void:
	var id: String = r[0]
	var tex := load(ART_DIR + id + ".png") as Texture2D
	if tex == null:
		push_error("Thiếu ảnh: " + id)
		return
	var fp: Vector2i = r[3]
	var fill: float = r[4]
	var ground_y: float = float(r[5])
	if ground_y < 0.0:
		ground_y = float(_solid_bottom(tex))
	var half := float(fp.x + fp.y)
	# Ảnh rộng bao nhiêu thì nền iso (rộng (x+y)·48 px) × độ phủ chừng đó.
	var s := half * IsoGrid.TILE_W * 0.5 * fill / float(tex.get_width())
	var art := BuildingArt.new()
	art.texture = tex
	art.art_scale = s
	# Đáy ảnh = đỉnh nền gần camera; tâm nền cao hơn đó nửa chiều cao hình thoi (tính theo px ảnh gốc).
	art.anchor = Vector2(float(tex.get_width()) * 0.5, ground_y - IsoGrid.front_offset(fp) / s)
	ResourceSaver.save(art, "res://data/building_art/%s.tres" % id)
	art = load("res://data/building_art/%s.tres" % id) as BuildingArt

	var d := BuildingDef.new()
	d.id = StringName(id)
	d.display_name = r[1]
	d.category = StringName(r[2])
	d.footprint = fp
	d.art = art
	d.max_level = r[6]
	d.build_cost = r[7]
	d.upgrade_costs = PackedInt32Array(r[8])
	d.build_time = r[9]
	d.upgrade_times = PackedFloat32Array(r[10])
	d.game_link = StringName(r[11])
	d.description = r[12]
	var stats: Array[Dictionary] = []
	for st in r[13]:
		stats.append(st)
	d.level_stats = stats
	ResourceSaver.save(d, "res://data/buildings/%s.tres" % id)

	var text := '[gd_scene load_steps=3 format=3]\n\n'
	text += '[ext_resource type="PackedScene" path="%sbuilding_base.tscn" id="1_base"]\n' % SCENE_DIR
	text += '[ext_resource type="Resource" path="res://data/buildings/%s.tres" id="2_def"]\n\n' % id
	text += '[node name="%s" instance=ExtResource("1_base")]\n' % id.to_pascal_case()
	text += 'def = ExtResource("2_def")\n'
	_write(SCENE_DIR + id + ".tscn", text)


## Hàng điểm ảnh đặc (alpha > 0.5) thấp nhất của sprite: đáy công trình = đỉnh nền gần camera.
func _solid_bottom(tex: Texture2D) -> int:
	var img := tex.get_image()
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return img.get_height() - 1


func _write_base_scene() -> void:
	var t := '[gd_scene load_steps=4 format=3]\n\n'
	t += '[ext_resource type="Script" path="res://scripts/building/building_base.gd" id="1_base"]\n'
	t += '[ext_resource type="Script" path="res://scripts/building/building_overlay.gd" id="2_overlay"]\n'
	t += '[ext_resource type="Script" path="res://scripts/building/building_visual.gd" id="3_visual"]\n\n'
	t += '[node name="Building" type="Node2D"]\nscript = ExtResource("1_base")\n\n'
	t += '[node name="Ground" type="Node2D" parent="."]\nscript = ExtResource("2_overlay")\nlayer = 0\n\n'
	t += '[node name="Visual" type="Sprite2D" parent="."]\nscript = ExtResource("3_visual")\n\n'
	t += '[node name="Hud" type="Node2D" parent="."]\nscript = ExtResource("2_overlay")\nlayer = 1\n'
	_write(SCENE_DIR + "building_base.tscn", t)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Không ghi được " + path)
		return
	f.store_string(text)
