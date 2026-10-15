import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'nest_auth_remote_data_source_test.dart'
    show ControllerAdapter, meFixture, activeStudent;
import 'support/auth_fakes.dart';
import 'support/dashboard_fixtures.dart';
import 'support/nest_fixtures.dart';

void main() {
  late AppDependencies dependencies;
  late ControllerAdapter adapter;
  late DashboardRepository repository;
  setUp(() async {
    dependencies = AppDependencies.create(
      sessionStorage: MemorySessionStorage()..value = testCredential,
    );
    adapter = ControllerAdapter()..response = meFixture(student: activeStudent);
    dependencies.apiClient.dio.httpClientAdapter = adapter;
    await dependencies.authRepository.getCurrentUser();
    adapter.requests.clear();
    repository = dependencies.dashboardRepository;
    adapter.onRequest = (options) {
      if (options.path == '/students/me') return body(profileFixture());
      if (options.path == '/applications') {
        final status = options.queryParameters['status'];
        return body(
          pageFixture(
            [applicationFixture],
            total: status == 'REVIEWING'
                ? 2
                : status == 'ACCEPTED'
                ? 1
                : 105,
            limit: options.queryParameters['limit'] as int,
          ),
        );
      }
      if (options.path == '/placements') {
        return body(
          pageFixture(
            options.queryParameters['status'] == 'IN_PROGRESS'
                ? [placementFixture]
                : [],
            limit: 1,
          ),
        );
      }
      return body(
        pageFixture(
          [opportunityFixture],
          page: options.queryParameters['page'] as int,
          limit: 12,
        ),
      );
    };
  });
  tearDown(() => dependencies.dispose());

  test('dashboard uses exact totals and protected student routes', () async {
    final summary = await repository.getSummary(studentUser);
    expect(summary.profile.studentCode, '2180607989');
    expect(summary.submitted, 105); // Not the length of the three-row preview.
    expect(summary.reviewing, 2);
    expect(summary.accepted, 1);
    expect(summary.placement!.status, 'IN_PROGRESS');
    expect(adapter.requests, hasLength(7));
    expect(adapter.requests.first.path, '/students/me');
    expect(
      adapter.requests.every(
        (request) =>
            request.headers['Authorization'] == 'Bearer test-only-token',
      ),
      isTrue,
    );
    expect(
      adapter.requests.every(
        (request) =>
            request.method == 'GET' &&
            !request.headers.keys.any((key) => key.toLowerCase() == 'x-secret'),
      ),
      isTrue,
    );
    expect(
      adapter.requests
          .where((request) => request.path == '/applications')
          .map((request) => request.queryParameters['status']),
      [null, 'REVIEWING', 'ACCEPTED'],
    );
  });

  test(
    'inactive profile stops dashboard requests before returning data',
    () async {
      adapter.onRequest = (_) => body(profileFixture(status: 'SUSPENDED'));
      await expectLater(
        repository.getSummary(studentUser),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            FailureKind.inactiveAccount,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test('another account profile is rejected', () async {
    adapter.onRequest = (_) =>
        body(profileFixture(accountId: 'another-account'));
    await expectLater(
      repository.getSummary(studentUser),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          FailureKind.server,
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('API account suspension maps to an access restriction', () async {
    adapter.onRequest = (_) =>
        body({'message': 'Student is not active'}, status: 403);
    await expectLater(
      repository.getSummary(studentUser),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          FailureKind.inactiveAccount,
        ),
      ),
    );
  });

  test(
    'public opportunities remain unauthenticated and support paging',
    () async {
      final page = await dependencies.opportunityRepository.getOpportunities(
        page: 2,
      );
      expect(page.page, 2);
      expect(page.items.single.title, 'Flutter Developer Intern');
      expect(page.items.single.vacancies, 5);
      expect(page.items.single.status, 'OPEN');
      expect(page.items.single.companyVerified, isTrue);
      expect(adapter.requests.single.path, '/public/opportunities');
      expect(adapter.requests.single.headers['Authorization'], isNull);
      expect(adapter.requests.single.queryParameters, {'page': 2, 'limit': 12});
    },
  );

  test('student detail uses Bearer; company details are public', () async {
    adapter.onRequest = (options) => body(
      options.path.startsWith('/opportunities/')
          ? opportunityDetailFixture
          : companyFixture,
    );
    final item = await dependencies.opportunityRepository.getOpportunity(
      'opportunity-1',
    );
    final company = await dependencies.opportunityRepository.getCompany(
      item.companyId!,
    );
    expect(item.vacancies, 5);
    expect(company.industry, 'Phát triển phần mềm');
    expect(adapter.requests[0].path, '/opportunities/opportunity-1');
    expect(
      adapter.requests[0].headers['Authorization'],
      'Bearer test-only-token',
    );
    expect(adapter.requests[1].path, '/companies/company-1');
    expect(adapter.requests[1].headers['Authorization'], isNull);
  });

  test('application sends only opportunityId with Bearer', () async {
    adapter.onRequest = (_) => body(applicationFixture, status: 201);
    final result = await dependencies.applicationRepository.applyForOpportunity(
      'opportunity-1',
    );
    expect(result.id, 'application-1');
    final request = adapter.requests.single;
    expect(request.path, '/applications');
    expect(request.method, 'POST');
    expect(request.data, {'opportunityId': 'opportunity-1'});
    expect(request.headers['Authorization'], 'Bearer test-only-token');
  });

  test(
    'duplicate application has application guidance without register errors',
    () async {
      adapter.onRequest = (_) =>
          body({'message': 'Already applied'}, status: 409);
      await expectLater(
        dependencies.applicationRepository.applyForOpportunity('opportunity-1'),
        throwsA(
          isA<AuthFailure>()
              .having(
                (failure) => failure.message,
                'message',
                contains('đã ứng tuyển'),
              )
              .having(
                (failure) => failure.fieldErrors,
                'field errors',
                isEmpty,
              ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'application timeout is not repeated and has uncertain-outcome guidance',
    () async {
      adapter.onRequest = (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
      await expectLater(
        dependencies.applicationRepository.applyForOpportunity('opportunity-1'),
        throwsA(
          isA<AuthFailure>()
              .having((failure) => failure.kind, 'kind', FailureKind.timeout)
              .having(
                (failure) => failure.message,
                'message',
                contains('kiểm tra mục Ứng tuyển'),
              ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test('application role denial remains forbidden without retry', () async {
    adapter.onRequest = (_) =>
        body({'message': 'Student profile is required'}, status: 403);
    await expectLater(
      dependencies.applicationRepository.applyForOpportunity('opportunity-1'),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          FailureKind.forbidden,
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('opportunity identity mismatch is rejected', () async {
    adapter.onRequest = (_) =>
        body({...opportunityDetailFixture, 'id': 'other-id'});
    await expectLater(
      dependencies.opportunityRepository.getOpportunity('opportunity-1'),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          FailureKind.server,
        ),
      ),
    );
  });

  test(
    'micro internships retain their backend type in the displayed label',
    () async {
      adapter.onRequest = (_) => body(
        pageFixture([
          {...opportunityFixture, 'type': 'MICRO_INTERNSHIP'},
        ], limit: 12),
      );
      final page = await dependencies.opportunityRepository.getOpportunities();
      expect(page.items.single.typeLabel, 'Thực tập ngắn hạn');
    },
  );

  test('network errors never become an empty success', () async {
    adapter.onRequest = (options) => throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
    await expectLater(
      repository.getSummary(studentUser),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          FailureKind.network,
        ),
      ),
    );
  });

  test(
    'application list uses server status filtering and bearer scope',
    () async {
      await dependencies.applicationRepository.getApplications(
        page: 2,
        status: 'REVIEWING',
      );
      final request = adapter.requests.single;
      expect(request.path, '/applications');
      expect(request.queryParameters, {
        'page': 2,
        'limit': 20,
        'status': 'REVIEWING',
      });
      expect(request.headers['Authorization'], 'Bearer test-only-token');
    },
  );

  test(
    'application detail reads the current student CV from the include',
    () async {
      adapter.onRequest = (_) => body(applicationDetailFixture());
      final detail = await dependencies.applicationRepository.getApplication(
        'application-1',
        studentUser,
      );
      expect(detail.studentCode, '2180607989');
      expect(detail.cvUrl, 'https://example.com/cv.pdf');
      expect(detail.application.canWithdraw, isTrue);
      expect(detail.application.companyVerified, isTrue);
      expect(adapter.requests.single.path, '/applications/application-1');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer test-only-token',
      );
    },
  );

  for (final field in ['id', 'studentId', 'opportunityId']) {
    test(
      'application rejects a mismatched $field in the server response',
      () async {
        adapter.onRequest = (_) =>
            body({...applicationDetailFixture(), field: 'another-id'});
        await expectLater(
          dependencies.applicationRepository.getApplication(
            'application-1',
            studentUser,
          ),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.kind,
              'kind',
              FailureKind.server,
            ),
          ),
        );
      },
    );
  }

  test('withdraw sends one bearer PATCH with no invented body', () async {
    adapter.onRequest = (_) =>
        body(applicationDetailFixture(status: 'WITHDRAWN'));
    final detail = await dependencies.applicationRepository.withdrawApplication(
      'application-1',
      studentUser,
    );
    expect(detail.application.canWithdraw, isFalse);
    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/applications/application-1/withdraw');
    expect(request.data, isNull);
    expect(request.headers['Authorization'], 'Bearer test-only-token');
    expect(
      request.headers.keys.any((key) => key.toLowerCase() == 'x-secret'),
      isFalse,
    );
  });

  for (final (status, kind) in [
    (400, FailureKind.validation),
    (409, FailureKind.conflict),
    (404, FailureKind.server),
    (403, FailureKind.forbidden),
  ]) {
    test(
      'withdraw $status returns guidance without automatically retrying',
      () async {
        adapter.onRequest = (_) =>
            body({'message': 'Action refused'}, status: status);
        await expectLater(
          dependencies.applicationRepository.withdrawApplication(
            'application-1',
            studentUser,
          ),
          throwsA(isA<AuthFailure>().having((f) => f.kind, 'kind', kind)),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  test('withdraw timeout is uncertain and never repeats the PATCH', () async {
    adapter.onRequest = (options) => throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
    );
    await expectLater(
      dependencies.applicationRepository.withdrawApplication(
        'application-1',
        studentUser,
      ),
      throwsA(
        isA<AuthFailure>()
            .having((f) => f.kind, 'kind', FailureKind.timeout)
            .having(
              (f) => f.message,
              'message',
              contains('tải lại trạng thái'),
            ),
      ),
    );
    expect(adapter.requests, hasLength(1));
  });

  test(
    'internship detail refreshes own registration and period via bearer GETs',
    () async {
      adapter.onRequest = (options) => body(
        options.path == '/students/me'
            ? profileFixture()
            : {...internshipPeriodFixture, 'requiredHours': 320},
      );
      final item = await dependencies.internshipRepository
          .getInternshipRegistration('registration-1', studentUser);
      expect(item.status, 'APPLYING');
      expect(item.periodId, 'period-1');
      expect(item.requiredHours, 320);
      expect(item.requiredWeeks, 12);
      expect(adapter.requests.map((request) => request.path), [
        '/students/me',
        '/internship-period/period-1',
      ]);
      expect(
        adapter.requests.every(
          (request) =>
              request.method == 'GET' &&
              request.headers['Authorization'] == 'Bearer test-only-token' &&
              !request.headers.containsKey('X-Secret'),
        ),
        isTrue,
      );
    },
  );

  test(
    'unassigned period cannot be opened by guessing a registration ID',
    () async {
      adapter.onRequest = (_) => body(profileFixture(internships: []));
      await expectLater(
        dependencies.internshipRepository.getInternshipRegistration(
          'registration-1',
          studentUser,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.kind,
            'kind',
            FailureKind.validation,
          ),
        ),
      );
      expect(adapter.requests.single.path, '/students/me');
    },
  );

  for (final field in ['id', 'universityId']) {
    test('internship period rejects a mismatched $field', () async {
      adapter.onRequest = (options) => body(
        options.path == '/students/me'
            ? profileFixture()
            : {...internshipPeriodFixture, field: 'other-id'},
      );
      await expectLater(
        dependencies.internshipRepository.getInternshipRegistration(
          'registration-1',
          studentUser,
        ),
        throwsA(
          isA<AuthFailure>().having((f) => f.kind, 'kind', FailureKind.server),
        ),
      );
    });
  }

  test(
    'nullable period requirements are omitted instead of defaulting to 240 hours',
    () async {
      adapter.onRequest = (options) => body(
        options.path == '/students/me'
            ? profileFixture()
            : {
                ...internshipPeriodFixture,
                'requiredHours': null,
                'requiredWeeks': null,
                'applyStartDate': null,
                'applyEndDate': null,
              },
      );
      final item = await dependencies.internshipRepository
          .getInternshipRegistration('registration-1', studentUser);
      expect(item.requiredHours, isNull);
      expect(item.requiredWeeks, isNull);
      expect(item.applyEndDate, isNull);
    },
  );

  test(
    'placements are server-scoped, paginated and can filter by registration',
    () async {
      adapter.onRequest = (options) => body(
        pageFixture([
          placementDetailFixture(),
        ], page: options.queryParameters['page'] as int),
      );
      final page = await dependencies.internshipRepository.getPlacements(
        studentUser,
        page: 2,
        registrationId: 'registration-1',
      );
      expect(page.page, 2);
      expect(page.items.single.companySupervisor!.email, 'mentor@example.com');
      expect(adapter.requests.single.queryParameters, {
        'page': 2,
        'limit': 20,
        'studentInternshipId': 'registration-1',
      });
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer test-only-token',
      );
    },
  );

  for (final field in [
    'id',
    'studentId',
    'companyId',
    'studentInternshipId',
    'applicationId',
    'opportunityId',
  ]) {
    test('placement rejects mismatched $field in the response', () async {
      adapter.onRequest = (_) =>
          body({...placementDetailFixture(), field: 'other-id'});
      await expectLater(
        dependencies.internshipRepository.getPlacement(
          'placement-1',
          studentUser,
        ),
        throwsA(
          isA<AuthFailure>().having((f) => f.kind, 'kind', FailureKind.server),
        ),
      );
    });
  }

  test(
    'placement list rejects consistent data from another student or registration',
    () async {
      final data = placementDetailFixture();
      data['studentId'] = 'other-student';
      data['student'] = {
        ...data['student'] as Map<String, Object?>,
        'id': 'other-student',
      };
      adapter.onRequest = (_) => body(pageFixture([data]));
      await expectLater(
        dependencies.internshipRepository.getPlacements(studentUser),
        throwsA(
          isA<AuthFailure>().having((f) => f.kind, 'kind', FailureKind.server),
        ),
      );
      adapter.onRequest = (_) => body(pageFixture([placementDetailFixture()]));
      await expectLater(
        dependencies.internshipRepository.getPlacements(
          studentUser,
          registrationId: 'another-registration',
        ),
        throwsA(
          isA<AuthFailure>().having((f) => f.kind, 'kind', FailureKind.server),
        ),
      );
    },
  );

  test(
    'direct placement retains null sources and unassigned supervisors',
    () async {
      adapter.onRequest = (_) => body({
        ...placementDetailFixture(linked: false),
        'universitySupervisor': null,
        'companySupervisor': null,
      });
      final item = await dependencies.internshipRepository.getPlacement(
        'placement-1',
        studentUser,
      );
      expect(item.registrationId, isNull);
      expect(item.opportunityId, isNull);
      expect(item.applicationId, isNull);
      expect(item.universitySupervisor, isNull);
      expect(item.companySupervisor, isNull);
      expect(adapter.requests.single.path, '/placements/placement-1');
    },
  );

  test(
    'company opportunities use verified IDs instead of company names or invented filters',
    () async {
      adapter.onRequest = (_) => body([
        {...opportunityDetailFixture, 'id': 'wanted'},
        {
          ...opportunityDetailFixture,
          'id': 'other',
          'company': {
            'id': 'company-2',
            'name': 'TIP Technology',
            'status': 'VERIFIED',
          },
        },
        {...opportunityDetailFixture, 'id': 'closed', 'status': 'CLOSED'},
      ]);
      final items = await dependencies.opportunityRepository
          .getCompanyOpportunities('company-1');
      expect(items.map((item) => item.id), ['wanted']);
      expect(adapter.requests.single.path, '/opportunities');
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer test-only-token',
      );
    },
  );

  test(
    'placement permission denial is not retried and missing detail is not an empty success',
    () async {
      for (final status in [403, 404]) {
        adapter.requests.clear();
        adapter.onRequest = (_) => body({
          'message': 'Placement was not found in your scope',
        }, status: status);
        await expectLater(
          dependencies.internshipRepository.getPlacement(
            'placement-1',
            studentUser,
          ),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.kind,
              'kind',
              status == 403 ? FailureKind.forbidden : FailureKind.server,
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}
