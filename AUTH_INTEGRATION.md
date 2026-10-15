# Auth sinh viên TIP

## Trạng thái

Flutter đã dùng `NestAuthRemoteDataSource` mặc định cho đăng nhập, đăng ký cá nhân,
xác minh email, kiểm tra hồ sơ, refresh token và đăng xuất. Không dùng mock success
trong luồng chạy thật. Hợp đồng được đối chiếu với source NestJS trong
`../TIP-web-portal/src/modules/auth/` và `../TIP-web-portal/src/bootstrap.ts`.
Backend API được cung cấp là NestJS; Prisma/PostgreSQL lưu dữ liệu tài khoản.

Theo hợp đồng direct API, app gọi `https://tip-web-portal-api.vercel.app`
trực tiếp, không cần gateway, không có prefix `/api` và không gửi `X-Secret`.
Không nhúng ORIGIN_SECRET vào Flutter. Website Next.js vẫn có thể gửi secret từ
server. Phần direct API không cần đổi frontend env; luồng Student enrollment
cần backend mới và migration additive riêng theo tài liệu backend được cung cấp.

Backend cho phép bỏ origin secret chỉ với danh sách public tường minh hoặc
handler/class có `JwtAuthGuard` trong metadata controller đã đăng ký. Route mới
không có guard, route không tồn tại và Swagger vẫn yêu cầu `X-Secret`.
CORS preflight cho route client không cấp quyền cho request thật. JWT guard vẫn
kiểm tra phiên, trạng thái tài khoản, quyền và tổ chức; 401 là token hết hạn/thu
hồi/không hợp lệ, 403 là không đủ quyền. Các giới hạn auth rate limit vẫn áp dụng.

Các route public (không cần token hay secret):

- GET `/health`, `/public/opportunities?page=1&limit=6`.
- GET `/companies`, `/companies/:id`, `/universities`, `/universities/:id`.
- POST `/auth/login`, `/auth/register`, `/auth/register-user`,
  `/auth/register-university`, `/auth/register-company`.
- POST `/auth/resend-otp`, `/auth/verify-otp`, `/auth/reset-password`.
- POST `/auth/refresh-token`, cần refresh token hợp lệ trong body.

Đăng ký vẫn cần OTP và phê duyệt tổ chức nếu có. Reset password vẫn cần token
reset dùng một lần; app hiện chưa có luồng reset password hay đăng ký tổ chức.

## Endpoint đã nối

Các endpoint nằm tại origin root; không dùng TIP_API_PREFIX.
Các response auth trong bảng dưới là JSON trực tiếp, không có envelope `data`.

| Thao tác | Endpoint | Request / kết quả |
| --- | --- | --- |
| Đăng nhập | POST `/auth/login` | `{username, password}` → `{accessToken, refreshToken}`, sau đó GET `/auth/me` |
| Đăng ký cá nhân | POST `/auth/register-user` | `{fullName, username, email, password, phone?}` → `{message, otpSent, account}`, không có phiên |
| Xác minh email | POST `/auth/verify-otp` | `{email, otp, purpose: "email_verification"}`, không có phiên |
| Gửi lại mã | POST `/auth/resend-otp` | `{email, purpose: "email_verification"}` |
| Hồ sơ hiện tại | GET `/auth/me` | Bearer access token → Account kèm `student`, `schoolUser`, `companyUser` |
| Refresh | POST `/auth/refresh-token` | `{refreshToken}` → cặp access/refresh token mới |
| Đăng xuất | POST `/auth/logout` | Bearer access token, không body; kết thúc phiên hiện tại |

Không dùng POST `/auth/register` vì đó là đăng ký nhà trường. Không gửi quyền,
passwordHash hay mật khẩu xác nhận. Login chỉ hỗ trợ username theo LoginDto/service,
không quảng bá đăng nhập bằng email. Username được trim; mật khẩu giữ nguyên.

Validation: login password tối thiểu 8 ký tự; đăng ký password 8–128 ký tự,
fullName tối đa 150, username tối đa 64, email hợp lệ, phone tùy chọn tối đa 30.
OTP gồm đúng 6 chữ số, hiệu lực 5 phút theo backend; nút gửi lại có thời gian chờ
60 giây. API validation vẫn là nguồn quyết định và lỗi được ánh xạ về từng trường.
Backend trả lỗi trùng chung username/email, nên UI đánh dấu cả hai và không tự
đoán trường nào đã trùng. Không hiển thị response hoặc token thô trong thông báo.

## Đăng ký và quyền Student

