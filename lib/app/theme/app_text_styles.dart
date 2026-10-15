import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';

abstract final class AppTextStyles {
  static const title = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.muted,
  );
}
