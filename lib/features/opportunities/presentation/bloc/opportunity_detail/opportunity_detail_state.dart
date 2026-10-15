import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/core/errors/failures.dart';

class OpportunityDetailState {
  const OpportunityDetailState({
    required this.item,
    required this.company,
    required this.failure,
    required this.companyFailure,
    required this.loading,
    required this.companyLoading,
    required this.confirmed,
  });
  final OpportunityOverview item;
  final CompanyOverview? company;
  final AuthFailure? failure;
  final AuthFailure? companyFailure;
  final bool loading;
  final bool companyLoading;
  final bool confirmed;
}
