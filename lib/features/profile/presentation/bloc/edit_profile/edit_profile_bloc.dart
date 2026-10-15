import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/profile/domain/usecases/update_student_profile.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/profile/presentation/bloc/edit_profile/edit_profile_event.dart';
import 'package:tip_app/features/profile/presentation/bloc/edit_profile/edit_profile_state.dart';

class EditProfileBloc extends Bloc<EditProfileEvent, EditProfileState> {
  EditProfileBloc(
    this.repository,
    this.profile,
    this.reloadProfile,
    this.pickCv,
  ) : super(
        EditProfileState(
          profile: profile,
          cv: null,
          failure: null,
          saving: false,
          picking: false,
          checking: false,
          uncertain: false,
          mayHaveChanged: false,
          saved: false,
        ),
      ) {
    on<EditProfileEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case EditProfileCvPickRequested():
            await _pickCv();
          case EditProfileRecheckRequested():
            await _recheck();
          case EditProfileSaveRequested():
            await _saveProfile(event.fullName, event.phone);
          case EditProfileCvRemoved():
            await _removeCv();
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final StudentProfileRepository repository;
  final StudentProfile profile;
  final Future<StudentProfile> Function()? reloadProfile;
  final Future<CvUpload?> Function() pickCv;
  late StudentProfile _profile = profile;
  CvUpload? _cv;
  AuthFailure? _failure;
  bool _saving = false;
  bool _picking = false;
  bool _checking = false;
  bool _uncertain = false;
  bool _mayHaveChanged = false;
  bool _saved = false;
  Emitter<EditProfileState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(EditProfileEvent event) async {
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
      EditProfileState(
        profile: _profile,
        cv: _cv,
        failure: _failure,
        saving: _saving,
        picking: _picking,
        checking: _checking,
        uncertain: _uncertain,
        mayHaveChanged: _mayHaveChanged,
        saved: _saved,
      ),
    );
  }

  Future<void> _pickCv() async {
    if (_busy || _uncertain) return;
    _update(() {
      _picking = true;
      _failure = null;
    });
    try {
      final cv = await pickCv();
      if (!isClosed && cv != null) _update(() => _cv = cv);
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
  }

  Future<void> _recheck() async {
    if (_busy || reloadProfile == null) return;
    _update(() => _checking = true);
    try {
      final profile = await reloadProfile!();
      if (isClosed) return;
      _update(() {
        _profile = profile;
        _cv = null;
        _uncertain = false;
        _failure = null;
      });
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể kiểm tra hồ sơ hiện tại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _checking = false);
    }
  }

  Future<void> _saveProfile(String fullName, String phone) async {
    if (_busy || _uncertain) {
      return;
    }
    _update(() {
      _saving = true;
      _failure = null;
    });
    try {
      await UpdateStudentProfile(repository)(
        fullName: fullName.trim() == _profile.fullName ? null : fullName.trim(),
        phone: phone.trim() == (_profile.phone ?? '') ? null : phone.trim(),
        cv: _cv,
      );
      if (isClosed) return;
      _update(() => _saved = true);
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
        _mayHaveChanged = _mayHaveChanged || _uncertain;
      });
    } on Object {
      if (!isClosed) {
        _update(() {
          _uncertain = true;
          _mayHaveChanged = true;
          _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa xác nhận được cập nhật. Hãy tải lại hồ sơ trước khi lưu lại.',
          );
        });
      }
    } finally {
      if (!isClosed) _update(() => _saving = false);
    }
  }

  Future<void> _removeCv() async {
    if (!_busy && !_uncertain) _update(() => _cv = null);
  }

  bool get _busy => _saving || _picking || _checking;
}
