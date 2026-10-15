import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/core/errors/failures.dart';

class ApplicationListState {
  const ApplicationListState({
    required this.items,
    required this.page,
    required this.failure,
    required this.loading,
    required this.retryReset,
    required this.status,
  });
  final List<ApplicationOverview> items;
  final PageSlice<ApplicationOverview>? page;
  final AuthFailure? failure;
  final bool loading;
  final bool retryReset;
  final String? status;
}
