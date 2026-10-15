import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/applications/domain/entities/application_detail.dart';

abstract interface class ApplicationRepository {
  Future<PageSlice<ApplicationOverview>> getApplications({
    int page = 1,
    int limit = 20,
    String? status,
  });
  Future<ApplicationDetail> getApplication(String id, AuthUser user);
  Future<ApplicationDetail> withdrawApplication(String id, AuthUser user);
  Future<ApplicationOverview> applyForOpportunity(String id);
}
