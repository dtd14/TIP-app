import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';

class ApplyForOpportunity {
  const ApplyForOpportunity(this.repository);
  final ApplicationRepository repository;
  Future<ApplicationOverview> call(String id) =>
      repository.applyForOpportunity(id);
}