`registerUser` tạo Account cá nhân và gửi OTP email, **không tạo Student**.
App chuyển đến màn hình xác minh, không tự đăng nhập. Nếu `otpSent: false`, Account
vẫn đã được tạo; UI hướng dẫn gửi lại mã thay vì yêu cầu tạo lại tài khoản.
Xác minh thành công trở về Đăng nhập, không suy ra đã được cấp phiên hoặc quyền.

Kết quả gửi lại mã hiển thị bằng snackbar một lần; countdown không lặp lại thông
báo. API trả `Email is already verified.` thì app hướng dẫn đăng nhập, không báo
đã gửi mã và không bắt đầu cooldown. Phản hồi chung chỉ xác nhận request đã được
xử lý; backend cũng trả phản hồi này khi email không tồn tại. Nó không xác nhận
email đã đến hộp thư. Lỗi dịch vụ email 503 có thông báo không thể gửi email.
Nếu không nhận được mã, cần đối chiếu response thực tế và log email trên backend,
kiểm tra cấu hình SMTP của deployment cùng thư rác; không log token hoặc mã OTP.

Sau đăng nhập, app lấy `/auth/me` trước khi lưu phiên. Account ACTIVE luôn vào
MainShell, không dùng trạng thái Student để quyết định điều hướng. Khi chưa có quyền
sinh viên, app hiển thị trang chủ, cơ hội và hồ sơ tài khoản. Chỉ tài khoản có Student
ACTIVE và quyền sinh viên mới tải dashboard sinh viên, ứng tuyển và thực tập.
`globalRole: USER` hoặc SYSTEM_ADMIN không thay thế hồ sơ Student. Student sai
kiểu hoặc liên kết Account không khớp bị từ chối. Các điều kiện trường/tổ chức,
email xác minh và tài khoản bị khóa còn được backend kiểm tra theo policy.

Tài khoản cá nhân đủ điều kiện gửi yêu cầu qua luồng Student enrollment dưới đây.
MainShell giữ trang chủ và cơ hội cho tài khoản ACTIVE; PENDING không cho phép
ứng tuyển hoặc vào các trang chỉ dành cho sinh viên.

## Ghi danh sinh viên

Triển khai theo tài liệu Student enrollment và source EnrollmentController,
EnrollmentDto, EnrollmentService do người dùng cung cấp ngày 03/10/2026.
Backend ở thư mục kế bên hiện là bản cũ; hợp đồng module mới đã được đối chiếu
với source gửi trong hội thoại/attachment. App không chạy migration hoặc sửa
database; backend mới phải được deploy trước khi dùng các màn hình này.

| Thao tác | Endpoint Bearer | Request |
| --- | --- | --- |
| Tìm trường đã xác minh | GET `/student-enrollments/universities` | `keyword?` |
| Ngành theo trường | GET `/student-enrollments/universities/:id/majors` | Không body |
| Lịch sử cá nhân | GET `/student-enrollments/me` | Không body; tối đa 50 |
| Gửi yêu cầu | POST `/student-enrollments` | `{universityId, majorId, studentCode, className, semester}` |
| Hủy yêu cầu đang chờ | PATCH `/student-enrollments/:id/cancel` | Không body |
| Hàng đợi của trường | GET `/student-enrollments` | `status?, keyword?, page, limit=20` |
| Xét duyệt | PATCH `/student-enrollments/:id/review` | `{decision: "APPROVED"}` hoặc `{decision: "REJECTED", reason}` |

Menu tài khoản là sidebar chung trên mobile. Tài khoản cá nhân USER ACTIVE đã
xác minh email, không có Student/SchoolUser/CompanyUser mới có form gửi yêu cầu.
Student có lịch sử, không có form đổi trường. UNIVERSITY_ADMIN có SchoolUser
ACTIVE thấy mục xét duyệt, danh sách được backend giới hạn theo trường; app không
gửi universityId để chọn phạm vi xét duyệt. Không đổi globalRole hoặc Student
từ trạng thái yêu cầu. Cờ xác minh email dựa trên `/auth/me` đã qua JWT guard,
theo auth policy đã đối chiếu trước đây; app không suy quyền từ token cục bộ.

