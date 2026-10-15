import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';

class EnrollmentCard extends StatelessWidget {
  const EnrollmentCard({
    super.key,
    required this.item,
    this.onCancel,
    this.onApprove,
    this.onReject,
  });
  final StudentEnrollment item;
  final VoidCallback? onCancel, onApprove, onReject;
  @override
  Widget build(BuildContext context) => DashboardPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const DashboardIcon(Icons.school_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.universityName ?? 'Yêu cầu ghi danh',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: StatusPill(
                item.statusLabel,
                color: switch (item.status) {
                  'APPROVED' => AppColors.accent,
                  'REJECTED' => const Color(0xFFB42318),
                  'PENDING' => AppColors.primary,
                  _ => AppColors.muted,
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final entry in {
          if (item.fullName != null) 'Họ và tên': item.fullName!,
          if (item.email != null) 'Email': item.email!,
          if (item.majorName != null) 'Ngành học': item.majorName!,
          'Mã sinh viên': item.studentCode,
          'Lớp': item.className,
          'Học kỳ': '${item.semester}',
          if (item.createdAt != null)
            'Ngày gửi': DateFormatter.date(item.createdAt!),
        }.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${entry.key}: ',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  TextSpan(
                    text: entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        if (item.status == 'REJECTED') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Lý do từ chối: ${item.reason ?? 'Chưa có thông tin'}',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFFB42318),
              ),
            ),
          ),
        ],
        if (onCancel != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: Key('cancel-${item.id}'),
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Hủy yêu cầu'),
          ),
        ],
        if (onApprove != null || onReject != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton(
                key: Key('approve-${item.id}'),
                onPressed: onApprove,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                child: const Text('Phê duyệt'),
              ),
              OutlinedButton(
                key: Key('reject-${item.id}'),
                onPressed: onReject,
                child: const Text('Từ chối'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
