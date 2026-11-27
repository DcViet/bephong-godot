# Bệ Phóng (Godot 4.7, GDScript)

Game quản lý bãi phóng tên lửa giao hàng ra không gian. Bản port từ prototype HTML sang Godot.

## Chạy
Mở thư mục này bằng Godot 4.7 (bản chuẩn, không cần C#) rồi bấm F5.
Dòng lệnh: `godot --path . ` — kiểm tra không giao diện: `godot --headless --path . -s res://tools/smoke_test.gd`.

## Cấu trúc
| File | Vai trò |
|---|---|
| `scripts/data.gd` | Dữ liệu tĩnh: tàu, quỹ đạo, công trình, thời tiết (chỉnh cân bằng ở đây) |
| `scripts/game.gd` | Autoload `Game`: trạng thái, luật, lưu/tải. Không có mã giao diện |
| `scripts/launch_view.gd` | Cảnh đảo nhìn iso nghiêng toàn màn hình kiểu Boom Beach (canvas 2D, viền mực dày): biển nông có bọt sóng, cọ, chạm bệ/công trình/ô trống, hoạt ảnh đếm ngược/bay |
| `scripts/ui/*.gd` | Theme dựng bằng mã và các bảng: header (ngày/đất/thời tiết bên trái, tiền/nợ/uy tín bên phải), hợp đồng, kế hoạch phóng, cột phải; `world_menu.gd` là menu nổi cạnh công trình |
| `scripts/main.gd` | Bố cục: cảnh toàn màn hình; HUD hai góc trên, menu dưới trái, PHÓNG / Qua ngày dưới phải (ngang ở màn dọc); chạm công trình hiện menu nổi, chi tiết mở bảng trượt (phải ở landscape, dưới ở portrait); hệ số UI theo màn hình/devicePixelRatio |
| `tools/smoke_test.gd` | Chạy thử headless |

## Đất: dọn đá mở rộng khoảng cỏ
Game mở đầu trên đảo đá ven biển, chỉ có một khoảng cỏ 4×4 ô giữa vách đá (Lô I). Mỗi lô cải tạo tốn tiền và vài ngày thi công (bão làm công trường nghỉ):
- Lô II (quảng trường 8×8): $450k, 3 ngày. Mở ô xây công trình, bệ thứ 2–3, nâng cấp lên cấp 2.
- Lô III (toàn bộ 10×10 ô cỏ): $1,1M, 5 ngày, cần uy tín 8 (giấy phép môi trường). Mở cấp 3 cho bệ và công trình.
Dữ liệu ở `GameData.LAND`; luật ở `Game.start_reclaim`, `land_block`, `reclaim_blocked`; cảnh vẽ trong `launch_view.gd`: phần đất chưa mở là các khối đá nâu thấp dần về phía mép cỏ; khi mở rộng, máy ủi dọn đá từng ô thành cỏ và khung nhìn tự thu nhỏ để bản đồ to ra (cỏ 4×4 → 8×8 → 10×10 có rừng cây, phía trước là bãi cát và cọ). File lưu cũ không có `land` được coi là đã cải tạo hết.

Luồng: giao diện gọi hàm hành động của `Game` → `Game` đổi `s` và phát `changed` → `main.gd` dựng lại các bảng.
Kết quả chuyến phóng được quyết định lúc bấm Phóng nhưng chỉ áp vào trạng thái khi hoạt ảnh xong (`finish_launch`).

File lưu: `user://bephong.save` (nút "Chơi lại từ đầu" ở cột phải xóa ván hiện tại).

## Bản debug trên GitHub
Mỗi lần push vào `main`, workflow `Debug build (Windows)` chạy smoke test rồi export bản debug Windows và đăng lên Release `debug-latest` (prerelease, ghi đè mỗi lần). Tải `BePhong-windows-debug.zip`, giải nén rồi chạy `BePhong.exe` (kèm `BePhong.console.exe` để xem log).
Chạy tay: tab Actions → Debug build (Windows) → Run workflow.

## Chơi trên trình duyệt / điện thoại
https://dcviet.github.io/bephong-godot/ — bản web (Godot Web, không dùng thread) do cùng workflow đăng lên nhánh `gh-pages`. Lần đầu tải ~38 MB. Lưu ván nằm trong bộ nhớ trình duyệt (IndexedDB), không đồng bộ giữa các thiết bị.