Đổi trường xóa lựa chọn ngành cũ. ID trường/ngành lấy từ kết quả backend; DTO
backend xác minh UUID. Tra cứu trường có debounce và bỏ phản hồi đã lỗi thời;
tải ngành cũng bỏ phản hồi của trường cũ. MSSV tối đa 50 ký tự, lớp tối đa 100,
học kỳ 1–8, lý do từ chối bắt buộc và tối đa 500, từ khóa tối đa 100. Kiểm tra độ
dài sau trim tại form/BLoC và API repository. Khi có PENDING,
form bị ẩn; sửa dữ liệu bằng hủy rồi gửi yêu cầu mới. Lịch sử từ chối/hủy vẫn giữ.
Từ chối bắt buộc lý do; phê duyệt yêu cầu xác nhận đã kiểm tra việc theo học thực tế.

Sau POST/PATCH, BLoC luôn đọc lại lịch sử/hàng đợi, kể cả 409 hoặc timeout.
Không tự gửi lại thao tác sau lỗi mạng/timeout; 403 không refresh/retry. Nếu tải
lại thất bại, các nút ghi bị khóa đến khi tải danh sách thành công. Backend vẫn
enforce eligibility, pending uniqueness và transaction; kiểm tra UI không thay
thế các kiểm tra đó.
409 do mã sinh viên đã dùng có hướng dẫn riêng kiểm tra mã/liên hệ trường.
400 do ngành không thuộc trường đã chọn hoặc trường chưa xác minh có hướng dẫn
chọn lại trường/ngành. Các thông báo này ánh xạ từ message đã xác nhận trong
service, không hiển thị response thô.

Sau APPROVED, “Cập nhật quyền tài khoản” gọi `/auth/me`, giữ credential hiện tại
và dựng lại MainShell/dashboard. Kéo làm mới trang chủ cá nhân hoặc trở lại
foreground cũng kiểm tra `/auth/me`. Chỉ khi response có Student hợp lệ ACTIVE
thì ứng tuyển và thực tập được mở. Không cần gọi login hay tạo Account mới.

**Response đã xác nhận từ EnrollmentService:**

- Tra cứu trường, ngành và lịch sử cá nhân trả mảng trực tiếp, không envelope.
- Trường/ngành: `id, name, code`; app hiển thị tên và mã trường khi có.
- Yêu cầu: `id, universityId, majorId, studentCode, className, semester, status`;
  tùy chọn `university.name, major.name, account.fullName/email, reason, createdAt`.
- Hàng đợi: `{data, total, page, limit}`. Các trạng thái là PENDING, APPROVED,
  REJECTED, CANCELLED.
- Submit/review trả một yêu cầu kèm các quan hệ account/university/major;
  cancel trả `{message: "Đã hủy yêu cầu."}`. App đọc lại lịch sử/hàng đợi sau
  mutation và không suy quyền Student từ kết quả submit/review.

Fixture enrollment theo select/include/return của service đã cung cấp. Parser
không chấp nhận envelope dự phòng cho các route trả mảng; response sai cấu trúc
báo lỗi, không coi là lịch sử rỗng hay cấp quyền. Đây là kiểm thử theo hợp đồng
source, chưa phải kiểm thử trên deployment có tài khoản thật.

## Chỉnh sửa hồ sơ sinh viên

`PATCH /students/me` dùng Bearer; JSON khi sửa tên/số điện thoại, multipart khi có
CV. Payload chỉ chứa `fullName, phone` và multipart file `cv`. Trường, ngành,
MSSV, lớp và học kỳ chỉ đọc, do trường quản lý; không gửi các trường này trong
PATCH. Sau lưu thành công, kiểm tra `/auth/me` và tải lại dashboard/hồ sơ.

