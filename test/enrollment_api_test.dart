import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';
import 'support/auth_fakes.dart';
import 'nest_auth_remote_data_source_test.dart'
    show ControllerAdapter, meFixture, activeStudent, authFailure;

// Response fixture follows the supplied EnrollmentService include/return values.
const schoolId = '22222222-2222-4222-8222-222222222222';
const majorId = '33333333-3333-4333-8333-333333333333';
const requestId = '44444444-4444-4444-8444-444444444444';
const enrollmentInput = StudentEnrollmentInput(
  universityId: schoolId,
  majorId: majorId,
  studentCode: 'SV001',
  className: 'CNTT01',
  semester: 4,
);
Map<String, Object?> record({String status = 'PENDING'}) => {
  'id': requestId,
  'accountId': 'account-1',
  'universityId': schoolId,
  'majorId': majorId,
  'studentCode': 'SV001',
  'className': 'CNTT01',
  'semester': 4,
  'status': status,
  'account': {
    'id': 'account-1',
    'fullName': 'Nguyễn Văn An',
    'email': 'student@example.com',
    'phone': null,
  },
  'university': {'id': schoolId, 'name': 'Đại học TIP', 'code': 'TIP'},
  'major': {'id': majorId, 'name': 'Công nghệ thông tin', 'code': 'CNTT'},
  'reason': status == 'REJECTED' ? 'Sai MSSV' : null,
  'createdAt': '2026-10-03T00:00:00.000Z',
  'reviewedAt': status == 'REJECTED' ? '2026-10-03T01:00:00.000Z' : null,
  'reviewedById': status == 'REJECTED' ? 'admin-1' : null,
};

