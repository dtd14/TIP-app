import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';

class ApplicationWithdrawalSheet extends StatelessWidget {
  const ApplicationWithdrawalSheet({
    super.key,
    required this.title,
    required this.company,
  });
  final String title, company;
  static const _danger = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE3E3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _danger,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rút đơn ứng tuyển?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Thao tác này không thể hoàn tác.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Bạn có chắc muốn rút đơn ứng tuyển vị trí ',
                      ),
                      TextSpan(
                        text: title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const TextSpan(text: ' tại '),
                      TextSpan(
                        text: company,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Đơn đã rút vẫn được lưu trong lịch sử. Bạn không thể nộp lại cùng cơ hội.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final keep = TextButton(
                key: const Key('keepApplication'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: const Color(0xFFE4EDFF),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Không, giữ lại đơn',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              );
              final withdraw = FilledButton(
                key: const Key('confirmWithdrawApplication'),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _danger,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Xác nhận rút',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [keep, const SizedBox(height: 10), withdraw],
                );
              }
              return Row(
                children: [
                  Expanded(child: keep),
                  const SizedBox(width: 10),
                  Expanded(child: withdraw),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
