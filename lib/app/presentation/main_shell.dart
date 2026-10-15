import 'package:tip_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:tip_app/features/profile/domain/usecases/get_student_profile.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/applications/presentation/pages/application_list_page.dart';
import 'package:tip_app/features/applications/presentation/pages/application_detail_page.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:tip_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:tip_app/features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'package:tip_app/features/dashboard/presentation/bloc/dashboard/dashboard_bloc.dart';
import 'package:tip_app/features/dashboard/presentation/bloc/dashboard/dashboard_state.dart';
import 'package:tip_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:tip_app/features/internships/presentation/pages/internship_list_page.dart';
import 'package:tip_app/features/opportunities/presentation/company_navigation.dart';
import 'package:tip_app/features/opportunities/presentation/pages/opportunity_list_page.dart';
import 'package:tip_app/features/profile/presentation/pages/profile_page.dart';
import 'package:tip_app/features/profile/presentation/pages/student_profile_page.dart';
import 'package:tip_app/features/profile/presentation/pages/student_cv_page.dart';
import 'package:tip_app/features/profile/presentation/pages/edit_student_profile_page.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/presentation/pages/student_enrollment_page.dart';
import 'package:tip_app/features/student_enrollment/presentation/pages/enrollment_review_page.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'main_shell_controller.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.user,
    required this.onLogout,
    this.controller,
  });
  final AuthUser user;
  final VoidCallback onLogout;
  final MainShellController? controller;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => DashboardBloc(
      GetDashboardSummary(context.read<DashboardRepository>()),
      user,
    )..refresh(),
    child: _StudentShell(
      user: user,
      onLogout: onLogout,
      controller: controller,
    ),
  );
}

class _StudentShell extends StatefulWidget {
  const _StudentShell({
    required this.user,
    required this.onLogout,
    this.controller,
  });
  final AuthUser user;
  final VoidCallback onLogout;
  final MainShellController? controller;
  @override
  State<_StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<_StudentShell>
    with WidgetsBindingObserver {
  int _tab = 0;
  int _navigationRevision = 0, _dashboardRevision = 0;
  void _requestedNavigation() {
    final controller = widget.controller!;
    if (_navigationRevision != controller.navigationRevision) {
      _navigationRevision = controller.navigationRevision;
      _navigate(controller.requestedTab!);
    }
    if (_dashboardRevision != controller.dashboardRevision) {
      _dashboardRevision = controller.dashboardRevision;
      context.read<DashboardBloc>().refresh();
    }
  }

  final _companies = CompanyNavigation();
  final _scaffold = GlobalKey<ScaffoldState>();
  static const _labels = [
    'Trang chủ',
    'Cơ hội',
    'Ứng tuyển',
    'Thực tập',
    'Hồ sơ',
  ];
  static const _icons = [
    Icons.home_outlined,
    Icons.work_outline_rounded,
    Icons.send_outlined,
    Icons.school_outlined,
    Icons.person_outline_rounded,
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tab = widget.controller?.requestedTab ?? 0;
    if (!widget.user.canAccessStudentApp && !{0, 1, 4}.contains(_tab)) _tab = 0;
    _navigationRevision = widget.controller?.navigationRevision ?? 0;
    _dashboardRevision = widget.controller?.dashboardRevision ?? 0;
    widget.controller?.addListener(_requestedNavigation);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.removeListener(_requestedNavigation);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthBloc>().add(
        const AuthRestoreRequested(preserveNavigation: true),
      );
    }
  }

  void _navigate(int tab) {
    widget.controller?.requestedTab = tab;
    setState(() => _tab = tab);
  }

