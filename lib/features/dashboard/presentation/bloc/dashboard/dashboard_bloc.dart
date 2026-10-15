import 'package:tip_app/features/dashboard/presentation/bloc/dashboard/dashboard_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'package:tip_app/features/dashboard/presentation/bloc/dashboard/dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this.getSummary, this.user) : super(const DashboardState()) {
    on<DashboardRefreshRequested>((event, emit) async {
      try {
        await _refresh(emit);
      } finally {
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  Future<void>? _refreshing;
  Future<void> refresh() {
    if (isClosed) return Future.value();
    if (_refreshing != null) return _refreshing!;
    final event = DashboardRefreshRequested();
    add(event);
    return _refreshing = event.completion.future.whenComplete(
      () => _refreshing = null,
    );
  }

  final GetDashboardSummary getSummary;
  final AuthUser user;

  Future<void> _refresh(Emitter<DashboardState> emit) async {
    if (state.loading || !user.canAccessStudentApp) return;
    final previous = state.summary;
    emit(DashboardState(summary: previous, loading: true));
    try {
      final summary = await getSummary(user);
      if (!isClosed) emit(DashboardState(summary: summary));
    } on AuthFailure catch (failure) {
      if (!isClosed) {
        emit(
          DashboardState(
            summary: failure.kind == FailureKind.inactiveAccount
                ? null
                : previous,
            failure: failure,
          ),
        );
      }
    } on Object {
      if (!isClosed) {
        emit(
          DashboardState(
            summary: previous,
            failure: const AuthFailure(
              FailureKind.unexpected,
              'Chưa thể tải trang chủ. Vui lòng thử lại.',
            ),
          ),
        );
      }
    }
  }
}
