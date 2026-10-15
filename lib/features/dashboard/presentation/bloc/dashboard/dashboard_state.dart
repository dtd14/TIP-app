import 'package:tip_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:tip_app/core/errors/failures.dart';

class DashboardState {
  const DashboardState({this.summary, this.loading = false, this.failure});
  final DashboardSummary? summary;
  final bool loading;
  final AuthFailure? failure;
}
