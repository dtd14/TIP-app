import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';

class GetCompanyOpportunities {
  const GetCompanyOpportunities(this.repository);
  final OpportunityRepository repository;
  Future<List<OpportunityOverview>> call(String companyId) =>
      repository.getCompanyOpportunities(companyId);
}
