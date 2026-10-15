import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

class EnrollmentState {
  const EnrollmentState({
    this.visibleCount = 20,
    this.items = const [],
    this.loading = false,
    this.saving = false,
    this.loaded = false,
    this.failure,
    this.message,
    this.page = 0,
    this.total = 0,
    this.hasNext = false,
    this.status = 'PENDING',
    this.keyword = '',
  });
  final int visibleCount;
  List<StudentEnrollment> get visibleItems =>
      List.unmodifiable(items.take(visibleCount));
  bool get hasMoreHistory => items.length > visibleCount;
  final List<StudentEnrollment> items;
  final bool loading, saving, loaded, hasNext;
  final AuthFailure? failure;
  final String? message, status;
  final String keyword;
  final int page, total;
  bool get hasPending => items.any((item) => item.isPending);
}
