import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/opportunities/domain/usecases/get_company.dart';
import 'package:tip_app/features/opportunities/domain/usecases/get_opportunity.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'dart:async';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_detail/opportunity_detail_event.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_detail/opportunity_detail_state.dart';

class OpportunityDetailBloc
    extends Bloc<OpportunityDetailEvent, OpportunityDetailState> {
  OpportunityDetailBloc(this.repository, this.opportunity, this.canApply)
    : super(
        OpportunityDetailState(
          item: opportunity,
          company: null,
          failure: null,
          companyFailure: null,
          loading: false,
          companyLoading: false,
          confirmed: false,
        ),
      ) {
    on<OpportunityDetailEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case OpportunityDetailLoadRequested():
            await _refresh();
          case OpportunityCompanyLoadRequested():
            await _loadCompany(event.id);
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final OpportunityRepository repository;
  final OpportunityOverview opportunity;
  final bool canApply;
  late OpportunityOverview _item = opportunity;
  CompanyOverview? _company;
  AuthFailure? _failure;
  AuthFailure? _companyFailure;
  bool _loading = false;
  bool _companyLoading = false;
  bool _confirmed = false;
  Emitter<OpportunityDetailState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(OpportunityDetailEvent event) async {
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
      OpportunityDetailState(
        item: _item,
        company: _company,
        failure: _failure,
        companyFailure: _companyFailure,
        loading: _loading,
        companyLoading: _companyLoading,
        confirmed: _confirmed,
      ),
    );
  }

  Future<void> _refresh() async {
    if (_loading || !canApply) return;
    _update(() {
      _loading = true;
      _confirmed = false;
      _failure = null;
    });
    try {
      final item = await GetOpportunity(repository)(opportunity.id);
      if (isClosed) return;
      _update(() {
        _item = item;
        _confirmed = true;
      });
      if (item.companyId != null) await _loadCompany(item.companyId!);
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể xác nhận thông tin cơ hội. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _loading = false);
    }
  }

  Future<void> _loadCompany(String id) async {
    if (_companyLoading) return;
    _update(() {
      _companyLoading = true;
      _companyFailure = null;
    });
    try {
      final company = await GetCompany(repository)(id);
      if (!isClosed) _update(() => _company = company);
    } on AuthFailure catch (failure) {
      if (!isClosed) _update(() => _companyFailure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _companyFailure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể tải thông tin doanh nghiệp.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _companyLoading = false);
    }
  }
}
