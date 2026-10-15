# Refactor các feature theo cấu trúc auth

## Kết quả phân tích

Trước refactor, `DashboardRepository` chứa API của năm feature. Entity và bộ
giải mã hồ sơ, cơ hội, ứng tuyển, doanh nghiệp và thực tập nằm chung trong
dashboard. Các thư mục `data`, `domain/usecases` và `presentation/bloc` của
nhiều feature rỗng vì màn hình tự gọi repository và quản lý request bằng
`setState`. Repository hồ sơ và ghi danh còn trực tiếp tạo request Dio.

## Cấu trúc sau refactor

Mỗi feature hoạt động có ba lớp:

```text
features/<feature>/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
└── presentation/
    ├── bloc/<flow>/
    │   ├── <flow>_bloc.dart
    │   ├── <flow>_event.dart
    │   └── <flow>_state.dart
    ├── pages/
    └── widgets/
```

Luồng dữ liệu: `Page → BLoC → Usecase → Repository contract → RepositoryImpl
→ RemoteDataSource → ApiClient`.

Domain không import Flutter, Dio, data hoặc presentation. Presentation chỉ
dùng domain và BLoC; controller nhập liệu, clipboard, điều hướng và hộp thoại
vẫn thuộc widget. Data source thực hiện HTTP; model kiểm tra/giải mã response;
repository chuyển lỗi và kiểm tra quyền sở hữu bản ghi.

| Feature | Trách nhiệm | Các BLoC |
| --- | --- | --- |
| dashboard | Tổng hợp trang chủ qua repository của các feature | DashboardBloc |
| opportunities | Cơ hội và thông tin doanh nghiệp | OpportunityListBloc, OpportunityDetailBloc, CompanyDetailBloc |
| applications | Danh sách, chi tiết, rút đơn và xác nhận nộp đơn | ApplicationListBloc, ApplicationDetailBloc, ApplicationConfirmationBloc |
| internships | Đợt, vị trí và người hướng dẫn thực tập | InternshipListBloc, InternshipDetailBloc, PlacementDetailBloc |
| profile | Đọc/chỉnh sửa hồ sơ và tải CV | ProfileBloc, EditProfileBloc, StudentCvBloc |
| student_enrollment | Ghi danh, lịch sử, xét duyệt và chọn trường/ngành | StudentEnrollmentBloc, EnrollmentLookupBloc |

Entity `StudentProfile` thuộc profile; `ApplicationOverview`/`ApplicationDetail`
thuộc applications; `OpportunityOverview`/`CompanyOverview` thuộc opportunities;
entity đợt/vị trí thực tập thuộc internships. `PageSlice`, primitive giải mã JSON,
mapper lỗi API và widget giao diện dùng chung thuộc core. Auth giữ adapter
`AuthApiErrorMapper` với API hiện có, gọi mapper chung trong core.

`AppDependencies` cung cấp từng repository độc lập. Test dùng fake triển khai
nhiều contract riêng để tái sử dụng fixture, không đưa facade đa feature vào lib.
Dashboard data source tổng hợp qua các contract domain, không lấy trách nhiệm
API của các feature khác.

## Phân trang

| Danh sách | Cách phân trang | Kích thước |
| --- | --- | --- |
| Cơ hội public | Server: `page`, `limit`, tổng từ response | 12 |
| Đơn ứng tuyển | Server, giữ bộ lọc status khi tải thêm/retry | 20 |
| Vị trí thực tập, vị trí trong một đợt | Server, giữ studentInternshipId của đợt | 20 |
| Hàng đợi xét duyệt ghi danh | Server, giữ status và keyword | 20 |
| Cơ hội của doanh nghiệp | Hiển thị từng trang từ response mảng | 12 |
| Các đợt trong hồ sơ | Hiển thị từng trang từ response mảng | 20 |
| Lịch sử ghi danh cá nhân | Hiển thị từng trang từ mảng API trả về (tối đa 50 bản ghi) | 20 |

Endpoint trả mảng chưa cung cấp contract phân trang server. Phân trang hiển thị
giúp giới hạn số hàng trên màn hình, nhưng vẫn phải tải toàn bộ mảng. Chọn
trường giữ giới hạn 50 kết quả của API và tìm kiếm có debounce; chọn ngành dùng
danh sách của trường đã chọn. Không thêm tham số API chưa được hỗ trợ.

BLoC giữ trang hiện tại, lỗi và kiểu retry. Tải thêm thất bại giữ danh sách cũ
và retry đúng trang; refresh thay danh sách từ trang 1. ID trùng được cập nhật,
không thêm hàng trùng. Hết trang thì bỏ qua request tiếp theo. Request đang
chờ được chặn lặp; phản hồi sau khi đóng BLoC không cập nhật UI.

Tìm kiếm/lọc cơ hội vẫn áp dụng trên dữ liệu đã tải theo contract hiện tại.
Quyền ghi danh dựa trên toàn bộ lịch sử đã tải, kể cả bản ghi chưa hiển thị.

## Giữ nguyên các kiểm tra nghiệp vụ

Các adapter vẫn kiểm tra account/student ID, quyền sở hữu đơn/vị trí, liên
kết nullable của vị trí trực tiếp và trạng thái hồ sơ. Rút đơn đọc lại trạng
thái sau conflict hoặc kết quả chưa chắc chắn. Cập nhật CV chỉ gửi tệp `cv`;
tên/điện thoại và các trường học vụ không bị gửi kèm từ snapshot cũ.

Điều hướng và snackbar thành công chỉ chạy khi kết quả thành công thay đổi,
tránh pop route hai lần khi BLoC phát state kết thúc request.

## Thư mục thừa chờ xác nhận

`lib/features/placements/` và toàn bộ thư mục con đang rỗng, không được import.
Nghiệp vụ vị trí đã được triển khai trong internships, cùng trang danh sách,
chi tiết, model, repository, usecase và BLoC. Có thể xóa toàn bộ cây placements
nếu không định tách thành feature riêng.

**Chưa xóa thư mục nào. Việc xóa cây placements chỉ thực hiện sau khi người
dùng xác nhận.** Các thư mục feature còn lại trước đây rỗng đã được sử dụng.

## Kiểm tra

```powershell
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
```

Test API/widget hiện có được nối lại theo repository sở hữu. Test phân trang
mới kiểm tra retry giữ trang/dữ liệu, cập nhật ID trùng, reset khi refresh,
chặn request lặp, đóng BLoC khi đang chờ, phân trang mảng và kiểm tra yêu cầu
PENDING ngoài các hàng đang hiển thị.

Kết quả kiểm tra sau refactor: `flutter analyze --no-pub` không báo lỗi/cảnh
báo; toàn bộ 267 test đều qua. Các kiểm tra API dùng adapter/fixture, không
gọi backend thật.