  void _logout() => widget.onLogout();
  Future<void> _application(ApplicationOverview item) async {
    var changed = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplicationDetailPage(
          application: item,
          user: widget.user,
          repository: context.read<ApplicationRepository>(),
          onRestricted: _restricted,
          onChanged: () => changed = true,
        ),
      ),
    );
    if (mounted && changed) await context.read<DashboardBloc>().refresh();
  }

  Future<bool> _editProfile(StudentProfile profile) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditStudentProfilePage(
          profile: profile,
          repository: context.read<StudentProfileRepository>(),
          onRestricted: _restricted,
          reloadProfile: () => GetStudentProfile(
            context.read<StudentProfileRepository>(),
          )(widget.user),
        ),
      ),
    );
    if (mounted && updated == true) {
      context.read<AuthBloc>().add(
        const AuthRestoreRequested(preserveNavigation: true),
      );
    }
    return updated == true;
  }

  Future<bool> _manageCv(StudentProfile profile) async =>
      (await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => StudentCvPage(
            user: widget.user,
            repository: context.read<StudentProfileRepository>(),
            profileRepository: context.read<StudentProfileRepository>(),
            onRestricted: _restricted,
          ),
        ),
      )) ==
      true;

  void _openEnrollment({bool review = false}) {
    if (review
        ? !widget.user.canReviewStudentEnrollments
        : !widget.user.canViewStudentEnrollments) {
      return;
    }
    _scaffold.currentState?.closeEndDrawer();
    final repository = context.read<StudentEnrollmentRepository>();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => review
            ? EnrollmentReviewPage(
                user: widget.user,
                repository: repository,
                onRestricted: _restricted,
              )
            : StudentEnrollmentPage(
                user: widget.user,
                repository: repository,
                onRestricted: _restricted,
                onReloadAccount: () =>
                    context.read<AuthBloc>().add(const AuthRestoreRequested()),
              ),
      ),
    );
  }

  Future<void> _refresh() async {
    if (widget.user.canAccessStudentApp) {
      await context.read<DashboardBloc>().refresh();
    } else {
      context.read<AuthBloc>().add(const AuthRestoreRequested());
    }
  }

  void _restricted(AuthFailure failure) =>
      context.read<AuthBloc>().add(AuthAccessRestricted(failure));

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<DashboardBloc, DashboardState>(
        listenWhen: (previous, current) => previous.failure != current.failure,
        listener: (context, state) {
          if (state.failure?.kind == FailureKind.inactiveAccount) {
            _restricted(state.failure!);
          }
        },
        builder: (context, state) {
          final cubit = context.read<DashboardBloc>();
          final tabs = widget.user.canAccessStudentApp
              ? const [0, 1, 2, 3, 4]
              : const [0, 1, 4];
          final dashboard = DashboardPage(
            user: widget.user,
            state: state,
            onRefresh: _refresh,
            onNavigate: _navigate,
            onApplication: _application,
            onApplicationCompany: (item) => _companies.open(
              context,
              companyId: item.companyId,
              applicationId: item.id,
              onRestricted: _restricted,
              onChanged: () => cubit.refresh(),
              onViewApplications: () => _navigate(2),
            ),
            onPlacementCompany: (item) => _companies.open(
              context,
              companyId: item.companyId,
              placementId: item.id,
              onRestricted: _restricted,
              onChanged: () => cubit.refresh(),
              onViewApplications: () => _navigate(2),
            ),
            onEnrollment: widget.user.canRequestStudentEnrollment
                ? () => _openEnrollment()
                : null,
          );
          final body = switch (_tab) {
            1 => OpportunityListPage(
              repository: context.read<OpportunityRepository>(),
              onRestricted: _restricted,
              canApply: widget.user.canAccessStudentApp,
              onApplied: () => cubit.refresh(),
              onViewApplications: () => _navigate(2),
            ),
            2 => ApplicationListPage(
              user: widget.user,
              repository: context.read<ApplicationRepository>(),
              onRestricted: _restricted,
              onChanged: () => cubit.refresh(),
            ),
            3 => InternshipListPage(
              user: widget.user,
              repository: context.read<InternshipRepository>(),
              onRestricted: _restricted,
              onViewOpportunities: () => _navigate(1),
              onViewApplications: () => _navigate(2),
              onChanged: () => cubit.refresh(),
            ),
            4 when widget.user.canAccessStudentApp => ProfilePage(
              user: widget.user,
              repository: context.read<StudentProfileRepository>(),
              onRestricted: _restricted,
              onChanged: () => cubit.refresh(),
              onEdit: _editProfile,
              onManageCv: _manageCv,
              onLogout: _logout,
              onEnrollment: widget.user.canViewStudentEnrollments
                  ? () => _openEnrollment()
                  : null,
            ),
            4 when !widget.user.canAccessStudentApp => AccountProfilePage(
              user: widget.user,
              onRefresh: _refresh,
              onLogout: _logout,
              onEnrollment: widget.user.canRequestStudentEnrollment
                  ? () => _openEnrollment()
                  : null,
              onReviewEnrollments: widget.user.canReviewStudentEnrollments
                  ? () => _openEnrollment(review: true)
                  : null,
            ),
            _ => dashboard,
          };
          return Scaffold(
            key: _scaffold,
            endDrawer: Drawer(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        widget.user.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.person_outline_rounded),
                      title: const Text('Hồ sơ của tôi'),
                      onTap: () {
                        _scaffold.currentState?.closeEndDrawer();
                        _navigate(4);
                      },
                    ),
                    if (widget.user.canViewStudentEnrollments)
                      ListTile(
                        key: const Key('enrollmentMenu'),
                        leading: const Icon(Icons.school_outlined),
                        title: Text(
                          widget.user.canRequestStudentEnrollment
                              ? 'Ghi danh sinh viên'
                              : 'Lịch sử ghi danh',
                        ),
                        onTap: () => _openEnrollment(),
                      ),
                    if (widget.user.canReviewStudentEnrollments)
                      ListTile(
                        key: const Key('enrollmentReviewMenu'),
                        leading: const Icon(Icons.fact_check_outlined),
                        title: const Text('Xét duyệt ghi danh'),
                        onTap: () => _openEnrollment(review: true),
                      ),
                    const Spacer(),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Đăng xuất'),
                      onTap: _logout,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            appBar: AppBar(
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              toolbarHeight: 65,
              titleSpacing: 16,
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF168DF0),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'TIP',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    height: 25,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: const Color(0xFFDEE5F2),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TIP Career',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _labels[_tab],
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                const NotificationBell(),
                IconButton(
                  tooltip: 'Menu tài khoản',
                  onPressed: () => _scaffold.currentState?.openEndDrawer(),
                  icon: const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('logout'),
                  tooltip: 'Đăng xuất',
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  onPressed: _logout,
                ),
              ],
            ),
            body: SafeArea(top: false, bottom: false, child: body),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFECF0F8))),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 8, 5, 7),
                  child: Row(
                    children: tabs
                        .map(
                          (index) => Expanded(
                            child: Semantics(
                              selected: _tab == index,
                              button: true,
                              child: Material(
                                color: _tab == index
                                    ? const Color(0xFFF0F4FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  key: Key('nav$index'),
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _navigate(index),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 9,
                                      horizontal: 2,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _icons[index],
                                          size: 22,
                                          color: _tab == index
                                              ? AppColors.primary
                                              : AppColors.muted,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          _labels[index],
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _tab == index
                                                ? AppColors.primary
                                                : AppColors.muted,
                                            fontWeight: _tab == index
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
