import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/http_service.dart';
import '../../shared/components/cinematic_background.dart';
import '../../shared/components/glass_card.dart';
import '../../shared/components/glass_button.dart';
import '../../shared/components/glass_text_field.dart';
import '../../shared/providers/connection_provider.dart';

class SmartInvoiceAssistantScreen extends ConsumerStatefulWidget {
  const SmartInvoiceAssistantScreen({super.key});

  @override
  ConsumerState<SmartInvoiceAssistantScreen> createState() => _SmartInvoiceAssistantScreenState();
}

class _SmartInvoiceAssistantScreenState extends ConsumerState<SmartInvoiceAssistantScreen> {
  // Tab 1 (Photo Capture) variables
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  XFile? _compressedImageFile;
  Uint8List? _imageBytes;
  Uint8List? _compressedImageBytes;
  bool _isCompressing = false;
  bool _isUploading = false;
  String? _photoStatusMessage;
  String? _photoErrorMessage;
  int _originalSize = 0;
  int _compressedSize = 0;

  // Tab 2 (AI Import) variables
  final TextEditingController _jsonController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _aiStatusMessage;
  String? _aiErrorMessage;

  static const String _promptText = '''Please analyze the attached invoice image carefully. Your task is to extract all the details and output them strictly in JSON format. Do not include any conversational explanation, prefaces, or markdown code block formatting (such as ```json ... ```). The output must be pure raw JSON conforming to the schema below.

Here is the JSON schema to output:
{
  "supplier_name": "Name of the supplier/seller as written on the invoice (e.g., 'SARL PIECES AUTO')",
  "supplier_phone": "Phone number(s) of the supplier if printed on the invoice, otherwise null",
  "supplier_address": "Address/Location of the supplier if printed on the invoice, otherwise null",
  "invoice_number": "Invoice number or reference number as printed (e.g., 'BR 05108/2026')",
  "paid_amount": 85000.00, // The amount paid / Montant Versement as printed on the invoice, otherwise null
  "due_amount": 0.00, // The remaining balance / Reste à Payer as printed on the invoice, otherwise null
  "discount": 50.00, // Total discount or remise as printed on the invoice, otherwise null
  "items": [
    {
      "index": 1,
      "original_name": "Product name exactly as written in French or English on the invoice (e.g., 'FILTRE HUILE PEUGEOT 206')",
      "translated_name_ar": "Translate the core spare part name into a clear, customer-friendly Arabic name for receipts (e.g., 'فلتر زيت بيجو 206'), otherwise null if it cannot be translated accurately",
      "sku": "Part number, OEM code, barcode, or reference code if visible, otherwise null (strict rule: do not invent values, do not put product name or category here, leave null if not found)",
      "qty": 10,
      "purchase_price": 350.00,
      "category_suggestion": "The category classification suggested for this item in English (choose from: Filters, Brakes, Oils, Suspension, Electrical, Cooling, Engine, Clutch, Belts, Steering, Body, Transmission, Exhaust)",
      "unit_suggestion": "The unit of measurement suggested (choose from: Piece, Litre, Box)",
      "packaging": {
        "is_box": false, // Set to true if the item name, description, or row indicates it is bought in bulk/box/carton (e.g., 'Carton 12', 'Box 24', 'Pack 6')
        "box_size": 1, // If is_box is true, extract the number of pieces inside the box (e.g., 12 for 'Carton 12'). Otherwise, 1
        "box_name": "Name of the packaging unit (e.g., 'Carton', 'Box', 'Pack') or null"
      },
      "brand_suggestion": "Brand name suggestion of the spare part (e.g., Purflux, Brembo, Valeo, Bosch, Sachs, Monroe) if visible or inferred",
      "compatibility_suggestions": ["List of compatible car models suggested (e.g., Peugeot 206, Clio 3, Symbol, Renault Kangoo) inferred from the part description"],
      "needs_review": false // Set to true if the item description is blurry/illegible, prices are ambiguous, or you are highly uncertain about its details
    }
  ]
}

Strict Rules:
1. Output ONLY a valid JSON object. Do not wrap it in markdown code blocks.
2. If buying price or quantity is missing, use 0 for price and 1 for quantity.
3. If no barcode, OEM reference, or SKU is found on the row, set "sku" to null.
4. Extract the product names exactly as written in French, preserving all letters, numbers, and specifications.
5. Pay close attention to packaging keywords (Carton, Box, Pack, Lot) to extract packaging information accurately. If unsure, set "needs_review" to true.''';

