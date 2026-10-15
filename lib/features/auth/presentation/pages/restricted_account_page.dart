import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/widgets/app_button.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';

class RestrictedAccountPage extends StatelessWidget {
  const RestrictedAccountPage({
    super.key,
    this.user,
    this.failure,
    required this.onLogout,
  });
  final AuthUser? user;
  final AuthFailure? failure;
  final VoidCallback onLogout;

  String get _status => switch (user?.accountStatus != 'ACTIVE'
      ? user?.accountStatus
      : user?.studentStatus) {
    'PENDING' => 'Đang chờ duyệt',
    'INACTIVE' => 'Chưa hoạt động',
    'SUSPENDED' => 'Đã tạm khóa',
    _ =>
      user?.studentId == null && failure == null
          ? 'Chưa có hồ sơ sinh viên'
          : 'Truy cập bị hạn chế',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TIP CAREER',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 36),
                Container(
                  width: 106,
                  height: 106,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0DA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_person_outlined,
                    size: 49,
                    color: Color(0xFFB8750B),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Chưa thể truy cập',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0DA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _status,
                    style: const TextStyle(
                      color: Color(0xFF9A630C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  failure?.message ??
                      user?.accessMessage ??
                      'Bạn chưa được cấp quyền truy cập.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vui lòng liên hệ bộ phận phụ trách thực tập của nhà trường để được hỗ trợ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 22),
                  Text(
                    user!.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                AppButton(
                  key: const Key('restrictedLogout'),
                  label: 'Đăng xuất',
                  onPressed: onLogout,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.read<AuthBloc>().add(
                    const AuthRestoreRequested(),
                  ),
                  child: const Text('Kiểm tra lại trạng thái'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
