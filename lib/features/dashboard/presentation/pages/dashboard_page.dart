import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/dashboard/presentation/bloc/dashboard/dashboard_state.dart';
import 'package:tip_app/features/dashboard/presentation/widgets/dashboard_stat_card.dart';
import 'package:tip_app/features/dashboard/presentation/widgets/dashboard_summary_section.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/dashboard/presentation/widgets/recent_activity_list.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.state,
    required this.onRefresh,
    required this.onNavigate,
    required this.onApplication,
    this.onEnrollment,
    this.onApplicationCompany,
    this.onPlacementCompany,
  });
  final AuthUser user;
  final DashboardState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onNavigate;
  final ValueChanged<ApplicationOverview> onApplication;
  final VoidCallback? onEnrollment;
  final ValueChanged<ApplicationOverview>? onApplicationCompany;
  final ValueChanged<PlacementOverview>? onPlacementCompany;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    return DashboardScroll(
      onRefresh: onRefresh,
      children: [
        _Greeting(user: user, profile: summary?.profile),
        const SizedBox(height: 14),
        if (!user.canAccessStudentApp) ...[
          const DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(
                  'Chào mừng đến TIP Career',
                  icon: Icons.explore_outlined,
                ),
                SizedBox(height: 10),
                Text(
                  'Khám phá các cơ hội thực tập và việc làm. Các mục ứng tuyển và thực tập sẽ có khi tài khoản được liên kết với hồ sơ sinh viên hợp lệ.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (state.loading) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 14),
        ],
        if (state.failure != null) ...[
          DashboardPanel(
            child: Column(
              children: [
                const DashboardIcon(Icons.cloud_off_outlined),
                const SizedBox(height: 10),
                Text(
                  state.failure!.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                TextButton(
                  onPressed: state.loading ? null : onRefresh,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (summary != null) ...[
          InternshipPeriodCard(
            registration: summary.profile.currentInternship(DateTime.now()),
          ),
          const SizedBox(height: 14),
          DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeading(
                  'Đơn ứng tuyển',
                  icon: Icons.assignment_outlined,
                  action: 'Xem tất cả',
                  onAction: () => onNavigate(2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatCard(
                        label: 'Tổng đơn',
                        value: summary.submitted,
                        icon: Icons.send_outlined,
                        onTap: () => onNavigate(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DashboardStatCard(
                        label: 'Đang xét',
                        value: summary.reviewing,
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.accent,
                        onTap: () => onNavigate(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DashboardStatCard(
                        label: 'Trúng tuyển',
                        value: summary.accepted,
                        icon: Icons.verified_outlined,
                        onTap: () => onNavigate(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (summary.applications.isEmpty)
                  const DashboardEmpty(
                    'Bạn chưa có đơn ứng tuyển.\nTìm cơ hội phù hợp để bắt đầu.',
                  )
                else
                  ...summary.applications
                      .take(1)
                      .map(
                        (item) => ApplicationTile(
                          item,
                          onTap: () => onApplication(item),
                          onCompany: onApplicationCompany == null
                              ? null
                              : () => onApplicationCompany!(item),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PlacementCard(
            placement: summary.placement,
            onDetails: () => onNavigate(3),
            onCompany: summary.placement == null || onPlacementCompany == null
                ? null
                : () => onPlacementCompany!(summary.placement!),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.explore_outlined,
                title: 'Khám phá cơ hội',
                subtitle: 'Tìm thêm việc làm mới',
                onTap: () => onNavigate(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: user.canAccessStudentApp
                    ? Icons.school_outlined
                    : Icons.person_outline_rounded,
                title: onEnrollment != null
                    ? 'Ghi danh sinh viên'
                    : user.canAccessStudentApp
                    ? 'Thực tập của tôi'
                    : 'Hồ sơ của tôi',
                subtitle: onEnrollment != null
                    ? 'Gửi yêu cầu đến trường'
                    : user.canAccessStudentApp
                    ? 'Xem đợt và vị trí'
                    : 'Thông tin tài khoản',
                color: AppColors.accent,
                onTap:
                    onEnrollment ??
                    (!user.canAccessStudentApp
                        ? () => onNavigate(4)
                        : summary == null
                        ? null
                        : () => onNavigate(3)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user, this.profile});
  final AuthUser user;
  final StudentProfile? profile;
  @override
  Widget build(BuildContext context) {
    final name = (profile?.fullName ?? user.fullName)
        .trim()
        .split(RegExp(r'\s+'))
        .last;
    return DashboardPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -55,
              child: Container(
                width: 155,
                height: 155,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F5FA),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 23,
                        child: Text(
                          name.isEmpty
                              ? 'SV'
                              : name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: 'Xin chào, $name '),
                                  const WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Icon(
                                      Icons.waving_hand_rounded,
                                      color: Color(0xFFF5B52D),
                                      size: 21,
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.canAccessStudentApp
                                  ? 'Chúc bạn một tuần thực tập hiệu quả!'
                                  : 'Khám phá cơ hội phù hợp với bạn.',
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (profile?.semester != null) ...[
                        const SizedBox(width: 8),
                        StatusPill(
                          'HK ${profile!.semester}',
                          color: AppColors.accent,
                        ),
                      ],
                    ],
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(Icons.school_outlined, profile!.major),
                        _Chip(Icons.badge_outlined, profile!.studentCode),
                        if (profile!.className != null)
                          _Chip(Icons.groups_outlined, profile!.className!),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE8EFFF),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.color = AppColors.primary,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardIcon(icon, color: color, size: 38),
            const SizedBox(height: 11),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
