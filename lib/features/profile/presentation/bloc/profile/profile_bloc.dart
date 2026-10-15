import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/profile/domain/usecases/get_student_profile.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/profile/presentation/bloc/profile/profile_event.dart';
import 'package:tip_app/features/profile/presentation/bloc/profile/profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this.repository, this.user)
    : super(ProfileState(profile: null, failure: null, loading: false)) {
    on<ProfileEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case ProfileLoadRequested():
            await _load();
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final StudentProfileRepository repository;
  final AuthUser user;
  StudentProfile? _profile;
  AuthFailure? _failure;
  bool _loading = false;
  Emitter<ProfileState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(ProfileEvent event) async {
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
      ProfileState(profile: _profile, failure: _failure, loading: _loading),
    );
  }

  Future<void> _load() async {
    if (_loading) return;
    _update(() {
      _loading = true;
      _failure = null;
    });
    try {
      final profile = await GetStudentProfile(repository)(user);
      if (!isClosed) _update(() => _profile = profile);
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể tải hồ sơ. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _loading = false);
    }
  }
}
