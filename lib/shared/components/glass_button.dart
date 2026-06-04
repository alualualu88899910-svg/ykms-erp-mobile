import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool isOutlined;
  final bool isLoading;
  final double height;
  final double borderRadius;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.primaryBlue,
    this.isOutlined = false,
    this.isLoading = false,
    this.height = 48,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    if (isOutlined) {
      return Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 1.2,
            ),
            color: color.withValues(alpha: 0.08),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEnabled ? onPressed : null,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Center(
                child: _buildChild(color),
              ),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.8),
            ],
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Center(
              child: _buildChild(Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(Color textColor) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    final TextStyle textStyle = TextStyle(
      color: textColor,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      fontFamily: 'Cairo',
    );

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(label, style: textStyle),
        ],
      );
    }

    return Text(label, style: textStyle);
  }
}
