import 'package:tip_app/features/applications/domain/usecases/get_application.dart';
import 'package:tip_app/features/opportunities/domain/usecases/get_opportunity.dart';
import 'package:tip_app/features/internships/presentation/bloc/placement_detail/placement_detail_state.dart';
import 'package:tip_app/features/internships/presentation/bloc/placement_detail/placement_detail_event.dart';
import 'package:tip_app/features/internships/presentation/bloc/placement_detail/placement_detail_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/features/applications/presentation/pages/application_detail_page.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/pages/opportunity_detail_page.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/features/internships/presentation/widgets/internship_ui.dart';
import 'package:tip_app/features/opportunities/presentation/pages/company_detail_page.dart';
import 'package:tip_app/features/internships/presentation/pages/internship_period_detail_page.dart';

class InternshipPlacementDetailPage extends StatefulWidget {
  const InternshipPlacementDetailPage({
    super.key,
    required this.placementId,
    required this.user,
    required this.repository,
    required this.onRestricted,
    required this.onViewOpportunities,
    required this.onViewApplications,
    required this.onChanged,
  });
  final String placementId;
  final AuthUser user;
  final InternshipRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  final VoidCallback onViewOpportunities, onViewApplications, onChanged;
  @override
  State<InternshipPlacementDetailPage> createState() =>
      _InternshipPlacementDetailPageState();
}

