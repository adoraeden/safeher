import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Surfaces (dark, matched to the AI Studio reference)
  static const Color background = Color(0xFF020617); // slate-950
  static const Color surface = Color(0xFF0F172A); // slate-900
  static const Color surfaceElevated = Color(0xFF1E293B); // slate-800
  static const Color border = Color(0xFF1E293B); // slate-800
  static const Color borderStrong = Color(0xFF334155); // slate-700

  // Text
  static const Color textPrimary = Color(0xFFF1F5F9); // slate-100
  static const Color textSecondary = Color(0xFF94A3B8); // slate-400

  // Brand
  static const Color primary = Color(0xFF2563EB); // blue-600
  static const Color primaryLight = Color(0xFF3B82F6); // blue-500
  static const Color accent = Color(
    0xFF4F46E5,
  ); // indigo-600, gradient endpoint

  // Semantic
  static const Color danger = Color(0xFFDC2626); // red-600 — SOS only
  static const Color dangerLight = Color(0xFFEF4444); // red-500
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
}
