class_name GameData
extends RefCounted
## Dữ liệu tĩnh của trò chơi: loại tàu, quỹ đạo, công trình, thời tiết.
## Đơn vị tiền: nghìn đô la ($k). Khối lượng: tấn. Thời gian: ngày.

const PARTS: Array = [
	["engine", "Động cơ"],
	["hull", "Khoang hàng"],
	["shield", "Chắn nhiệt"],
	["avionics", "Điện tử"],
]

const NAMES: Array = ["Hải Âu", "Chim Én", "Sơn Ca", "Đại Bàng", "Thiên Nga", "Phượng Hoàng", "Cò Trắng", "Diều Hâu"]

## risk: phần trăm rủi ro cộng thêm vào xác suất thất bại.
const WX: Dictionary = {
	"clear": {"label": "Quang đãng", "risk": 0.0},
	"wind": {"label": "Gió mạnh", "risk": 0.04},
	"storm": {"label": "Giông bão", "risk": 0.22},
}

## reach: quỹ đạo xa nhất tới được (chỉ số trong ORB). pad_lvl: cấp bệ tối thiểu.
## base: xác suất thất bại cơ bản. tier: hệ số chi phí sửa. h, w: kích thước vẽ.
const ROCKETS: Dictionary = {
	"sparrow": {"name": "Sparrow", "payload": 2.5, "reach": 0, "pad_lvl": 1, "fuel": 80, "price": 600, "base": 0.08, "rep": 0, "tier": 1.0, "h": 46.0, "w": 12.0, "band": "#ff7a45"},
	"kestrel": {"name": "Kestrel", "payload": 6.0, "reach": 1, "pad_lvl": 2, "fuel": 380, "price": 1800, "base": 0.06, "rep": 8, "tier": 2.5, "h": 62.0, "w": 16.0, "band": "#4fd1c5"},
	"condor": {"name": "Condor", "payload": 12.0, "reach": 2, "pad_lvl": 3, "fuel": 1100, "price": 5200, "base": 0.07, "rep": 35, "tier": 6.0, "h": 82.0, "w": 22.0, "band": "#f2b04c"},
}

## per_t: tiền thưởng mỗi tấn. gap: số ngày tàu hồi phục sau chuyến. unlock: uy tín cần để có hợp đồng loại này.
const ORB: Array = [
	{"key": "LEO", "label": "LEO", "full": "Quỹ đạo thấp", "per_t": 170.0, "gap": 1, "alt": 400.0, "vel": 7.7, "unlock": 0, "mass": [0.6, 2.2],
		"clients": ["Viện Hải Dương Nam Hải", "Ảnh Vệ Tinh Lạc Việt", "ĐH Bách Khoa (CubeSat)", "Tiếp tế Tinh Vân"],
		"missions": ["Cụm CubeSat quan trắc", "Vệ tinh ảnh độ phân giải cao", "Thí nghiệm vi trọng lực", "Tiếp tế trạm quỹ đạo"]},
	{"key": "GEO", "label": "GEO", "full": "Quỹ đạo địa tĩnh", "per_t": 260.0, "gap": 2, "alt": 35786.0, "vel": 10.2, "unlock": 8, "mass": [1.5, 5.0],
		"clients": ["Viễn Thông Đông Dương", "Truyền hình Sao Việt", "Cục Khí tượng Quốc gia"],
		"missions": ["Vệ tinh viễn thông", "Vệ tinh dự báo thời tiết", "Vệ tinh truyền hình trực tiếp"]},
	{"key": "MOON", "label": "Mặt Trăng", "full": "Quỹ đạo Mặt Trăng", "per_t": 420.0, "gap": 4, "alt": 384400.0, "vel": 10.9, "unlock": 35, "mass": [4.0, 10.0],
		"clients": ["Liên minh Nguyệt Quang", "Quỹ Thám hiểm Nguyệt Cung"],
		"missions": ["Thiết bị căn cứ Mặt Trăng", "Xe tự hành khảo sát", "Trạm trung chuyển quỹ đạo"]},
]

## cost: chi phí lên cấp 1, 2, 3. fx: hiệu ứng của từng cấp.
const FAC: Dictionary = {
	"shop": {"name": "Xưởng sửa chữa", "cost": [350, 800, 1700], "fx": ["−15% chi phí sửa", "−30% chi phí sửa, sửa nhanh xong trong ngày", "−45% chi phí sửa, đại tu chỉ 1 ngày"]},
	"wx": {"name": "Trạm thời tiết", "cost": [300, 700, 1500], "fx": ["Dự báo đúng 75%", "Dự báo đúng 88%", "Dự báo đúng 97%"]},
	"fuel": {"name": "Kho nhiên liệu", "cost": [400, 900, 1900], "fx": ["−8% tiền nhiên liệu", "−16% tiền nhiên liệu", "−24% tiền nhiên liệu"]},
	"asm": {"name": "Nhà lắp ráp", "cost": [500, 1100, 2300], "fx": ["Tàu hồi phục sau chuyến nhanh hơn 1 ngày", "Bệ phóng chuẩn bị lại nhanh hơn 1 ngày", "Thêm −1 ngày cho cả hai (tối thiểu 1 ngày)"]},
}

## Đất: ba giai đoạn cải tạo vùng đầm lầy ven biển (đồng tâm quanh ô giữa).
## cost: chi phí ($k). days: số ngày thi công. rep: uy tín cần có (giấy phép môi trường). fx: được gì.
const LAND: Array = [
	{"short": "Lô I", "name": "Bãi khởi điểm", "cost": 0, "days": 0, "rep": 0,
		"fx": "Nền 4×4 ô đã đầm nén quanh trung tâm điều khiển: chỉ đủ chỗ cho một bệ phóng cấp 1.", "done": ""},
	{"short": "Lô II", "name": "Quảng trường", "cost": 450, "days": 3, "rep": 0,
		"fx": "Nền 8×8 ô: xây công trình, bệ phóng thứ hai và thứ ba, nâng bệ và công trình lên cấp 2.",
		"done": "mặt bằng 8×8 ô đã sẵn sàng, có thể xây công trình và bệ mới."},
	{"short": "Lô III", "name": "Vùng ngoài", "cost": 1100, "days": 5, "rep": 8,
		"fx": "Toàn bộ 12×12 ô, có kênh thoát nước và dải cây xanh: mở cấp 3 cho bệ và công trình (tàu Condor).",
		"done": "toàn bộ khu đất đã được cải tạo, mở cấp 3 cho bệ và công trình."},
]

const PAD_UP: Array = [0, 1200, 3500]
const PAD_NEW: Array = [0, 1200, 2500]
const MAX_ACTIVE: int = 3
const MAX_DEBT: int = 4000
const BANKRUPT_BELOW: int = -600
