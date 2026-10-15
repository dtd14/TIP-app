import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';

class PlacementDetailState {
  const PlacementDetailState({
    required this.detail,
    required this.company,
    required this.failure,
    required this.companyFailure,
    required this.loading,
    required this.companyLoading,
  });
  final InternshipPlacement? detail;
  final CompanyOverview? company;
  final AuthFailure? failure;
  final AuthFailure? companyFailure;
  final bool loading;
  final bool companyLoading;
}
