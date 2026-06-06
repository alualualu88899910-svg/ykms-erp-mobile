import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/components/cinematic_background.dart';
import '../../shared/components/glass_card.dart';
import '../../shared/components/glass_button.dart';
import '../../shared/components/glass_text_field.dart';
import '../../shared/providers/connection_provider.dart';

class ConnectionSetupScreen extends ConsumerStatefulWidget {
  const ConnectionSetupScreen({super.key});

  @override
  ConsumerState<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends ConsumerState<ConnectionSetupScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _isScanningQr = false;
  String? _localError;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _onScanSuccess(String scannedValue) {
    setState(() {
      _isScanningQr = false;
      _localError = null;
    });

    String ip = scannedValue.trim();
    if (ip.contains("://")) {
      final uri = Uri.tryParse(ip);
      if (uri != null && uri.host.isNotEmpty) {
        ip = uri.host;
      }
    } else if (ip.contains(":")) {
      ip = ip.split(":").first;
    }

    _ipController.text = ip;
    _handleConnect(ip);
  }

  Future<void> _handleConnect(String ip) async {
    String cleanIp = ip.trim();
    
    if (cleanIp.contains("://")) {
      final uri = Uri.tryParse(cleanIp);
      if (uri != null && uri.host.isNotEmpty) {
        cleanIp = uri.host;
      }
    }
    
    if (cleanIp.contains(":")) {
      cleanIp = cleanIp.split(":").first;
    }

    if (cleanIp.isEmpty) {
      setState(() {
        _localError = "الرجاء إدخال عنوان IP صحيح";
      });
      return;
    }

    setState(() {
      _localError = null;
    });

    final success = await ref.read(connectionProvider.notifier).connect(cleanIp);
    if (!success && mounted) {
      final connState = ref.read(connectionProvider);
      setState(() {
        _localError = connState.error ?? "فشل الاتصال بالخادم. تأكد من تشغيل الـ ERP على نفس الشبكة.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final isConnecting = connectionState.status == ConnectionStatus.connecting;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      body: Stack(
        children: [
          const CinematicBackground(),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Hero(
                      tag: 'logo',
                      child: Image.asset(
                        'assets/logo.png',
                        width: 80,
                        height: 80,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.business_rounded,
                          size: 80,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "YKMS ERP",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: primaryTextColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "مساعد قطع الغيار وربط الـ ERP المحلي",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 48),

                    if (_isScanningQr) ...[
                      // QR Code scanner view wrapped in GlassCard
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                          height: 280,
                          child: MobileScanner(
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                                _onScanSuccess(barcodes.first.rawValue!);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassButton(
                        onPressed: () {
                          setState(() {
                            _isScanningQr = false;
                          });
                        },
                        label: "إلغاء مسح الكود",
                        color: AppColors.dangerRed,
                        isOutlined: true,
                        icon: Icons.close_rounded,
                      ),
                    ] else ...[
                      // Manual IP Form / QR Button inside GlassCard
                      GlassCard(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GlassButton(
                              onPressed: () {
                                setState(() {
                                    _isScanningQr = true;
                                });
                              },
                              icon: Icons.qr_code_scanner_rounded,
                              label: "مسح رمز QR من شاشة الـ ERP",
                              color: AppColors.primaryBlue,
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: Row(
                                children: [
                                  Expanded(child: Divider(color: isDark ? AppColors.borderDark : Colors.black.withValues(alpha: 0.12))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Text(
                                      "أو أدخل العنوان يدوياً", 
                                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: isDark ? AppColors.borderDark : Colors.black.withValues(alpha: 0.12))),
                                ],
                              ),
                            ),

                            // Auto discovery status indicator
                            if (connectionState.status == ConnectionStatus.disconnected) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "جاري البحث عن السيرفر تلقائياً في الشبكة...",
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // IP Text field
                            GlassTextField(
                              controller: _ipController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              hintText: "192.168.1.100",
                              labelText: "عنوان IP خادم الـ ERP",
                              prefixIcon: const Icon(Icons.computer_rounded, color: AppColors.primaryBlue),
                              isMonospace: true,
                            ),
                            const SizedBox(height: 20),

                            // Submit Button
                            GlassButton(
                              onPressed: isConnecting ? null : () => _handleConnect(_ipController.text),
                              isLoading: isConnecting,
                              color: AppColors.successGreen,
                              label: "اتصـــــال",
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Error messages display
                    if (_localError != null || connectionState.error != null) ...[
                      const SizedBox(height: 20),
                      GlassCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 8,
                        child: Text(
                          _localError ?? connectionState.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.dangerRed, 
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    // Hint / Info
                    Text(
                      "ملاحظة: يجب أن يكون هاتفك وجهاز الكمبيوتر متصلين على نفس شبكة الـ Wi-Fi أو نقطة الاتصال.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: secondaryTextColor.withValues(alpha: 0.6), 
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
