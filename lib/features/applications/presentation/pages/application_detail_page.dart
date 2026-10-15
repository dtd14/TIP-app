import 'package:tip_app/features/opportunities/domain/usecases/get_opportunity.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_detail/application_detail_state.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_detail/application_detail_event.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_detail/application_detail_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/pages/opportunity_detail_page.dart';
import 'package:tip_app/features/applications/domain/entities/application_detail.dart';
import 'package:tip_app/features/applications/presentation/widgets/application_ui.dart';
import 'package:tip_app/features/applications/presentation/widgets/application_withdrawal_sheet.dart';
import 'package:tip_app/features/opportunities/presentation/company_navigation.dart';

class ApplicationDetailPage extends StatefulWidget {
  const ApplicationDetailPage({
    super.key,
    required this.application,
    required this.user,
    required this.repository,
    required this.onRestricted,
    required this.onChanged,
  });
  final ApplicationOverview application;
  final AuthUser user;
  final ApplicationRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  final VoidCallback onChanged;
  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = ApplicationDetailBloc(
    widget.repository,
    widget.application,
    widget.user,
  );
  ApplicationDetail? get _detail => _bloc.state.detail;
  AuthFailure? get _failure => _bloc.state.failure;
  bool get _loading => _bloc.state.loading;
  bool get _withdrawing => _bloc.state.withdrawing;
  bool get _confirmed => _bloc.state.confirmed;
  bool get _withdrawn => _bloc.state.withdrawn;
  Future<void> _load() => _bloc.dispatch(ApplicationDetailLoadRequested());
  Future<void> _withdraw() async {
    if (_withdrawing ||
        _confirming ||
        _loading ||
        !_confirmed ||
        _detail?.application.canWithdraw != true) {
      return;
    }
    _confirming = true;
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      barrierColor: AppColors.text.withValues(alpha: .45),
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => ApplicationWithdrawalSheet(
        title: _detail!.application.title,
        company: _detail!.application.company,
      ),
    );
    _confirming = false;
    if (!mounted || confirm != true || _withdrawing || _loading) return;
    await _performWithdrawal();
    if (!mounted) return;
    widget.onChanged();
    if (_withdrawn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã rút đơn ứng tuyển.')));
    }
  }

  Future<void> _performWithdrawal() =>
      _bloc.dispatch(ApplicationWithdrawalRequested());
  void _onBlocState(BuildContext context, ApplicationDetailState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<ApplicationDetailBloc, ApplicationDetailState>(
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<ApplicationDetailBloc, ApplicationDetailState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  final _companies = CompanyNavigation();
  bool _confirming = false;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _opportunity() async {
    if (_opening || _detail == null || _withdrawing) return;
    setState(() => _opening = true);
    try {
      final opportunity = await GetOpportunity(
        context.read<OpportunityRepository>(),
      )(_detail!.opportunityId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => OpportunityDetailPage(
            opportunity: opportunity,
            repository: context.read<OpportunityRepository>(),
            canApply: false,
            readOnlyHint: 'Bạn đã có đơn ứng tuyển cho cơ hội này.',
            onRestricted: widget.onRestricted,
            onApplied: () {},
          ),
        ),
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      if (failure.kind == FailureKind.inactiveAccount) {
        widget.onRestricted(failure);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể mở tin tuyển dụng. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _buildContent(BuildContext context) {
    final detail = _detail, item = detail?.application ?? widget.application;
    return PopScope(
      canPop: !_withdrawing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Chi tiết ứng tuyển',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            key: const Key('applicationBack'),
            onPressed: _withdrawing ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: DashboardScroll(
          onRefresh: () async {
            if (!_withdrawing) await _load();
          },
          children: [
            ApplicationHeaderCard(
              onCompany: _withdrawing
                  ? null
                  : () => _companies.open(
                      context,
                      companyId: item.companyId,
                      applicationId: item.id,
                      onRestricted: widget.onRestricted,
                      onChanged: widget.onChanged,
                    ),
              title: item.title,
              company: item.company,
              type: item.type,
              status: item.status,
              verified: item.companyVerified,
            ),
            const SizedBox(height: 12),
            if (detail != null)
              OutlinedButton.icon(
                key: const Key('applicationOpportunity'),
                onPressed: _opening || _withdrawing ? null : _opportunity,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(_opening ? 'Đang mở…' : 'Tin tuyển dụng'),
              ),
            const SizedBox(height: 14),
            if (_loading || _withdrawing)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: LinearProgressIndicator(),
              ),
            if (_failure != null) ...[
              DashboardPanel(
                child: Column(
                  children: [
                    Text(_failure!.message, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _loading || _withdrawing ? null : _load,
                      child: const Text('Tải lại đơn'),
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
                  const SectionHeading(
                    'Trạng thái đơn',
                    icon: Icons.fact_check_outlined,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: applicationStatusColor(
                        item.status,
                      ).withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      applicationStatusMessage(item.status),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: applicationStatusColor(item.status),
                      ),
                    ),
                  ),
                  ApplicationFields({
                    'Thời gian nộp': _dateTime(item.appliedAt),
                    if (item.updatedAt != null)
                      'Cập nhật đơn': _dateTime(item.updatedAt!),
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (detail != null) ...[
              DashboardPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeading(
                      'Thông tin chi tiết đơn',
                      icon: Icons.assignment_outlined,
                    ),
                    ApplicationFields({
                      'Mã đơn': item.id,
                      'Ứng viên': detail.fullName,
                      'MSSV': detail.studentCode,
                      'Chuyên ngành': detail.major,
                      'Trường': detail.university,
                      'Email': detail.email,
                      if (detail.phone != null && detail.phone!.isNotEmpty)
                        'Số điện thoại': detail.phone!,
                      'Doanh nghiệp': item.company,
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ApplicationCvPanel(cvUrl: detail.cvUrl),
              const SizedBox(height: 14),
              if (item.canWithdraw)
                DashboardPanel(
                  child: OutlinedButton.icon(
                    key: const Key('withdrawApplication'),
                    onPressed: _confirmed && !_loading && !_withdrawing
                        ? _withdraw
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                      backgroundColor: const Color(0xFFFFF1F0),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Rút đơn ứng tuyển'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _dateTime(DateTime value) {
    final local = value.toLocal();
    return '${DateFormatter.date(value)} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
