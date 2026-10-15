import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:tip_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:tip_app/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:tip_app/core/data/api_request.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this.remote);
  final DashboardRemoteDataSource remote;
  @override
  Future<DashboardSummary> getSummary(AuthUser user) =>
      apiRequest(() => remote.summary(user));
}
