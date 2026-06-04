import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/http_service.dart';
import '../../shared/components/cinematic_background.dart';
import '../../shared/components/glass_card.dart';
import '../../shared/components/glass_button.dart';

class ProductEnrichmentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;

  const ProductEnrichmentScreen({super.key, required this.product});

  @override
  ConsumerState<ProductEnrichmentScreen> createState() => _ProductEnrichmentScreenState();
}

class _ProductEnrichmentScreenState extends ConsumerState<ProductEnrichmentScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  XFile? _compressedImageFile;
  Uint8List? _imageBytes;
  Uint8List? _compressedImageBytes;
  bool _isCompressing = false;
  bool _isUploading = false;
  bool _isPrimaryImage = true;
  bool _isScanningBarcode = false;
  bool _isLinkingBarcode = false;
  String? _statusMessage;
  String? _errorMessage;

  int _originalSize = 0;
  int _compressedSize = 0;

  Future<void> _captureImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final originalBytes = bytes.length;

      setState(() {
        _imageFile = pickedFile;
        _imageBytes = bytes;
        _originalSize = originalBytes;
      });

      if (kIsWeb) {
        setState(() {
          _compressedImageFile = pickedFile;
          _compressedImageBytes = bytes;
          _compressedSize = originalBytes;
          _isCompressing = false;
        });
        return;
      }

      setState(() {
        _isCompressing = true;
      });

      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        targetPath,
        quality: 80,
        minWidth: 800,
        minHeight: 800,
      );

      if (compressed != null) {
        final compressedBytes = await compressed.length();
        final compBytes = await compressed.readAsBytes();

        setState(() {
          _compressedImageFile = compressed;
          _compressedImageBytes = compBytes;
          _compressedSize = compressedBytes;
          _isCompressing = false;
        });
      } else {
        setState(() {
          _compressedImageFile = pickedFile;
          _compressedImageBytes = bytes;
          _compressedSize = originalBytes;
          _isCompressing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "خطأ أثناء التقاط أو ضغط الصورة: $e";
        _isCompressing = false;
      });
    }
  }

  Future<void> _uploadImage() async {
    final uploadFile = _compressedImageFile ?? _imageFile;
    if (uploadFile == null) {
      setState(() {
        _errorMessage = "الرجاء التقاط صورة أولاً";
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _statusMessage = "جاري رفع الصورة إلى الخادم...";
    });

    try {
      final productId = widget.product['id'] as int;
      final success = await ref.read(httpServiceProvider).uploadProductImage(
            productId,
            uploadFile,
            isPrimary: _isPrimaryImage,
          );

      if (success) {
        setState(() {
          _statusMessage = "تم رفع الصورة وحفظها بنجاح! ✅";
          _imageFile = null;
          _imageBytes = null;
          _compressedImageFile = null;
          _compressedImageBytes = null;
        });
      } else {
        setState(() {
          _errorMessage = "فشل في رفع الصورة. تأكد من اتصالك بالخادم.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "حدث خطأ أثناء الرفع: $e";
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final barcode = barcodes.first.rawValue!;
      setState(() {
        _isScanningBarcode = false;
      });
      _linkBarcode(barcode);
    }
  }

  Future<void> _linkBarcode(String barcode) async {
    setState(() {
      _isLinkingBarcode = true;
      _errorMessage = null;
      _statusMessage = "جاري ربط الباركود الجديد بالمنتج...";
    });

    try {
      final productId = widget.product['id'] as int;
      final success = await ref.read(httpServiceProvider).linkBarcode(productId, barcode);

      if (success) {
        setState(() {
          _statusMessage = "تم ربط الباركود الجديد ($barcode) بنجاح! ✅";
        });
      } else {
        setState(() {
          _errorMessage = "فشل ربط الباركود. تأكد من اتصالك بالخادم.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "حدث خطأ أثناء ربط الباركود: $e";
      });
    } finally {
      setState(() {
        _isLinkingBarcode = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final String currentBarcode = product['barcode']?.toString() ?? 'غير متوفر';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(product['name']),
      ),
      body: Stack(
        children: [
          const CinematicBackground(),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product Info Card
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "باركود: ",
                                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                                ),
                                Text(
                                  currentBarcode,
                                  style: AppTheme.monospaceNumbers.copyWith(color: secondaryTextColor, fontSize: 13),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  "المخزون: ",
                                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                                ),
                                Text(
                                  "${product['quantity']}",
                                  style: AppTheme.monospaceNumbers.copyWith(color: secondaryTextColor, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              "السعر: ",
                              style: TextStyle(color: secondaryTextColor, fontSize: 13),
                            ),
                            Text(
                              "${product['price']}",
                              style: AppTheme.monospaceNumbers.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              " د.ج",
                              style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Image picker / preview area
                  Text(
                    "إضافة صور للمنتج:",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_imageFile == null)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 48, color: mutedTextColor),
                          const SizedBox(height: 12),
                          Text(
                            "التقط صورة للمنتج لإرسالها للـ ERP", 
                            style: TextStyle(color: mutedTextColor, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _captureImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_rounded),
                                label: const Text("كاميرا"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => _captureImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_rounded),
                                label: const Text("المعرض"),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: isDark ? AppColors.borderLight : Colors.black.withValues(alpha: 0.18)),
                                  foregroundColor: secondaryTextColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _compressedImageBytes ?? _imageBytes!,
                              height: 220,
                              width: double.infinity,
                              fit: p.extension(_compressedImageFile?.name ?? _imageFile!.name).toLowerCase() == '.heic'
                                  ? BoxFit.contain
                                  : BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Compression Info Bar
                          if (_isCompressing)
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.successGreen),
                                ),
                                SizedBox(width: 10),
                                Text("جاري ضغط الصورة...", style: TextStyle(color: AppColors.successGreen, fontSize: 13)),
                              ],
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text("الحجم الأصلي: ", style: TextStyle(fontSize: 11, color: mutedTextColor)),
                                      Text(_formatSize(_originalSize), style: AppTheme.monospaceNumbers.copyWith(fontSize: 12, color: mutedTextColor)),
                                    ],
                                  ),
                                  const Icon(Icons.arrow_forward_rounded, color: AppColors.successGreen, size: 16),
                                  Row(
                                    children: [
                                      const Text("الحجم المضغوط: ", style: TextStyle(fontSize: 11, color: AppColors.successGreen)),
                                      Text(_formatSize(_compressedSize), style: AppTheme.monospaceNumbers.copyWith(fontSize: 12, color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          Divider(color: isDark ? AppColors.borderDark : Colors.black.withValues(alpha: 0.12), height: 24),
                          
                          // Primary photo configuration
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _isPrimaryImage,
                                  onChanged: (val) {
                                    setState(() {
                                      _isPrimaryImage = val ?? true;
                                    });
                                  },
                                  activeColor: AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "تعيين كصورة رئيسية للمنتج في الـ ERP", 
                                style: TextStyle(color: secondaryTextColor, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Action Upload / Reset Buttons
                          Row(
                            children: [
                              Expanded(
                                child: GlassButton(
                                  onPressed: _isUploading || _isCompressing ? null : _uploadImage,
                                  icon: Icons.cloud_upload_rounded,
                                  label: "رفع الصورة للـ ERP",
                                  color: AppColors.successGreen,
                                  isLoading: _isUploading,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: _isUploading ? null : () {
                                  setState(() {
                                    _imageFile = null;
                                    _imageBytes = null;
                                    _compressedImageFile = null;
                                    _compressedImageBytes = null;
                                  });
                                },
                                icon: const Icon(Icons.delete_rounded, color: AppColors.dangerRed),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.dangerRed.withValues(alpha: 0.1),
                                  padding: const EdgeInsets.all(12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Link Alternative Barcode Section
                  Text(
                    "ربط باركود بديل:",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isScanningBarcode) ...[
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        height: 180,
                        child: Stack(
                          children: [
                            MobileScanner(
                              onDetect: _onBarcodeDetected,
                            ),
                            Center(
                              child: Container(
                                width: 220,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primaryBlue, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      onPressed: () {
                        setState(() {
                          _isScanningBarcode = false;
                        });
                      },
                      label: "إلغاء مسح الباركود",
                      color: AppColors.dangerRed,
                      isOutlined: true,
                      icon: Icons.close_rounded,
                    ),
                  ] else ...[
                    GlassButton(
                      onPressed: _isLinkingBarcode ? null : () {
                        setState(() {
                          _isScanningBarcode = true;
                        });
                      },
                      icon: Icons.qr_code_scanner_rounded,
                      label: "امسح باركود جديد لربطه بالمنتج",
                      color: AppColors.primaryBlue,
                      isLoading: _isLinkingBarcode,
                    ),
                  ],

                  // Messages Info Overlay
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 20),
                    GlassCard(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 8,
                      child: Text(
                        _statusMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.successGreen, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    GlassCard(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 8,
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.dangerRed, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
