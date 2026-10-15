import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/company_detail/company_detail_state.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/company_detail/company_detail_event.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/company_detail/company_detail_bloc.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/pages/opportunity_detail_page.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';
import 'package:tip_app/features/internships/presentation/widgets/internship_ui.dart';

class CompanyDetailPage extends StatefulWidget {
  const CompanyDetailPage({
    super.key,
    required this.companyId,
    required this.user,
    required this.repository,
    required this.onRestricted,
    required this.onChanged,
    this.onViewApplications,
  });
  final String companyId;
  final AuthUser user;
  final OpportunityRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  final VoidCallback onChanged;
  final VoidCallback? onViewApplications;
  @override
  State<CompanyDetailPage> createState() => _CompanyDetailPageState();
}

class _CompanyDetailPageState extends State<CompanyDetailPage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = CompanyDetailBloc(
    widget.repository,
    widget.user,
    widget.companyId,
  );
  CompanyOverview? get _company => _bloc.state.company;
  List<OpportunityOverview>? get _opportunities =>
      _bloc.state.visibleOpportunities;
  AuthFailure? get _companyFailure => _bloc.state.companyFailure;
  AuthFailure? get _opportunityFailure => _bloc.state.opportunityFailure;
  bool get _companyLoading => _bloc.state.companyLoading;
  bool get _opportunitiesLoading => _bloc.state.opportunitiesLoading;
  Future<void> _refresh() => _bloc.dispatch(CompanyRefreshRequested());
  Future<void> _loadCompany() => _bloc.dispatch(CompanyLoadRequested());
  Future<void> _loadOpportunities() =>
      _bloc.dispatch(CompanyOpportunitiesLoadRequested());
  void _onBlocState(BuildContext context, CompanyDetailState state) {
    if (state.opportunityFailure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.opportunityFailure!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<CompanyDetailBloc, CompanyDetailState>(
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<CompanyDetailBloc, CompanyDetailState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  bool _opening = false;
  bool _websiteOpening = false;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _opportunity(OpportunityOverview opportunity) async {
    if (_opening) return;
    _opening = true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OpportunityDetailPage(
          opportunity: opportunity,
          repository: widget.repository,
          canApply: widget.user.canAccessStudentApp,
          onRestricted: widget.onRestricted,
          onApplied: widget.onChanged,
          onViewApplications: widget.onViewApplications,
        ),
      ),
    );
    _opening = false;
  }

  Future<void> _website() async {
    if (_websiteOpening) return;
    setState(() => _websiteOpening = true);
    var opened = false;
    try {
      final uri = Uri.tryParse(_company?.website ?? '');
      if (uri != null &&
          const {'https', 'http'}.contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on Object {
      /* Show a bounded message without logging navigation data. */
    }
    if (!mounted) return;
    setState(() => _websiteOpening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa thể mở website của doanh nghiệp.')),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    final company = _company;
    return InternshipFrame(
      title: 'Doanh nghiệp',
      backKey: 'companyBack',
      onRefresh: _refresh,
      children: [
        if (_companyLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: LinearProgressIndicator(),
          ),
        if (_companyFailure != null)
          InternshipErrorCard(
            message: _companyFailure!.message,
            onRetry: _companyLoading ? null : _loadCompany,
          ),
        if (company != null) ...[
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: CompanyAvatar(
                    name: company.name,
                    logoUrl: company.logoUrl,
                    size: 72,
                  ),
                ),
                const SizedBox(height: 16),
                CompanyName(
                  company.name,
                  verified: company.status == 'VERIFIED',
                  fontSize: 22,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill(
                    _statusLabel(company.status),
                    color: company.status == 'VERIFIED'
                        ? AppColors.accent
                        : AppColors.muted,
                  ),
                ),
                if (company.industry != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    company.industry!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (company.website != null ||
              company.address != null ||
              company.industry != null) ...[
            InternshipFacts(
              title: 'Thông tin doanh nghiệp',
              icon: Icons.business_outlined,
              fields: {
                if (company.website != null) 'Website': company.website!,
                if (company.address != null) 'Địa chỉ': company.address!,
                if (company.industry != null) 'Lĩnh vực': company.industry!,
              },
            ),
            if (company.website != null)
              OutlinedButton.icon(
                key: const Key('companyWebsite'),
                onPressed: _websiteOpening ? null : _website,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Mở website'),
              ),
            const SizedBox(height: 14),
          ],
        ],
        if (widget.user.canAccessStudentApp) ...[
          const SectionHeading(
            'Cơ hội đang tuyển',
            icon: Icons.work_outline_rounded,
          ),
          const SizedBox(height: 12),
          if (_opportunitiesLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: LinearProgressIndicator(),
            ),
          if (_opportunityFailure != null)
            InternshipErrorCard(
              message: _opportunityFailure!.message,
              onRetry: _opportunitiesLoading ? null : _loadOpportunities,
            ),
          if (_opportunities != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_bloc.state.opportunities!.length} cơ hội đang mở',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          if (_opportunities?.isEmpty == true)
            const DashboardPanel(
              child: DashboardEmpty('Doanh nghiệp chưa có cơ hội đang tuyển.'),
            ),
          ...?_opportunities?.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: OpportunityCard(
                item: item,
                onDetails: () => _opportunity(item),
              ),
            ),
          ),
          if (_bloc.state.hasMoreOpportunities && !_opportunitiesLoading)
            OutlinedButton(
              onPressed: () =>
                  _bloc.dispatch(CompanyMoreOpportunitiesRequested()),
              child: const Text('Tải thêm cơ hội'),
            ),
        ],
      ],
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'VERIFIED' => 'Đã xác minh',
    'PENDING' => 'Chờ xác minh',
    'SUSPENDED' => 'Tạm khóa',
    'INACTIVE' => 'Ngừng hoạt động',
    _ => 'Chưa xác định',
  };
}
