extends SceneTree
## Chạy thử không giao diện:
##   godot --headless --path . -s res://tools/smoke_test.gd
## Dựng màn hình chính, phóng thật (có hoạt ảnh tua nhanh), qua ngày, mua sắm, rồi mô phỏng nhiều chuyến để xem tỉ lệ.

const SEED := 20261127
var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_fail += 1
		print("  FAIL ", msg)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = root.get_node("Game")
	# Cố định seed để test lặp lại được: chuyến phóng đầu ngẫu nhiên có thể mất tàu và kết thúc ván.
	game.rng.seed = SEED
	game.new_game()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_check(game.s.day == 1, "ván mới bắt đầu ở ngày 1")
	_check(game.pending_result.get("intro", false), "ván mới hiện thẻ giới thiệu dự án")
	_check(game.s.land.stage == 0, "bắt đầu ở Lô I (đầm lầy)")
	game.dismiss_result()
	_check(game.eval_plan().valid, "kế hoạch phóng đầu tiên hợp lệ")

	# 1) Phóng thật qua hoạt ảnh.
	game.start_launch()
	_check(game.launching, "đang phóng sau khi bấm")
	main.view.time_scale = 40.0
	var frames := 0
	while game.pending_result.is_empty() and frames < 2000:
		await process_frame
		frames += 1
	_check(not game.pending_result.is_empty(), "hoạt ảnh kết thúc và có kết quả (%d khung)" % frames)
	print("  kết quả: ", game.pending_result.title, " | tiền ", game.s.money)
	game.dismiss_result()
	await process_frame
	await process_frame
	_check(game.pending_result.is_empty(), "đóng bảng kết quả")

	# 2) Qua ngày, mở rộng, sửa tàu, mua tàu.
	for i in 12:
		game.next_day()
	await process_frame
	_check(game.s.day == 13, "qua 12 ngày")
	# Cải tạo đất: chưa có Lô II thì chưa xây được; cải tạo xong mới xây.
	game.s.money = 20000
	game.s.rep = 50
	game.build_pad()
	game.upgrade_facility("shop")
	_check(game.s.pads.size() == 1 and game.s.fac.shop == 0, "chưa cải tạo Lô II thì chưa xây được")
	game.start_reclaim()
	_check(game.s.land.left == 3 and game.s.land.target == 1, "khởi công cải tạo Lô II (3 ngày)")
	game.start_reclaim()
	_check(game.s.land.left == 3, "đang thi công thì không khởi công thêm")
	var guard := 0
	while game.s.land.stage < 1 and guard < 40:
		game.s.money = 20000
		game.next_day()
		guard += 1
	_check(game.s.land.stage == 1, "xong Lô II sau %d ngày (bão làm chậm)" % guard)
	game.start_reclaim()
	guard = 0
	while game.s.land.stage < 2 and guard < 60:
		game.s.money = 20000
		game.next_day()
		guard += 1
	_check(game.s.land.stage == 2, "xong Lô III sau %d ngày" % guard)
	game.s.money = 20000
	game.upgrade_pad(1)
	game.build_pad()
	for k in ["shop", "wx", "fuel", "asm"]:
		game.upgrade_facility(k)
	var fleet_before: int = game.s.rockets.size()
	game.buy_rocket("kestrel")
	game.repair(game.s.rockets[0].id, "full")
	game.upgrade_engine(game.s.rockets[0].id)
	game.borrow()
	game.repay(0)
	for t in ["fleet", "grow", "log"]:
		game.set_tab(t)
		await process_frame
		await process_frame
	_check(game.s.rockets.size() == fleet_before + 1, "mua thêm một tàu (%d → %d)" % [fleet_before, game.s.rockets.size()])
	_check(game.s.pads.size() == 2 and game.s.pads[0].lvl == 2, "bệ thứ hai và nâng cấp bệ")
	_check(game.s.fac.shop == 1 and game.s.fac.asm == 1, "nâng công trình")

	# 3) Mô phỏng nhiều chuyến không qua hoạt ảnh để xem tỉ lệ thành công.
	var ok := 0
	var total := 400
	for i in total:
		game.new_game()
		game.s.sel.c = game.s.contracts[0].id
		var pl: Dictionary = game.eval_plan()
		var out := {"success": game.rng.randf() > pl.fail, "insured": false, "fuel": pl.fuel, "ins_cost": 0,
			"fail": pl.fail, "fail_at": 0.5, "cause": "Động cơ trục trặc", "loss": false, "pad_dmg": false}
		if out.success:
			ok += 1
		game.launching = true
		game.finish_launch({"c": pl.c, "r": pl.r, "p": pl.p, "out": out, "pad_index": 0})
	print("  tỉ lệ thành công ván đầu: %d/%d" % [ok, total])

	# 4) Lưu / tải.
	game.new_game()
	game.s.money = 1234
	game.save_game()
	game.s.money = 1
	_check(game.load_game() and game.s.money == 1234, "lưu và tải giữ nguyên kiểu số")
	game.new_game()

	print("KẾT THÚC: %d lỗi" % _fail)
	quit(1 if _fail > 0 else 0)
