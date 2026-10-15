import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';

class ApplicationTile extends StatelessWidget {
  const ApplicationTile(
    this.application, {
    super.key,
    this.onTap,
    this.onCompany,
  });
  final ApplicationOverview application;
  final VoidCallback? onTap;
  final VoidCallback? onCompany;
  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final status = StatusPill(
      application.statusLabel,
      color: application.status == 'REJECTED'
          ? const Color(0xFFB42318)
          : AppColors.primary,
    );
    return Material(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CompanyLink(
                    name: application.company,
                    onTap: onCompany,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.work_outline_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CompanyName(
                          application.company,
                          verified: application.companyVerified,
                          fontSize: 11,
                          onTap: onCompany,
                        ),
                      ],
                    ),
                  ),
                  if (!stacked) ...[const SizedBox(width: 6), status],
                ],
              ),
              if (stacked) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: status),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
