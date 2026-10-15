import 'package:tip_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_detail/opportunity_detail_state.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_detail/opportunity_detail_event.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_detail/opportunity_detail_bloc.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/opportunities/domain/entities/company_overview.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';
import 'package:tip_app/features/applications/presentation/pages/application_confirmation_page.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/opportunities/presentation/company_navigation.dart';

class OpportunityDetailPage extends StatefulWidget {
  const OpportunityDetailPage({
    super.key,
    required this.opportunity,
    required this.repository,
    required this.canApply,
    required this.onRestricted,
    required this.onApplied,
    this.onViewApplications,
    this.readOnlyHint,
  });
  final OpportunityOverview opportunity;
  final OpportunityRepository repository;
  final bool canApply;
  final ValueChanged<AuthFailure> onRestricted;
  final VoidCallback onApplied;
  final VoidCallback? onViewApplications;
  final String? readOnlyHint;
  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = OpportunityDetailBloc(
    widget.repository,
    widget.opportunity,
    widget.canApply,
  );
  OpportunityOverview get _item => _bloc.state.item;
  CompanyOverview? get _company => _bloc.state.company;
  AuthFailure? get _failure => _bloc.state.failure;
  AuthFailure? get _companyFailure => _bloc.state.companyFailure;
  bool get _loading => _bloc.state.loading;
  bool get _companyLoading => _bloc.state.companyLoading;
  bool get _confirmed => _bloc.state.confirmed;
  Future<void> _refresh() => _bloc.dispatch(OpportunityDetailLoadRequested());
  Future<void> _loadCompany(String id) =>
      _bloc.dispatch(OpportunityCompanyLoadRequested(id));
  void _onBlocState(BuildContext context, OpportunityDetailState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<OpportunityDetailBloc, OpportunityDetailState>(
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<OpportunityDetailBloc, OpportunityDetailState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  final _companies = CompanyNavigation();
  Future<void> _companyDetails() => _companies.open(
    context,
    companyId: _item.companyId,
    opportunityId: _item.id,
    onRestricted: widget.onRestricted,
    onChanged: widget.onApplied,
    onViewApplications: widget.onViewApplications,
  );
  bool _applying = false;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    if (widget.canApply) {
      _refresh();
    } else if (_item.companyId != null) {
      _loadCompany(_item.companyId!);
    }
  }

  Future<void> _apply() async {
    if (_applying ||
        _applied ||
        !_confirmed ||
        !widget.canApply ||
        !_item.acceptsApplicationsAt(DateTime.now())) {
      return;
    }
    setState(() {
      _applying = true;
    });
    try {
      final user = context.read<AuthBloc>().state.user;
      if (user == null || !user.canAccessStudentApp) return;
      final result = await Navigator.of(context).push<ApplicationOverview>(
        MaterialPageRoute(
          builder: (_) => ApplicationConfirmationPage(
            opportunity: _item,
            user: user,
            repository: context.read<ApplicationRepository>(),
            onRestricted: widget.onRestricted,
            onViewApplications: widget.onViewApplications,
            onApplicationsChanged: widget.onApplied,
          ),
        ),
      );
      if (!mounted || result == null) return;
      setState(() => _applied = true);
      widget.onApplied();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi đơn ứng tuyển. Bạn có thể theo dõi trong mục Ứng tuyển.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  String? get _applicationHint {
    if (_applied) return null;
    if (!widget.canApply) {
      return widget.readOnlyHint ?? 'Cần hồ sơ sinh viên hợp lệ để ứng tuyển.';
    }
    if (_loading) return 'Đang kiểm tra thông tin cơ hội…';
    if (!_confirmed) return 'Cần tải lại thông tin cơ hội trước khi ứng tuyển.';
    if (_item.status != 'OPEN') return 'Cơ hội hiện không nhận đơn ứng tuyển.';
    if (_item.deadline == null) {
      return 'Doanh nghiệp chưa cập nhật hạn ứng tuyển.';
    }
    if (!_item.deadline!.isAfter(DateTime.now())) {
      return 'Cơ hội đã hết hạn ứng tuyển.';
    }
    return null;
  }

  Widget _buildContent(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        key: const Key('opportunityBack'),
        tooltip: 'Quay lại',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiết cơ hội',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'TIP Career · Tuyển dụng',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
      actions: const [NotificationBell()],
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: DashboardScroll(
        onRefresh: _refresh,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFEEF5FF)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEEF1F8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CompanyAvatar(
                      onTap: _applying ? null : _companyDetails,
                      name: _item.company,
                      logoUrl: _company?.logoUrl ?? _item.companyLogoUrl,
                      size: 54,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OpportunityBadges(_item, showDeadline: false),
                          const SizedBox(height: 10),
                          Text(
                            _item.title,
                            style: const TextStyle(
                              fontSize: 21,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CompanyName(
                            onTap: _applying ? null : _companyDetails,
                            _item.company,
                            verified: _company == null
                                ? _item.companyVerified
                                : _company!.status == 'VERIFIED',
                            fontSize: 13,
                          ),
                          if (_item.location != null) ...[
                            const SizedBox(height: 8),
                            OpportunityMeta(
                              Icons.location_on_outlined,
                              _item.location!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_failure != null) ...[
            DashboardPanel(
              child: Column(
                children: [
                  Text(_failure!.message, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _loading ? null : _refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel(
                  'THÔNG TIN CƠ BẢN',
                  Icons.info_outline_rounded,
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tiles = [
                      if (_item.vacancies != null)
                        _InfoTile(
                          icon: Icons.groups_outlined,
                          label: 'Số lượng tuyển',
                          value: '${_item.vacancies} vị trí',
                        ),
                      _InfoTile(
                        icon: Icons.schedule_rounded,
                        label: 'Hạn ứng tuyển',
                        value: _item.deadline == null
                            ? 'Chưa cập nhật'
                            : DateFormatter.date(_item.deadline!),
                        note: _item.deadline == null
                            ? null
                            : deadlineLabel(_item.deadline!, DateTime.now()),
                      ),
                    ];
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: tiles
                          .map(
                            (tile) => SizedBox(
                              width:
                                  constraints.maxWidth >= 290 &&
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1) <=
                                          1.2 &&
                                      tiles.length > 1
                                  ? (constraints.maxWidth - 10) / 2
                                  : constraints.maxWidth,
                              child: tile,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                if (_item.location != null) ...[
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.location_on_outlined,
                    label: 'Địa điểm làm việc',
                    value: _item.location!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeading(
                  'Mô tả công việc',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 14),
                // Description is one backend text field; do not invent requirements or benefits.
                SelectableText(
                  _item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel(
                  'THÔNG TIN DOANH NGHIỆP',
                  Icons.business_outlined,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    CompanyAvatar(
                      onTap: _applying ? null : _companyDetails,
                      name: _item.company,
                      logoUrl: _company?.logoUrl ?? _item.companyLogoUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CompanyName(
                        onTap: _applying ? null : _companyDetails,
                        _company?.name ?? _item.company,
                        verified: _company == null
                            ? _item.companyVerified
                            : _company!.status == 'VERIFIED',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (_companyLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_company != null) ...[
                  const SizedBox(height: 12),
                  if (_company!.industry != null)
                    _CompanyField(
                      Icons.layers_outlined,
                      'Lĩnh vực',
                      _company!.industry!,
                    ),
                  if (_company!.website != null)
                    _CompanyField(
                      Icons.language_rounded,
                      'Website',
                      _company!.website!,
                    ),
                  if (_company!.address != null)
                    _CompanyField(
                      Icons.location_on_outlined,
                      'Địa chỉ doanh nghiệp',
                      _company!.address!,
                    ),
                ],
                if (_companyFailure != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _companyFailure!.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  TextButton(
                    onPressed: _companyLoading
                        ? null
                        : () => _loadCompany(_item.companyId!),
                    child: const Text('Tải lại doanh nghiệp'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECF0F8))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_applicationHint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _applicationHint!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton.icon(
                key: const Key('applyOpportunity'),
                onPressed:
                    widget.canApply &&
                        _confirmed &&
                        !_loading &&
                        !_applying &&
                        !_applied &&
                        _item.acceptsApplicationsAt(DateTime.now())
                    ? _apply
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF245CF4),
                ),
                icon: _applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _applied
                            ? Icons.check_circle_outline_rounded
                            : Icons.send_rounded,
                        size: 18,
                      ),
                label: Text(
                  _applied
                      ? 'Đã ứng tuyển'
                      : _applying
                      ? 'Đang gửi đơn…'
                      : 'Ứng tuyển ngay',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.icon);
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: const Color(0xFF245CF4)),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
            color: Color(0xFF8699B8),
          ),
        ),
      ),
    ],
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });
  final IconData icon;
  final String label, value;
  final String? note;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFEEF1F8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF245CF4)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 5),
          Text(
            note!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
}

class _CompanyField extends StatelessWidget {
  const _CompanyField(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF8699B8)),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 3),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
