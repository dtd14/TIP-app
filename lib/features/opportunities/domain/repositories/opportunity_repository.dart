import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';

abstract interface class OpportunityRepository {
  Future<PageSlice<OpportunityOverview>> getOpportunities({int page = 1});
  Future<OpportunityOverview> getOpportunity(String id);
  Future<CompanyOverview> getCompany(String id);
  Future<List<OpportunityOverview>> getCompanyOpportunities(String companyId);
}
