import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/app/theme/app_text_styles.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.only(top: 60),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2475EF), Color(0xFF00B2CC)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TIP',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  'CAREER PATH',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: Color(0xFF2475EF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text(
        'Khám phá cơ hội thực tập & việc làm\nbứt phá dành cho sinh viên',
        style: AppTextStyles.body,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
    ],
  );
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.form,
    required this.footer,
  });
  final String title;
  final Widget form;
  final Widget footer;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F7FF), Color(0xFFF8F7FF)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    AuthHeader(title: title),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12092A78),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: form,
                    ),
                    const SizedBox(height: 16),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthMessage extends StatelessWidget {
  const AuthMessage({super.key, required this.message, this.error = true});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? const Color(0xFFFFF0F0) : const Color(0xFFEAF7FC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: TextStyle(
            height: 1.5,
            color: error ? const Color(0xFF9B2631) : AppColors.accent,
          ),
        ),
      ),
    ),
  );
}
