import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/company_detail/company_detail_bloc.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/company_detail/company_detail_event.dart';
import 'package:tip_app/features/student_enrollment/presentation/bloc/student_enrollment/student_enrollment_bloc.dart';
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';
import 'support/enrollment_fakes.dart';

void main() {
  test(
    'company array renders pages locally and refresh resets the view',
    () async {
      final repository = FakeDashboardRepository()
        ..onCompanyOpportunities = (_) async => List.generate(
          13,
          (index) => OpportunityOverview(
            id: 'opportunity-$index',
            title: 'Intern',
            company: 'TIP',
            type: 'INTERNSHIP',
            description: 'Description',
          ),
        );
      final bloc = CompanyDetailBloc(repository, studentUser, 'company-1');
      addTearDown(bloc.close);
      await bloc.dispatch(CompanyOpportunitiesLoadRequested());
      expect(bloc.state.opportunities, hasLength(13));
      expect(bloc.state.visibleOpportunities, hasLength(12));
      expect(bloc.state.hasMoreOpportunities, true);
      await bloc.dispatch(CompanyMoreOpportunitiesRequested());
      expect(bloc.state.visibleOpportunities, hasLength(13));
      expect(bloc.state.hasMoreOpportunities, false);
      expect(repository.companyOpportunityCalls, 1);
      await bloc.dispatch(CompanyOpportunitiesLoadRequested());
      expect(bloc.state.visibleOpportunities, hasLength(12));
    },
  );

  test(
    'history pagination preserves membership checks outside visible rows',
    () async {
      final repository = FakeEnrollmentRepository()
        ..items = [
          ...List.generate(
            20,
            (index) => enrollment(id: 'old-$index', status: 'REJECTED'),
          ),
          enrollment(id: 'pending'),
        ];
      final bloc = StudentEnrollmentBloc(repository, nonStudentUser);
      addTearDown(bloc.close);
      await bloc.refresh();
      expect(bloc.state.visibleItems, hasLength(20));
      expect(bloc.state.hasPending, true);
      expect(bloc.state.hasMoreHistory, true);
      await bloc.submit(enrollmentInput);
      expect(repository.submitCalls, 0);
      await bloc.nextPage();
      expect(bloc.state.visibleItems, hasLength(21));
      expect(bloc.state.visibleItems.last.id, 'pending');
      expect(repository.mineCalls, 1);
      await bloc.refresh();
      expect(bloc.state.visibleItems, hasLength(20));
    },
  );
}
