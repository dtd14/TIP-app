import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';

class GetOpportunities {
  const GetOpportunities(this.repository);
  final OpportunityRepository repository;
  Future<PageSlice<OpportunityOverview>> call({int page = 1}) =>
      repository.getOpportunities(page: page);
}
