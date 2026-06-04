import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CinematicBackground extends StatefulWidget {
  final Widget? child;
  const CinematicBackground({super.key, this.child});

  @override
  State<CinematicBackground> createState() => _CinematicBackgroundState();
}

class _CinematicBackgroundState extends State<CinematicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _CinematicPainter(_controller.value, isDark),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _CinematicPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;
  _CinematicPainter(this.animationValue, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final baseRect = Offset.zero & size;
    
    if (isDark) {
      // 1. Draw base linear gradient (Dark Mode)
      final baseGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0A0D14),
          AppColors.darkBg,
          Color(0xFF0C1120),
          Color(0xFF08111E),
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
      );
      final paint = Paint()..shader = baseGradient.createShader(baseRect);
      canvas.drawRect(baseRect, paint);

      // Pulse factor (0.92 to 1.08)
      final double pulse = 1.0 + (math.sin(animationValue * math.pi * 2) * 0.08);
      // Opacity factor (0.4 to 1.0)
      final double opacityFactor = 0.7 + (math.cos(animationValue * math.pi * 2) * 0.3);

      // 2. Top-Left Blue Glow Orb (similar to desktop rgba(37,99,235,0.18))
      final topLeftGlow = RadialGradient(
        center: Alignment.topLeft,
        radius: pulse * 0.8,
        colors: [
          AppColors.blueGlow.withValues(alpha: AppColors.blueGlow.a * opacityFactor),
          Colors.transparent,
        ],
      );
      final topLeftPaint = Paint()..shader = topLeftGlow.createShader(baseRect);
      canvas.drawRect(baseRect, topLeftPaint);

      // 3. Bottom-Right Blue Glow Orb (rgba(37,99,235,0.12))
      final bottomRightGlow = RadialGradient(
        center: const Alignment(0.85, 0.9),
        radius: pulse * 0.75,
        colors: [
          AppColors.blueGlowSecondary.withValues(alpha: AppColors.blueGlowSecondary.a * opacityFactor),
          Colors.transparent,
        ],
      );
      final bottomRightPaint = Paint()..shader = bottomRightGlow.createShader(baseRect);
      canvas.drawRect(baseRect, bottomRightPaint);

      // 4. Center-ish Teal Glow Orb (rgba(15,118,110,0.06))
      final centerTealGlow = RadialGradient(
        center: const Alignment(-0.2, 0.15),
        radius: pulse * 0.9,
        colors: [
          AppColors.tealGlow.withValues(alpha: AppColors.tealGlow.a * (1.4 - opacityFactor)),
          Colors.transparent,
        ],
      );
      final centerTealPaint = Paint()..shader = centerTealGlow.createShader(baseRect);
      canvas.drawRect(baseRect, centerTealPaint);
    } else {
      // 1. Draw base linear gradient (Light Mode matching desktop theme variables)
      final baseGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFDBE9F4),
          Color(0xFFC8DDF2),
          Color(0xFFB8D0EA),
        ],
        stops: [0.0, 0.5, 1.0],
      );
      final paint = Paint()..shader = baseGradient.createShader(baseRect);
      canvas.drawRect(baseRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CinematicPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isDark != isDark;
  }
}
