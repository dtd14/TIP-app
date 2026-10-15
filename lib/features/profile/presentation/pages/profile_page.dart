import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';

import 'package:tip_app/core/widgets/portal_ui.dart';

class AccountProfilePage extends StatelessWidget {
  const AccountProfilePage({
    super.key,
    required this.user,
    required this.onRefresh,
    required this.onLogout,
    this.onEnrollment,
    this.onReviewEnrollments,
  });
  final AuthUser user;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogout;
  final VoidCallback? onEnrollment, onReviewEnrollments;

  @override
  Widget build(BuildContext context) => DashboardScroll(
    onRefresh: onRefresh,
    children: [
      const Text(
        'Hồ sơ tài khoản',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 18),
      DashboardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              user.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Center(child: StatusPill('Đang hoạt động')),
            const SizedBox(height: 16),
            Text(
              user.canRequestStudentEnrollment
                  ? 'Gửi yêu cầu ghi danh đến trường đang theo học. Nhà trường sẽ xác minh và phê duyệt trước khi cấp hồ sơ sinh viên.'
                  : user.hasSchoolProfile ||
                        user.hasCompanyProfile ||
                        user.globalRole == 'SYSTEM_ADMIN'
                  ? 'Các chức năng quản lý được hiển thị theo vai trò của tài khoản.'
                  : 'Hồ sơ sinh viên chưa có quyền truy cập các chức năng dành cho sinh viên. Vui lòng liên hệ nhà trường để được hỗ trợ.',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (onEnrollment != null) ...[
        FilledButton.icon(
          key: const Key('openEnrollment'),
          onPressed: onEnrollment,
          icon: const Icon(Icons.school_outlined),
          label: const Text('Ghi danh sinh viên'),
        ),
        const SizedBox(height: 12),
      ],
      if (onReviewEnrollments != null) ...[
        FilledButton.icon(
          key: const Key('openEnrollmentReview'),
          onPressed: onReviewEnrollments,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Xét duyệt ghi danh'),
        ),
        const SizedBox(height: 12),
      ],
      OutlinedButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Đăng xuất'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB42318),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    ],
  );
}
