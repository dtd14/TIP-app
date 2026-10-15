import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';
import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/core/data/json_decoder.dart';
import 'package:tip_app/features/internships/data/models/internship_model.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/internships/data/datasources/internship_remote_data_source.dart';
import 'package:tip_app/core/data/api_request.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';

class InternshipRepositoryImpl implements InternshipRepository {
  const InternshipRepositoryImpl(this.remote, this.profileRepository);
  final InternshipRemoteDataSource remote;
  final StudentProfileRepository profileRepository;
  @override
  Future<PageSlice<PlacementOverview>> getPlacementPreview(String status) =>
      apiRequest(
        () async => JsonDecoder.page(
          await remote.placements(status),
          InternshipModel.placement,
        ),
      );
  @override
  Future<InternshipRegistration> getInternshipRegistration(
    String id,
    AuthUser user,
  ) => apiRequest(
    () async {
      final profile = await profileRepository.getStudentProfile(user);
      final registration = profile.internships
          .where((item) => item.id == id)
          .firstOrNull;
      if (registration == null) {
        throw const AuthFailure(
          FailureKind.validation,
          'Đợt thực tập không còn trong hồ sơ của bạn. Vui lòng tải lại danh sách.',
        );
      }
      if (registration.periodId == null) {
        throw const FormatException('Missing internship period identity');
      }
      final period = JsonDecoder.object(
        await remote.internshipPeriod(registration.periodId!),
      );
      if (period['id'] != registration.periodId ||
          (profile.universityId != null &&
              period['universityId'] != profile.universityId)) {
        throw const FormatException('Internship period identity mismatch');
      }
      return InternshipModel.registration({
        'id': id,
        'status': registration.status,
      }, period);
    },
    notFoundMessage:
        'Đợt thực tập hiện không còn khả dụng. Vui lòng tải lại danh sách.',
  );

  @override
  Future<PageSlice<InternshipPlacement>> getPlacements(
    AuthUser user, {
    int page = 1,
    String? registrationId,
  }) => apiRequest(
    () async => JsonDecoder.page(
      await remote.placementList(page: page, registrationId: registrationId),
      (data) {
        final detail = _ownedPlacement(data, user);
        if (registrationId != null && detail.registrationId != registrationId) {
          throw const FormatException('Placement registration mismatch');
        }
        return detail;
      },
    ),
  );
  @override
  Future<InternshipPlacement> getPlacement(
    String id,
    AuthUser user,
  ) => apiRequest(
    () async {
      final detail = _ownedPlacement(await remote.placementDetail(id), user);
      if (detail.overview.id != id) {
        throw const FormatException('Placement identity mismatch');
      }
      return detail;
    },
    notFoundMessage: 'Không tìm thấy vị trí thực tập trong tài khoản của bạn.',
  );
  InternshipPlacement _ownedPlacement(Object? data, AuthUser user) {
    final detail = InternshipModel.internshipPlacement(data);
    if (!user.canAccessStudentApp || detail.studentId != user.studentId) {
      throw const FormatException('Placement student mismatch');
    }
    return detail;
  }
}
