import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/components/glass_card.dart';

class InventoryCountScannerScreen extends StatefulWidget {
  const InventoryCountScannerScreen({super.key});

  @override
  State<InventoryCountScannerScreen> createState() => _InventoryCountScannerScreenState();
}

class _InventoryCountScannerScreenState extends State<InventoryCountScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.all],
  );
  bool _hasPopped = false;

  void _onDetect(BarcodeCapture capture) {
    if (_hasPopped) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final barcode = barcodes.first.rawValue!;
      
      setState(() {
        _hasPopped = true;
      });

      Navigator.of(context).pop(barcode);
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مسح باركود الرف لجرد المادة"),
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
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Scanner Overlay Frame
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primaryBlue,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 10,
                    right: 10,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom prompt wrapped in GlassCard
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Text(
                "وجه الكاميرا نحو رمز الباركود للمنتج. سيتم قراءة الرمز تلقائياً للتحقق من وجود المادة بالجرد.",
                style: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 12,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
