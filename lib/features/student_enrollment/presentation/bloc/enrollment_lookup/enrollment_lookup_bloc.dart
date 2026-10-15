import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/domain/usecases/get_enrollment_schools.dart';
import 'package:tip_app/features/student_enrollment/domain/usecases/get_enrollment_majors.dart';
import 'enrollment_lookup_event.dart';
import 'enrollment_lookup_state.dart';

class EnrollmentLookupBloc
    extends Bloc<EnrollmentLookupEvent, EnrollmentLookupState> {
  EnrollmentLookupBloc(StudentEnrollmentRepository repository)
    : _schools = GetEnrollmentSchools(repository),
      _majors = GetEnrollmentMajors(repository),
      super(const EnrollmentLookupState()) {
    on<EnrollmentSchoolSearchChanged>((event, emit) {
      _debounce?.cancel();
      final generation = ++_schoolGeneration;
      emit(const EnrollmentLookupState(loadingSchools: true));
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!isClosed) {
          add(
            EnrollmentSchoolsRequested(event.keyword, generation: generation),
          );
        }
      });
    });
    on<EnrollmentSchoolsRequested>((event, emit) async {
      final generation = event.generation ?? ++_schoolGeneration;
      if (generation != _schoolGeneration) return;
      emit(const EnrollmentLookupState(loadingSchools: true));
      try {
        final schools = await _schools(keyword: event.keyword.trim());
        if (!isClosed && generation == _schoolGeneration) {
          emit(EnrollmentLookupState(schools: List.unmodifiable(schools)));
        }
      } on Object catch (error) {
        if (!isClosed && generation == _schoolGeneration) {
          emit(EnrollmentLookupState(schoolFailure: _failure(error)));
        }
      }
    });
    on<EnrollmentMajorsRequested>((event, emit) async {
      final generation = ++_majorGeneration;
      emit(const EnrollmentLookupState(loadingMajors: true));
      try {
        final majors = await _majors(event.universityId);
        if (!isClosed && generation == _majorGeneration) {
          emit(EnrollmentLookupState(majors: List.unmodifiable(majors)));
        }
      } on Object catch (error) {
        if (!isClosed && generation == _majorGeneration) {
          emit(EnrollmentLookupState(majorFailure: _failure(error)));
        }
      }
    });
  }
  final GetEnrollmentSchools _schools;
  final GetEnrollmentMajors _majors;
  int _schoolGeneration = 0, _majorGeneration = 0;
  Timer? _debounce;

  AuthFailure _failure(Object error) => error is AuthFailure
      ? error
      : const AuthFailure(
          FailureKind.unexpected,
          'Chưa thể tải trường hoặc ngành học. Vui lòng thử lại.',
        );

  @override
  Future<void> close() {
    _debounce?.cancel();
    _schoolGeneration++;
    _majorGeneration++;
    return super.close();
  }
}
