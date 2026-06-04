import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/components/glass_card.dart';
import '../../shared/providers/connection_provider.dart';

class PosScannerScreen extends ConsumerStatefulWidget {
  const PosScannerScreen({super.key});

  @override
  ConsumerState<PosScannerScreen> createState() => _PosScannerScreenState();
}

class _PosScannerScreenState extends ConsumerState<PosScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.all],
  );
  bool _isLocked = false;
  DateTime? _lockUntil;

  void _onDetect(BarcodeCapture capture) {
    if (_isLocked) return;

    final now = DateTime.now();
    if (_lockUntil != null && now.isBefore(_lockUntil!)) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final barcode = barcodes.first.rawValue!;
      
      setState(() {
        _isLocked = true;
        _lockUntil = now.add(const Duration(milliseconds: 1500));
      });

      ref.read(connectionProvider.notifier).sendBarcode(barcode);

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isLocked = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectionProvider.select((s) => s.lastScannedProduct), (prev, next) {
      if (next != null && (prev == null || next['timestamp'] != prev['timestamp'])) {
        if (!next['found']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "خطأ: لم يتم التعرف على المنتج بالباركود: ${next['barcode']}",
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    final connectionState = ref.watch(connectionProvider);
    final lastProduct = connectionState.lastScannedProduct;

    return Scaffold(
      appBar: AppBar(
        title: const Text("مسح باركود الرف للـ POS"),
        actions: [
          IconButton(
            onPressed: () => _scannerController.toggleTorch(),
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off_rounded, color: AppColors.textSecondaryDark);
                  case TorchState.on:
                    return const Icon(Icons.flash_on_rounded, color: AppColors.warningAmber);
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto, color: AppColors.textSecondaryDark);
                  case TorchState.unavailable:
                    return const Icon(Icons.flash_off_rounded, color: AppColors.textMutedDark);
                }
              },
            ),
          ),
          IconButton(
            onPressed: () => _scannerController.switchCamera(),
            icon: const Icon(Icons.flip_camera_ios_rounded, color: AppColors.textSecondaryDark),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(color: AppColors.darkBg),

          Column(
            children: [
              // 1. Camera Viewport (60% height)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isLocked 
                            ? AppColors.successGreen.withValues(alpha: 0.5) 
                            : AppColors.primaryBlue.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                        ),
                        // Scanner overlay frame
                        Center(
                          child: Container(
                            width: 260,
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isLocked ? AppColors.successGreen : AppColors.primaryBlue,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        // Lock overlay
                        if (_isLocked)
                          Container(
                            color: Colors.black.withValues(alpha: 0.4),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 64, color: AppColors.successGreen),
                                  SizedBox(height: 10),
                                  Text(
                                    "تم الإرسال للـ POS...",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Info details card (40% height)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "آخر عملية مسح:",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Status Info Card wrapped in GlassCard
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: lastProduct == null
                              ? const Center(
                                  child: Text(
                                    "وجه الكاميرا نحو باركود المنتج للمسح",
                                    style: TextStyle(color: AppColors.textMutedDark),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              "باركود: ",
                                              style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text(
                                              "${lastProduct['barcode']}",
                                              style: AppTheme.monospaceNumbers.copyWith(
                                                color: AppColors.textPrimaryDark,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: lastProduct['found'] 
                                                ? AppColors.successGreen.withValues(alpha: 0.1)
                                                : AppColors.warningAmber.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: lastProduct['found'] 
                                                  ? AppColors.successGreen.withValues(alpha: 0.2)
                                                  : AppColors.warningAmber.withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Text(
                                            lastProduct['found'] ? "موجود بالـ ERP" : "منتج غير مسجل",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: lastProduct['found'] 
                                                  ? AppColors.successGreen 
                                                  : AppColors.warningAmber,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(color: AppColors.borderDark, height: 20),
                                    Text(
                                      lastProduct['name'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (lastProduct['found']) ...[
                                      Row(
                                        children: [
                                          const Text("السعر: ", style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
                                          Text(
                                            "${lastProduct['price'] ?? 0}",
                                            style: AppTheme.monospaceNumbers.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const Text(" د.ج  |  الكمية: ", style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
                                          Text(
                                            "${lastProduct['quantity'] ?? 0}",
                                            style: AppTheme.monospaceNumbers.copyWith(color: AppColors.textSecondaryDark, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      const Text(
                                        "يمكنك تسجيل هذا المنتج من شاشة إثراء البيانات",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMutedDark,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
