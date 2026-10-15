import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';

class GetApplications {
  const GetApplications(this.repository);
  final ApplicationRepository repository;
  Future<PageSlice<ApplicationOverview>> call({int page = 1, String? status}) =>
      repository.getApplications(page: page, status: status);
}
