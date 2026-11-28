extends SceneTree
## Chạy thử hệ thống xây dựng không giao diện:
##   godot --headless --path . -s res://tools/building_test.gd

var _fail := 0
var _wallet := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_fail += 1
		print("  FAIL ", msg)


func _initialize() -> void:
	_run.call_deferred()


func _pay(a: int) -> bool:
	if _wallet < a:
		return false
	_wallet -= a
	return true


func _run() -> void:
	_test_iso()
	_test_catalog()
	_test_grid()
	await _test_controller()
	print("")
	print("KẾT QUẢ: %s" % ("ĐẠT" if _fail == 0 else "%d LỖI" % _fail))
	quit(1 if _fail > 0 else 0)


func _test_iso() -> void:
	print("IsoGrid")
	var ok := true
	for c in [Vector2i(0, 0), Vector2i(5, 2), Vector2i(2, 9), Vector2i(15, 15)]:
		if IsoGrid.world_to_cell(IsoGrid.cell_center(c)) != c:
			ok = false
	_check(ok, "tâm ô quy đổi hai chiều về đúng ô")
	_check(IsoGrid.grid_to_world(Vector2(1, 0)).is_equal_approx(Vector2(48, 24)), "gx tăng → xuống-phải (khớp launch_view)")
	_check(IsoGrid.grid_to_world(Vector2(0, 1)).is_equal_approx(Vector2(-48, 24)), "gy tăng → xuống-trái (khớp launch_view)")
	_check(IsoGrid.rect_center(Rect2i(2, 3, 2, 2)).is_equal_approx(IsoGrid.grid_to_world(Vector2(3, 4))), "tâm nền = tâm hình chữ nhật ô")
	var poly := IsoGrid.footprint_polygon(Vector2i(3, 2))
	_check(is_equal_approx(poly[1].x - poly[3].x, (3 + 2) * IsoGrid.TILE_W * 0.5), "bề rộng nền (x+y)·W/2")
	_check(is_equal_approx(IsoGrid.front_offset(Vector2i(2, 2)), 2.0 * IsoGrid.TILE_H * 0.5), "đỉnh nền gần camera cách tâm (x+y)·H/4")


func _test_catalog() -> void:
	print("Danh mục & scene")
	var all := BuildingCatalog.all()
	_check(all.size() == 16, "đủ 16 định nghĩa (có %d)" % all.size())
	var scenes_ok := true
	var art_ok := true
	for d in all:
		var ps := load(d.scene_path()) as PackedScene
		if ps == null:
			scenes_ok = false
			continue
		var inst := ps.instantiate()
		if not (inst is BuildingBase) or (inst as BuildingBase).def != d:
			scenes_ok = false
		inst.free()
		if d.art == null or d.art.texture == null or d.art.art_scale <= 0.0:
			art_ok = false
	_check(scenes_ok, "mỗi công trình là một scene riêng, kế thừa BuildingBase và trỏ đúng định nghĩa")
	_check(art_ok, "mỗi định nghĩa có ảnh và tỉ lệ vẽ")
	var hangar := BuildingCatalog.get_def(&"hangar")
	_check(hangar != null and hangar.footprint_for(1) == Vector2i(hangar.footprint.y, hangar.footprint.x), "quay lẻ đổi chỗ x và y của nền")
	var shop := BuildingCatalog.get_def(&"workshop")
	_check(shop.upgrade_cost(1) == 800 and shop.upgrade_cost(2) == 1700 and shop.upgrade_cost(3) == -1, "giá nâng cấp khớp bảng FAC của game (xưởng: 800, 1700)")
	_check(is_equal_approx(float(shop.stat(2, "repair_discount")), 0.30), "chỉ số theo cấp (xưởng cấp 2 giảm 30%)")


