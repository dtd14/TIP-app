import 'package:flutter/material.dart';

class LogoutConfirmationDialog extends StatelessWidget {
  const LogoutConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('logoutConfirmation'),
    title: const Text('Xác nhận đăng xuất', textAlign: TextAlign.center),
    content: const Text(
      'Đăng xuất khỏi tài khoản này?',
      textAlign: TextAlign.center,
    ),
    actions: [
      Row(
        children: [
          Expanded(
            child: TextButton(
              key: const Key('cancelLogout'),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const Key('confirmLogout'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Đăng xuất', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    ],
  );
}
