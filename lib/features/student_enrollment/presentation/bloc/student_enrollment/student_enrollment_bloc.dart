import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';
import 'package:tip_app/features/student_enrollment/domain/enrollment_validation.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';

import 'package:tip_app/features/student_enrollment/domain/usecases/get_my_enrollments.dart';
import 'package:tip_app/features/student_enrollment/domain/usecases/submit_enrollment.dart';
import 'package:tip_app/features/student_enrollment/domain/usecases/cancel_enrollment.dart';
import 'package:tip_app/features/student_enrollment/domain/usecases/get_enrollment_queue.dart';
import 'package:tip_app/features/student_enrollment/domain/usecases/review_enrollment.dart';
import 'package:tip_app/features/student_enrollment/presentation/bloc/student_enrollment/student_enrollment_event.dart';
import 'package:tip_app/features/student_enrollment/presentation/bloc/student_enrollment/student_enrollment_state.dart';

class StudentEnrollmentBloc
    extends Bloc<StudentEnrollmentEvent, EnrollmentState> {
  StudentEnrollmentBloc(this.repository, this.user, {this.reviewMode = false})
    : super(const EnrollmentState()) {
    on<StudentEnrollmentEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case EnrollmentRefreshRequested():
            await _refresh();
          case EnrollmentNextPageRequested():
            await _nextPage();
          case EnrollmentFilterChanged():
            await _filter(status: event.status, keyword: event.keyword);
          case EnrollmentSubmitRequested():
            await _submit(event.input);
          case EnrollmentCancelRequested():
            await _cancel(event.item);
          case EnrollmentReviewRequested():
            await _review(
              event.item,
              approve: event.approve,
              reason: event.reason,
            );
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  Emitter<EnrollmentState>? _emitter;
  bool _pending = false;
  int _visibleCount = 20;
  Future<void> _dispatch(StudentEnrollmentEvent event) async {
    if (isClosed || _pending || state.loading || state.saving) return;
    _pending = true;
    try {
      add(event);
      await event.completion.future;
    } finally {
      _pending = false;
    }
  }

  Future<void> refresh() => _dispatch(EnrollmentRefreshRequested());
  Future<void> nextPage() => _dispatch(EnrollmentNextPageRequested());
  Future<void> filter({String? status, String keyword = ''}) =>
      _dispatch(EnrollmentFilterChanged(status: status, keyword: keyword));
  Future<void> submit(StudentEnrollmentInput input) =>
      _dispatch(EnrollmentSubmitRequested(input));
  Future<void> cancel(StudentEnrollment item) =>
      _dispatch(EnrollmentCancelRequested(item));
  Future<void> review(
    StudentEnrollment item, {
    required bool approve,
    String? reason,
  }) => _dispatch(
    EnrollmentReviewRequested(item, approve: approve, reason: reason),
  );
  final StudentEnrollmentRepository repository;
  final AuthUser user;
  final bool reviewMode;
  bool get _eligible => reviewMode
      ? user.canReviewStudentEnrollments
      : user.canViewStudentEnrollments;

  EnrollmentState _state({
    List<StudentEnrollment>? items,
    bool? loading,
    bool? saving,
    bool? loaded,
    AuthFailure? failure,
    String? message,
    int? page,
    int? total,
    bool? hasNext,
    String? status,
    String? keyword,
    bool replaceStatus = false,
  }) => EnrollmentState(
    visibleCount: _visibleCount,
    items: items ?? state.items,
    loading: loading ?? state.loading,
    saving: saving ?? state.saving,
    loaded: loaded ?? state.loaded,
    failure: failure,
    message: message,
    page: page ?? state.page,
    total: total ?? state.total,
    hasNext: hasNext ?? state.hasNext,
    status: replaceStatus ? status : state.status,
    keyword: keyword ?? state.keyword,
  );

  Future<void> _refresh() async {
    if (state.loading || state.saving) return;
    await _load(reset: true);
  }

  Future<void> _nextPage() async {
    if (!reviewMode) {
      if (!state.loading && !state.saving && state.hasMoreHistory) {
        _visibleCount += 20;
        _emitter!(_state());
      }
      return;
    }
    if (state.loading || state.saving || !state.hasNext) return;
    await _load(reset: false);
  }

  Future<void> _filter({String? status, String keyword = ''}) async {
    if (state.loading || state.saving) return;
    final keywordError = EnrollmentValidation.keyword(keyword);
    if (keywordError != null) {
      _emitter!(
        _state(failure: AuthFailure(FailureKind.validation, keywordError)),
      );
      return;
    }
    _emitter!(
      _state(
        items: const [],
        loaded: false,
        page: 0,
        total: 0,
        hasNext: false,
        status: status,
        replaceStatus: true,
        keyword: keyword.trim(),
      ),
    );
    await _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (!_eligible) {
      _emitter!(
        _state(
          failure: const AuthFailure(
            FailureKind.forbidden,
            'Tài khoản chưa được phép truy cập mục ghi danh này.',
          ),
        ),
      );
      return;
    }
    _emitter!(_state(loading: true));
    try {
      final List<StudentEnrollment> items;
      var page = 1, total = 0;
      var hasNext = false;
      if (reviewMode) {
        final result = await GetEnrollmentQueue(repository)(
          status: state.status,
          keyword: state.keyword,
          page: reset ? 1 : state.page + 1,
        );
        items = result.items;
        page = result.page;
        total = result.total;
        hasNext = result.hasNext;
      } else {
        items = await GetMyEnrollments(repository)();
        total = items.length;
      }
      if (isClosed) return;
      if (reset) _visibleCount = 20;
      final merged = reset ? <StudentEnrollment>[] : [...state.items];
      for (final item in items) {
        final index = merged.indexWhere((existing) => existing.id == item.id);
        if (index < 0) {
          merged.add(item);
        } else {
          merged[index] = item;
        }
      }
      _emitter!(
        _state(
          items: List.unmodifiable(merged),
          loading: false,
          loaded: true,
          page: page,
          total: total,
          hasNext: hasNext,
        ),
      );
    } on AuthFailure catch (failure) {
      if (!isClosed) {
        _emitter!(_state(loading: false, loaded: false, failure: failure));
      }
    } on Object {
      if (!isClosed) {
        _emitter!(
          _state(
            loading: false,
            loaded: false,
            failure: const AuthFailure(
              FailureKind.unexpected,
              'Chưa thể tải yêu cầu ghi danh. Vui lòng thử lại.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _mutate(Future<void> Function() action, String message) async {
    if (state.saving || state.loading || !state.loaded || !_eligible) return;
    _emitter!(_state(saving: true));
    AuthFailure? failure;
    try {
      await action();
    } on AuthFailure catch (error) {
      failure = error;
    } on Object {
      failure = const AuthFailure(
        FailureKind.unexpected,
        'Chưa xác nhận kết quả. Hãy tải lại danh sách trước khi thao tác tiếp.',
      );
    }
    if (isClosed) return;
    // A write never changes membership locally. Reload authoritative history/queue.
    await _load(reset: true);
    if (!isClosed) {
      _emitter!(
        _state(
          saving: false,
          failure: failure ?? state.failure,
          message: failure == null ? message : null,
        ),
      );
    }
  }

  Future<void> _submit(StudentEnrollmentInput input) async {
    if (!user.canRequestStudentEnrollment ||
        state.hasPending ||
        state.items.any((item) => item.status == 'APPROVED') ||
        !state.loaded) {
      return;
    }
    final failure = EnrollmentValidation.input(input);
    if (failure != null) {
      _emitter!(_state(failure: failure));
      return;
    }
    await _mutate(
      () => SubmitEnrollment(repository)(input),
      'Đã gửi yêu cầu. Bạn có thể dùng chức năng sinh viên sau khi nhà trường phê duyệt.',
    );
  }

  Future<void> _cancel(StudentEnrollment item) async {
    if (reviewMode ||
        !item.isPending ||
        !state.items.any(
          (existing) => existing.id == item.id && existing.isPending,
        )) {
      return;
    }
    await _mutate(
      () => CancelEnrollment(repository)(item.id),
      'Đã hủy yêu cầu ghi danh.',
    );
  }

  Future<void> _review(
    StudentEnrollment item, {
    required bool approve,
    String? reason,
  }) async {
    if (!reviewMode ||
        !item.isPending ||
        !state.items.any(
          (existing) => existing.id == item.id && existing.isPending,
        )) {
      return;
    }
    final reasonError = approve ? null : EnrollmentValidation.reason(reason);
    if (reasonError != null) {
      _emitter!(
        _state(failure: AuthFailure(FailureKind.validation, reasonError)),
      );
      return;
    }
    await _mutate(
      () => ReviewEnrollment(repository)(
        item.id,
        approve: approve,
        reason: reason,
      ),
      approve ? 'Đã duyệt yêu cầu ghi danh.' : 'Đã từ chối yêu cầu ghi danh.',
    );
  }
}
