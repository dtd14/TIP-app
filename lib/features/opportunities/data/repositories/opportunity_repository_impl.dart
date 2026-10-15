import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/core/data/json_decoder.dart';
import 'package:tip_app/features/opportunities/data/models/opportunity_model.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/data/datasources/opportunity_remote_data_source.dart';
import 'package:tip_app/core/data/api_request.dart';

class OpportunityRepositoryImpl implements OpportunityRepository {
  const OpportunityRepositoryImpl(this.remote);
  final OpportunityRemoteDataSource remote;
  @override
  Future<PageSlice<OpportunityOverview>> getOpportunities({int page = 1}) =>
      apiRequest(
        () async => JsonDecoder.page(
          await remote.opportunities(page: page),
          OpportunityModel.publicOpportunity,
        ),
      );

  @override
  Future<OpportunityOverview> getOpportunity(String id) => apiRequest(() async {
    final result = OpportunityModel.opportunity(await remote.opportunity(id));
    if (result.id != id) {
      throw const FormatException('Opportunity identity mismatch');
    }
    return result;
  }, notFoundMessage: 'Cơ hội không còn khả dụng. Vui lòng tải lại danh sách.');

  @override
  Future<CompanyOverview> getCompany(String id) => apiRequest(() async {
    final result = OpportunityModel.company(await remote.company(id));
    if (result.id != id) {
      throw const FormatException('Company identity mismatch');
    }
    return result;
  }, notFoundMessage: 'Doanh nghiệp không còn khả dụng. Vui lòng tải lại.');

  @override
  Future<List<OpportunityOverview>> getCompanyOpportunities(String companyId) =>
      apiRequest(() async {
        final response = await remote.availableOpportunities();
        if (response is! List) {
          throw const FormatException('Invalid opportunity list');
        }
        return List.unmodifiable(
          response
              .map(OpportunityModel.opportunity)
              .where(
                (item) => item.companyId == companyId && item.status == 'OPEN',
              ),
        );
      });
}
