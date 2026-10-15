import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';

class GetOpportunity {
  const GetOpportunity(this.repository);
  final OpportunityRepository repository;
  Future<OpportunityOverview> call(String id) => repository.getOpportunity(id);
}
