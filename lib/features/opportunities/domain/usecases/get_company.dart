import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';

class GetCompany {
  const GetCompany(this.repository);
  final OpportunityRepository repository;
  Future<CompanyOverview> call(String id) => repository.getCompany(id);
}
