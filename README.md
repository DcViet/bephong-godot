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
| `scripts/launch_view.gd` | Cảnh bãi phóng nhìn iso nghiêng toàn màn hình (vẽ bằng canvas 2D, viền mực dày), chạm bệ/công trình/ô trống, hoạt ảnh đếm ngược/bay |
| `scripts/ui/*.gd` | Theme dựng bằng mã và các bảng: header, hợp đồng, kế hoạch phóng, cột phải |
| `scripts/main.gd` | Bố cục: cảnh toàn màn hình + thanh trên/dưới nổi + bảng trượt (phải ở landscape, dưới ở portrait), hệ số UI theo màn hình/devicePixelRatio |
| `tools/smoke_test.gd` | Chạy thử headless |

Luồng: giao diện gọi hàm hành động của `Game` → `Game` đổi `s` và phát `changed` → `main.gd` dựng lại các bảng.
Kết quả chuyến phóng được quyết định lúc bấm Phóng nhưng chỉ áp vào trạng thái khi hoạt ảnh xong (`finish_launch`).

File lưu: `user://bephong.save` (nút "Chơi lại từ đầu" ở cột phải xóa ván hiện tại).

## Bản debug trên GitHub
Mỗi lần push vào `main`, workflow `Debug build (Windows)` chạy smoke test rồi export bản debug Windows và đăng lên Release `debug-latest` (prerelease, ghi đè mỗi lần). Tải `BePhong-windows-debug.zip`, giải nén rồi chạy `BePhong.exe` (kèm `BePhong.console.exe` để xem log).
Chạy tay: tab Actions → Debug build (Windows) → Run workflow.

## Chơi trên trình duyệt / điện thoại
https://dcviet.github.io/bephong-godot/ — bản web (Godot Web, không dùng thread) do cùng workflow đăng lên nhánh `gh-pages`. Lần đầu tải ~38 MB. Lưu ván nằm trong bộ nhớ trình duyệt (IndexedDB), không đồng bộ giữa các thiết bị.
