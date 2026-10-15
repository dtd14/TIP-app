import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/core/data/json_decoder.dart';

abstract final class OpportunityModel {
  static OpportunityOverview publicOpportunity(Object? value) =>
      opportunity(value, publicListing: true);

  static OpportunityOverview opportunity(
    Object? value, {
    bool publicListing = false,
  }) {
    final data = JsonDecoder.object(value);
    final company = JsonDecoder.object(data['company']);
    final vacancies = data['vacancies'];
    if (vacancies != null && (vacancies is! int || vacancies < 1)) {
      throw const FormatException('Invalid vacancies');
    }
    return OpportunityOverview(
      id: JsonDecoder.text(data, 'id'),
      title: JsonDecoder.text(data, 'title'),
      company: JsonDecoder.text(company, 'name'),
      type: JsonDecoder.text(data, 'type'),
      description: JsonDecoder.text(data, 'description'),
      location: JsonDecoder.optionalText(data, 'location'),
      deadline: JsonDecoder.optionalDate(data, 'applicationDeadline'),
      vacancies: vacancies as int?,
      // The public controller only returns OPEN jobs from VERIFIED companies.
      status: publicListing ? 'OPEN' : JsonDecoder.text(data, 'status'),
      companyVerified: publicListing || company['status'] == 'VERIFIED',
      companyId: JsonDecoder.optionalText(company, 'id'),
      companyLogoUrl: JsonDecoder.optionalText(company, 'logoUrl'),
    );
  }

  static CompanyOverview company(Object? value) {
    final data = JsonDecoder.object(value);
    return CompanyOverview(
      id: JsonDecoder.text(data, 'id'),
      name: JsonDecoder.text(data, 'name'),
      status: JsonDecoder.text(data, 'status'),
      logoUrl: JsonDecoder.optionalText(data, 'logoUrl'),
      industry: JsonDecoder.optionalText(data, 'industry'),
      address: JsonDecoder.optionalText(data, 'address'),
      website: JsonDecoder.optionalText(data, 'website'),
    );
  }
}