CV dùng [file_selector của Flutter](https://pub.dev/packages/file_selector), chỉ
chọn PDF, kiểm tra phần mở rộng, dấu `%PDF-` ở đầu nội dung và kích thước tối đa
4.194.304 byte trước khi gửi. Server vẫn xác minh tệp. Dio tự tạo Content-Type
multipart với boundary; không đặt header này bằng tay. macOS có entitlement
đọc file người dùng chọn; cần kiểm thử native picker/signing trên thiết bị thật.

## Trang chủ sinh viên

Dữ liệu thật từ source controller/service backend:

- GET `/students/me`: hồ sơ, ngành, trường, lớp, học kỳ và internships kèm kỳ thực tập.
- GET `/applications?page=1&limit=3`: đơn mới nhất và tổng số đơn đã nộp.
- GET `/applications?status=REVIEWING&page=1&limit=1`: tổng đang xét.
- GET `/applications?status=ACCEPTED&page=1&limit=1`: tổng trúng tuyển.
- GET `/placements?status=IN_PROGRESS&page=1&limit=1`, rồi CONFIRMED/PENDING:
  ưu tiên vị trí đang thực tập, sau đó sắp bắt đầu/chờ xác nhận. Các request chạy
  song song; không suy tổng từ số dòng trên trang đầu.
- GET `/public/opportunities?page=1&limit=12`: danh sách cơ hội không kèm token.

Profile phải khớp accountId/studentId của phiên. Không ACTIVE hoặc backend trả
403 do tài khoản/hồ sơ không hoạt động sẽ chuyển sang màn hình hạn chế; dữ liệu
trang chủ không hiển thị tại đó. Có nút đăng xuất và kiểm tra lại trạng thái.
Khi app quay lại foreground, kiểm tra lại phiên trên backend. Backend vẫn có thể
từ chối login trước khi cấp token cho tài khoản không hoạt động; khi đó lỗi ở
màn hình login, không tạo phiên giả để mở trang chủ.

Kéo xuống để tải lại; lỗi mạng có nút thử lại, không biến thành số 0 hay trạng thái
không có dữ liệu. Danh sách cơ hội/ứng tuyển có phân trang và xem thông tin. Sinh
viên đủ quyền có thể nộp đơn từ chi tiết cơ hội và sửa thông tin cá nhân/CV.
Báo cáo tuần chưa có model/API trong
backend nên đã bỏ khỏi giao diện. Chỉ thông báo giữ “Sắp ra mắt” theo yêu cầu.

Trạng thái đợt và đăng ký thực tập hiển thị trực tiếp từ InternshipPeriod.status
và StudentInternship.status; không suy diễn thành quy trình 5 bước. Đợt sắp tới
hoặc đã kết thúc có tiêu đề phù hợp. Tổng đơn lấy từ total của API, bao gồm đơn
đã từ chối/rút. OpportunityType gồm INTERNSHIP, MICRO_INTERNSHIP và JOB, hiển thị
đúng loại cả trong danh sách và chi tiết.

## Cơ hội và ứng tuyển

- `/public/opportunities` chỉ có query page/limit. Tìm kiếm tên vị trí, công ty,
  mô tả, địa điểm; lọc loại/địa điểm và sắp xếp hạn gần nhất thực hiện trên các cơ
  hội đã tải. Giao diện ghi rõ phạm vi và giữ nút tải thêm ngay cả khi bộ lọc chưa
  tìm thấy kết quả. Tổng trong “Tất cả” lấy từ API; không giả tổng theo từng loại.
- Public response có vacancies nhưng không có companyId/logoUrl/status. Trạng
  thái OPEN và doanh nghiệp VERIFIED được xác nhận bởi policy của public service.
  Logo thiếu dùng chữ viết tắt của tên công ty, không dùng hình minh họa giả.
- Sinh viên đủ quyền tải lại `GET /opportunities/:id` với Bearer trước khi bật
  ứng tuyển; response có companyId/logoUrl/status. `GET /companies/:id` public bổ
  sung lĩnh vực, website và địa chỉ. Lỗi thông tin doanh nghiệp có retry riêng,
  không ngăn hiển thị cơ hội hoặc gửi đơn đã được xác nhận hợp lệ.
- Tài khoản cá nhân xem chi tiết từ dữ liệu public đã tải, không gọi route chi
  tiết dành cho sinh viên; nút ứng tuyển có hướng dẫn cần hồ sơ sinh viên hợp lệ.
- Nút ứng tuyển ở chi tiết cơ hội mở màn hình xác nhận. Màn hình đọc lại
  `/students/me` và `/opportunities/:id`, hiển thị hồ sơ học vụ chỉ đọc, cho xem
  CV/đổi CV qua màn hình chỉnh sửa hồ sơ hiện có. Sau chỉnh sửa tải lại thông
  tin và yêu cầu xác nhận lại. Checkbox đồng ý là bước giao diện; không gửi thêm
  trường consent hoặc thông tin sinh viên vào body. CV không bắt buộc theo
  application service hiện tại.
- `POST /applications` chỉ gọi sau xác nhận, dùng Bearer, JSON chỉ có opportunityId. Nút chặn gửi lặp;
  chỉ báo thành công sau response thành công. Sau khi quay lại danh sách, tải lại
  dashboard để cập nhật thống kê. Đơn trùng 409 có hướng dẫn kiểm tra danh sách;
  timeout gửi/nhận có thông báo chưa xác nhận kết quả, không tự gửi lại. 403 không
  refresh/retry; tài khoản bị khóa chuyển màn hình trạng thái. Hạn null, hết hạn
  hoặc cơ hội không OPEN vô hiệu hóa ứng tuyển theo service backend.
- Tab Ứng tuyển dùng `GET /applications?page=1&limit=20&status=...` theo bộ lọc.
  Backend giới hạn các đơn thuộc sinh viên hiện tại; app không truyền studentId
  hoặc companyId để thay đổi phạm vi. Tổng lấy từ total cho bộ lọc đang chọn;
  lỗi phân trang giữ các thẻ đã tải và thử lại đúng trang chưa thành công.
- Chọn đơn ở danh sách hoặc trang chủ mở `GET /applications/:id` với Bearer.
  Parser kiểm tra id đơn, studentId, opportunityId và các quan hệ lồng nhau.
  Chi tiết có trạng thái hiện tại, appliedAt/updatedAt, mã đơn, hồ sơ ứng viên,
  doanh nghiệp và liên kết mở tin tuyển dụng (không cho nộp lại từ đơn có sẵn).
  Không suy diễn lịch sử các lần xét duyệt từ updatedAt.
- Rút đơn dùng `PATCH /applications/:id/withdraw`, Bearer, không body.
  Chỉ PENDING/REVIEWING có nút rút; bảng xác nhận trượt từ dưới lên hiển thị
  vị trí/doanh nghiệp đang chọn. Giữ đơn, quay lại hoặc chạm ngoài bảng không
  gửi PATCH. Unique student/opportunity
  vẫn áp dụng sau khi rút: không thể nộp lại cùng cơ hội. Thành công, 409 hoặc
  timeout đều tải lại chi tiết; không tự lặp PATCH. Khi quay lại danh sách tải
  lại bộ lọc và thống kê trang chủ. Đơn kết thúc không có thao tác rút.
- `applicationInclude.student.cvUrl` là CV hiện tại, không phải snapshot lúc
  nộp. UI không tự đặt tên file, dung lượng, thời gian upload hay chữ ký số.
  Liên kết CV HTTPS mở bên ngoài bằng [url_launcher](https://pub.dev/packages/url_launcher),
  không gửi token, không log URL; lỗi mở chỉ có thông báo chung.
- Không có trường lương, danh sách kỹ năng, điểm khớp hồ sơ, bookmark, chat,
  số lượng nhân viên hoặc module thông báo trong schema hiện tại. Các mục đó đã
  bỏ khỏi UI, ngoại trừ thông báo “Sắp ra mắt” theo yêu cầu. Mô tả là một trường
  văn bản; không tự tách hoặc tạo thêm yêu cầu/quyền lợi không có trong response.
  Lịch phỏng vấn, offer/hợp đồng và ảnh văn phòng cũng không hiển thị trong đơn.

## Thực tập và doanh nghiệp

- Đối chiếu schema, InternshipPeriodController/Service, PlacementController,
  placementInclude/policy và OpportunityService trong backend cùng workspace.
  Không thêm schema hay sửa API backend.
- Tab Thực tập đọc lại `/students/me`; danh sách chỉ gồm các StudentInternship
  của sinh viên, không liệt kê mọi đợt của trường để ngụ ý tự đăng ký. Trạng thái
  của đợt và trạng thái sinh viên hiển thị riêng. Bộ lọc hoàn thành dùng
  StudentInternship.status = COMPLETED; FAILED/NOT_ASSIGNED không được coi là
  hoàn thành dù InternshipPeriod đã kết thúc. Bộ lọc đang mở/hiện tại dùng
  OPEN/ONGOING cùng READY/APPLYING/PLACED/IN_PROGRESS.
- Chi tiết xác minh lại đăng ký trong hồ sơ, rồi gọi Bearer
  `GET /internship-period/:id`. Kiểm tra id đợt và universityId trước khi hiển thị.
  applyStartDate/applyEndDate và requiredHours/requiredWeeks nullable; null
  không được thay bằng số/ngày mẫu. periodNumber là số đợt, không tự suy diễn
  academic year hoặc khóa sinh viên từ academicYearId.
- Vị trí dùng Bearer `GET /placements?page=1&limit=20` và `GET /placements/:id`.
  Server giới hạn quyền; app kiểm tra studentId và id/quan hệ include. Chi tiết
  đợt thêm đúng `studentInternshipId` để lấy các vị trí thuộc đăng ký đó.
  Không truyền studentId/companyId/universityId để mở rộng phạm vi. Phân trang
  giữ thẻ đã tải khi lỗi và thử lại đúng trang. Hủy/hoàn thành vẫn nằm trong lịch sử.
- Chi tiết có lịch thực tập, trạng thái Placement, sinh viên/trường, hai người
  hướng dẫn từ account.fullName/email/phone. Thiếu người hướng dẫn hiện
  “Chưa phân công”. StudentInternship/opportunity/application có thể null cho
  vị trí tạo trực tiếp: không tạo liên kết hay dữ liệu giả. Tin tuyển dụng đóng
  hoặc hết hạn có thể trả 404 cho sinh viên; app báo lỗi và giữ chi tiết vị trí.
- Doanh nghiệp đọc public `GET /companies/:id`. Logo có fallback chữ viết tắt;
  chỉ có trạng thái VERIFIED được gắn đã xác minh, không suy diễn đối tác active.
  Website HTTP/HTTPS hợp lệ mở bằng ứng dụng bên ngoài, không gửi access token.
  Cơ hội dùng Bearer `GET /opportunities` (mảng, chưa phân trang), lọc cục bộ theo
  company.id và OPEN. Không dựa vào tên công ty hoặc truyền companyId không có
  trong DTO. Chọn cơ hội mở luồng xác nhận ứng tuyển hiện có.
- Nhấn tên/logo ở trang chủ, cơ hội, ứng tuyển và thực tập mở chi tiết doanh
  nghiệp, không đồng thời mở chi tiết đơn/vị trí. Các overview giữ company.id
  nếu API trả về. CompanyNavigation chặn nhấn lặp; thiếu ID chỉ được đọc bản ghi
  liên quan qua API có Bearer và quyền sinh viên, không dò theo tên công ty.
  Public opportunities hiện chỉ trả company.name: tài khoản không có Student
  cần backend trả thêm company.id để mở từ thẻ public. App đã hỗ trợ field này
  khi được bổ sung, không cần thay đổi schema/biến môi trường. Thông tin công ty
  vẫn public; tài khoản chưa có Student không gọi danh sách cơ hội bảo vệ.
  Từ danh sách ứng tuyển quay lại luôn đọc lại danh sách, kể cả khi gửi đơn từ
  trang doanh nghiệp có phản hồi chưa xác nhận được.
- Không có nhật ký tuần/báo cáo, điểm đánh giá/chứng nhận, hợp đồng/quy chế PDF,
  giờ đã làm/tiến độ phần trăm, bản đồ, quy mô hoặc giờ làm việc trong schema/API.
  Những mục đó được bỏ. Không đưa nút tự đăng ký đợt, xác nhận/hủy/đổi trạng thái
  Placement cho sinh viên; API ghi dành cho vai trò trường/doanh nghiệp.
  Thông báo dùng REST theo tài khoản và ticket WebSocket, cùng cơ chế
  Bearer/refresh; contract/cấu hình ghi trong NOTIFICATIONS_INTEGRATION.md.

## Phiên

Cặp token lưu bằng flutter_secure_storage, tách theo backend origin. Không lưu mật
khẩu. AuthInterceptor chỉ gắn Bearer cho request opt-in cùng origin; tắt theo
redirect, không log dữ liệu nhạy cảm. Credential cookie cũ không dùng được cho các
route Bearer và bị loại bỏ khi kiểm tra phiên.

Khởi động đọc phiên và gọi `/me` kiểm tra trên backend; không cấp quyền offline.
Protected request nhận 401 sẽ refresh một lần rồi retry một lần, không phụ thuộc
response có trường statusCode hay không. 403 không refresh và không retry. Các request
đồng thời dùng chung một lần refresh; cặp mới được lưu trước khi retry. Refresh
bị thu hồi/không hợp lệ sẽ xóa phiên và về đăng nhập. Lỗi mạng hoặc timeout không
bị coi là phiên hết hạn; màn hình khôi phục có nút thử lại. Không tự gửi lại đăng
ký hoặc OTP sau timeout.
Refresh/login trả về muộn sau logout không được khôi phục phiên đã xóa.
Khi quay lại từ trình xem CV, app kiểm tra `/auth/me` mà không hủy trang đang
mở nếu tài khoản và quyền giữ nguyên. Đổi tên cập nhật dữ liệu hiển thị mà giữ
tab/màn hình; thay đổi định danh/quyền, hết phiên hoặc bị
khóa vẫn thay navigator/loại bỏ trang chi tiết đang mở.

Logout gọi backend rồi xóa credential và user trong bộ nhớ. Nếu lỗi mạng, vẫn
đăng xuất local và báo chưa xác nhận kết thúc phiên server. Nếu secure storage
không xóa được, có trạng thái lỗi và nút thử lại. Không dùng logout-all.

## Chạy và kiểm tra

Chạy trong thư mục Flutter `F:\Flutter\tip_app\tip_app` (backend ở thư mục kế bên):

```powershell
flutter pub get
flutter run --dart-define=TIP_API_BASE_URL=https://tip-web-portal-api.vercel.app
```

TIP_API_BASE_URL chỉ nhận origin HTTPS, không có credentials, path prefix,
query hoặc fragment. JSON body dùng `Content-Type: application/json` do Dio suy
ra từ Map. Không đặt Content-Type toàn cục để Dio tạo multipart boundary.

CV upload dùng multipart field `cv`, chỉ PDF, tối đa 4 MiB (4.194.304 bytes).
App kiểm tra loại/kích thước file, dùng `FormData` và
để Dio tạo Content-Type kèm boundary; route bảo vệ cần Bearer token. Feature
upload được triển khai trong màn hình chỉnh sửa hồ sơ sinh viên.

Trang Hồ sơ mới đọc riêng `/students/me`, không phụ thuộc việc tải thống kê
applications/placements có thành công hay không. Avatar chỉ là chữ viết tắt
từ tên; không có API cập nhật ảnh đại diện. Email/username, MSSV, trường, ngành,
lớp và học kỳ là chỉ đọc. Badge xác minh email lấy từ `/auth/me`; không suy diễn
mọi trường học vụ đã xác minh hoặc chương trình “chính quy”.
Trang “CV của tôi” đọc lại profile và mở liên kết HTTPS thật bằng trình xem bên
ngoài. CV đã lưu không có original filename, byte size, cvUpdatedAt, version hay
ảnh preview riêng, nên không tạo metadata/nội dung CV giả. Giới tính/ngày sinh
và khóa/năm học theo sinh viên cũng không có trong schema hiện tại.
StudentProfileRepository.update nhận các trường tùy chọn: form chỉ gửi tên/
điện thoại thay đổi; upload từ trang CV gửi riêng `cv` bằng multipart. Không gửi
email hoặc trường học vụ. Chọn tệp bị hủy/không hợp lệ không gọi PATCH.
Trong lúc chọn/upload/lưu chặn nhấn lặp và quay lại. Sau timeout/kết quả chưa
xác nhận được, không tự lặp write; khóa gửi tiếp cho đến khi đọc lại dữ liệu.
Upload được ACK nhưng GET profile lỗi vẫn vô hiệu hóa nút xem link cũ, có retry
đọc dữ liệu. Quay lại từ CV làm mới hồ sơ/thống kê khi có thay đổi hoặc kết quả
write chưa chắc chắn. Profile edit cũng hỗ trợ kiểm tra lại sau timeout.

Máy phát triển này dùng cache/thư mục tạm trong workspace để tránh ổ C thiếu chỗ:

```powershell
$env:PUB_CACHE = Join-Path (Get-Location).Path '.pub-cache'
$taskTemp = Join-Path (Get-Location).Path '.dart_tool\test_temp'
New-Item -ItemType Directory -Path $taskTemp -Force | Out-Null
$env:TEMP = $taskTemp
$env:TMP = $taskTemp
flutter pub get
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
```

Android có INTERNET và tắt backup; iOS/macOS có Keychain entitlements, macOS có
network client entitlement. Cần kiểm tra lưu trữ và signing trên thiết bị thật.

## Phạm vi kiểm thử

Test dùng fake repository/datasource hoặc Dio HTTP adapter trong `test/`, không
gọi backend: validation DTO, lỗi API, Account thiếu Student, loading/submit lặp,
điều hướng đăng ký–OTP–đăng nhập, giữ form khi lỗi, khôi phục/đăng xuất, cặp token
trong secure storage mock, refresh đồng thời/retry hữu hạn, response muộn sau
logout, generic 401, role denial 403, và không retry đăng ký/OTP sau timeout.

Kiểm tra ngày 03/10/2026: formatter không còn thay đổi, `flutter analyze --no-pub`
không có lỗi và `flutter test --no-pub` đạt **198/198 test**.
Test mới gồm 7 endpoint ghi danh/DTO/Bearer, điều kiện theo vai trò,
PENDING/409/timeout, lịch sử, xét duyệt, cập nhật quyền qua `/auth/me` mà không
login lại, PDF 4 MiB/multipart boundary và màn hình nhỏ/chữ lớn/bàn phím.
Luồng ứng tuyển được kiểm thử qua API adapter/widget: xác nhận và hủy không
gửi đơn, consent/CV tùy chọn, cơ hội đóng giữa các bước, timeout không lặp POST,
lọc trạng thái/phân trang, detail thuộc đúng Student, PATCH rút/409/timeout,
không rút đơn kết thúc, không mở URL CV không an toàn và giữ trang/consent khi
kiểm tra phiên lúc app quay lại. Sau khi đổi bảng xác nhận rút đơn, 21/21 test
giao diện ứng tuyển đạt (có kiểm tra đóng bảng và màn hình 320 px/chữ 200%);
analyzer không báo lỗi. Đã render và kiểm tra ảnh ba màn hình và bảng rút đơn trong
`.dart_tool/previews/`. Chưa xác thực ứng tuyển/rút đơn bằng tài khoản thật hoặc
mở PDF trên thiết bị thật; cần smoke check các thao tác đó sau khi chạy app.

Kiểm tra mới nhất ngày 06/10/2026 sau cập nhật tab Thực tập: formatter không
còn thay đổi, analyzer sạch và toàn bộ **232/232 test đạt**. Test mới đối chiếu
Bearer/route/query, đăng ký thuộc hồ sơ, id/trường/sinh viên/quan hệ placement,
liên kết nullable, bộ lọc hoàn thành đúng trạng thái sinh viên, phân trang/retry,
liên kết đợt–vị trí–doanh nghiệp–đơn/cơ hội, quyền bị từ chối và hết phiên.
Đã render bốn màn hình vào `.dart_tool/previews/internships.png`,
`internship_period.png`, `internship_placement.png`, `internship_company.png`
và kiểm tra màn hình 320 px/chữ lớn. Yêu cầu giờ/tuần lấy từ dữ liệu thật; không
thay bằng số giờ đã làm hoặc phần trăm tiến độ. Kiểm thử vẫn dùng fixture/API
adapter; chưa kiểm tra các màn hình này bằng tài khoản backend hoặc thiết bị thật.

Cập nhật điều hướng doanh nghiệp ngày 06/10/2026: **246/246 test đạt**,
analyzer sạch. Test kiểm tra nhấn tên/logo trên thẻ thực tập, cơ hội, ứng tuyển
và chi tiết vị trí; nhấn doanh nghiệp không đồng thời mở đơn/vị trí, nhấn lặp
chỉ mở một trang, lookup lỗi giữ trang hiện tại và public account không đoán
ID theo tên. Backend public cần thêm company.id để tài khoản chưa có Student
mở từ cơ hội; app đã hỗ trợ response có ID mà không gọi route sinh viên.

Cập nhật Hồ sơ/CV ngày 08/10/2026: **261/261 test đạt**, analyzer sạch và
formatter không còn thay đổi. Test mới gồm partial PATCH/CV-only multipart,
profile độc lập với dashboard, dữ liệu CV trống, chọn tệp bị hủy/PDF không hợp
lệ, timeout không lặp upload, pending write chặn nhấn lặp/quay lại, ACK upload
nhưng reload lỗi khóa link cũ, URL không an toàn không được mở/log, đổi tên giữ
tab Hồ sơ, kiểm tra lại form sau timeout và màn hình 320 px/chữ lớn. Đã render
`student_profile.png`, `student_profile_edit.png`, `student_cv.png` trong
`.dart_tool/previews/`. Kiểm thử dùng fixture/API adapter; chưa thử upload và mở
PDF bằng tài khoản thật trên thiết bị thật.

Smoke checks deployment ngày 02/10/2026, không gửi secret:

| Request | Kết quả |
| --- | --- |
| GET `/health` | 200 |
| GET `/public/opportunities?page=1&limit=6` | 200 |
| POST `/auth/login`, JSON `{}` | 400, lỗi validation username/password |
| GET `/auth/me`, không token | 401 |
| GET `/auth/me`, Bearer token giả | 401 |
| GET `/swagger-json`, không secret | 401 |

```powershell
curl.exe https://tip-web-portal-api.vercel.app/health
curl.exe 'https://tip-web-portal-api.vercel.app/public/opportunities?page=1&limit=6'
curl.exe -X POST https://tip-web-portal-api.vercel.app/auth/login -H 'Content-Type: application/json' -d '{}'
```

Chưa kiểm thử đăng nhập web/mobile, refresh và profile/role denial end-to-end với
credential thật. Cần tài khoản test phù hợp và email nhận OTP để kiểm tra những
luồng đó; smoke checks không tạo tài khoản thật. Role denial, refresh và profile
được kiểm tra bằng Dio adapter trong test Flutter.
Chưa chạy end-to-end Student enrollment trên backend mới hoặc upload CV qua
native picker trên thiết bị; không tạo/duyệt yêu cầu hoặc tài khoản thật trong
các kiểm thử Flutter này.
