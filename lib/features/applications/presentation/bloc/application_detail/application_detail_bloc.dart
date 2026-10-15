import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/applications/domain/usecases/withdraw_application.dart';
import 'package:tip_app/features/applications/domain/usecases/get_application.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/applications/domain/entities/application_detail.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_detail/application_detail_event.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_detail/application_detail_state.dart';

class ApplicationDetailBloc
    extends Bloc<ApplicationDetailEvent, ApplicationDetailState> {
  ApplicationDetailBloc(this.repository, this.application, this.user)
    : super(
        ApplicationDetailState(
          detail: null,
          failure: null,
          loading: false,
          withdrawing: false,
          confirmed: false,
          withdrawn: false,
        ),
      ) {
    on<ApplicationDetailEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case ApplicationDetailLoadRequested():
            await _load();
          case ApplicationWithdrawalRequested():
            await _performWithdrawal();
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final ApplicationRepository repository;
  final ApplicationOverview application;
  final AuthUser user;
  ApplicationDetail? _detail;
  AuthFailure? _failure;
  bool _loading = false;
  bool _withdrawing = false;
  bool _confirmed = false;
  bool _withdrawn = false;
  Emitter<ApplicationDetailState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(ApplicationDetailEvent event) async {
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
      ApplicationDetailState(
        detail: _detail,
        failure: _failure,
        loading: _loading,
        withdrawing: _withdrawing,
        confirmed: _confirmed,
        withdrawn: _withdrawn,
      ),
    );
  }

  Future<void> _load() async {
    if (_loading) return;
    _update(() {
      _loading = true;
      _confirmed = false;
      _failure = null;
    });
    try {
      final detail = await GetApplication(repository)(application.id, user);
      if (!isClosed) {
        _update(() {
          _detail = detail;
          _confirmed = true;
        });
      }
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể tải chi tiết đơn. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _loading = false);
    }
  }

  Future<void> _performWithdrawal() async {
    if (_withdrawing ||
        _loading ||
        !_confirmed ||
        _detail?.application.canWithdraw != true) {
      return;
    }
    _update(() {
      _withdrawing = true;
      _withdrawn = false;
      _failure = null;
    });
    AuthFailure? failure;
    var success = false;
    try {
      await WithdrawApplication(repository)(application.id, user);
      success = true;
    } on AuthFailure catch (error) {
      failure = error;
      if (error.kind == FailureKind.inactiveAccount) {
        if (!isClosed) {
          _update(() {
            _withdrawing = false;
            _failure = error;
          });
        }
        return;
      }
    } on Object {
      failure = const AuthFailure(
        FailureKind.unexpected,
        'Chưa xác nhận được kết quả rút đơn. Vui lòng tải lại trạng thái.',
      );
    }
    if (isClosed) return;
    // Read current state even after a conflict or an uncertain response.
    await _load();
    if (isClosed) return;
    _update(() {
      _withdrawing = false;
      _failure = failure ?? _failure;
    });
    _update(() => _withdrawn = success);
  }
}
