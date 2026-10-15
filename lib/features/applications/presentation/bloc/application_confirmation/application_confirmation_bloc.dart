import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/profile/domain/usecases/get_student_profile.dart';
import 'package:tip_app/features/applications/domain/usecases/apply_for_opportunity.dart';
import 'package:tip_app/features/opportunities/domain/usecases/get_opportunity.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_confirmation/application_confirmation_event.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_confirmation/application_confirmation_state.dart';

class ApplicationConfirmationBloc
    extends Bloc<ApplicationConfirmationEvent, ApplicationConfirmationState> {
  ApplicationConfirmationBloc(
    this.repository,
    this.profiles,
    this.opportunities,
    this.user,
    this.opportunity,
  ) : super(
        ApplicationConfirmationState(
          profile: null,
          opportunity: null,
          failure: null,
          loading: false,
          sending: false,
          consent: false,
          uncertain: false,
          submitted: null,
        ),
      ) {
    on<ApplicationConfirmationEvent>((event, emit) async {
      _emitter = emit;
      try {
        switch (event) {
          case ApplicationPreparationRequested():
            await _load();
          case ApplicationSubmissionRequested():
            await _send();
          case ApplicationConsentChanged():
            await _setConsent(event.value);
        }
      } finally {
        _emitter = null;
        if (!event.completion.isCompleted) event.completion.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final ApplicationRepository repository;
  final StudentProfileRepository profiles;
  final OpportunityRepository opportunities;
  final AuthUser user;
  final OpportunityOverview opportunity;
  StudentProfile? _profile;
  OpportunityOverview? _opportunity;
  AuthFailure? _failure;
  bool _loading = false;
  bool _sending = false;
  bool _consent = false;
  bool _uncertain = false;
  ApplicationOverview? _submitted;
  Emitter<ApplicationConfirmationState>? _emitter;
  final _pendingTypes = <Type>{};
  Future<void> dispatch(ApplicationConfirmationEvent event) async {
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
      ApplicationConfirmationState(
        profile: _profile,
        opportunity: _opportunity,
        failure: _failure,
        loading: _loading,
        sending: _sending,
        consent: _consent,
        uncertain: _uncertain,
        submitted: _submitted,
      ),
    );
  }

  Future<void> _load() async {
    if (_loading || _sending) return;
    _update(() {
      _loading = true;
      _failure = null;
      _consent = false;
      _profile = null;
      _opportunity = null;
    });
    try {
      if (!user.canAccessStudentApp) {
        throw const AuthFailure(
          FailureKind.forbidden,
          'Cần hồ sơ sinh viên hợp lệ để ứng tuyển.',
        );
      }
      final results = await Future.wait<Object>([
        GetStudentProfile(profiles)(user),
        GetOpportunity(opportunities)(opportunity.id),
      ]);
      if (isClosed) return;
      _update(() {
        _profile = results[0] as StudentProfile;
        _opportunity = results[1] as OpportunityOverview;
        _uncertain = false;
      });
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() => _failure = failure);
    } on Object {
      if (!isClosed) {
        _update(
          () => _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa thể kiểm tra hồ sơ ứng tuyển. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (!isClosed) _update(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending ||
        _loading ||
        !_consent ||
        _profile == null ||
        _uncertain ||
        !user.canAccessStudentApp ||
        _opportunity?.acceptsApplicationsAt(DateTime.now()) != true) {
      return;
    }
    _update(() {
      _sending = true;
      _failure = null;
    });
    try {
      final application = await ApplyForOpportunity(repository)(
        _opportunity!.id,
      );
      if (isClosed) return;
      _update(() => _submitted = application);
    } on AuthFailure catch (failure) {
      if (isClosed) return;
      _update(() {
        _failure = failure;
        _uncertain =
            failure.kind == FailureKind.timeout ||
            failure.kind == FailureKind.network ||
            failure.kind == FailureKind.server ||
            failure.kind == FailureKind.unexpected;
      });
    } on Object {
      if (!isClosed) {
        _update(() {
          _uncertain = true;
          _failure = const AuthFailure(
            FailureKind.unexpected,
            'Chưa xác nhận được kết quả. Hãy kiểm tra danh sách đơn trước khi gửi lại.',
          );
        });
      }
    } finally {
      if (!isClosed) _update(() => _sending = false);
    }
  }

  Future<void> _setConsent(bool value) async {
    _update(() => _consent = value);
  }
}