class _InternshipPlacementDetailPageState
    extends State<InternshipPlacementDetailPage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = PlacementDetailBloc(
    widget.repository,
    context.read<OpportunityRepository>(),
    widget.user,
    widget.placementId,
  );
  InternshipPlacement? get _detail => _bloc.state.detail;
  CompanyOverview? get _company => _bloc.state.company;
  AuthFailure? get _failure => _bloc.state.failure;
  AuthFailure? get _companyFailure => _bloc.state.companyFailure;
  bool get _loading => _bloc.state.loading;
  bool get _companyLoading => _bloc.state.companyLoading;
  Future<void> _load() => _bloc.dispatch(PlacementLoadRequested());
  Future<void> _loadCompany(String id) =>
      _bloc.dispatch(PlacementCompanyLoadRequested(id));
  void _onBlocState(BuildContext context, PlacementDetailState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<PlacementDetailBloc, PlacementDetailState>(
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<PlacementDetailBloc, PlacementDetailState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _open(Future<Widget> Function() page) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final destination = await page();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => destination));
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      if (failure.kind == FailureKind.inactiveAccount) {
        widget.onRestricted(failure);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể mở thông tin liên kết. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _jumpToApplications() {
    widget.onViewApplications();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<Widget> _opportunity() async {
    final repository = context.read<OpportunityRepository>();
    final item = await GetOpportunity(repository)(_detail!.opportunityId!);
    return OpportunityDetailPage(
      opportunity: item,
      repository: repository,
      canApply: false,
      readOnlyHint: 'Cơ hội này đã liên kết với vị trí thực tập của bạn.',
      onRestricted: widget.onRestricted,
      onApplied: () {},
    );
  }

  Future<Widget> _application() async {
    final repository = context.read<ApplicationRepository>();
    final detail = await GetApplication(repository)(
      _detail!.applicationId!,
      widget.user,
    );
    return ApplicationDetailPage(
      application: detail.application,
      user: widget.user,
      repository: repository,
      onRestricted: widget.onRestricted,
      onChanged: widget.onChanged,
    );
  }

  Future<void> _companyDetails() => _open(
    () async => CompanyDetailPage(
      companyId: _detail!.companyId,
      user: widget.user,
      repository: context.read<OpportunityRepository>(),
      onRestricted: widget.onRestricted,
      onChanged: widget.onChanged,
      onViewApplications: widget.onViewApplications,
    ),
  );

  Widget _buildContent(BuildContext context) {
    final detail = _detail, item = detail?.overview;
    return InternshipFrame(
      title: 'Chi tiết vị trí thực tập',
      backKey: 'placementBack',
      onRefresh: _load,
      children: [
        if (_loading || _opening)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: LinearProgressIndicator(),
          ),
        if (_failure != null)
          InternshipErrorCard(
            message: _failure!.message,
            onRetry: _loading ? null : _load,
          ),
        if (detail != null && item != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFE8F7FE)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEEF1F8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'VỊ TRÍ ĐƯỢC PHÂN CÔNG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CompanyAvatar(
                      key: const Key('placementCompanyLogo'),
                      onTap: _opening ? null : _companyDetails,
                      name: item.company,
                      logoUrl: _company?.logoUrl,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CompanyName(
                            key: const Key('placementCompanyName'),
                            onTap: _opening ? null : _companyDetails,
                            _company?.name ?? item.company,
                            verified: _company?.status == 'VERIFIED',
                            fontSize: 12,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 21,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill(
                    item.statusLabel,
                    color: item.status == 'CANCELLED'
                        ? const Color(0xFFB42318)
                        : AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InternshipFacts(
            title: 'Thông tin thực tập',
            icon: Icons.date_range_outlined,
            fields: {
              'Bắt đầu': DateFormatter.date(item.startDate),
              'Kết thúc': DateFormatter.date(item.endDate),
              if (detail.periodName != null) 'Đợt thực tập': detail.periodName!,
              'Sinh viên': detail.studentName,
              'MSSV': detail.studentCode,
              'Trường': detail.university,
            },
          ),
          const SizedBox(height: 14),
          if (_companyLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: LinearProgressIndicator(),
            ),
          if (_companyFailure != null)
            InternshipErrorCard(
              message: _companyFailure!.message,
              onRetry: _companyLoading
                  ? null
                  : () => _loadCompany(detail.companyId),
            ),
          DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeading(
                  'Doanh nghiệp tiếp nhận',
                  icon: Icons.apartment_rounded,
                ),
                const SizedBox(height: 12),
                CompanyName(
                  key: const Key('placementReceivingCompanyName'),
                  onTap: _opening ? null : _companyDetails,
                  _company?.name ?? item.company,
                  verified: _company?.status == 'VERIFIED',
                  fontSize: 16,
                ),
                if (_company?.industry != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _company!.industry!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                if (_company?.address != null) ...[
                  const SizedBox(height: 8),
                  OpportunityMeta(
                    Icons.location_on_outlined,
                    _company!.address!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeading('Người hướng dẫn', icon: Icons.groups_outlined),
          const SizedBox(height: 12),
          _contact('Người hướng dẫn tại trường', detail.universitySupervisor),
          const SizedBox(height: 12),
          _contact(
            'Người hướng dẫn tại doanh nghiệp',
            detail.companySupervisor,
          ),
          if (detail.registrationId != null ||
              detail.opportunityId != null ||
              detail.applicationId != null) ...[
            const SizedBox(height: 18),
            DashboardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeading(
                    'Thông tin liên kết',
                    icon: Icons.link_rounded,
                  ),
                  const SizedBox(height: 12),
                  if (detail.registrationId != null)
                    TextButton.icon(
                      key: const Key('placementPeriod'),
                      onPressed: _opening
                          ? null
                          : () => _open(
                              () async => InternshipPeriodDetailPage(
                                registrationId: detail.registrationId!,
                                user: widget.user,
                                repository: widget.repository,
                                onRestricted: widget.onRestricted,
                                onViewOpportunities: widget.onViewOpportunities,
                                onViewApplications: widget.onViewApplications,
                                onChanged: widget.onChanged,
                              ),
                            ),
                      icon: const Icon(Icons.school_outlined, size: 18),
                      label: const Text('Chi tiết đợt thực tập'),
                    ),
                  if (detail.opportunityId != null)
                    TextButton.icon(
                      key: const Key('placementOpportunity'),
                      onPressed: _opening ? null : () => _open(_opportunity),
                      icon: const Icon(Icons.work_outline_rounded, size: 18),
                      label: const Text('Tin tuyển dụng liên kết'),
                    ),
                  if (detail.applicationId != null)
                    TextButton.icon(
                      key: const Key('placementApplication'),
                      onPressed: _opening ? null : () => _open(_application),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Đơn ứng tuyển liên kết'),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: _jumpToApplications,
            child: const Text('Đơn ứng tuyển của tôi'),
          ),
        ],
      ],
    );
  }

  Widget _contact(String title, InternshipContact? contact) => contact == null
      ? DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chưa phân công',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        )
      : InternshipFacts(
          title: title,
          icon: Icons.person_outline_rounded,
          fields: {
            'Họ tên': contact.name,
            'Email': contact.email,
            if (contact.phone != null) 'Điện thoại': contact.phone!,
          },
        );
}
