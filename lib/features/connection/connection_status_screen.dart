import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/components/cinematic_background.dart';
import '../../shared/components/glass_card.dart';
import '../../shared/components/glass_button.dart';
import '../../shared/providers/connection_provider.dart';

class ConnectionStatusScreen extends ConsumerWidget {
  const ConnectionStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionProvider);
    final isConnected = connectionState.status == ConnectionStatus.connected;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text("حالة الاتصال بالشبكة"),
      ),
      body: Stack(
        children: [
          const CinematicBackground(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Connection status card wrapped in GlassCard
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          size: 64,
                          color: isConnected ? AppColors.successGreen : AppColors.dangerRed,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isConnected ? "متصل بخادم ERP" : "غير متصل بالخادم",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isConnected 
                              ? "خادم: ${connectionState.serverName} | عنوان: ${connectionState.ipAddress}"
                              : "لم يتم التوصيل بعد أو انقطع الاتصال",
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  Text(
                    "إحصائيات الجلسة الحالية",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Statistics cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          context,
                          title: "باركود مرسل",
                          count: connectionState.barcodesSent,
                          icon: Icons.qr_code_scanner_rounded,
                          color: AppColors.primaryBlue,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          title: "صور مرفوعة",
                          count: connectionState.imagesSent,
                          icon: Icons.add_photo_alternate_rounded,
                          color: AppColors.successGreen,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatItem(
                    context,
                    title: "فواتير مرسلة ومستخرجة بـ AI",
                    count: connectionState.invoicesSent,
                    icon: Icons.document_scanner_rounded,
                    color: AppColors.warningAmber,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                  ),

                  const Spacer(),

                  // Action Buttons
                  GlassButton(
                    onPressed: () {
                      ref.read(connectionProvider.notifier).disconnect();
                      Navigator.of(context).pop();
                    },
                    color: AppColors.dangerRed,
                    label: "قطع الاتصال بالكمبيوتر",
                    icon: Icons.power_settings_new_rounded,
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    color: AppColors.primaryBlue,
                    isOutlined: true,
                    label: "العودة للرئيسية",
                    icon: Icons.arrow_back_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  "$count",
                  style: AppTheme.monospaceNumbers.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
