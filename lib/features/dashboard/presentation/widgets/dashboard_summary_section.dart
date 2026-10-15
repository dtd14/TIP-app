import 'package:tip_app/features/internships/domain/entities/placement_overview.dart';
import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';

class InternshipPeriodCard extends StatelessWidget {
  const InternshipPeriodCard({
    super.key,
    required this.registration,
    this.now,
    this.title,
  });
  final InternshipRegistration? registration;
  final String? title;
  final DateTime? now;
  @override
  Widget build(BuildContext context) {
    final item = registration;
    final today = now ?? DateTime.now();
    final deadline = item?.applyEndDate;
    final duration = deadline?.difference(today);
    final remaining = duration == null
        ? null
        : !duration.isNegative
        ? 'Còn ${(duration.inSeconds / 86400).ceil()} ngày'
        : 'Đã hết hạn nộp';
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DashboardIcon(Icons.assignment_outlined, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? item?.titleAt(today) ?? 'Đợt thực tập',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: StatusPill(
                    item.periodStatusLabel,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
          if (item == null)
            const DashboardEmpty(
              'Bạn chưa được phân công đợt thực tập.\nNhà trường sẽ cập nhật thông tin tại đây.',
            )
          else ...[
            if (item.status == 'FAILED') ...[
              const SizedBox(height: 8),
              const StatusPill('Liên hệ nhà trường', color: Color(0xFFB42318)),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          DateFormatter.range(item.startDate, item.endDate),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (remaining != null &&
                      item.periodStatus == 'OPEN' &&
                      const {'READY', 'APPLYING'}.contains(item.status))
                    StatusPill(remaining, color: const Color(0xFFD92D20)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Trạng thái đăng ký:',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                StatusPill(
                  item.statusLabel,
                  color: item.status == 'FAILED'
                      ? const Color(0xFFB42318)
                      : AppColors.accent,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class PlacementCard extends StatelessWidget {
  const PlacementCard({
    super.key,
    required this.placement,
    this.onDetails,
    this.onCompany,
  });
  final PlacementOverview? placement;
  final VoidCallback? onDetails;
  final VoidCallback? onCompany;
  @override
  Widget build(BuildContext context) {
    final item = placement;
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            'Vị trí chính thức',
            icon: Icons.apartment_rounded,
          ),
          const SizedBox(height: 12),
          if (item == null)
            const DashboardEmpty(
              'Chưa có vị trí thực tập được phân công.\nKhám phá cơ hội và theo dõi đơn ứng tuyển của bạn.',
              icon: Icons.business_outlined,
            )
          else
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CompanyLink(
                        name: item.company,
                        onTap: onCompany,
                        child: const DashboardIcon(
                          Icons.apartment_rounded,
                          size: 42,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            CompanyName(
                              item.company,
                              verified: false,
                              fontSize: 12,
                              onTap: onCompany,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoBox(
                        'Thời gian thực tập',
                        DateFormatter.range(item.startDate, item.endDate),
                      ),
                      _InfoBox(
                        'Người hướng dẫn',
                        item.supervisor ?? 'Chưa phân công',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Flexible(child: StatusPill(item.statusLabel)),
                      const Spacer(),
                      if (onDetails != null)
                        TextButton(
                          onPressed: onDetails,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 32),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'Chi tiết →',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
