# TIP Career — Flutter

Ứng dụng sinh viên theo feature + Clean Architecture + BLoC.

- [Cấu trúc dự án](STRUCTURE.md)
- [Auth: endpoint, quản lý phiên, giới hạn deployment và cách kiểm tra](AUTH_INTEGRATION.md)

Chạy trong `F:\Flutter\tip_app\tip_app`:

```powershell
flutter pub get
flutter run --dart-define=TIP_API_BASE_URL=https://tip-web-portal-api.vercel.app
```

Auth đã nối API NestJS cho đăng nhập bằng username, đăng ký cá nhân, OTP xác minh
email, kiểm tra Student, refresh token và đăng xuất. Cặp token lưu bằng secure
storage; mock chỉ dùng trong test. Đăng ký cá nhân không tạo hồ sơ Student.

App gọi trực tiếp API Vercel, không có prefix `/api` và không gửi `X-Secret`.
Các route public không cần token; route bảo vệ dùng Bearer access token và refresh
tối đa một lần khi nhận 401. Không nhúng ORIGIN_SECRET vào Flutter.
Trang chủ có thông tin sinh viên, đợt thực tập, thống kê ứng tuyển và vị trí chính
thức từ API. Thanh điều hướng mở danh sách cơ hội/ứng tuyển có phân trang, thực tập
và hồ sơ sinh viên. Thông tin học vụ chỉ đọc; tên, số điện thoại và CV có thể sửa.
Tài khoản ACTIVE luôn vào trang chủ sau khi API xác nhận phiên,
kể cả chưa có Student ACTIVE; các mục sinh viên chỉ hiện khi đủ quyền. Tài khoản
không ACTIVE hoặc phiên bị backend chặn có màn hình hạn chế riêng,
cho phép đăng xuất và kiểm tra lại trạng thái.

Giao diện dựa trên dữ liệu backend: không có mục báo cáo tuần; chỉ thông báo giữ
“Sắp ra mắt” theo kế hoạch backend. Thẻ thực tập hiển thị trạng thái kỳ và đăng ký
từ API, không dùng quy trình 5 bước suy diễn từ ảnh mẫu. Loại cơ hội phân biệt thực
tập, thực tập ngắn hạn và việc làm. Đã dọn 116 file TODO/mock không dùng trong lib;
fake và fixture chỉ nằm trong test.
Xem hợp đồng và smoke checks trong AUTH_INTEGRATION.md.

Tài khoản cá nhân đã xác minh email có thể vào “Ghi danh sinh viên” từ menu tài
khoản, hồ sơ hoặc trang chủ để tìm trường đã xác minh, chọn ngành và gửi MSSV,
lớp, học kỳ (1–8). Yêu cầu đang chờ có thể hủy; các yêu cầu cũ giữ trong lịch sử.
Quản trị viên trường có mục “Xét duyệt ghi danh” theo vai trò. Sau khi được duyệt,
nhấn “Cập nhật quyền tài khoản” để tải `/auth/me` và mở các mục sinh viên, không
cần đăng nhập lại. Mọi API ghi danh dùng Bearer, không gửi origin secret.

Hợp đồng request/response đã đối chiếu với EnrollmentController, EnrollmentDto
và EnrollmentService được cung cấp. Validation khớp giới hạn của DTO; parser
dùng mảng trực tiếp cho tra cứu/lịch sử và `{data, total, page, limit}` cho hàng
đợi. Phạm vi kiểm thử được ghi rõ trong AUTH_INTEGRATION.md.

Danh sách cơ hội dùng thẻ doanh nghiệp, tìm kiếm, lọc loại/địa điểm và sắp xếp
trong các cơ hội đã tải; API public hiện chỉ hỗ trợ phân trang. Chi tiết mở toàn
màn hình, có số lượng tuyển, hạn nộp, mô tả và thông tin doanh nghiệp khi API trả
về. Sinh viên đủ quyền có thể nộp đơn qua API; tài khoản cá nhân vẫn xem được cơ
hội. Không hiển thị lương, kỹ năng, độ khớp hồ sơ, lưu cơ hội hoặc chat vì chưa có
model/API tương ứng. Thông báo có REST, WebSocket ticket, badge chưa đọc, phân
trang, đánh dấu đã đọc và mở nội dung liên quan. Cấu hình URL/Origin realtime
được ghi trong [NOTIFICATIONS_INTEGRATION.md](NOTIFICATIONS_INTEGRATION.md).

