import 'package:tip_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

abstract interface class DashboardRepository {
  Future<DashboardSummary> getSummary(AuthUser user);
}
