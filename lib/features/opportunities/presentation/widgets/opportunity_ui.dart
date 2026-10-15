import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';

class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 48,
    this.onTap,
  });
  final String name;
  final String? logoUrl;
  final double size;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final initials = words
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    final fallback = Center(
      child: Text(
        initials.isEmpty ? 'TIP' : initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: size * .28,
        ),
      ),
    );
    final uri = Uri.tryParse(logoUrl ?? '');
    return CompanyLink(
      name: name,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6ECFA)),
        ),
        clipBehavior: Clip.antiAlias,
        child: uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
            ? Image.network(
                logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class CompanyName extends StatelessWidget {
  const CompanyName(
    this.name, {
    super.key,
    required this.verified,
    this.fontSize = 16,
    this.onTap,
  });
  final String name;
  final bool verified;
  final double fontSize;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => CompanyLink(
    name: name,
    onTap: onTap,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          if (verified)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 5),
                child: Tooltip(
                  message: 'Doanh nghiệp đã xác minh',
                  child: Icon(
                    Icons.verified_rounded,
                    size: 15,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: fontSize,
        color: AppColors.text,
      ),
    ),
  );
}

class CompanyLink extends StatelessWidget {
  const CompanyLink({
    super.key,
    required this.name,
    required this.child,
    this.onTap,
  });
  final String name;
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => onTap == null
      ? child
      : Tooltip(
          message: 'Xem doanh nghiệp $name',
          child: Semantics(
            link: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: child,
              ),
            ),
          ),
        );
}

String deadlineLabel(DateTime deadline, DateTime now) {
  if (!deadline.isAfter(now)) return 'Đã hết hạn';
  final remaining = deadline.difference(now);
  return remaining.inHours < 24
      ? 'Hạn trong 24 giờ'
      : 'Còn ${remaining.inDays} ngày';
}

class OpportunityBadges extends StatelessWidget {
  const OpportunityBadges(this.item, {super.key, this.showDeadline = true});
  final OpportunityOverview item;
  final bool showDeadline;
  @override
  Widget build(BuildContext context) {
    final deadline = item.deadline;
    final urgent =
        deadline != null && deadline.difference(DateTime.now()).inDays < 7;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        StatusPill(
          item.typeLabel,
          color: item.type == 'MICRO_INTERNSHIP'
              ? AppColors.accent
              : AppColors.primary,
        ),
        StatusPill(
          item.statusLabel,
          color: item.status == 'OPEN' ? AppColors.accent : AppColors.muted,
        ),
        if (showDeadline && deadline != null)
          StatusPill(
            urgent
                ? deadlineLabel(deadline, DateTime.now())
                : 'Hạn: ${DateFormatter.date(deadline)}',
            color: urgent ? const Color(0xFFB42318) : AppColors.muted,
          ),
      ],
    );
  }
}

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({
    super.key,
    required this.item,
    required this.onDetails,
    this.onCompany,
  });
  final OpportunityOverview item;
  final VoidCallback onDetails;
  final VoidCallback? onCompany;
  @override
  Widget build(BuildContext context) => DashboardPanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CompanyAvatar(
              name: item.company,
              logoUrl: item.companyLogoUrl,
              onTap: onCompany,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompanyName(
                    item.company,
                    verified: item.companyVerified,
                    onTap: onCompany,
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Cơ hội từ doanh nghiệp',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        OpportunityBadges(item),
        const SizedBox(height: 12),
        Text(
          item.title,
          style: const TextStyle(
            fontSize: 19,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          item.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.muted,
          ),
        ),
        if (item.location != null || item.vacancies != null) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (item.location != null)
                OpportunityMeta(Icons.location_on_outlined, item.location!),
              if (item.vacancies != null)
                OpportunityMeta(
                  Icons.groups_outlined,
                  '${item.vacancies} vị trí',
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: Key('opportunityDetails-${item.id}'),
            onPressed: onDetails,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text('Xem chi tiết')),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class OpportunityMeta extends StatelessWidget {
  const OpportunityMeta(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.accent),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
    ],
  );
}
