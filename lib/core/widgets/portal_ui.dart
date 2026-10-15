import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';

class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEEF1F8)),
    ),
    child: child,
  );
}

class DashboardIcon extends StatelessWidget {
  const DashboardIcon(
    this.icon, {
    super.key,
    this.color = AppColors.primary,
    this.size = 38,
  });
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, color: color, size: size * .54),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color = AppColors.accent});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    super.key,
    required this.icon,
    this.action,
    this.onAction,
  });
  final String title;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          action != null &&
          constraints.maxWidth < 300 &&
          MediaQuery.textScalerOf(context).scale(1) > 1.2;
      final button = action == null
          ? null
          : TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                minimumSize: const Size(48, 36),
              ),
              child: Text(action!, style: const TextStyle(fontSize: 11)),
            );
      final heading = Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          if (!stacked) ?button,
        ],
      );
      return stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                Align(alignment: Alignment.centerRight, child: button),
              ],
            )
          : heading;
    },
  );
}

class DashboardEmpty extends StatelessWidget {
  const DashboardEmpty(
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
  });
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFFB4C5E1), size: 32),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class DashboardScroll extends StatelessWidget {
  const DashboardScroll({
    super.key,
    required this.children,
    required this.onRefresh,
  });
  final List<Widget> children;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.primary,
    onRefresh: onRefresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
