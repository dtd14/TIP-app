import 'package:tip_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:tip_app/features/internships/domain/entities/internship_registration.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/features/applications/presentation/widgets/application_ui.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';
import 'package:tip_app/features/internships/domain/entities/internship_placement.dart';

class InternshipFrame extends StatelessWidget {
  const InternshipFrame({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.children,
    this.backKey = 'internshipBack',
  });
  final String title, backKey;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        key: Key(backKey),
        tooltip: 'Quay lại',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      actions: const [NotificationBell()],
    ),
    body: SafeArea(
      top: false,
      child: DashboardScroll(onRefresh: onRefresh, children: children),
    ),
  );
}

class InternshipErrorCard extends StatelessWidget {
  const InternshipErrorCard({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DashboardPanel(
      child: Column(
        children: [
          const DashboardIcon(Icons.cloud_off_outlined),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

class InternshipFacts extends StatelessWidget {
  const InternshipFacts({
    super.key,
    required this.title,
    required this.icon,
    required this.fields,
  });
  final String title;
  final IconData icon;
  final Map<String, String> fields;
  @override
  Widget build(BuildContext context) => DashboardPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title, icon: icon),
        const SizedBox(height: 5),
        ApplicationFields(fields),
      ],
    ),
  );
}

class InternshipRequirements extends StatelessWidget {
  const InternshipRequirements({super.key, required this.registration});
  final InternshipRegistration registration;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width =
          constraints.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.2
          ? (constraints.maxWidth - 10) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (registration.requiredHours != null)
            SizedBox(
              width: width,
              child: _metric(
                Icons.schedule_rounded,
                'Yêu cầu giờ',
                '${registration.requiredHours} giờ',
              ),
            ),
          if (registration.requiredWeeks != null)
            SizedBox(
              width: width,
              child: _metric(
                Icons.calendar_month_outlined,
                'Thời lượng yêu cầu',
                '${registration.requiredWeeks} tuần',
              ),
            ),
        ],
      );
    },
  );
  Widget _metric(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DashboardIcon(icon, color: AppColors.accent, size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class InternshipPeriodTile extends StatelessWidget {
  const InternshipPeriodTile({
    super.key,
    required this.registration,
    required this.onDetails,
  });
  final InternshipRegistration registration;
  final VoidCallback? onDetails;
  @override
  Widget build(BuildContext context) {
    final item = registration;
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(
                item.periodStatusLabel,
                color: item.isActive ? AppColors.accent : AppColors.muted,
              ),
              if (item.periodNumber != null)
                StatusPill(
                  'Đợt ${item.periodNumber}',
                  color: AppColors.primary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 17,
              height: 1.35,
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          ApplicationFields({
            'Thời gian thực tập': DateFormatter.range(
              item.startDate,
              item.endDate,
            ),
            if (item.applyEndDate != null)
              'Hạn nộp hồ sơ': DateFormatter.date(item.applyEndDate!),
          }),
          if (item.requiredHours != null || item.requiredWeeks != null) ...[
            const SizedBox(height: 12),
            InternshipRequirements(registration: item),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7FC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Trạng thái của bạn:',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                Text(
                  item.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: item.status == 'FAILED'
                        ? const Color(0xFFB42318)
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: Key('internshipPeriod-${item.id}'),
            onPressed: onDetails,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Xem chi tiết đợt'),
          ),
        ],
      ),
    );
  }
}

class InternshipPlacementTile extends StatelessWidget {
  const InternshipPlacementTile({
    super.key,
    required this.placement,
    required this.onDetails,
    this.onCompany,
  });
  final InternshipPlacement placement;
  final VoidCallback onDetails;
  final VoidCallback? onCompany;
  @override
  Widget build(BuildContext context) {
    final item = placement.overview;
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyAvatar(name: item.company, size: 40, onTap: onCompany),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CompanyName(
                      item.company,
                      verified: false,
                      fontSize: 11,
                      onTap: onCompany,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              item.statusLabel,
              color: item.status == 'CANCELLED'
                  ? const Color(0xFFB42318)
                  : AppColors.accent,
            ),
          ),
          ApplicationFields({
            'Thời gian': DateFormatter.range(item.startDate, item.endDate),
            if (placement.periodName != null)
              'Đợt thực tập': placement.periodName!,
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: Key('internshipPlacement-${item.id}'),
            onPressed: onDetails,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Chi tiết vị trí'),
          ),
        ],
      ),
    );
  }
}
