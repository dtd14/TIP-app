import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/core/errors/failures.dart';

class OpportunityListState {
  const OpportunityListState({
    required this.items,
    required this.page,
    required this.failure,
    required this.loading,
    required this.retryReset,
  });
  final List<OpportunityOverview> items;
  final PageSlice<OpportunityOverview>? page;
  final AuthFailure? failure;
  final bool loading;
  final bool retryReset;
}
