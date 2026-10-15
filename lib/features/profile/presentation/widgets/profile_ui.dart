import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';

class ProfileHero extends StatelessWidget {
  const ProfileHero({super.key, required this.profile, this.onEdit});
  final StudentProfile profile;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Colors.white, Color(0xFFE8F7FE)]),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEEF1F8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: Text(
                _initials(profile.fullName),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'MSSV: ${profile.studentCode}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusPill(profile.major, color: AppColors.accent),
                      if (profile.className != null)
                        StatusPill(
                          profile.className!,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (onEdit != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const Key('editStudentProfile'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text(
                'Chỉnh sửa hồ sơ',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    ),
  );
  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'SV';
    return (words.length == 1
            ? words.first.characters.first
            : words.first.characters.first + words.last.characters.first)
        .toUpperCase();
  }
}

class ProfileAcademicCard extends StatelessWidget {
  const ProfileAcademicCard({
    super.key,
    required this.profile,
    this.explain = false,
  });
  final StudentProfile profile;
  final bool explain;
  @override
  Widget build(BuildContext context) => DashboardPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('Thông tin học vụ', icon: Icons.school_outlined),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: StatusPill(
            'Chỉ đọc · Nhà trường quản lý',
            color: AppColors.muted,
          ),
        ),
        if (explain) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Thông tin học vụ do nhà trường quản lý. Vui lòng liên hệ nhà trường nếu cần chỉnh sửa.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
        for (final (label, value, icon) in [
          ('Mã sinh viên', profile.studentCode, Icons.badge_outlined),
          ('Trường đại học', profile.university, Icons.apartment_rounded),
          ('Ngành học', profile.major, Icons.school_outlined),
          ('Lớp', profile.className ?? 'Chưa cập nhật', Icons.groups_outlined),
          (
            'Học kỳ hiện tại',
            profile.semester == null
                ? 'Chưa cập nhật'
                : 'Học kỳ ${profile.semester}',
            Icons.calendar_month_outlined,
          ),
        ])
          explain
              ? ProfileReadField(label, value, icon: icon)
              : _ProfileSummaryRow(label, value),
      ],
    ),
  );
}

class _ProfileSummaryRow extends StatelessWidget {
  const _ProfileSummaryRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 15),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelText = Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        );
        final valueText = SelectableText(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        );
        if (constraints.maxWidth < 270 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [labelText, const SizedBox(height: 5), valueText],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: labelText),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Align(alignment: Alignment.centerRight, child: valueText),
            ),
          ],
        );
      },
    ),
  );
}

class ProfileReadField extends StatelessWidget {
  const ProfileReadField(
    this.label,
    this.value, {
    super.key,
    this.icon,
    this.trailing,
  });
  final String label, value;
  final IconData? icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: AppColors.muted),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ],
    ),
  );
}

class CvViewButton extends StatefulWidget {
  const CvViewButton({super.key, required this.cvUrl, this.enabled = true});
  final String? cvUrl;
  final bool enabled;
  @override
  State<CvViewButton> createState() => _CvViewButtonState();
}

class _CvViewButtonState extends State<CvViewButton> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening || !widget.enabled) return;
    setState(() => _opening = true);
    var opened = false;
    try {
      final uri = Uri.tryParse(widget.cvUrl ?? '');
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on Object {
      /* Never log a potentially signed CV URL. */
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
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      backgroundColor: const Color(0xFFE4EDFF),
      side: BorderSide.none,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    onPressed: widget.enabled && widget.cvUrl != null && !_opening
        ? _open
        : null,
    icon: const Icon(Icons.visibility_outlined, size: 17),
    label: Text(_opening ? 'Đang mở…' : 'Xem CV'),
  );
}

class ProfileCvCard extends StatelessWidget {
  const ProfileCvCard({super.key, required this.cvUrl, required this.onManage});
  final String? cvUrl;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) => DashboardPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          'CV dùng ứng tuyển',
          icon: Icons.description_outlined,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const DashboardIcon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFFB42318),
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cvUrl == null
                        ? 'Chưa có CV trong hồ sơ'
                        : 'CV hiện tại của bạn',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'PDF · Tối đa 4 MiB khi tải lên',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ProfileCvActions(
          viewKey: 'profileViewCv',
          cvUrl: cvUrl,
          action: FilledButton.icon(
            key: const Key('manageStudentCv'),
            onPressed: onManage,
            icon: const Icon(Icons.upload_file_outlined, size: 17),
            label: Text(cvUrl == null ? 'Tải lên CV' : 'Quản lý CV'),
          ),
        ),
      ],
    ),
  );
}

class ProfileCvActions extends StatelessWidget {
  const ProfileCvActions({
    super.key,
    required this.cvUrl,
    required this.action,
    required this.viewKey,
    this.enabled = true,
  });
  final String? cvUrl;
  final Widget action;
  final String viewKey;
  final bool enabled;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final view = CvViewButton(
        key: Key(viewKey),
        cvUrl: cvUrl,
        enabled: enabled,
      );
      if (constraints.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.2) {
        return Row(
          children: [
            Expanded(child: view),
            const SizedBox(width: 10),
            Expanded(child: action),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [view, const SizedBox(height: 8), action],
      );
    },
  );
}
