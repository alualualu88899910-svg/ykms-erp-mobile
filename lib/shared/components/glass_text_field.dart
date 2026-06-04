import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final TextDirection? textDirection;
  final ValueChanged<String>? onSubmitted;
  final bool isMonospace;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  const GlassTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.maxLines = 1,
    this.textDirection,
    this.onSubmitted,
    this.isMonospace = false,
    this.textInputAction,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      maxLines: maxLines,
      textDirection: textDirection,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      focusNode: focusNode,
      style: TextStyle(
        color: textColor,
        fontFamily: isMonospace ? 'monospace' : 'Cairo',
        fontSize: isMonospace ? 13 : 14,
        letterSpacing: isMonospace ? 1.2 : null,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        hintTextDirection: textDirection,
      ),
    );
  }
}
