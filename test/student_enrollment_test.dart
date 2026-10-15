import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';
import 'package:tip_app/features/student_enrollment/presentation/bloc/student_enrollment/student_enrollment_bloc.dart';
import 'support/auth_fakes.dart';
import 'support/enrollment_fakes.dart';
import 'nest_auth_remote_data_source_test.dart' show meFixture, activeStudent;

void main() {
  test(
    'verified personal USER is eligible; Student and organization accounts are not',
    () {
      expect(nonStudentUser.canRequestStudentEnrollment, isTrue);
      expect(studentUser.canRequestStudentEnrollment, isFalse);
      expect(studentUser.canViewStudentEnrollments, isTrue);
      expect(schoolAdmin.canRequestStudentEnrollment, isFalse);
      expect(schoolAdmin.canReviewStudentEnrollments, isTrue);
      for (final user in [
        const AuthUser(
          id: 'a',
          fullName: '',
          accountStatus: 'ACTIVE',
          studentAccessGranted: false,
        ),
        const AuthUser(
          id: 'a',
          fullName: '',
          accountStatus: 'LOCKED',
          studentAccessGranted: false,
          globalRole: 'USER',
          emailVerified: true,
        ),
        const AuthUser(
          id: 'a',
          fullName: '',
          accountStatus: 'ACTIVE',
          studentAccessGranted: false,
          globalRole: 'SYSTEM_ADMIN',
          emailVerified: true,
        ),
        const AuthUser(
          id: 'a',
          fullName: '',
          accountStatus: 'ACTIVE',
          studentAccessGranted: false,
          globalRole: 'USER',
          emailVerified: true,
          hasCompanyProfile: true,
        ),
        const AuthUser(
          id: 'a',
          fullName: '',
          accountStatus: 'ACTIVE',
          studentAccessGranted: false,
          globalRole: 'USER',
          emailVerified: true,
          hasSchoolProfile: true,
          schoolRole: 'TEACHER',
          schoolStatus: 'ACTIVE',
        ),
      ]) {
        expect(user.canRequestStudentEnrollment, isFalse);
        expect(user.canReviewStudentEnrollments, isFalse);
      }
    },
  );
  test(
    'me grants membership from Student, never from enrollment status or global role',
    () {
      final before = AuthUserModel.fromMeResponse(meFixture());
      final after = AuthUserModel.fromMeResponse(
        meFixture(student: activeStudent),
      );
      expect(before.canAccessHome, isTrue);
      expect(before.canRequestStudentEnrollment, isTrue);
      expect(before.canAccessStudentApp, isFalse);
      expect(after.id, before.id);
      expect(after.canAccessStudentApp, isTrue);
      expect(after.canRequestStudentEnrollment, isFalse);
      expect(
        () => AuthUserModel.fromMeResponse({
          ...meFixture(),
          'schoolUser': {'accountId': 'other'},
        }),
        throwsException,
      );
    },
  );

  late FakeEnrollmentRepository repo;
  late StudentEnrollmentBloc cubit;
  setUp(() {
    repo = FakeEnrollmentRepository();
    cubit = StudentEnrollmentBloc(repo, nonStudentUser);
  });
  tearDown(() => cubit.close());
  test(
    'submit only after history is loaded, reloads and does not grant Student',
    () async {
      await cubit.submit(enrollmentInput);
      expect(repo.submitCalls, 0);
      await cubit.refresh();
      await cubit.submit(enrollmentInput);
      expect(repo.submitCalls, 1);
      expect(repo.mineCalls, 2);
      expect(cubit.state.hasPending, isTrue);
      expect(nonStudentUser.canAccessStudentApp, isFalse);
      await cubit.submit(enrollmentInput);
      expect(repo.submitCalls, 1);
    },
  );
  test('cancel keeps history; corrections submit a new request', () async {
    repo.items = [enrollment()];
    await cubit.refresh();
    await cubit.cancel(cubit.state.items.single);
    expect(cubit.state.items.single.status, 'CANCELLED');
    expect(cubit.state.hasPending, isFalse);
    await cubit.submit(enrollmentInput);
    expect(cubit.state.items.length, 2);
    expect(repo.cancelCalls, 1);
    expect(repo.submitCalls, 1);
  });
  test('rejected request is immutable and permits a new submission', () async {
    repo.items = [enrollment(status: 'REJECTED')];
    await cubit.refresh();
    await cubit.cancel(cubit.state.items.single);
    expect(repo.cancelCalls, 0);
    await cubit.submit(enrollmentInput);
    expect(repo.submitCalls, 1);
    expect(cubit.state.items.last.status, 'REJECTED');
  });
  test('409 reloads authoritative history without retrying write', () async {
    await cubit.refresh();
    repo.onSubmit = () async {
      repo.items = [enrollment()];
      throw const AuthFailure(FailureKind.conflict, 'Conflict');
    };
    await cubit.submit(enrollmentInput);
    expect(repo.submitCalls, 1);
    expect(repo.mineCalls, 2);
    expect(cubit.state.hasPending, isTrue);
    expect(cubit.state.failure?.kind, FailureKind.conflict);
    expect(cubit.state.message, isNull);
  });
  test(
    'timeout reconciles a committed write and blocks automatic resend',
    () async {
      await cubit.refresh();
      repo.onSubmit = () async {
        repo.items = [enrollment()];
        throw const AuthFailure(FailureKind.timeout, 'Unknown result');
      };
      await cubit.submit(enrollmentInput);
      await cubit.submit(enrollmentInput);
      expect(repo.submitCalls, 1);
      expect(cubit.state.hasPending, isTrue);
    },
  );
  test(
    'pending write blocks repeated submission; reload failure disables further writes',
    () async {
      final pending = Completer<void>();
      await cubit.refresh();
      repo.onSubmit = () => pending.future;
      final saving = cubit.submit(enrollmentInput);
      await cubit.stream.firstWhere((state) => state.saving);
      await cubit.submit(enrollmentInput);
      expect(repo.submitCalls, 1);
      repo.onMine = () async =>
          throw const AuthFailure(FailureKind.network, 'Offline');
      pending.complete();
      await saving;
      expect(cubit.state.loaded, isFalse);
      await cubit.submit(enrollmentInput);
      expect(repo.submitCalls, 1);
    },
  );
  test(
    'school admin queue preserves filters and paginates using server metadata',
    () async {
      await cubit.close();
      cubit = StudentEnrollmentBloc(repo, schoolAdmin, reviewMode: true);
      final queries = <Object?>[];
      repo.onQueue = (status, keyword, page) async {
        queries.add([status, keyword, page]);
        return EnrollmentQueue(
          items: [enrollment(id: 'request-$page')],
          total: 21,
          page: page,
          limit: 20,
        );
      };
      await cubit.filter(status: null, keyword: ' SV001 ');
      await cubit.nextPage();
      expect(queries, [
        [null, 'SV001', 1],
        [null, 'SV001', 2],
      ]);
      expect(cubit.state.items.length, 2);
      expect(cubit.state.hasNext, isFalse);
    },
  );
  test(
    'review requires admin scope, pending request, and rejection reason',
    () async {
      repo.items = [enrollment()];
      await cubit.refresh();
      await cubit.review(enrollment(), approve: true);
      expect(repo.reviewCalls, 0);
      await cubit.close();
      cubit = StudentEnrollmentBloc(repo, schoolAdmin, reviewMode: true);
      await cubit.refresh();
      await cubit.review(enrollment(), approve: false, reason: '  ');
      expect(repo.reviewCalls, 0);
      await cubit.review(enrollment(), approve: false, reason: 'Sai MSSV');
      expect(repo.reviewCalls, 1);
      expect(repo.approved, isFalse);
      expect(cubit.state.items, isEmpty);
    },
  );
  test('invalid semester and missing school prevent writes', () async {
    await cubit.refresh();
    await cubit.submit(
      const StudentEnrollmentInput(
        universityId: '',
        majorId: 'm',
        studentCode: 's',
        className: 'c',
        semester: 9,
      ),
    );
    expect(repo.submitCalls, 0);
    expect(cubit.state.failure?.kind, FailureKind.validation);
  });
  test(
    'approved history without reloaded me blocks new submission but does not grant access',
    () async {
      repo.items = [enrollment(status: 'APPROVED')];
      await cubit.refresh();
      await cubit.submit(enrollmentInput);
      expect(repo.submitCalls, 0);
      expect(cubit.user.canAccessStudentApp, isFalse);
    },
  );
}
