import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/opportunities/domain/usecases/get_opportunities.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_list/opportunity_list_event.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_list/opportunity_list_state.dart';

class OpportunityListBloc
    extends Bloc<OpportunityListEvent, OpportunityListState> {
  OpportunityListBloc(this.repository)
    : super(
        OpportunityListState(
          items: const [],
          page: null,
          failure: null,
          loading: false,
          retryReset: true,
        ),
      ) {
    on<OpportunityListEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case OpportunityListLoadRequested():
            await _load(reset: event.reset);
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final OpportunityRepository repository;
  final List<OpportunityOverview> _items = [];
  PageSlice<OpportunityOverview>? _page;
  AuthFailure? _failure;
  bool _loading = false;
  bool _retryReset = true;
  Emitter<OpportunityListState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(OpportunityListEvent event) async {
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
      OpportunityListState(
        items: List.unmodifiable(_items),
        page: _page,
        failure: _failure,
        loading: _loading,
        retryReset: _retryReset,
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
      final result = await GetOpportunities(repository)(
        page: reset ? 1 : (_page?.page ?? 0) + 1,
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
            'Chưa thể tải cơ hội. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _loading = false);
    }
  }
}
