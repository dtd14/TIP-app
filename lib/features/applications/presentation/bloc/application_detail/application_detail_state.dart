import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/applications/domain/entities/application_detail.dart';

class ApplicationDetailState {
  const ApplicationDetailState({
    required this.detail,
    required this.failure,
    required this.loading,
    required this.withdrawing,
    required this.confirmed,
    required this.withdrawn,
  });
  final ApplicationDetail? detail;
  final AuthFailure? failure;
  final bool loading;
  final bool withdrawing;
  final bool confirmed;
  final bool withdrawn;
}
