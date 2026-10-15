import 'package:tip_app/features/internships/presentation/bloc/internship_list/internship_list_state.dart';
import 'package:tip_app/features/internships/presentation/bloc/internship_list/internship_list_event.dart';
import 'package:tip_app/features/internships/presentation/bloc/internship_list/internship_list_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';
import 'package:tip_app/features/internships/presentation/widgets/internship_ui.dart';
import 'package:tip_app/features/internships/presentation/pages/internship_period_detail_page.dart';
import 'package:tip_app/features/internships/presentation/pages/internship_placement_detail_page.dart';
import 'package:tip_app/features/opportunities/presentation/company_navigation.dart';

class InternshipListPage extends StatefulWidget {
  const InternshipListPage({
    super.key,
    required this.user,
    required this.repository,
    required this.onRestricted,
    required this.onViewOpportunities,
    required this.onViewApplications,
    required this.onChanged,
  });
  final AuthUser user;
  final InternshipRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  final VoidCallback onViewOpportunities, onViewApplications, onChanged;
  @override
  State<InternshipListPage> createState() => _InternshipListPageState();
}

class _InternshipListPageState extends State<InternshipListPage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = InternshipListBloc(
    widget.repository,
    context.read<StudentProfileRepository>(),
    widget.user,
  );
  StudentProfile? get _profile => _bloc.state.profile;
  List<InternshipPlacement> get _placements => _bloc.state.placements;
  PageSlice<InternshipPlacement>? get _page => _bloc.state.page;
  AuthFailure? get _failure => _bloc.state.failure;
  AuthFailure? get _placementFailure => _bloc.state.placementFailure;
  bool get _loading => _bloc.state.loading;
  bool get _placementsLoading => _bloc.state.placementsLoading;
  bool get _retryReset => _bloc.state.retryReset;
  Future<void> _reload() => _bloc.dispatch(InternshipListLoadRequested());
  Future<void> _loadPlacements({bool reset = false}) =>
      _bloc.dispatch(InternshipListNextPageRequested(reset: reset));
  void _onBlocState(BuildContext context, InternshipListState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
    if (state.placementFailure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.placementFailure!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<InternshipListBloc, InternshipListState>(
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<InternshipListBloc, InternshipListState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  final _companies = CompanyNavigation();
  bool _opening = false;
  String get _filter => _bloc.state.registrationFilter;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _open(Widget page) async {
    if (_opening) return;
    _opening = true;
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => page));
    _opening = false;
  }

  Widget _buildContent(BuildContext context) {
    final registrations = _bloc.state.registrations;
    final filters = {
      'ALL': 'Tất cả ${registrations.length}',
      'ACTIVE':
          'Đang mở / Hiện tại ${registrations.where((item) => item.isActive).length}',
      'COMPLETED':
          'Đã hoàn thành ${registrations.where((item) => item.isCompleted).length}',
    };
    final visible = _bloc.state.filteredRegistrations;
    return DashboardScroll(
      onRefresh: _reload,
      children: [
        const Text(
          'LỘ TRÌNH HỌC VỤ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Thực tập của tôi',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Theo dõi các đợt thực tập và vị trí được nhà trường phân công.',
          style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: LinearProgressIndicator(),
          ),
        if (_failure != null)
          InternshipErrorCard(
            message: _failure!.message,
            onRetry: _loading ? null : _reload,
          ),
        if (_profile != null) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('internshipFilter-${entry.key}'),
                        selected: _filter == entry.key,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _filter == entry.key
                              ? Colors.white
                              : AppColors.text,
                        ),
                        label: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onSelected: (_) => _bloc.dispatch(
                          InternshipRegistrationFilterChanged(entry.key),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeading('Các đợt thực tập', icon: Icons.school_outlined),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const DashboardPanel(
              child: DashboardEmpty('Chưa có đợt thực tập phù hợp với bộ lọc.'),
            ),
          ...visible
              .take(_bloc.state.visibleRegistrations)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InternshipPeriodTile(
                    registration: item,
                    onDetails: item.periodId == null
                        ? null
                        : () => _open(
                            InternshipPeriodDetailPage(
                              registrationId: item.id,
                              user: widget.user,
                              repository: widget.repository,
                              onRestricted: widget.onRestricted,
                              onViewOpportunities: widget.onViewOpportunities,
                              onViewApplications: widget.onViewApplications,
                              onChanged: widget.onChanged,
                            ),
                          ),
                  ),
                ),
              ),
          if (visible.length > _bloc.state.visibleRegistrations)
            OutlinedButton(
              onPressed: () =>
                  _bloc.dispatch(InternshipMoreRegistrationsRequested()),
              child: const Text('Tải thêm đợt'),
            ),
          const SizedBox(height: 4),
          const SectionHeading(
            'Vị trí được phân công',
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
                '${_page!.total} vị trí trong hồ sơ',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          if (!_placementsLoading &&
              _placementFailure == null &&
              _placements.isEmpty)
            const DashboardPanel(
              child: DashboardEmpty(
                'Bạn chưa có vị trí thực tập được phân công.',
              ),
            ),
          ..._placements.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InternshipPlacementTile(
                placement: item,
                onCompany: () => _companies.open(
                  context,
                  companyId: item.companyId,
                  onRestricted: widget.onRestricted,
                  onChanged: widget.onChanged,
                  onViewApplications: widget.onViewApplications,
                ),
                onDetails: () => _open(
                  InternshipPlacementDetailPage(
                    placementId: item.overview.id,
                    user: widget.user,
                    repository: widget.repository,
                    onRestricted: widget.onRestricted,
                    onViewOpportunities: widget.onViewOpportunities,
                    onViewApplications: widget.onViewApplications,
                    onChanged: widget.onChanged,
                  ),
                ),
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
                  'Bước tiếp theo',
                  icon: Icons.explore_outlined,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nhà trường phân công đợt và vị trí thực tập. Bạn có thể tìm cơ hội và theo dõi các đơn đã gửi.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: widget.onViewOpportunities,
                  child: const Text('Khám phá cơ hội'),
                ),
                TextButton(
                  onPressed: widget.onViewApplications,
                  child: const Text('Đơn ứng tuyển của tôi'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
