import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/applications/domain/usecases/get_applications.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_list/application_list_event.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_list/application_list_state.dart';

class ApplicationListBloc
    extends Bloc<ApplicationListEvent, ApplicationListState> {
  ApplicationListBloc(this.repository)
    : super(
        ApplicationListState(
          items: const [],
          page: null,
          failure: null,
          loading: false,
          retryReset: true,
          status: null,
        ),
      ) {
    on<ApplicationListEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case ApplicationListLoadRequested():
            await _load(reset: event.reset);
          case ApplicationListFilterChanged():
            await _filter(event.status);
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final ApplicationRepository repository;
  final List<ApplicationOverview> _items = [];
  PageSlice<ApplicationOverview>? _page;
  AuthFailure? _failure;
  bool _loading = false;
  bool _retryReset = true;
  String? _status;
  Emitter<ApplicationListState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(ApplicationListEvent event) async {
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
      ApplicationListState(
        items: List.unmodifiable(_items),
        page: _page,
        failure: _failure,
        loading: _loading,
        retryReset: _retryReset,
        status: _status,
      ),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && _page != null && !_page!.hasNext)) return;
    _retryReset = reset;
    _update(() {
      _loading = true;
      _failure = null;
    });
    try {
      final result = await GetApplications(repository)(
        page: reset ? 1 : (_page?.page ?? 0) + 1,
        status: _status,
      );
      if (isClosed) return;
      _update(() {
        if (reset) _items.clear();
        for (final item in result.items) {
          final index = _items.indexWhere((existing) => existing.id == item.id);
          if (index < 0) {
            _items.add(item);
          } else {
            _items[index] = item;
          }
        }
        _page = result;
      });
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể tải danh sách ứng tuyển. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _loading = false);
    }
  }

  Future<void> _filter(String? status) async {
    if (_loading || _status == status) return;
    _update(() {
      _status = status;
      _items.clear();
      _page = null;
    });
    await _load(reset: true);
  }
}
