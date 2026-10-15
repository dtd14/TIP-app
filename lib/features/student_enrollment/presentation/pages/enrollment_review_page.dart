import 'package:tip_app/features/student_enrollment/presentation/bloc/student_enrollment/student_enrollment_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';
import 'package:tip_app/features/student_enrollment/domain/enrollment_validation.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/student_enrollment/presentation/bloc/student_enrollment/student_enrollment_bloc.dart';
import 'package:tip_app/features/student_enrollment/presentation/widgets/enrollment_card.dart';

class EnrollmentReviewPage extends StatelessWidget {
  const EnrollmentReviewPage({
    super.key,
    required this.user,
    required this.repository,
    required this.onRestricted,
  });
  final AuthUser user;
  final StudentEnrollmentRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        StudentEnrollmentBloc(repository, user, reviewMode: true)..refresh(),
    child: _ReviewView(onRestricted: onRestricted),
  );
}

class _ReviewView extends StatefulWidget {
  const _ReviewView({required this.onRestricted});
  final ValueChanged<AuthFailure> onRestricted;
  @override
  State<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<_ReviewView> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _review(StudentEnrollment item, bool approve) async {
    final cubit = context.read<StudentEnrollmentBloc>();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(item: item, approve: approve),
    );
    if (reason != null && !cubit.isClosed) {
      await cubit.review(item, approve: approve, reason: reason);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<StudentEnrollmentBloc, EnrollmentState>(
    listener: (context, state) {
      if (state.failure?.kind == FailureKind.inactiveAccount) {
        widget.onRestricted(state.failure!);
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
      final busy = state.loading || state.saving;
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Xét duyệt ghi danh',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: DashboardScroll(
          onRefresh: cubit.refresh,
          children: [
            const DashboardPanel(
              child: Text(
                'Danh sách thuộc phạm vi trường của bạn. Cần xác minh sinh viên thực sự đang theo học trước khi phê duyệt.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('enrollmentQueueSearch'),
              controller: _search,
              enabled: !busy,
              onSubmitted: (_) =>
                  cubit.filter(status: state.status, keyword: _search.text),
              decoration: InputDecoration(
                hintText: 'Tìm yêu cầu',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Tìm kiếm',
                  onPressed: busy
                      ? null
                      : () => cubit.filter(
                          status: state.status,
                          keyword: _search.text,
                        ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('enrollmentQueueStatus'),
              initialValue: state.status ?? 'ALL',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: const [
                DropdownMenuItem(
                  value: 'PENDING',
                  child: Text('Chờ xét duyệt'),
                ),
                DropdownMenuItem(
                  value: 'APPROVED',
                  child: Text('Đã được duyệt'),
                ),
                DropdownMenuItem(value: 'REJECTED', child: Text('Đã từ chối')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy')),
                DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
              ],
              onChanged: busy
                  ? null
                  : (value) => cubit.filter(
                      status: value == 'ALL' ? null : value,
                      keyword: _search.text,
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              '${state.total} yêu cầu',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (state.failure != null) ...[
              DashboardPanel(
                child: Column(
                  children: [
                    Text(state.failure!.message, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: busy ? null : cubit.refresh,
                      child: const Text('Tải lại danh sách'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (state.loaded && state.items.isEmpty)
              const DashboardPanel(
                child: DashboardEmpty('Không có yêu cầu phù hợp.'),
              ),
            ...state.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EnrollmentCard(
                  item: item,
                  onApprove: item.isPending && !busy && state.loaded
                      ? () => _review(item, true)
                      : null,
                  onReject: item.isPending && !busy && state.loaded
                      ? () => _review(item, false)
                      : null,
                ),
              ),
            ),
            if (state.hasNext)
              OutlinedButton(
                onPressed: busy || !state.loaded ? null : cubit.nextPage,
                child: const Text('Tải thêm yêu cầu'),
              ),
          ],
        ),
      );
    },
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.item, required this.approve});
  final StudentEnrollment item;
  final bool approve;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _verified = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.approve ? 'Phê duyệt ghi danh?' : 'Từ chối ghi danh?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.item.fullName ?? widget.item.studentCode} · ${widget.item.className}',
          ),
          const SizedBox(height: 14),
          if (widget.approve)
            CheckboxListTile(
              key: const Key('enrollmentVerified'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Tôi đã xác minh sinh viên đang theo học tại trường.',
                style: TextStyle(fontSize: 13),
              ),
              value: _verified,
              onChanged: (value) => setState(() => _verified = value!),
            )
          else
            Form(
              key: _form,
              child: TextFormField(
                key: const Key('enrollmentRejectionReason'),
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Lý do từ chối'),
                validator: EnrollmentValidation.reason,
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        key: const Key('enrollmentReviewConfirm'),
        onPressed: widget.approve && !_verified
            ? null
            : () {
                if (!widget.approve && !_form.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  widget.approve ? '' : _reason.text.trim(),
                );
              },
        child: Text(widget.approve ? 'Xác nhận duyệt' : 'Xác nhận từ chối'),
      ),
    ],
  );
}
