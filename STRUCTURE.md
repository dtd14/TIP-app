# Cấu trúc dự án

Ứng dụng sinh viên TIP dùng Flutter, BLoC, Dio và secure storage.
App gọi trực tiếp API NestJS, không gửi origin secret. Chi tiết contract và
kiểm tra được ghi trong [AUTH_INTEGRATION.md](AUTH_INTEGRATION.md).

- `lib/main.dart`, `lib/bootstrap.dart`: khởi tạo ứng dụng.
- `lib/app/`: widget gốc, dependency injection, router, theme và MainShell.
- `lib/core/`: cấu hình, client HTTP, interceptor, storage, validation, PageSlice, giải mã JSON, mapper lỗi API và widget dùng chung.
- `lib/features/auth/`: đăng nhập, đăng ký cá nhân, OTP, phiên và màn hình hạn chế truy cập.
- `lib/features/dashboard/`: tổng hợp dữ liệu sinh viên, quản lý tải trang chủ và widget thẻ.
- `lib/features/opportunities/`: entity, model, data source, repository, usecase, BLoC, danh sách/chi tiết cơ hội và doanh nghiệp.
- `lib/features/applications/`: entity chi tiết đơn, xác nhận trước khi nộp, danh sách, chi tiết đơn và widget giao diện/CV dùng chung.
- `lib/features/internships/`: entity đợt/vị trí/người hướng dẫn, data source, model, repository, usecase, BLoC và các trang thực tập.
- `lib/features/student_enrollment/`: entity, data source, model, repository, usecase, BLoC, form ghi danh, lịch sử và xét duyệt; BLoC riêng cho chọn trường/ngành.
- `lib/features/profile/`: hồ sơ sinh viên, chỉnh sửa tên/điện thoại/CV, trang CV riêng, file picker và widget đọc thông tin dùng chung; thông tin học vụ/email chỉ đọc.
- `lib/features/notifications/`: REST và WebSocket ticket theo tài khoản, BLoC theo phiên, badge dùng chung ở header, phân trang, đánh dấu đã đọc, polling fallback và điều hướng nội dung liên quan. Contract/cấu hình nằm trong [NOTIFICATIONS_INTEGRATION.md](NOTIFICATIONS_INTEGRATION.md).
- `test/`: unit/widget tests cùng fake/fixture riêng; không gọi backend thật.

Mỗi feature hoạt động có `domain/entities`, `domain/repositories`,
`domain/usecases`, `data/datasources`, `data/models`, `data/repositories`,
`presentation/bloc/<flow>`, `presentation/pages` và `presentation/widgets`.
BLoC có file event/state riêng; request và lỗi được quản lý trong BLoC.
Widget giữ controller nhập liệu, điều hướng và các thao tác giao diện.

Dashboard tổng hợp trang chủ qua contract của profile, applications và
internships. Mỗi feature có repository và entity riêng, cùng dùng ApiClient
và cơ chế Bearer/refresh. Chi tiết phân tích, phân trang và thư mục chờ xóa
được ghi trong [ARCHITECTURE_REFACTOR.md](ARCHITECTURE_REFACTOR.md).

Luồng trang chủ: `Page → DashboardBloc → GetDashboardSummary → Repository → Remote data source`.
Các entity và repository contract ở domain không phụ thuộc Flutter hoặc Dio.
API adapter parse response và kiểm tra liên kết account/student trước khi trả dữ liệu.
Tab Thực tập tải riêng `/students/me` và `/placements`, vẫn hoạt động khi tổng
hợp trang chủ lỗi. Đợt lấy từ hồ sơ chính sinh viên; chi tiết đọc lại đăng ký
và `/internship-period/:id`. Vị trí được phân trang và lọc theo đăng ký thực tập
ở server, giữ lịch sử hủy/hoàn thành. Entity vị trí giữ các liên kết nullable;
vị trí trực tiếp không được tự gắn vào đợt hoặc đơn nào.
Tab Hồ sơ cũng tải riêng `/students/me`. Form chỉ gửi thay đổi cá nhân; trang
CV gửi riêng tệp `cv` để không ghi đè thông tin từ snapshot cũ. Lưu xong tải lại
profile và dashboard. Router cập nhật tên tài khoản mà giữ tab/màn hình đang mở;
thay đổi quyền, account/student ID hoặc trạng thái vẫn hủy navigator cũ.

AuthBloc quyết định hiển thị login, MainShell, màn hình hạn chế hoặc trạng thái
khôi phục phiên. Tài khoản ACTIVE luôn vào MainShell sau khi API xác nhận phiên; dữ liệu và
chức năng sinh viên cần Student ACTIVE. Backend vẫn quyết định quyền.
Màn hình hạn chế cho phép đăng xuất và kiểm tra lại trạng thái. Interceptor chỉ
gắn token cho request yêu cầu xác thực tại origin đã cấu hình.

MainShell cung cấp năm mục cho sinh viên, ba mục (trang chủ, cơ hội, hồ sơ tài
khoản) cho tài khoản ACTIVE chưa có quyền sinh viên. Trang chủ có kéo xuống tải lại; danh sách
cơ hội và đơn ứng tuyển có phân trang, retry. Chi tiết cơ hội mở toàn màn hình;
chi tiết đơn ứng tuyển và xác nhận ứng tuyển cũng mở toàn màn hình. Các màn hình
dùng chung màu, thẻ và thành phần giao diện với trang chủ. Tìm kiếm/lọc/sắp xếp
cơ hội giới hạn trong danh sách đã tải; lọc trạng thái đơn thực hiện ở server.
Sinh viên đủ quyền xác nhận hồ sơ trước khi nộp đơn bằng opportunityId;
backend kiểm tra quyền, trạng thái
và hạn nộp. Navigator riêng cho phiên đăng nhập hỗ trợ nút quay lại hệ thống và
được hủy cùng các trang chi tiết khi phiên hết hạn hoặc bị hạn chế.
Kiểm tra phiên khi quay lại app giữ các trang đang mở nếu dữ liệu tài khoản và
quyền không đổi. Khi thay đổi tài khoản/quyền, router thay navigator ngay cả khi
phản hồi `/auth/me` quá nhanh và trạng thái restoring không được vẽ.
Menu tài khoản chung có liên kết ghi danh cá nhân/lịch sử hoặc xét duyệt theo vai
trò. Yêu cầu PENDING/APPROVED không tự cấp quyền trong app; chỉ hồ sơ Student
hợp lệ trả về từ `/auth/me` cho phép mở các chức năng sinh viên.
Các mục giao diện khớp schema/backend API. Báo cáo tuần chưa có model nên đã bỏ;
chỉ thông báo giữ “Sắp ra mắt” theo yêu cầu. Thẻ thực tập hiển thị trạng thái
InternshipPeriod và StudentInternship, không hiển thị thanh 5 bước suy diễn.

Đã loại bỏ 116 file Dart không được tham chiếu và chỉ chứa comment TODO, gồm mock
data source trong lib và các bộ khung chưa triển khai. Dữ liệu fake chỉ giữ trong
test; không đưa số liệu mẫu vào ứng dụng thật. Đã bỏ thêm widget danh sách dùng
chung và bottom sheet chi tiết cũ sau khi thay bằng trang ứng tuyển chuyên biệt.
Thư mục assets còn rỗng, chưa khai
báo ảnh hay font tùy chỉnh.

Chạy kiểm tra:

```powershell
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
```
