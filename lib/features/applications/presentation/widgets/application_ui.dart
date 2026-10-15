import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';

String applicationTypeLabel(String? type) => switch (type) {
  'INTERNSHIP' => 'Thực tập',
  'MICRO_INTERNSHIP' => 'Thực tập ngắn hạn',
  'JOB' => 'Việc làm',
  _ => 'Cơ hội',
};
Color applicationStatusColor(String status) => switch (status) {
  'ACCEPTED' || 'REVIEWING' => AppColors.accent,
  'REJECTED' => const Color(0xFFB42318),
  'WITHDRAWN' => AppColors.muted,
  _ => AppColors.primary,
};
String applicationStatusMessage(String status) => switch (status) {
  'PENDING' => 'Đơn đã được gửi đến doanh nghiệp và đang chờ xét duyệt.',
  'REVIEWING' => 'Doanh nghiệp đang xem xét đơn ứng tuyển của bạn.',
  'ACCEPTED' => 'Doanh nghiệp đã chấp nhận đơn ứng tuyển của bạn.',
  'REJECTED' => 'Đơn chưa được chấp nhận. Bạn có thể khám phá các cơ hội khác.',
  'WITHDRAWN' => 'Bạn đã rút đơn. Đơn vẫn được giữ trong danh sách.',
  _ => 'Trạng thái đang được cập nhật.',
};

class ApplicationHeaderCard extends StatelessWidget {
  const ApplicationHeaderCard({
    super.key,
    required this.title,
    required this.company,
    this.type,
    this.status,
    this.verified = false,
    this.location,
    this.deadline,
    this.vacancies,
    this.onCompany,
  });
  final String title, company;
  final String? type, status, location;
  final bool verified;
  final DateTime? deadline;
  final int? vacancies;
  final VoidCallback? onCompany;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Colors.white, Color(0xFFE8F7FE)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEEF1F8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanyAvatar(name: company, size: 48, onTap: onCompany),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompanyName(
                    company,
                    verified: verified,
                    fontSize: 12,
                    onTap: onCompany,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  if (location != null) ...[
                    const SizedBox(height: 7),
                    OpportunityMeta(Icons.location_on_outlined, location!),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            if (type != null)
              StatusPill(applicationTypeLabel(type), color: AppColors.primary),
            if (status != null)
              StatusPill(
                ApplicationOverview.labelForStatus(status!),
                color: applicationStatusColor(status!),
              ),
            if (vacancies != null)
              StatusPill('$vacancies vị trí', color: AppColors.primary),
            if (deadline != null)
              StatusPill(
                'Hạn: ${DateFormatter.date(deadline!)}',
                color: AppColors.muted,
              ),
          ],
        ),
      ],
    ),
  );
}

class ApplicationFields extends StatelessWidget {
  const ApplicationFields(this.fields, {super.key});
  final Map<String, String> fields;
  @override
  Widget build(BuildContext context) => Column(
    children: fields.entries
        .map(
          (entry) => Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(9),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final label = Text(
                  entry.key,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                );
                final value = Text(
                  entry.value,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
                if (constraints.maxWidth < 270 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.2) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [label, const SizedBox(height: 5), value],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: value,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        )
        .toList(),
  );
}

class ApplicationCvPanel extends StatefulWidget {
  const ApplicationCvPanel({super.key, required this.cvUrl, this.onEdit});
  final String? cvUrl;
  final VoidCallback? onEdit;
  @override
  State<ApplicationCvPanel> createState() => _ApplicationCvPanelState();
}

class _ApplicationCvPanelState extends State<ApplicationCvPanel> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    final uri = Uri.tryParse(widget.cvUrl ?? '');
    setState(() => _opening = true);
    var opened = false;
    try {
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on Object {
      /* Show a bounded message without exposing a signed URL. */
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa thể mở CV. Vui lòng kiểm tra liên kết trong hồ sơ.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DashboardPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          'CV trong hồ sơ',
          icon: Icons.description_outlined,
          action: widget.onEdit == null ? null : 'Đổi CV',
          onAction: widget.onEdit,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const DashboardIcon(
                Icons.picture_as_pdf_outlined,
                color: Color(0xFFB42318),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.cvUrl == null
                      ? 'Bạn chưa có CV trong hồ sơ.'
                      : 'CV hiện tại của bạn',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.cvUrl != null)
                TextButton.icon(
                  key: const Key('viewApplicationCv'),
                  onPressed: _opening ? null : _open,
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('Xem'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Doanh nghiệp xem CV hiện tại trong hồ sơ sinh viên. Khi bạn đổi CV, liên kết trong đơn cũng thay đổi.',
          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
        ),
      ],
    ),
  );
}
