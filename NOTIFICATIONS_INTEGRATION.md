# Tích hợp thông báo

## Contract đã cung cấp

Triển khai dựa trên `NotificationsController`, các DTO,
`NotificationsService` và model Prisma `Notification` người dùng cung cấp.
Mọi request dùng chung ApiClient, Bearer và cơ chế refresh phiên. Tài khoản
ACTIVE chưa có Student cũng có thể mở thông báo của chính tài khoản.

| Thao tác | Endpoint | Response |
| --- | --- | --- |
| Danh sách | `GET /notifications?filter=all&page=1&limit=20` | `{data, total, page, limit}` |
| Danh sách chưa đọc | `GET /notifications?filter=unread&page=1&limit=20` | Cùng cấu trúc |
| Số chưa đọc | `GET /notifications/unread-count` | `{count}` |
| Đọc một thông báo | `PATCH /notifications/:id/read` | NotificationDto đã có readAt |
| Đọc tất cả | `PATCH /notifications/read-all` | `{count}`: số bản ghi vừa cập nhật |

Các request PATCH không gửi cutoff, account ID hoặc readAt từ client.
Backend lấy tài khoản từ JWT và tự xác định thời điểm cập nhật. DTO cho phép
page 1–100000, limit 1–100; app mặc định dùng 20 hàng/trang.

NotificationDto gồm id, type, title, body, entityType, entityId, createdAt
và readAt nullable. `type`/`entityType` là String, chưa có enum contract;
app giữ các giá trị gốc và hiển thị title/body dưới dạng văn bản.

## Cấu trúc và giao diện

`lib/features/notifications/` có domain entities/repositories/usecases,
data datasources/models/repositories và presentation bloc/pages/widgets.
NotificationsBloc nhận các usecase; widget chỉ gửi event và đọc state.

NotificationsSession đặt BLoC phía trên navigator của phiên đã xác thực.
Badge, trang thông báo và các header chi tiết dùng chung state. Hủy phiên
hoặc thay tài khoản/quyền sẽ hủy BLoC, các trang và dữ liệu phiên cũ.

Header trang chính, chi tiết cơ hội và các màn hình dùng InternshipFrame
đã thay placeholder bằng NotificationBell. Trang thông báo dùng cùng màu,
thẻ bo góc, typography và giới hạn chiều rộng với portal; danh sách dùng
SliverList để tạo hàng theo viewport.

Chức năng REST hiện có:

- Badge số chưa đọc; hiển thị `99+` khi số lớn hơn 99.
- Bộ lọc tất cả/chưa đọc, pull-to-refresh, phân trang và retry đúng trang.
- Đọc một thông báo bằng nút đánh dấu hoặc khi mở toàn bộ nội dung.
- Đánh dấu tất cả đã đọc, rồi tải lại danh sách và số chưa đọc từ server.
- Tải count khi vào phiên, mở/tải lại trang và khi quay lại app.

Tải thêm thất bại giữ các hàng đã tải; merge theo ID và sắp theo createdAt,
sau đó ID giảm dần như backend. Khi đọc một hàng trong bộ lọc unread, BLoC
tải lại trang 1 vì việc loại bỏ hàng làm thay đổi offset của trang tiếp theo.

`read-all.count` không được đưa vào badge. BLoC đọc lại authoritative state
để thông báo đến sau cutoff của backend vẫn giữ trạng thái chưa đọc. Không
tự gán readAt cho các hàng từ đồng hồ client.

Count tải độc lập để request count chậm không chặn trang danh sách. Phản hồi
count cũ không ghi đè count từ request mới hơn. Lỗi count không làm mất danh
sách; phản hồi sau khi đóng phiên không cập nhật state.

## WebSocket và đồng bộ realtime

Đã đối chiếu thêm NotificationsGateway, NotificationTicketService,
NotificationDeliveryService và NotificationEventsService do người dùng cung cấp.
Gateway dùng WebSocket thuần tại `/notifications/ws`, không dùng Socket.IO.

1. Xin ticket mới bằng `POST /notifications/socket-ticket` qua ApiClient/Bearer.
2. Mở kết nối WS; URL không chứa ticket hay access token.
3. Gửi đúng một frame text `{"type":"authenticate","ticket":"..."}`.
4. Chờ `{"type":"notifications.ready"}`. Mỗi lần ready đều đồng bộ REST để
   nhận các thay đổi có thể đã bị bỏ lỡ khi offline.
5. `notifications.changed` chứa eventId, reason (`created`, `read`, `read-all`)
   và emittedAt. Đây là invalidation, không chứa danh sách/count hay recipient ID.
   BLoC tải lại count và danh sách nếu trang thông báo đang mở.

Ticket chỉ được dùng một lần. Reconnect luôn xin ticket mới; lỗi 4401 không tự
đăng xuất vì cũng có thể là access token cũ cần refresh. POST ticket tiếp theo
dùng cơ chế refresh của ApiClient. Ticket không được lưu vào storage hoặc log.