void main() {
  late AppDependencies dependencies;
  late ControllerAdapter adapter;
  setUp(() async {
    dependencies = AppDependencies.create(
      sessionStorage: MemorySessionStorage()..value = testCredential,
    );
    adapter = ControllerAdapter()..response = meFixture(student: activeStudent);
    dependencies.apiClient.dio.httpClientAdapter = adapter;
    await dependencies.authRepository.getCurrentUser();
    adapter.requests.clear();
  });
  tearDown(() => dependencies.dispose());

  test(
    'all seven enrollment endpoints use Bearer without secret and exact DTO fields',
    () async {
      final repo = dependencies.studentEnrollmentRepository;
      adapter.response = [
        {'id': schoolId, 'name': 'Đại học TIP', 'code': 'TIP'},
      ];
      expect(
        (await repo.universities(keyword: ' TIP ')).single.name,
        'Đại học TIP',
      );
      adapter.response = [
        {'id': majorId, 'name': 'CNTT', 'code': 'CNTT'},
      ];
      await repo.majors(schoolId);
      adapter.response = [record(status: 'REJECTED')];
      expect((await repo.mine()).single.reason, 'Sai MSSV');
      adapter.response = record();
      await repo.submit(enrollmentInput);
      adapter.response = {'message': 'Đã hủy yêu cầu.'};
      await repo.cancel(requestId);
      adapter.response = {
        'data': [record()],
        'total': 21,
        'page': 1,
        'limit': 20,
      };
      expect(
        (await repo.queue(status: 'PENDING', keyword: ' SV001 ')).hasNext,
        isTrue,
      );
      adapter.response = record(status: 'REJECTED');
      await repo.review(requestId, approve: false, reason: ' Sai MSSV ');
      expect(adapter.requests.map((r) => '${r.method} ${r.path}').toList(), [
        'GET /student-enrollments/universities',
        'GET /student-enrollments/universities/$schoolId/majors',
        'GET /student-enrollments/me',
        'POST /student-enrollments',
        'PATCH /student-enrollments/$requestId/cancel',
        'GET /student-enrollments',
        'PATCH /student-enrollments/$requestId/review',
      ]);
      for (final request in adapter.requests) {
        expect(request.headers['Authorization'], 'Bearer test-only-token');
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-secret')),
        );
      }
      expect(adapter.requests[0].queryParameters, {'keyword': 'TIP'});
      expect(adapter.requests[3].contentType, contains('application/json'));
      expect(adapter.requests[3].data, {
        'universityId': schoolId,
        'majorId': majorId,
        'studentCode': 'SV001',
        'className': 'CNTT01',
        'semester': 4,
      });
      expect(adapter.requests[5].queryParameters, {
        'page': 1,
        'limit': 20,
        'status': 'PENDING',
        'keyword': 'SV001',
      });
      expect(adapter.requests[6].data, {
        'decision': 'REJECTED',
        'reason': 'Sai MSSV',
      });
    },
  );
  test(
    'approval sends only decision; empty rejection reason prevents request',
    () async {
      adapter.response = record(status: 'APPROVED');
      await dependencies.studentEnrollmentRepository.review(
        requestId,
        approve: true,
        reason: 'ignored',
      );
      expect(adapter.requests.single.data, {'decision': 'APPROVED'});
      await expectLater(
        dependencies.studentEnrollmentRepository.review(
          requestId,
          approve: false,
          reason: ' ',
        ),
        throwsA(authFailure(FailureKind.validation)),
      );
      expect(adapter.requests.length, 1);
    },
  );
  test('409 and 403 never retry a write or refresh tokens', () async {
    for (final status in [409, 403]) {
      adapter.status = status;
      adapter.response = {'message': 'Denied'};
      await expectLater(
        dependencies.studentEnrollmentRepository.submit(enrollmentInput),
        throwsA(
          authFailure(
            status == 409 ? FailureKind.conflict : FailureKind.forbidden,
          ),
        ),
      );
    }
    expect(adapter.requests.length, 2);
    expect(
      adapter.requests.every((r) => r.path == '/student-enrollments'),
      isTrue,
    );
  });
  test(
    'malformed history or pagination is an error, not an empty successful list',
    () async {
      adapter.response = [
        {...record(), 'semester': 9},
      ];
      await expectLater(
        dependencies.studentEnrollmentRepository.mine(),
        throwsA(authFailure(FailureKind.server)),
      );
      adapter.response = {'data': [], 'total': 2, 'page': 0, 'limit': 20};
      await expectLater(
        dependencies.studentEnrollmentRepository.queue(),
        throwsA(authFailure(FailureKind.server)),
      );
    },
  );
  test('receive timeout does not repeat enrollment submission', () async {
    adapter.onRequest = (options) => throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
    );
    await expectLater(
      dependencies.studentEnrollmentRepository.submit(enrollmentInput),
      throwsA(authFailure(FailureKind.timeout)),
    );
    expect(adapter.requests.length, 1);
  });
  test(
    'lookup and history require direct arrays; admin queue uses the documented envelope',
    () async {
      adapter.response = {'data': []};
      await expectLater(
        dependencies.studentEnrollmentRepository.universities(),
        throwsA(authFailure(FailureKind.server)),
      );
      await expectLater(
        dependencies.studentEnrollmentRepository.majors(schoolId),
        throwsA(authFailure(FailureKind.server)),
      );
      await expectLater(
        dependencies.studentEnrollmentRepository.mine(),
        throwsA(authFailure(FailureKind.server)),
      );
      adapter.response = {
        'data': [record()],
        'total': 1,
        'page': 1,
        'limit': 20,
      };
      final row =
          (await dependencies.studentEnrollmentRepository.queue()).items.single;
      expect(row.universityName, 'Đại học TIP');
      expect(row.majorName, 'Công nghệ thông tin');
      expect(row.fullName, 'Nguyễn Văn An');
      expect(row.email, 'student@example.com');
      expect(row.createdAt, DateTime.utc(2026, 10, 3));
    },
  );
  test(
    'duplicate student code and school-major mismatch provide the matching guidance',
    () async {
      adapter.status = 409;
      adapter.response = {
        'message': 'Mã sinh viên đã được sử dụng tại trường này.',
      };
      await expectLater(
        dependencies.studentEnrollmentRepository.submit(enrollmentInput),
        throwsA(
          isA<AuthFailure>()
              .having(
                (f) => f.fieldErrors['studentCode'],
                'studentCode',
                isNotNull,
              )
              .having(
                (f) => f.message,
                'message',
                contains('Mã sinh viên đã được sử dụng'),
              ),
        ),
      );
      adapter.status = 400;
      adapter.response = {
        'message':
            'Ngành học không thuộc trường đã chọn hoặc trường chưa được xác minh.',
      };
      await expectLater(
        dependencies.studentEnrollmentRepository.submit(enrollmentInput),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            contains('chọn lại trường và ngành'),
          ),
        ),
      );
      expect(adapter.requests.length, 2);
    },
  );
  test(
    'search rejects keyword over 100 characters without making a request',
    () async {
      adapter.response = [];
      await dependencies.studentEnrollmentRepository.universities(
        keyword: 'k' * 100,
      );
      expect(adapter.requests.single.queryParameters['keyword'], 'k' * 100);
      adapter.requests.clear();
      await expectLater(
        dependencies.studentEnrollmentRepository.universities(
          keyword: 'k' * 101,
        ),
        throwsA(authFailure(FailureKind.validation)),
      );
      await expectLater(
        dependencies.studentEnrollmentRepository.queue(keyword: 'k' * 101),
        throwsA(authFailure(FailureKind.validation)),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'review accepts 500 trimmed characters and rejects 501 before PATCH',
    () async {
      adapter.response = record(status: 'REJECTED');
      await dependencies.studentEnrollmentRepository.review(
        requestId,
        approve: false,
        reason: ' ${'r' * 500} ',
      );
      expect(adapter.requests.single.data, {
        'decision': 'REJECTED',
        'reason': 'r' * 500,
      });
      await expectLater(
        dependencies.studentEnrollmentRepository.review(
          requestId,
          approve: false,
          reason: 'r' * 501,
        ),
        throwsA(authFailure(FailureKind.validation)),
      );
      expect(adapter.requests.length, 1);
    },
  );
  test(
    'unverified schools, mismatched majors and unknown request states are rejected',
    () async {
      adapter.response = [
        {'id': 's', 'name': 'School', 'status': 'PENDING'},
      ];
      await expectLater(
        dependencies.studentEnrollmentRepository.universities(),
        throwsA(authFailure(FailureKind.server)),
      );
      adapter.response = [
        {'id': 'm', 'name': 'Major', 'universityId': 'other'},
      ];
      await expectLater(
        dependencies.studentEnrollmentRepository.majors('school-1'),
        throwsA(authFailure(FailureKind.server)),
      );
      adapter.response = [record(status: 'UNKNOWN')];
      await expectLater(
        dependencies.studentEnrollmentRepository.mine(),
        throwsA(authFailure(FailureKind.server)),
      );
    },
  );
  test('profile JSON updates only personal fields', () async {
    adapter.response = null;
    await dependencies.studentProfileRepository.update(
      fullName: '  Tên mới  ',
      phone: ' 0901234567 ',
    );
    final request = adapter.requests.single;
    expect(request.path, '/students/me');
    expect(request.method, 'PATCH');
    expect(request.data, {'fullName': 'Tên mới', 'phone': '0901234567'});
    expect(request.headers['Authorization'], 'Bearer test-only-token');
  });
  test(
    'CV upload uses cv field, PDF media type and client-generated multipart boundary',
    () async {
      adapter.response = null;
      final bytes = Uint8List.fromList('%PDF-1.7\nTest'.codeUnits);
      await dependencies.studentProfileRepository.update(
        fullName: 'Tên',
        phone: '',
        cv: CvUpload(name: 'cv.pdf', bytes: bytes),
      );
      final request = adapter.requests.single;
      final body = request.data as FormData;
      expect(body.fields.map((e) => e.key), ['fullName', 'phone']);
      expect(body.files.single.key, 'cv');
      expect(body.files.single.value.contentType.toString(), 'application/pdf');
      expect(body.files.single.value.filename, 'cv.pdf');
      expect(request.contentType, contains('multipart/form-data; boundary='));
      expect(body.files.single.value.length, bytes.length);
    },
  );
  test('CV validates actual PDF and inclusive 4 MiB size limit', () {
    final exactly = Uint8List(CvUpload.maxBytes)
      ..setRange(0, 5, '%PDF-'.codeUnits);
    expect(CvUpload(name: 'CV.PDF', bytes: exactly).bytes.length, 4194304);
    expect(
      () => CvUpload(name: 'cv.pdf', bytes: Uint8List(CvUpload.maxBytes + 1)),
      throwsA(authFailure(FailureKind.validation)),
    );
    expect(
      () => CvUpload(
        name: 'cv.pdf',
        bytes: Uint8List.fromList('not PDF'.codeUnits),
      ),
      throwsA(authFailure(FailureKind.validation)),
    );
    expect(
      () => CvUpload(name: 'cv.txt', bytes: exactly),
      throwsA(authFailure(FailureKind.validation)),
    );
  });

  test(
    'CV-only update never overwrites name, phone, email or academic fields',
    () async {
      adapter.response = null;
      await dependencies.studentProfileRepository.update(
        cv: CvUpload(
          name: 'new.pdf',
          bytes: Uint8List.fromList('%PDF-1.7\nTest'.codeUnits),
        ),
      );
      final request = adapter.requests.single;
      expect(request.path, '/students/me');
      expect(request.method, 'PATCH');
      final data = request.data as FormData;
      expect(data.fields, isEmpty);
      expect(data.files.single.key, 'cv');
      expect(data.files.single.value.filename, 'new.pdf');
      expect(request.headers['Authorization'], 'Bearer test-only-token');
      expect(request.contentType, contains('multipart/form-data; boundary='));
    },
  );

  test(
    'phone-only update preserves the existing name and empty update is rejected',
    () async {
      adapter.response = null;
      await dependencies.studentProfileRepository.update(phone: ' 0901234567 ');
      expect(adapter.requests.single.data, {'phone': '0901234567'});
      adapter.requests.clear();
      await expectLater(
        dependencies.studentProfileRepository.update(),
        throwsA(authFailure(FailureKind.validation)),
      );
      expect(adapter.requests, isEmpty);
    },
  );
}
