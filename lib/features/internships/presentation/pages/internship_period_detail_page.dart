import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/internships/presentation/bloc/internship_detail/internship_detail_state.dart';
import 'package:tip_app/features/internships/presentation/bloc/internship_detail/internship_detail_event.dart';
import 'package:tip_app/features/internships/presentation/bloc/internship_detail/internship_detail_bloc.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/features/internships/presentation/widgets/internship_ui.dart';
import 'package:tip_app/features/internships/presentation/pages/internship_placement_detail_page.dart';
import 'package:tip_app/features/opportunities/presentation/company_navigation.dart';

class InternshipPeriodDetailPage extends StatefulWidget {
  const InternshipPeriodDetailPage({
    super.key,
    required this.registrationId,
    required this.user,
    required this.repository,
    required this.onRestricted,
    required this.onViewOpportunities,
    required this.onViewApplications,
    required this.onChanged,
  });
  final String registrationId;
  final AuthUser user;
  final InternshipRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  final VoidCallback onViewOpportunities, onViewApplications, onChanged;
  @override
  State<InternshipPeriodDetailPage> createState() =>
      _InternshipPeriodDetailPageState();
}

class _InternshipPeriodDetailPageState
    extends State<InternshipPeriodDetailPage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = InternshipDetailBloc(
    widget.repository,
    context.read<StudentProfileRepository>(),
    widget.user,
    widget.registrationId,
  );
  InternshipRegistration? get _registration => _bloc.state.registration;
  List<InternshipPlacement> get _placements => _bloc.state.placements;
  PageSlice<InternshipPlacement>? get _page => _bloc.state.page;
  AuthFailure? get _failure => _bloc.state.failure;
  AuthFailure? get _placementFailure => _bloc.state.placementFailure;
  bool get _loading => _bloc.state.loading;
  bool get _placementsLoading => _bloc.state.placementsLoading;
  bool get _retryReset => _bloc.state.retryReset;
  Future<void> _load() => _bloc.dispatch(InternshipDetailLoadRequested());
  Future<void> _loadPlacements({bool reset = false}) =>
      _bloc.dispatch(InternshipDetailNextPageRequested(reset: reset));
  void _onBlocState(BuildContext context, InternshipDetailState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
    if (state.placementFailure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.placementFailure!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<InternshipDetailBloc, InternshipDetailState>(
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<InternshipDetailBloc, InternshipDetailState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  final _companies = CompanyNavigation();
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _navigate(VoidCallback action) {
    action();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _placement(InternshipPlacement item) async {
    if (_opening) return;
    _opening = true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InternshipPlacementDetailPage(
          placementId: item.overview.id,
          user: widget.user,
          repository: widget.repository,
          onRestricted: widget.onRestricted,
          onViewOpportunities: widget.onViewOpportunities,
          onViewApplications: widget.onViewApplications,
          onChanged: widget.onChanged,
        ),
      ),
    );
    _opening = false;
  }

  Widget _buildContent(BuildContext context) {
    final item = _registration;
    return InternshipFrame(
      title: 'Chi tiết đợt thực tập',
      onRefresh: _load,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: LinearProgressIndicator(),
          ),
        if (_failure != null)
          InternshipErrorCard(
            message: _failure!.message,
            onRetry: _loading ? null : _load,
          ),
        if (item != null) ...[
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(item.periodStatusLabel),
                    if (item.periodNumber != null)
                      StatusPill(
                        'Đợt ${item.periodNumber}',
                        color: AppColors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thông tin đợt thực tập và phân công do nhà trường cập nhật.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'TRẠNG THÁI CỦA BẠN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                    color: Color(0xFFB8EAFA),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.statusLabel,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage(item.status),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Color(0xFFDFE9FF),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.user.fullName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InternshipFacts(
            title: 'Mốc thời gian',
            icon: Icons.event_outlined,
            fields: {
              if (item.applyStartDate != null)
                'Bắt đầu nộp hồ sơ': DateFormatter.date(item.applyStartDate!),
              if (item.applyEndDate != null)
                'Hạn nộp hồ sơ': DateFormatter.date(item.applyEndDate!),
              'Bắt đầu thực tập': DateFormatter.date(item.startDate),
              'Kết thúc thực tập': DateFormatter.date(item.endDate),
            },
          ),
          if (item.requiredHours != null || item.requiredWeeks != null) ...[
            const SizedBox(height: 14),
            DashboardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeading(
                    'Yêu cầu thời lượng',
                    icon: Icons.fact_check_outlined,
                  ),
                  const SizedBox(height: 12),
                  InternshipRequirements(registration: item),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          const SectionHeading(
            'Vị trí trong đợt',
            icon: Icons.business_center_outlined,
          ),
          const SizedBox(height: 12),
          if (_placementsLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: LinearProgressIndicator(),
            ),
          if (_placementFailure != null)
            InternshipErrorCard(
              message: _placementFailure!.message,
              onRetry: _placementsLoading
                  ? null
                  : () => _loadPlacements(reset: _retryReset),
            ),
          if (_page != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_page!.total} vị trí trong đợt',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          if (!_placementsLoading &&
              _placementFailure == null &&
              _placements.isEmpty)
            const DashboardPanel(
              child: DashboardEmpty(
                'Bạn chưa có vị trí được phân công trong đợt này.',
              ),
            ),
          ..._placements.map(
            (placement) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InternshipPlacementTile(
                placement: placement,
                onCompany: () => _companies.open(
                  context,
                  companyId: placement.companyId,
                  onRestricted: widget.onRestricted,
                  onChanged: widget.onChanged,
                  onViewApplications: widget.onViewApplications,
                ),
                onDetails: () => _placement(placement),
              ),
            ),
          ),
          if (_page?.hasNext == true &&
              !_placementsLoading &&
              _placementFailure == null)
            OutlinedButton(
              onPressed: _loadPlacements,
              child: const Text('Tải thêm vị trí'),
            ),
          const SizedBox(height: 14),
          DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeading(
                  'Hành động nhanh',
                  icon: Icons.explore_outlined,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('periodExplore'),
                  onPressed: () => _navigate(widget.onViewOpportunities),
                  child: const Text('Khám phá cơ hội'),
                ),
                TextButton(
                  key: const Key('periodApplications'),
                  onPressed: () => _navigate(widget.onViewApplications),
                  child: const Text('Đơn ứng tuyển của tôi'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _statusMessage(String status) => switch (status) {
    'READY' =>
      'Bạn đã được nhà trường phân công đợt thực tập. Hãy tìm cơ hội phù hợp.',
    'APPLYING' => 'Bạn đang trong giai đoạn tìm vị trí và nộp hồ sơ ứng tuyển.',
    'PLACED' => 'Bạn đã có vị trí thực tập được phân công.',
    'IN_PROGRESS' => 'Bạn đang thực tập tại vị trí được phân công.',
    'COMPLETED' => 'Nhà trường đã cập nhật trạng thái hoàn thành thực tập.',
    'FAILED' =>
      'Bạn chưa hoàn thành đợt thực tập. Vui lòng liên hệ nhà trường.',
    'NOT_ASSIGNED' => 'Bạn chưa có vị trí được phân công trong đợt này.',
    _ => 'Vui lòng theo dõi cập nhật của nhà trường.',
  };
}
