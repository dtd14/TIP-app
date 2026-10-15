import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/data/models/opportunity_model.dart';
import 'package:tip_app/features/internships/data/models/internship_model.dart';
import 'package:tip_app/features/applications/data/models/application_model.dart';
import 'package:tip_app/features/profile/data/models/student_profile_model.dart';
import 'package:tip_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/applications/domain/entities/application_detail.dart';
import 'package:tip_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/core/errors/failures.dart';

Map<String, Object?> profileFixture({
  String status = 'ACTIVE',
  String accountId = 'account-1',
  List<Object?>? internships,
}) => {
  'id': 'student-1',
  'accountId': accountId,
  'universityId': 'school-1',
  'studentCode': '2180607989',
  'semester': 2,
  'className': 'CNTT21',
  'status': status,
  'account': {
    'fullName': 'Nguyễn Văn An',
    'email': 'student@example.com',
    'status': 'ACTIVE',
    'phone': null,
  },
  'major': {'name': 'Công nghệ thông tin'},
  'university': {'id': 'school-1', 'name': 'Đại học TIP'},
  'internships':
      internships ??
      [
        {
          'id': 'registration-1',
          'status': 'APPLYING',
          'internshipPeriodId': 'period-1',
          'internshipPeriod': internshipPeriodFixture,
        },
      ],
};
const internshipPeriodFixture = {
  'id': 'period-1',
  'universityId': 'school-1',
  'academicYearId': 'year-1',
  'name': 'Đợt thực tập HK2 · 2026',
  'status': 'OPEN',
  'periodNumber': 2,
  'startDate': '2026-09-01T00:00:00Z',
  'endDate': '2026-12-31T00:00:00Z',
  'applyStartDate': '2026-08-01T00:00:00Z',
  'applyEndDate': '2026-08-31T00:00:00Z',
  'requiredHours': 240,
  'requiredWeeks': 12,
};
Map<String, Object?> placementDetailFixture({
  String status = 'IN_PROGRESS',
  bool linked = true,
}) => {
  ...placementFixture,
  'status': status,
  'studentId': 'student-1',
  'companyId': 'company-1',
  'universityId': 'school-1',
  'company': {'id': 'company-1', 'name': 'TIP Technology'},
  'university': {'id': 'school-1', 'name': 'Đại học TIP', 'code': 'TIP'},
  'student': {
    'id': 'student-1',
    'studentCode': '2180607989',
    'account': {
      'fullName': 'Nguyễn Văn An',
      'email': 'student@example.com',
      'phone': null,
    },
  },
  'studentInternshipId': linked ? 'registration-1' : null,
  'opportunityId': linked ? 'opportunity-1' : null,
  'applicationId': linked ? 'application-1' : null,
  'studentInternship': linked
      ? {
          'id': 'registration-1',
          'status': 'IN_PROGRESS',
          'internshipPeriod': {
            'id': 'period-1',
            'name': 'Đợt thực tập HK2 · 2026',
            'startDate': '2026-09-01T00:00:00Z',
            'endDate': '2026-12-31T00:00:00Z',
          },
        }
      : null,
  'application': linked ? {'id': 'application-1', 'status': 'ACCEPTED'} : null,
  'opportunity': linked
      ? {
          'id': 'opportunity-1',
          'title': 'Android Developer Intern',
          'type': 'INTERNSHIP',
        }
      : null,
  'universitySupervisor': {
    'id': 'school-supervisor-1',
    'role': 'UNIVERSITY_SUPERVISOR',
    'account': {
      'fullName': 'Nguyễn Tuấn Anh',
      'email': 'supervisor@example.edu.vn',
      'phone': '0901234567',
    },
  },
  'companySupervisor': {
    'id': 'company-supervisor-1',
    'role': 'STAFF',
    'account': {
      'fullName': 'Trần Văn C',
      'email': 'mentor@example.com',
      'phone': null,
    },
  },
};
const applicationFixture = {
  'id': 'application-1',
  'status': 'ACCEPTED',
  'appliedAt': '2026-10-01T00:00:00Z',
  'updatedAt': '2026-10-02T00:00:00Z',
  'opportunity': {
    'title': 'Android Developer Intern',
    'company': {'name': 'ABC Technology'},
  },
};
Map<String, Object?> applicationDetailFixture({String status = 'PENDING'}) => {
  ...applicationFixture,
  'status': status,
  'studentId': 'student-1',
  'opportunityId': 'opportunity-1',
  'student': {
    'id': 'student-1',
    'studentCode': '2180607989',
    'cvUrl': 'https://example.com/cv.pdf',
    'major': {'id': 'major-1', 'name': 'Công nghệ thông tin'},
    'account': {
      'fullName': 'Nguyễn Văn An',
      'email': 'student@example.com',
      'phone': '0901234567',
    },
  },
  'university': {'id': 'school-1', 'name': 'Đại học TIP', 'code': 'TIP'},
  'opportunity': {
    'id': 'opportunity-1',
    'title': 'Android Developer Intern',
    'type': 'INTERNSHIP',
    'status': 'OPEN',
    'applicationDeadline': '2099-10-31T00:00:00Z',
    'vacancies': 5,
    'company': {
      'id': 'company-1',
      'name': 'ABC Technology',
      'status': 'VERIFIED',
    },
  },
};
const placementFixture = {
  'id': 'placement-1',
  'status': 'IN_PROGRESS',
  'positionTitle': 'Android Developer Intern',
  'company': {'name': 'Công ty Cổ phần ABC Technology'},
  'startDate': '2026-09-01T00:00:00Z',
  'endDate': '2026-12-31T00:00:00Z',
  'universitySupervisor': {
    'account': {'fullName': 'Nguyễn Tuấn Anh'},
  },
};
const opportunityFixture = {
  'id': 'opportunity-1',
  'title': 'Flutter Developer Intern',
  'type': 'INTERNSHIP',
  'company': {'name': 'TIP Technology'},
  'description': 'Tham gia phát triển ứng dụng Flutter.',
  'location': 'TP. Hồ Chí Minh',
  'applicationDeadline': null,
  'vacancies': 5,
};
final opportunityDetailFixture = {
  ...opportunityFixture,
  'status': 'OPEN',
  'company': {
    'id': 'company-1',
    'name': 'TIP Technology',
    'status': 'VERIFIED',
    'logoUrl': null,
  },
};
const companyFixture = {
  'id': 'company-1',
  'name': 'TIP Technology',
  'status': 'VERIFIED',
  'industry': 'Phát triển phần mềm',
  'website': 'https://example.com',
  'address': 'TP. Hồ Chí Minh',
  'logoUrl': null,
};
Map<String, Object?> pageFixture(
  List<Object?> items, {
  int? total,
  int page = 1,
  int limit = 20,
}) => {
  'data': items,
  'total': total ?? items.length,
  'page': page,
  'limit': limit,
};

