import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/opportunities/domain/usecases/get_company_opportunities.dart';
import 'package:tip_app/features/opportunities/domain/usecases/get_company.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/company_detail/company_detail_event.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/company_detail/company_detail_state.dart';

class CompanyDetailBloc extends Bloc<CompanyDetailEvent, CompanyDetailState> {
  CompanyDetailBloc(this.repository, this.user, this.companyId)
    : super(
        CompanyDetailState(
          company: null,
          opportunities: null,
          companyFailure: null,
          opportunityFailure: null,
          companyLoading: false,
          opportunitiesLoading: false,
        ),
      ) {
    on<CompanyDetailEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case CompanyMoreOpportunitiesRequested():
            if (state.hasMoreOpportunities) {
              _update(() => _visibleCount += 12);
            }
          case CompanyRefreshRequested():
            await _refresh();
          case CompanyLoadRequested():
            await _loadCompany();
          case CompanyOpportunitiesLoadRequested():
            await _loadOpportunities();
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final OpportunityRepository repository;
  final AuthUser user;
  final String companyId;
  int _visibleCount = 12;
  CompanyOverview? _company;
  List<OpportunityOverview>? _opportunities;
  AuthFailure? _companyFailure;
  AuthFailure? _opportunityFailure;
  bool _companyLoading = false;
  bool _opportunitiesLoading = false;
  Emitter<CompanyDetailState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(CompanyDetailEvent event) async {
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
      CompanyDetailState(
        visibleCount: _visibleCount,
        company: _company,
        opportunities: _opportunities,
        companyFailure: _companyFailure,
        opportunityFailure: _opportunityFailure,
        companyLoading: _companyLoading,
        opportunitiesLoading: _opportunitiesLoading,
      ),
    );
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _loadCompany(),
      if (user.canAccessStudentApp) _loadOpportunities(),
    ]);
  }

  Future<void> _loadCompany() async {
    if (_companyLoading) return;
    _update(() {
      _companyLoading = true;
      _companyFailure = null;
    });
    try {
      final company = await GetCompany(repository)(companyId);
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

  Future<void> _loadOpportunities() async {
    if (_opportunitiesLoading) return;
    _update(() {
      _opportunitiesLoading = true;
      _opportunityFailure = null;
    });
    try {
      final opportunities = await GetCompanyOpportunities(repository)(
        companyId,
      );
      if (!isClosed) {
        _update(() {
          _opportunities = List.unmodifiable(opportunities);
          _visibleCount = 12;
        });
      }
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _opportunityFailure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _opportunityFailure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể tải các cơ hội của doanh nghiệp.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _opportunitiesLoading = false);
    }
  }
}