Hồ sơ sinh viên gồm thông tin học vụ chỉ đọc, liên hệ và CV dùng ứng tuyển.
Chỉnh sửa chỉ gửi các trường tên/điện thoại đã thay đổi; email không có API sửa
nên giữ chỉ đọc. Trang “CV của tôi” đọc lại hồ sơ, mở CV thật bằng trình xem bên
ngoài và cho chọn/tải PDF mới tối đa 4 MiB. Tải CV chỉ gửi multipart `cv`, không
ghi đè tên/điện thoại. Timeout yêu cầu kiểm tra lại dữ liệu trước khi thử tiếp.
Không hiển thị giới tính/ngày sinh, khóa/năm học suy diễn, phiên bản, tên gốc,
dung lượng/ngày cập nhật của CV đã lưu hoặc dựng ảnh xem trước CV mẫu.

Ứng tuyển gồm ba màn hình: từ chi tiết cơ hội mở xác nhận, kiểm tra hồ sơ/CV và
đồng ý chia sẻ rồi mới gửi đơn; tab Ứng tuyển hiển thị danh sách riêng có lọc
trạng thái/phân trang; chọn một đơn mở chi tiết toàn màn hình. Đơn PENDING hoặc
REVIEWING có thể rút sau xác nhận. Backend không cho nộp lại cùng cơ hội kể cả
sau khi rút. CV hiển thị là CV hiện tại của hồ sơ, chưa có bản lưu riêng theo đơn.
Không hiển thị lịch phỏng vấn, offer/hợp đồng, chat hoặc timeline xét duyệt vì
chưa có dữ liệu tương ứng. Xem CV mở liên kết HTTPS bằng trình xem bên ngoài;
quay lại app giữ màn hình nếu kiểm tra phiên xác nhận tài khoản/quyền chưa đổi.

Tab Thực tập hiển thị các đợt đã được phân công, lọc đang mở/hiện tại hoặc đã
hoàn thành theo trạng thái đăng ký của sinh viên. Chi tiết đợt có lịch nộp hồ sơ,
lịch thực tập, yêu cầu giờ/tuần và các vị trí liên quan. Chi tiết vị trí hiển thị
doanh nghiệp, người hướng dẫn tại trường/doanh nghiệp và liên kết thật tới đợt,
đơn, cơ hội. Trang doanh nghiệp có logo/thông tin từ API, website và các cơ hội
đang tuyển; chọn cơ hội dùng lại luồng xác nhận ứng tuyển. Danh sách vị trí có
phân trang, gồm cả lịch sử hoàn thành/hủy.
Nhấn tên/logo doanh nghiệp ở các thẻ trang chủ, cơ hội, ứng tuyển hoặc thực tập
để mở chi tiết doanh nghiệp. Khi thiếu ID trên cơ hội public, sinh viên đọc lại
chi tiết cơ hội để lấy ID; app không ghép doanh nghiệp theo tên. Tài khoản chưa
có Student cần backend bổ sung `company.id` vào response public để mở trực tiếp.
Nhật ký, báo cáo, điểm/chứng nhận, hợp đồng, quy chế PDF, tiến độ giờ đã làm,
bản đồ, quy mô và giờ làm việc chưa có model/API nên không hiển thị. Sinh viên
không có nút tự đăng ký đợt, đổi trạng thái hoặc hủy vị trí vì backend dành những
thao tác này cho trường/doanh nghiệp. Header dùng chung nút chuông thông báo
với số chưa đọc theo tài khoản.

```powershell
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
```

Hướng dẫn cache và thư mục tạm trên ổ F nằm trong AUTH_INTEGRATION.md.
