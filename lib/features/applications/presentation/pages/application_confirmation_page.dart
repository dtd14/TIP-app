import 'package:tip_app/features/profile/domain/usecases/get_student_profile.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_confirmation/application_confirmation_state.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_confirmation/application_confirmation_event.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_confirmation/application_confirmation_bloc.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/profile/presentation/pages/edit_student_profile_page.dart';
import 'package:tip_app/features/applications/presentation/widgets/application_ui.dart';
import 'package:tip_app/features/opportunities/presentation/company_navigation.dart';

class ApplicationConfirmationPage extends StatefulWidget {
  const ApplicationConfirmationPage({
    super.key,
    required this.opportunity,
    required this.user,
    required this.repository,
    required this.onRestricted,
    this.onViewApplications,
    this.onApplicationsChanged,
  });
  final OpportunityOverview opportunity;
  final AuthUser user;
  final ApplicationRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  final VoidCallback? onViewApplications;
  final VoidCallback? onApplicationsChanged;
  @override
  State<ApplicationConfirmationPage> createState() =>
      _ApplicationConfirmationPageState();
}

class _ApplicationConfirmationPageState
    extends State<ApplicationConfirmationPage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = ApplicationConfirmationBloc(
    widget.repository,
    context.read<StudentProfileRepository>(),
    context.read<OpportunityRepository>(),
    widget.user,
    widget.opportunity,
  );
  StudentProfile? get _profile => _bloc.state.profile;
  OpportunityOverview? get _opportunity => _bloc.state.opportunity;
  AuthFailure? get _failure => _bloc.state.failure;
  bool get _loading => _bloc.state.loading;
  bool get _sending => _bloc.state.sending;
  bool get _consent => _bloc.state.consent;
  bool get _uncertain => _bloc.state.uncertain;
  Future<void> _load() => _bloc.dispatch(ApplicationPreparationRequested());
  Future<void> _send() => _bloc.dispatch(ApplicationSubmissionRequested());
  Future<void> _setConsent(bool value) =>
      _bloc.dispatch(ApplicationConsentChanged(value));
  void _onBlocState(BuildContext context, ApplicationConfirmationState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
    if (state.submitted != null) Navigator.of(context).pop(state.submitted);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<ApplicationConfirmationBloc, ApplicationConfirmationState>(
    listenWhen: (previous, current) =>
        previous.failure != current.failure ||
        previous.submitted != current.submitted,
    bloc: _bloc,
    listener: _onBlocState,
    child:
        BlocBuilder<ApplicationConfirmationBloc, ApplicationConfirmationState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
  );

  final _companies = CompanyNavigation();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _edit() async {
    if (_profile == null || _sending) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditStudentProfilePage(
          profile: _profile!,
          repository: context.read<StudentProfileRepository>(),
          onRestricted: widget.onRestricted,
          reloadProfile: () => GetStudentProfile(
            context.read<StudentProfileRepository>(),
          )(widget.user),
        ),
      ),
    );
    if (mounted && saved == true) await _load();
  }

  Widget _buildContent(BuildContext context) {
    final profile = _profile, opportunity = _opportunity ?? widget.opportunity;
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Xác nhận ứng tuyển',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            key: const Key('applicationConfirmationBack'),
            onPressed: _sending ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: DashboardScroll(
          onRefresh: _load,
          children: [
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                StatusPill('1 · Chọn vị trí', color: AppColors.accent),
                StatusPill('2 · Kiểm tra hồ sơ', color: AppColors.primary),
                StatusPill('3 · Gửi đơn', color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Kiểm tra trước khi gửi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vui lòng kiểm tra thông tin hồ sơ trước khi gửi đơn đến doanh nghiệp.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            ApplicationHeaderCard(
              onCompany: _sending
                  ? null
                  : () => _companies.open(
                      context,
                      companyId: opportunity.companyId,
                      opportunityId: opportunity.id,
                      onRestricted: widget.onRestricted,
                      onChanged: () => widget.onApplicationsChanged?.call(),
                      onViewApplications: widget.onViewApplications,
                    ),
              title: opportunity.title,
              company: opportunity.company,
              type: opportunity.type,
              verified: opportunity.companyVerified,
              location: opportunity.location,
              deadline: opportunity.deadline,
              vacancies: opportunity.vacancies,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            if (_failure != null) ...[
              DashboardPanel(
                child: Column(
                  children: [
                    Text(
                      _failure!.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    TextButton(
                      onPressed: _loading || _sending ? null : _load,
                      child: const Text('Kiểm tra lại hồ sơ'),
                    ),
                    if (widget.onViewApplications != null)
                      TextButton(
                        key: const Key('checkMyApplications'),
                        onPressed: _sending
                            ? null
                            : () {
                                widget.onViewApplications!();
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              },
                        child: const Text('Kiểm tra đơn của tôi'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_opportunity != null &&
                !opportunity.acceptsApplicationsAt(DateTime.now())) ...[
              const DashboardPanel(
                child: Text(
                  'Cơ hội đã đóng, hết hạn hoặc chưa cập nhật hạn ứng tuyển.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (profile != null) ...[
              DashboardPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeading(
                      'Hồ sơ dùng ứng tuyển',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          child: Text(
                            profile.fullName.trim().isEmpty
                                ? 'SV'
                                : profile.fullName.trim().substring(0, 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.fullName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'MSSV: ${profile.studentCode}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ApplicationFields({
                      'Chuyên ngành': profile.major,
                      'Trường': profile.university,
                      'Email': profile.email,
                      if (profile.phone != null && profile.phone!.isNotEmpty)
                        'Số điện thoại': profile.phone!,
                      if (profile.className != null) 'Lớp': profile.className!,
                      if (profile.semester != null)
                        'Học kỳ': '${profile.semester}',
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ApplicationCvPanel(
                cvUrl: profile.cvUrl,
                onEdit: _sending ? null : _edit,
              ),
              const SizedBox(height: 16),
              DashboardPanel(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    key: const Key('applicationConsent'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                    value: _consent,
                    onChanged: _sending ? null : (value) => _setConsent(value!),
                    title: Text(
                      'Tôi xác nhận thông tin trên là chính xác và đồng ý chia sẻ hồ sơ cùng CV với ${opportunity.company}.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _sending ? null : () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    key: const Key('confirmApplication'),
                    onPressed:
                        !_loading &&
                            !_sending &&
                            !_uncertain &&
                            _consent &&
                            profile != null &&
                            _opportunity?.acceptsApplicationsAt(
                                  DateTime.now(),
                                ) ==
                                true
                        ? _send
                        : null,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined, size: 17),
                    label: Text(_sending ? 'Đang gửi…' : 'Ứng tuyển ngay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