  Future<void> _captureInvoice(ImageSource source) async {
    setState(() {
      _photoErrorMessage = null;
      _photoStatusMessage = null;
    });

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
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
        'invoice_comp_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        targetPath,
        quality: 85,
        minWidth: 1000,
        minHeight: 1000,
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
        _photoErrorMessage = "حدث خطأ أثناء التقاط أو ضغط الفاتورة: $e";
        _isCompressing = false;
      });
    }
  }

  Future<void> _uploadInvoice() async {
    final uploadFile = _compressedImageFile ?? _imageFile;
    if (uploadFile == null) {
      setState(() {
        _photoErrorMessage = "الرجاء تصوير الفاتورة أولاً";
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _photoErrorMessage = null;
      _photoStatusMessage = "جاري إرسال الفاتورة إلى خادم الـ ERP...";
    });

    try {
      final success = await ref.read(httpServiceProvider).uploadInvoiceImage(uploadFile);

      if (success) {
        setState(() {
          _photoStatusMessage = "تم إرسال الفاتورة للكمبيوتر بنجاح! 📄✅\nتظهر الآن نافذة المعالجة والـ Prompt تلقائياً على شاشة الـ ERP.";
          _imageFile = null;
          _imageBytes = null;
          _compressedImageFile = null;
          _compressedImageBytes = null;
        });
      } else {
        setState(() {
          _photoErrorMessage = "فشل في إرسال الفاتورة. تأكد من اتصالك بالخادم.";
        });
      }
    } catch (e) {
      setState(() {
        _photoErrorMessage = "حدث خطأ أثناء الرفع: $e";
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  void _copyPrompt() async {
    await Clipboard.setData(const ClipboardData(text: _promptText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم نسخ برومبت التحليل الذكي بنجاح! 📋", style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.successGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _jsonController.text = data.text!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم لصق النص من الحافظة 📋", style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.primaryBlue,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("الحافظة فارغة أو لا تحتوي على نص ⚠️", style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.warningAmber,
          ),
        );
      }
    }
  }

  void _sendJsonToComputer() {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _aiErrorMessage = "الرجاء لصق كود الـ JSON أو الرد أولاً";
        _aiStatusMessage = null;
      });
      return;
    }

    final connectionState = ref.read(connectionProvider);
    if (connectionState.status != ConnectionStatus.connected) {
      setState(() {
        _aiErrorMessage = "التطبيق غير متصل بالكمبيوتر حالياً ⚠️";
        _aiStatusMessage = null;
      });
      return;
    }

    setState(() {
      _aiErrorMessage = null;
      _aiStatusMessage = "جاري إرسال البيانات للكمبيوتر...";
    });

    final success = ref.read(connectionProvider.notifier).send({
      'type': 'IMPORT_INVOICE_JSON',
      'data': {
        'json': text,
      }
    });

    if (success) {
      ref.read(connectionProvider.notifier).incrementInvoicesSent();
      setState(() {
        _aiStatusMessage = "تم إرسال كود الفاتورة للكمبيوتر بنجاح! 📄🚀\nستفتح الآن فاتورة شراء جديدة تلقائياً وتُملأ بالمنتجات.";
        _jsonController.clear();
      });
    } else {
      setState(() {
        _aiErrorMessage = "فشل الإرسال. الرجاء التحقق من الاتصال بالشبكة المحلية.";
        _aiStatusMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final isConnected = connectionState.status == ConnectionStatus.connected;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("مساعد الفواتير الذكي (AI)"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.camera_alt_rounded), text: "تصوير الفاتورة"),
              Tab(icon: Icon(Icons.auto_awesome_rounded), text: "استيراد كود AI"),
            ],
          ),
        ),
        body: Stack(
          children: [
            const CinematicBackground(),
            TabBarView(
              children: [
                _buildPhotoCaptureTab(isConnected, isDark, primaryTextColor, secondaryTextColor, mutedTextColor),
                _buildAiImportTab(isConnected, isDark, primaryTextColor, secondaryTextColor, mutedTextColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCaptureTab(bool isConnected, bool isDark, Color primaryTextColor, Color secondaryTextColor, Color mutedTextColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.warningAmber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "تلميح: للحصول على أفضل نتائج بـ AI، تأكد من وضوح نصوص الفاتورة والأسعار، والتصوير تحت إضاءة جيدة.",
                    style: TextStyle(fontSize: 12, color: secondaryTextColor, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_imageFile == null)
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.document_scanner_rounded, size: 64, color: mutedTextColor),
                  const SizedBox(height: 16),
                  Text(
                    "صوّر فاتورة المورد الورقية لإرسالها للـ PC", 
                    style: TextStyle(color: mutedTextColor, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _captureInvoice(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text("الكاميرا"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warningAmber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _captureInvoice(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text("معرض الصور"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryTextColor,
                          side: BorderSide(color: isDark ? AppColors.borderLight : Colors.black.withValues(alpha: 0.18)),
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
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isCompressing)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warningAmber),
                        ),
                        SizedBox(width: 10),
                        Text("جاري ضغط الفاتورة...", style: TextStyle(color: AppColors.warningAmber, fontSize: 13)),
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
                          const Icon(Icons.arrow_forward_rounded, color: AppColors.warningAmber, size: 16),
                          Row(
                            children: [
                              const Text("الحجم المحسّن: ", style: TextStyle(fontSize: 11, color: AppColors.warningAmber)),
                              Text(_formatSize(_compressedSize), style: AppTheme.monospaceNumbers.copyWith(fontSize: 12, color: AppColors.warningAmber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Divider(color: isDark ? AppColors.borderDark : Colors.black.withValues(alpha: 0.12), height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          onPressed: _isUploading || _isCompressing || !isConnected ? null : _uploadInvoice,
                          icon: Icons.send_rounded,
                          label: "إرسال الصورة للكمبيوتر 🚀",
                          color: AppColors.warningAmber,
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
 
          if (!isConnected) ...[
            const SizedBox(height: 16),
            _buildConnectionWarning(),
          ],
 
          if (_photoStatusMessage != null) ...[
            const SizedBox(height: 24),
            _buildStatusOverlay(_photoStatusMessage!, true),
          ],
 
          if (_photoErrorMessage != null) ...[
            const SizedBox(height: 24),
            _buildStatusOverlay(_photoErrorMessage!, false),
          ],
        ],
      ),
    );
  }

  Widget _buildAiImportTab(bool isConnected, bool isDark, Color primaryTextColor, Color secondaryTextColor, Color mutedTextColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step 1
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.looks_one_rounded, color: AppColors.primaryBlue, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "الخطوة 1: نسخ البرومبت المطور",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "انسخ البرومبت أدناه، ثم ارفع صورة الفاتورة في تطبيقات الذكاء الاصطناعي (ChatGPT, Gemini, Claude, DeepSeek) والصق البرومبت ليقوم بتحليل الفاتورة وإرجاع كود JSON.",
                  style: TextStyle(fontSize: 12, color: secondaryTextColor, height: 1.5),
                ),
                const SizedBox(height: 16),
                GlassButton(
                  onPressed: _copyPrompt,
                  icon: Icons.copy_rounded,
                  label: "نسخ برومبت التحليل الذكي",
                  color: AppColors.primaryBlue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Step 2
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.looks_two_rounded, color: AppColors.warningAmber, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "الخطوة 2: لصق كود الـ JSON المسترجع",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "بعد انتهاء الذكاء الاصطناعي من تحليل الفاتورة وإعطائك كود الـ JSON، انسخه من هناك والصقه في الصندوق أدناه لإرساله للكمبيوتر.",
                  style: TextStyle(fontSize: 12, color: secondaryTextColor, height: 1.5),
                ),
                const SizedBox(height: 16),
                
                Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    GlassTextField(
                      controller: _jsonController,
                      focusNode: _focusNode,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      textDirection: TextDirection.ltr,
                      isMonospace: true,
                      hintText: "{\n  \"supplier_name\": ...\n}",
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: ElevatedButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.paste_rounded, size: 14),
                        label: const Text("لصق 📋", style: TextStyle(fontSize: 11, fontFamily: 'Cairo')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark 
                              ? AppColors.darkBgSecondary.withValues(alpha: 0.8) 
                              : AppColors.lightBgSecondary.withValues(alpha: 0.8),
                          foregroundColor: secondaryTextColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                GlassButton(
                  onPressed: isConnected ? _sendJsonToComputer : null,
                  icon: Icons.send_rounded,
                  label: "إرسال تفاصيل الفاتورة للكمبيوتر 📱💻",
                  color: AppColors.successGreen,
                ),
              ],
            ),
          ),

          if (!isConnected) ...[
            const SizedBox(height: 16),
            _buildConnectionWarning(),
          ],

          if (_aiStatusMessage != null) ...[
            const SizedBox(height: 20),
            _buildStatusOverlay(_aiStatusMessage!, true),
          ],

          if (_aiErrorMessage != null) ...[
            const SizedBox(height: 20),
            _buildStatusOverlay(_aiErrorMessage!, false),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionWarning() {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 8,
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.dangerRed, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "يرجى ربط التطبيق بالكمبيوتر أولاً لتفعيل الإرسال.",
              style: TextStyle(color: AppColors.dangerRed, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverlay(String msg, bool isSuccess) {
    final color = isSuccess ? AppColors.successGreen : AppColors.dangerRed;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 10,
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 13, height: 1.5),
      ),
    );
  }
}
