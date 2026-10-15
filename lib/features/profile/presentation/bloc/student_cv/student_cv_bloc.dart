import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/profile/domain/usecases/update_student_profile.dart';
import 'package:tip_app/features/profile/domain/usecases/get_student_profile.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/profile/presentation/bloc/student_cv/student_cv_event.dart';
import 'package:tip_app/features/profile/presentation/bloc/student_cv/student_cv_state.dart';

class StudentCvBloc extends Bloc<StudentCvEvent, StudentCvState> {
  StudentCvBloc(this.repository, this.profileRepository, this.user, this.pickCv)
    : super(
        StudentCvState(
          profile: null,
          failure: null,
          selected: null,
          loading: false,
          picking: false,
          uploading: false,
          trusted: false,
          changed: false,
          uncertain: false,
        ),
      ) {
    on<StudentCvEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case StudentCvLoadRequested():
            await _load();
          case StudentCvRecheckRequested():
            await _readProfile();
          case StudentCvUploadRequested():
            await _upload();
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final StudentProfileRepository repository;
  final StudentProfileRepository profileRepository;
  final AuthUser user;
  final Future<CvUpload?> Function() pickCv;
  StudentProfile? _profile;
  AuthFailure? _failure;
  CvUpload? _selected;
  bool _loading = false;
  bool _picking = false;
  bool _uploading = false;
  bool _trusted = false;
  bool _changed = false;
  bool _uncertain = false;
  bool _uploadSucceeded = false;
  Emitter<StudentCvState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(StudentCvEvent event) async {
    if (isClosed || !_pendingTypes.add(event.runtimeType)) return;
    try {
      add(event);
      await event.completion.future;
    } finally {
      _pendingTypes.remove(event.runtimeType);
    }
  }

  void _update(void Function() change) {
    if (isClosed) return;
    change();
    _emitter!(
      StudentCvState(
        uploadSucceeded: _uploadSucceeded,
        profile: _profile,
        failure: _failure,
        selected: _selected,
        loading: _loading,
        picking: _picking,
        uploading: _uploading,
        trusted: _trusted,
        changed: _changed,
        uncertain: _uncertain,
      ),
    );
  }

  Future<void> _load() async {
    if (_loading || _picking || _uploading) return;
    await _readProfile();
  }

  Future<void> _readProfile() async {
    _update(() {
      _loading = true;
      _trusted = false;
      _failure = null;
    });
    try {
      final profile = await GetStudentProfile(repository)(user);
      if (isClosed) return;
      _update(() {
        _profile = profile;
        _trusted = true;
        _uncertain = false;
        _selected = null;
      });
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể tải thông tin CV. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    if (!_trusted || _loading || _picking || _uploading || _uncertain) return;
    _update(() {
      _uploadSucceeded = false;
      _picking = true;
      _failure = null;
    });
    CvUpload? selected;
    try {
      selected = await pickCv();
    } on AuthFailure catch (failure) {
      if (!isClosed) _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể đọc tệp CV. Vui lòng chọn lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _picking = false);
    }
    if (isClosed || selected == null) return;
    _update(() {
      _selected = selected;
      _uploading = true;
      _trusted = false;
      _failure = null;
    });
    try {
      // Send only the CV: never overwrite name/phone from an old profile snapshot.
      await UpdateStudentProfile(profileRepository)(cv: selected);
      if (isClosed) return;
      _changed = true;
      _uploadSucceeded = true;
      await _readProfile();
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() {
        _failure = failure;
        _uncertain = const {
          FailureKind.timeout,
          FailureKind.network,
          FailureKind.server,
          FailureKind.unexpected,
        }.contains(failure.kind);
        _changed = _changed || _uncertain;
      });
    } on Object {
      if (!isClosed) {
        _update(() {
          _uncertain = true;
          _changed = true;
          _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa xác nhận được kết quả tải lên. Hãy tải lại hồ sơ trước khi thử lại.',
          );
        });
      }
    } finally {
      if (!isClosed) _update(() => _uploading = false);
    }
  }
}
