import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/core/errors/failures.dart';

class CompanyDetailState {
  const CompanyDetailState({
    this.visibleCount = 12,
    required this.company,
    required this.opportunities,
    required this.companyFailure,
    required this.opportunityFailure,
    required this.companyLoading,
    required this.opportunitiesLoading,
  });
  final int visibleCount;
  List<OpportunityOverview>? get visibleOpportunities => opportunities == null
      ? null
      : List.unmodifiable(opportunities!.take(visibleCount));
  bool get hasMoreOpportunities => (opportunities?.length ?? 0) > visibleCount;
  final CompanyOverview? company;
  final List<OpportunityOverview>? opportunities;
  final AuthFailure? companyFailure;
  final AuthFailure? opportunityFailure;
  final bool companyLoading;
  final bool opportunitiesLoading;
}