Client chờ xác nhận authenticate tối đa 4 giây (gateway cho 5 giây). Kết nối
hoặc xác thực thất bại dùng backoff 2/4/8/16/32/60 giây; HTTP 429 chờ 60 giây.
HTTP 503 với code `REALTIME_DISABLED` dừng thử socket cho subscription đó.
Khi realtime tắt hoặc mất kết nối, app đồng bộ REST định kỳ mỗi 30 giây khi
ở foreground. Khi kết nối phục hồi, chuyển sang đối soát REST mỗi 2 phút để
phục hồi cả invalidation bị mất dù socket vẫn kết nối (publish best effort).

Event liên tiếp được gộp trong 250 ms, dedupe 128 eventId gần nhất. Thay đổi
đến trong một lượt đồng bộ đang chạy tạo một lượt tiếp theo để không mất cập
nhật. App inactive/hidden/paused/detached hủy socket, ticket request đang chờ,
retry và polling; resumed tạo subscription mới và đồng bộ. Đăng xuất/thay
tài khoản hủy toàn bộ connection của phiên cũ.

Data layer tách native/web bằng conditional import, dùng
[web_socket_channel 3.0.3](https://pub.dev/packages/web_socket_channel).
Native truyền Origin qua header; browser tự gửi Origin của trang web.

## Cấu hình triển khai cần xác nhận

- `TIP_NOTIFICATIONS_WS_URL`: WSS URL thực tế, path chính xác `/notifications/ws`.
  Để trống thì suy ra cùng host với `TIP_API_BASE_URL`; cần xác nhận deployment
  đó thật sự gắn gateway và hỗ trợ HTTP upgrade.
- `TIP_NOTIFICATIONS_ORIGIN`: Origin HTTP(S) đã được thêm vào
  `NOTIFICATIONS_ALLOWED_ORIGINS` của backend, dành cho mobile/desktop.
  Không đoán một giá trị allowlist. Nếu chưa cấu hình, native sử dụng REST polling.
- Flutter web không thể đặt Origin tùy ý; backend phải cho phép Origin của
  website đang chạy app, kể cả port khi chạy localhost.

Ví dụ sau dùng giá trị minh họa, cần thay bằng URL/Origin được backend cho phép:

```powershell
flutter run --dart-define=TIP_NOTIFICATIONS_WS_URL=wss://api.example.com/notifications/ws --dart-define=TIP_NOTIFICATIONS_ORIGIN=https://app.example.com
```

## Điều hướng theo event service

| entityType | Màn hình/kiểm tra |
| --- | --- |
| Application | Chi tiết đơn thuộc sinh viên hiện tại; repository kiểm tra quyền sở hữu |
| Placement | Chi tiết vị trí, chỉ khi có quyền Student |
| InternshipPeriod | Tra lại profile để đổi periodId thành registrationId thuộc sinh viên, rồi mở chi tiết đợt |
| StudentEnrollment | Lịch sử yêu cầu ghi danh cá nhân |
| StudentEnrollmentReview | Hàng đợi xét duyệt, chỉ UNIVERSITY_ADMIN đủ quyền |
| AccountProfile | Chỉ account ID của chính mình; về tab hồ sơ và kiểm tra lại auth/me |

SchoolUser, CompanyUser, UniversityRegistration và loại chưa được app hỗ trợ
vẫn hiển thị nội dung; không mở một endpoint khác bằng ID suy đoán. Link ghi
danh mở danh sách/hàng đợi hiện có vì contract chưa cung cấp GET chi tiết một
yêu cầu. Các thao tác theo quyền tổ chức vẫn do backend kiểm soát.

MainShellController có phạm vi tài khoản để tab hồ sơ được giữ đúng khi kiểm
tra lại auth/me làm thay đổi quyền Student. Không cấp quyền từ nội dung thông báo.

## Kiểm tra

Test repository xác nhận route/query/Bearer, phạm vi DTO, response count và
readAt/identity. Test BLoC kiểm tra retry phân trang, chặn request lặp, count
đến muộn, read-all có thông báo mới và việc restart phân trang unread.
Widget test kiểm tra badge, quyền tài khoản không có Student, retry, mất phiên
và màn hình 320px với text scale 1.5. Tất cả dùng fixture, không gọi backend thật.

Test bổ sung kiểm tra ticket/Origin, fresh-ticket reconnect, disabled fallback,
auth timeout, cancel lúc xin ticket, đồng bộ/coalesce/polling, mapping quyền
điều hướng và profile approval thay đổi quyền Student. Một test dùng WebSocket
loopback thật để kiểm tra native transport; không kết nối backend production.

Kết quả kiểm tra: analyzer sạch, toàn bộ 315 test đều qua và build web debug
thành công, bao gồm conditional import cho native/web.

Giá trị URL/Origin của deployment production chưa
được cung cấp, nên chưa xác minh kết nối realtime với server đang triển khai.

```powershell
flutter analyze --no-pub
flutter test --no-pub
```