DashboardSummary dashboardFixture({bool empty = false}) => DashboardSummary(
  profile: StudentProfileModel.profile(
    profileFixture(internships: empty ? [] : null),
  ),
  applications: empty ? [] : [ApplicationModel.application(applicationFixture)],
  submitted: empty ? 0 : 5,
  reviewing: empty ? 0 : 2,
  accepted: empty ? 0 : 1,
  placement: empty ? null : InternshipModel.placement(placementFixture),
);

class FakeDashboardRepository
    implements
        DashboardRepository,
        OpportunityRepository,
        ApplicationRepository,
        InternshipRepository,
        StudentProfileRepository {
  @override
  Future<PageSlice<PlacementOverview>> getPlacementPreview(
    String status,
  ) async => PageSlice(items: [], total: 0, page: 1, limit: 1);
  @override
  Future<void> update({String? fullName, String? phone, CvUpload? cv}) async {}
  Future<InternshipRegistration> Function(String)? onRegistration;
  Future<PageSlice<InternshipPlacement>> Function(int, String?)? onPlacements;
  Future<InternshipPlacement> Function(String)? onPlacement;
  Future<List<OpportunityOverview>> Function(String)? onCompanyOpportunities;
  final placementQueries = <(int, String?)>[];
  int registrationCalls = 0, placementCalls = 0, companyOpportunityCalls = 0;
  Future<DashboardSummary> Function(AuthUser)? onSummary;
  Future<PageSlice<ApplicationOverview>> Function(int page)? onApplications;
  Future<PageSlice<OpportunityOverview>> Function(int page)? onOpportunities;
  Future<OpportunityOverview> Function(String id)? onOpportunity;
  Future<CompanyOverview> Function(String id)? onCompany;
  Future<ApplicationOverview> Function(String id)? onApply;
  Future<StudentProfile> Function(AuthUser)? onProfile;
  Future<ApplicationDetail> Function(String)? onApplication, onWithdraw;
  Future<PageSlice<ApplicationOverview>> Function(int, String?)?
  onFilteredApplications;
  final applicationQueries = <(int, String?)>[];
  int profileCalls = 0, applicationDetailCalls = 0, withdrawCalls = 0;
  String applicationStatus = 'PENDING';
  final opportunityPages = <int>[];
  int detailCalls = 0, companyCalls = 0, applyCalls = 0;
  int summaryCalls = 0;
  @override
  Future<DashboardSummary> getSummary(AuthUser user) async {
    summaryCalls++;
    return onSummary == null ? dashboardFixture() : onSummary!(user);
  }

  @override
  Future<PageSlice<ApplicationOverview>> getApplications({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    applicationQueries.add((page, status));
    if (onFilteredApplications != null) {
      return onFilteredApplications!(page, status);
    }
    return onApplications == null
        ? PageSlice(
            items: [ApplicationModel.application(applicationFixture)],
            total: 1,
            page: page,
            limit: 20,
          )
        : onApplications!(page);
  }

  @override
  Future<StudentProfile> getStudentProfile(AuthUser user) async {
    profileCalls++;
    return onProfile == null ? dashboardFixture().profile : onProfile!(user);
  }

  @override
  Future<ApplicationDetail> getApplication(String id, AuthUser user) async {
    applicationDetailCalls++;
    return onApplication == null
        ? ApplicationModel.applicationDetail(
            applicationDetailFixture(status: applicationStatus),
          )
        : onApplication!(id);
  }

  @override
  Future<ApplicationDetail> withdrawApplication(
    String id,
    AuthUser user,
  ) async {
    withdrawCalls++;
    if (onWithdraw != null) return onWithdraw!(id);
    applicationStatus = 'WITHDRAWN';
    return ApplicationModel.applicationDetail(
      applicationDetailFixture(status: applicationStatus),
    );
  }

  @override
  Future<PageSlice<OpportunityOverview>> getOpportunities({
    int page = 1,
  }) async {
    opportunityPages.add(page);
    return onOpportunities != null
        ? onOpportunities!(page)
        : PageSlice(
            items: [OpportunityModel.publicOpportunity(opportunityFixture)],
            total: 1,
            page: page,
            limit: 12,
          );
  }

  @override
  Future<OpportunityOverview> getOpportunity(String id) async {
    detailCalls++;
    return onOpportunity != null
        ? onOpportunity!(id)
        : OpportunityModel.opportunity(opportunityDetailFixture);
  }

  @override
  Future<CompanyOverview> getCompany(String id) async {
    companyCalls++;
    return onCompany != null
        ? onCompany!(id)
        : OpportunityModel.company(companyFixture);
  }

  @override
  Future<ApplicationOverview> applyForOpportunity(String id) async {
    applyCalls++;
    return onApply != null
        ? onApply!(id)
        : ApplicationModel.application(applicationFixture);
  }

  @override
  Future<InternshipRegistration> getInternshipRegistration(
    String id,
    AuthUser user,
  ) async {
    registrationCalls++;
    if (onRegistration != null) return onRegistration!(id);
    final profile = await getStudentProfile(user);
    final registration = profile.internships
        .where((item) => item.id == id)
        .firstOrNull;
    if (registration == null) {
      throw const AuthFailure(
        FailureKind.validation,
        'Đợt thực tập không còn trong hồ sơ của bạn.',
      );
    }
    return registration;
  }

  @override
  Future<PageSlice<InternshipPlacement>> getPlacements(
    AuthUser user, {
    int page = 1,
    String? registrationId,
  }) async {
    placementQueries.add((page, registrationId));
    if (onPlacements != null) return onPlacements!(page, registrationId);
    return PageSlice(
      items: [InternshipModel.internshipPlacement(placementDetailFixture())],
      total: 1,
      page: page,
      limit: 20,
    );
  }

  @override
  Future<InternshipPlacement> getPlacement(String id, AuthUser user) async {
    placementCalls++;
    return onPlacement != null
        ? onPlacement!(id)
        : InternshipModel.internshipPlacement(placementDetailFixture());
  }

  @override
  Future<List<OpportunityOverview>> getCompanyOpportunities(
    String companyId,
  ) async {
    companyOpportunityCalls++;
    return onCompanyOpportunities != null
        ? onCompanyOpportunities!(companyId)
        : [
            OpportunityModel.opportunity({
              ...opportunityDetailFixture,
              'applicationDeadline': '2099-10-31T00:00:00Z',
            }),
          ];
  }
}
