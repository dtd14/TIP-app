import 'package:tip_app/features/student_enrollment/presentation/bloc/student_enrollment/student_enrollment_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/presentation/bloc/student_enrollment/student_enrollment_bloc.dart';
import 'package:tip_app/features/student_enrollment/presentation/widgets/enrollment_card.dart';
import 'package:tip_app/features/student_enrollment/presentation/widgets/enrollment_form.dart';

class StudentEnrollmentPage extends StatelessWidget {
  const StudentEnrollmentPage({
    super.key,
    required this.user,
    required this.repository,
    required this.onReloadAccount,
    required this.onRestricted,
  });
  final AuthUser user;
  final StudentEnrollmentRepository repository;
  final VoidCallback onReloadAccount;
  final ValueChanged<AuthFailure> onRestricted;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => StudentEnrollmentBloc(repository, user)..refresh(),
    child: _EnrollmentView(
      user: user,
      repository: repository,
      onReloadAccount: onReloadAccount,
      onRestricted: onRestricted,
    ),
  );
}

class _EnrollmentView extends StatelessWidget {
  const _EnrollmentView({
    required this.user,
    required this.repository,
    required this.onReloadAccount,
    required this.onRestricted,
  });
  final AuthUser user;
  final StudentEnrollmentRepository repository;
  final VoidCallback onReloadAccount;
  final ValueChanged<AuthFailure> onRestricted;
  Future<void> _cancel(BuildContext context, StudentEnrollment item) async {
    final cubit = context.read<StudentEnrollmentBloc>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy yêu cầu ghi danh?'),
        content: const Text(
          'Yêu cầu đã hủy vẫn được giữ trong lịch sử. Bạn có thể gửi yêu cầu mới để sửa thông tin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ yêu cầu'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (confirm == true && !cubit.isClosed) await cubit.cancel(item);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<StudentEnrollmentBloc, EnrollmentState>(
    listener: (context, state) {
      if (state.failure?.kind == FailureKind.inactiveAccount) {
        onRestricted(state.failure!);
        return;
      }
      if (state.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    },
    builder: (context, state) {
      final cubit = context.read<StudentEnrollmentBloc>();
      final approved = state.items.any((item) => item.status == 'APPROVED');
      return Scaffold(
        appBar: AppBar(
          title: Text(
            user.canRequestStudentEnrollment
                ? 'Ghi danh sinh viên'
                : 'Lịch sử ghi danh',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: DashboardScroll(
          onRefresh: cubit.refresh,
          children: [
            DashboardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeading(
                    'Kết nối với nhà trường',
                    icon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Gửi yêu cầu không cấp quyền sinh viên ngay. Nhà trường cần xác minh việc theo học và phê duyệt hồ sơ.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('enrollmentReloadAccount'),
                    onPressed: state.saving ? null : onReloadAccount,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Cập nhật quyền tài khoản'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (state.loading || state.saving)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (state.failure != null) ...[
              DashboardPanel(
                child: Column(
                  children: [
                    Text(
                      state.failure!.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                    TextButton(
                      onPressed: state.loading || state.saving
                          ? null
                          : cubit.refresh,
                      child: const Text('Tải lại yêu cầu'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (state.hasPending) ...[
              const DashboardPanel(
                child: Text(
                  'Bạn đang có một yêu cầu chờ duyệt. Nếu cần sửa thông tin, hãy hủy yêu cầu đó và gửi yêu cầu mới.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (approved && !user.canAccessStudentApp) ...[
              const DashboardPanel(
                child: Text(
                  'Yêu cầu đã được duyệt. Nhấn “Cập nhật quyền tài khoản” để tải hồ sơ sinh viên mới mà không cần đăng nhập lại.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (user.canRequestStudentEnrollment &&
                state.loaded &&
                !state.hasPending &&
                !approved) ...[
              EnrollmentForm(
                repository: repository,
                onRestricted: onRestricted,
                busy: state.saving,
                onSubmit: cubit.submit,
              ),
              const SizedBox(height: 20),
            ],
            const SectionHeading(
              'Lịch sử yêu cầu',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: 8),
            const Text(
              'Hiển thị tối đa 50 yêu cầu gần nhất.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            if (state.loaded && state.items.isEmpty)
              const DashboardPanel(
                child: DashboardEmpty('Bạn chưa gửi yêu cầu ghi danh nào.'),
              ),
            ...state.visibleItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EnrollmentCard(
                  item: item,
                  onCancel:
                      item.isPending &&
                          !state.saving &&
                          !state.loading &&
                          state.loaded
                      ? () => _cancel(context, item)
                      : null,
                ),
              ),
            ),
            if (state.hasMoreHistory)
              OutlinedButton(
                onPressed: state.loading || state.saving
                    ? null
                    : cubit.nextPage,
                child: const Text('Tải thêm lịch sử'),
              ),
          ],
        ),
      );
    },
  );
}
