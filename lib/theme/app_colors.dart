import 'package:flutter/material.dart';

/// Brand palette — matches the app icon (assets/icon/app_icon.png) and the
/// old PHP app's inline CSS ("Primary Blue #1e3a8a, Cyan/Accent #06b6d4"),
/// carried forward so the new app still feels like the same product.
class AppColors {
  AppColors._();

  static const primaryBlue = Color(0xFF1E3A8A);
  static const accentCyan = Color(0xFF06B6D4);
  static const accentGold = Color(0xFFFBBF24);

  // Semantic status colors used across payments/students (paid/overdue/
  // partial/pending) — kept in one place so every screen agrees on what
  // "overdue" looks like.
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const neutral = Color(0xFF64748B);

  static const surfaceTint = Color(0xFFF4F6FB);
}
