import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/profile/domain/usecases/get_student_profile.dart';
import 'package:tip_app/features/internships/domain/usecases/get_placements.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/features/internships/presentation/bloc/internship_list/internship_list_event.dart';
import 'package:tip_app/features/internships/presentation/bloc/internship_list/internship_list_state.dart';

class InternshipListBloc
    extends Bloc<InternshipListEvent, InternshipListState> {
  InternshipListBloc(this.repository, this.profiles, this.user)
    : super(
        InternshipListState(
          profile: null,
          placements: const [],
          page: null,
          failure: null,
          placementFailure: null,
          loading: false,
          placementsLoading: false,
          retryReset: true,
        ),
      ) {
    on<InternshipListEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case InternshipRegistrationFilterChanged():
            _update(() {
              _registrationFilter = event.filter;
              _visibleRegistrations = 20;
            });
          case InternshipMoreRegistrationsRequested():
            if (state.hasMoreRegistrations) {
              _update(() => _visibleRegistrations += 20);
            }
          case InternshipListLoadRequested():
            await _reload();
          case InternshipListNextPageRequested():
            await _loadPlacements(reset: event.reset);
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final InternshipRepository repository;
  final StudentProfileRepository profiles;
  final AuthUser user;
  String _registrationFilter = 'ALL';
  int _visibleRegistrations = 20;
  StudentProfile? _profile;
  final List<InternshipPlacement> _placements = [];
  PageSlice<InternshipPlacement>? _page;
  AuthFailure? _failure;
  AuthFailure? _placementFailure;
  bool _loading = false;
  bool _placementsLoading = false;
  bool _retryReset = true;
  Emitter<InternshipListState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(InternshipListEvent event) async {
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
      InternshipListState(
        registrationFilter: _registrationFilter,
        visibleRegistrations: _visibleRegistrations,
        profile: _profile,
        placements: List.unmodifiable(_placements),
        page: _page,
        failure: _failure,
        placementFailure: _placementFailure,
        loading: _loading,
        placementsLoading: _placementsLoading,
        retryReset: _retryReset,
      ),
    );
  }

  Future<void> _reload() async {
    if (_loading || _placementsLoading) return;
    _update(() {
      _loading = true;
      _failure = null;
    });
    try {
      final profile = await GetStudentProfile(profiles)(user);
      if (isClosed) return;
      _update(() {
        _profile = profile;
        _visibleRegistrations = 20;
      });
      await _loadPlacements(reset: true);
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể tải các đợt thực tập. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _loading = false);
    }
  }

  Future<void> _loadPlacements({bool reset = false}) async {
    if (_placementsLoading || (!reset && _page != null && !_page!.hasNext)) {
      return;
    }
    _retryReset = reset;
    _update(() {
      _placementsLoading = true;
      _placementFailure = null;
    });
    try {
      final page = await GetPlacements(repository)(
        user,
        page: reset ? 1 : (_page?.page ?? 0) + 1,
      );
      if (isClosed) return;
      _update(() {
        if (reset) _placements.clear();
        for (final item in page.items) {
          final index = _placements.indexWhere(
            (old) => old.overview.id == item.overview.id,
          );
          if (index < 0) {
            _placements.add(item);
          } else {
            _placements[index] = item;
          }
        }
        _page = page;
      });
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _placementFailure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _placementFailure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể tải các vị trí thực tập. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _placementsLoading = false);
    }
  }
}
