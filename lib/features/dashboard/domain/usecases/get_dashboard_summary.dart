import 'package:tip_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardSummary {
  const GetDashboardSummary(this.repository);
  final DashboardRepository repository;
  Future<DashboardSummary> call(AuthUser user) => repository.getSummary(user);
}