func _test_grid() -> void:
	print("BuildGrid")
	var g := BuildGrid.new(Vector2i(8, 8))
	_check(g.check(Rect2i(0, 0, 3, 3)) == BuildGrid.Reason.OK, "ô trống đặt được")
	_check(g.check(Rect2i(6, 6, 3, 3)) == BuildGrid.Reason.OUT_OF_AREA, "vượt biên lưới bị từ chối")
	g.block_rect(Rect2i(4, 4, 1, 1))
	_check(g.check(Rect2i(3, 3, 2, 2)) == BuildGrid.Reason.BLOCKED, "ô bị chặn từ chối")
	g.set_buildable(Rect2i(0, 0, 4, 4))
	_check(g.check(Rect2i(2, 2, 3, 3)) == BuildGrid.Reason.OUT_OF_AREA, "ngoài vùng được phép xây (vùng đất mở dần)")


func _test_controller() -> void:
	print("BuildController")
	var c := BuildController.new()
	c.grid_size = Vector2i(12, 12)
	c.handle_input = false
	c.auto_tick = false          # test tự đẩy thời gian bằng tick() để kết quả chính xác
	c.ghost_follows_mouse = false
	root.add_child(c)
	c.payment = _pay
	var refunded := [0]
	c.refund = func(a: int) -> void: refunded[0] += a
	await process_frame

	var shop := BuildingCatalog.get_def(&"workshop")        # nền 3×2, xây 350, nâng 800/1700
	var tower := BuildingCatalog.get_def(&"control_tower")  # nền 2×2

	# Xây và vòng đời.
	var b := c.build_at(shop, Vector2i(2, 2), 0)
	await process_frame
	_check(b != null and b.state == BuildingBase.State.CONSTRUCTING, "đặt xong chuyển sang trạng thái đang xây")
	_check(b.position.is_equal_approx(IsoGrid.rect_center(Rect2i(2, 2, 3, 2))), "gốc node = tâm nền trên lưới iso")
	_check(c.grid.building_at(Vector2i(4, 3)) == b and c.grid.building_at(Vector2i(5, 3)) == null, "chiếm đúng 3×2 ô")
	var visual := b.get_node("Visual") as BuildingVisual
	_check(visual.region_enabled, "đang xây: sprite hiện dần theo tiến độ")
	b.tick(shop.build_time * 0.5)
	_check(is_equal_approx(b.progress, 0.5) and b.state == BuildingBase.State.CONSTRUCTING, "nửa thời gian xây → tiến độ 50%")
	b.tick(shop.build_time)
	await process_frame
	_check(b.state == BuildingBase.State.READY and b.level == 1 and not visual.region_enabled, "đủ thời gian → hoạt động, sprite hiện đủ")

	# Va chạm.
	_check(c.build_at(tower, Vector2i(4, 3), 0) == null and c.last_reason == BuildGrid.Reason.OCCUPIED, "đặt chồng lên công trình bị từ chối")
	_check(c.build_at(tower, Vector2i(11, 11), 0) == null and c.last_reason == BuildGrid.Reason.OUT_OF_AREA, "đặt ra ngoài lưới bị từ chối")

	# Xoay.
	c.select(b)
	_check(b.selected, "chọn công trình")
	_check(c.rotate_selected() and b.footprint_size() == Vector2i(2, 3) and b.rotation_steps == 1, "xoay 90°: nền 3×2 thành 2×3")
	_check(c.grid.building_at(Vector2i(4, 2)) == null and c.grid.building_at(Vector2i(3, 4)) == b, "bảng chiếm chỗ cập nhật theo hướng mới")
	_check(visual.flip_h, "hướng lẻ: sprite lật ngang")
	# Nền 2×3 đang ở x2–3, y2–4. Đặt một tháp 2×2 ở (4,2): chưa chạm, nhưng nền 3×2 (x2–4) sẽ vướng nó.
	var blocker := c.build_at(tower, Vector2i(4, 2), 0)
	_check(blocker != null, "đặt công trình lân cận")
	_check(not c.rotate_selected() and b.rotation_steps == 1, "không xoay được nếu nền mới vướng công trình khác")
	c.demolish(blocker)
	_check(c.rotate_selected(-1) and b.rotation_steps == 0, "hết vướng thì xoay ngược về hướng gốc")

	# Chọn bằng điểm.
	var centre := b.global_position
	_check(c.building_at_world(centre) == b, "bấm vào tâm nền thì chọn đúng công trình")
	_check(c.building_at_world(Vector2(5000, 5000)) == null, "bấm ra ngoài thì không chọn gì")
	var up_pt := centre + Vector2(0, -60)
	var hit_art := b.hit_test(up_pt)
	print("       (điểm cao hơn nền 60px trúng sprite: %s)" % hit_art)

	# Nâng cấp & tiền.
	_wallet = 100
	_check(not c.upgrade(b) and b.state == BuildingBase.State.READY and _wallet == 100, "không đủ tiền thì không nâng cấp và không bị trừ tiền")
	_wallet = 5000
	_check(c.upgrade(b) and b.state == BuildingBase.State.UPGRADING and _wallet == 4200, "đủ tiền: trừ 800, vào trạng thái nâng cấp")
	_check(not c.upgrade(b), "đang nâng cấp thì không nâng tiếp")
	b.tick(shop.upgrade_time(1) + 0.1)
	_check(b.level == 2 and b.state == BuildingBase.State.READY, "xong nâng cấp: cấp 2")
	_check(is_equal_approx(float(b.stat("repair_discount")), 0.30), "chỉ số đổi theo cấp")
	c.upgrade(b)
	b.complete_now()
	_check(b.level == 3 and b.upgrade_cost() == -1 and not c.upgrade(b), "đạt cấp tối đa thì hết nâng cấp")

	# Lưu / tải qua JSON (số nguyên thành float sau khi parse). Thêm một tháp đang xây dở, quay lẻ, để kiểm tra giữ tiến độ.
	var half := c.build_at(tower, Vector2i(1, 8), 1)
	half.tick(tower.build_time * 0.4)
	var saved := c.serialize()
	var parsed: Array = JSON.parse_string(JSON.stringify(saved))
	c.restore(parsed)
	await process_frame
	var restored := c.grid.building_at(Vector2i(2, 2))
	_check(c.buildings().size() == 2 and restored != null and restored.level == 3 and restored.state == BuildingBase.State.READY, "lưu rồi tải lại giữ nguyên số công trình, cấp và trạng thái")
	var half2 := c.grid.building_at(Vector2i(1, 8))
	_check(half2 != null and half2.state == BuildingBase.State.CONSTRUCTING and half2.rotation_steps == 1 and absf(half2.progress - 0.4) < 0.001, "công trình đang xây dở giữ nguyên hướng quay và tiến độ sau khi tải")

	# Phá bỏ.
	refunded[0] = 0
	c.select(restored)
	c.demolish_selected()
	await process_frame
	_check(c.grid.building_at(Vector2i(2, 2)) == null and c.selected == null, "phá bỏ giải phóng ô và bỏ chọn")
	_check(refunded[0] == int(float(shop.build_cost) * shop.demolish_refund), "hoàn lại một phần chi phí xây")

	# Chế độ đặt (ghost).
	_wallet = 10
	c.begin_placement(tower)
	await process_frame
	_check(c.is_placing() and c.ghost.state == BuildingBase.State.GHOST, "vào chế độ đặt: có bản xem trước")
	c.move_ghost(Vector2i(7, 7))
	c.rotate_ghost()
	_check(c.ghost.rotation_steps == 1, "xoay bản xem trước")
	_check(c.confirm_placement() == null and c.is_placing(), "không đủ tiền thì từ chối và vẫn ở chế độ đặt")
	_wallet = 5000
	var placed := c.confirm_placement()
	_check(placed != null and not c.is_placing() and _wallet == 5000 - tower.build_cost, "đủ tiền: đặt, trừ tiền, thoát chế độ đặt")
	_check(c.buildings().size() == 2, "bản xem trước không bị tính là công trình (2 công trình trên lưới)")

	# Mọi công trình đều dựng được trên lưới rộng.
	c.clear()
	var big := BuildController.new()
	big.grid_size = Vector2i(70, 6)
	big.handle_input = false
	root.add_child(big)
	await process_frame
	var n := 0
	var x := 0
	for d in BuildingCatalog.all():
		if big.build_at(d, Vector2i(x, 0), 0, true) != null:
			n += 1
		x += 4
	_check(n == 16, "cả 16 công trình đặt được và hoàn tất")
