import 'package:flutter/material.dart';

class AppColors {
  // App Background Gradient - Dark cinematic
  static const Color darkBg = Color(0xFF080B12); // rgb(8, 11, 18)
  static const Color darkBgSecondary = Color(0xFF0F141E); // rgb(15, 20, 30)

  // Light Theme Colors
  static const Color lightBg = Color(0xFFDBE9F4); // rgb(219, 233, 244)
  static const Color lightBgSecondary = Color(0xFFFFFFFF);

  // Core Theme Brand Colors
  static const Color primaryBlue = Color(0xFF2563EB); // rgb(37, 99, 235)
  static const Color primaryBlueHover = Color(0xFF1D4ED8); // rgb(29, 78, 216)
  static const Color successGreen = Color(0xFF10B981); // rgb(16, 185, 129)
  static const Color dangerRed = Color(0xFFEF4444); // rgb(239, 68, 68)
  static const Color warningAmber = Color(0xFFF59E0B); // rgb(245, 158, 11)
  static const Color infoCyan = Color(0xFF06B6D4); // rgb(6, 182, 212)

  // Dark Mode Text
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFCBD5E1); // rgb(203, 213, 225)
  static const Color textMutedDark = Color(0xFF475569); // rgb(71, 85, 105)

  // Light Mode Text
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF334155);
  static const Color textMutedLight = Color(0xFF64748B);

  // Gradient Colors
  static const Color tealFrom = Color(0xFF064E3B);
  static const Color tealTo = Color(0xFF0F172A);

  // Cinematic background glows (matching desktop CSS)
  static const Color blueGlow = Color(0x2E2563EB); // rgba(37,99,235,0.18)
  static const Color blueGlowSecondary = Color(0x1F2563EB); // rgba(37,99,235,0.12)
  static const Color tealGlow = Color(0x0F0F766E); // rgba(15,118,110,0.06)

  // Transparent/Glass Border Colors
  static const Color borderLight = Color(0x2EFFFFFF); // 0.18 alpha for light
  static const Color borderDark = Color(0x14FFFFFF); // 0.08 alpha for dark

  // Sidebar Background (for status tabs)
  static const Color sidebarBgDark = Color(0xFF05080C);
}
