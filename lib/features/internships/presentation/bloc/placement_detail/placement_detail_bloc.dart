import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/internships/domain/usecases/get_placement.dart';
import 'package:tip_app/features/opportunities/domain/usecases/get_company.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/features/internships/presentation/bloc/placement_detail/placement_detail_event.dart';
import 'package:tip_app/features/internships/presentation/bloc/placement_detail/placement_detail_state.dart';

class PlacementDetailBloc
    extends Bloc<PlacementDetailEvent, PlacementDetailState> {
  PlacementDetailBloc(
    this.repository,
    this.opportunities,
    this.user,
    this.placementId,
  ) : super(
        PlacementDetailState(
          detail: null,
          company: null,
          failure: null,
          companyFailure: null,
          loading: false,
          companyLoading: false,
        ),
      ) {
    on<PlacementDetailEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case PlacementLoadRequested():
            await _load();
          case PlacementCompanyLoadRequested():
            await _loadCompany(event.id);
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final InternshipRepository repository;
  final OpportunityRepository opportunities;
  final AuthUser user;
  final String placementId;
  InternshipPlacement? _detail;
  CompanyOverview? _company;
  AuthFailure? _failure;
  AuthFailure? _companyFailure;
  bool _loading = false;
  bool _companyLoading = false;
  Emitter<PlacementDetailState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(PlacementDetailEvent event) async {
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
      PlacementDetailState(
        detail: _detail,
        company: _company,
        failure: _failure,
        companyFailure: _companyFailure,
        loading: _loading,
        companyLoading: _companyLoading,
      ),
    );
  }

  Future<void> _load() async {
    if (_loading || _companyLoading) return;
    _update(() {
      _loading = true;
      _failure = null;
      _detail = null;
      _company = null;
    });
    try {
      final detail = await GetPlacement(repository)(placementId, user);
      if (isClosed) return;
      _update(() => _detail = detail);
      await _loadCompany(detail.companyId);
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể tải chi tiết vị trí thực tập.',
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
      final company = await GetCompany(opportunities)(id);
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
