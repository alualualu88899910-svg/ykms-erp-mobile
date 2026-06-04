import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/http_service.dart';
import '../../shared/components/cinematic_background.dart';
import '../../shared/components/glass_card.dart';
import '../../shared/components/glass_button.dart';
import '../../shared/components/glass_text_field.dart';
import '../../shared/providers/connection_provider.dart';
import 'inventory_count_scanner_screen.dart';

class InventoryCountScreen extends ConsumerStatefulWidget {
  const InventoryCountScreen({super.key});

  @override
  ConsumerState<InventoryCountScreen> createState() => _InventoryCountScreenState();
}

class _InventoryCountScreenState extends ConsumerState<InventoryCountScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _activeSession;
  String? _errorMessage;

  // Selected item variables
  Map<String, dynamic>? _selectedItem;
  bool _searchingItem = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _mismatchReason;

  // Live search suggestions variables
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _searchingSuggestions = false;

  final List<String> _mismatchReasons = [
    "سرقة أو فقدان",
    "تلف أو كسر",
    "خطأ في إدخال فاتورة سابقة",
    "خطأ في البيع دون تسجيل",
    "أخرى (اكتب في الملاحظات)"
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _checkActiveSession());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkActiveSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedItem = null;
      _suggestions = [];
    });

    final connectionState = ref.read(connectionProvider);
    if (connectionState.status != ConnectionStatus.connected) {
      setState(() {
        _isLoading = false;
        _errorMessage = "التطبيق غير متصل بجهاز الكمبيوتر ⚠️";
      });
      return;
    }

    try {
      final session = await ref.read(httpServiceProvider).getActiveInventorySession();
      setState(() {
        _activeSession = session;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "حدث خطأ أثناء فحص الجلسة: $e";
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _searchingSuggestions = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _searchingSuggestions = true;
      });
      try {
        final results = await ref.read(httpServiceProvider).searchInventoryItems(_activeSession!['id'], query);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _searchingSuggestions = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searchingSuggestions = false;
        });
      }
    });
  }

  void _selectSuggestion(Map<String, dynamic> item) {
    setState(() {
      _selectedItem = item;
      _suggestions = [];
      _searchController.text = item['product_name_snapshot'] ?? item['product_name'] ?? '';
      _qtyController.clear();
      _notesController.clear();
      _mismatchReason = null;
      if (item['counted_qty'] != null) {
        _qtyController.text = item['counted_qty'].toString();
      }
      if (item['notes'] != null) {
        _notesController.text = item['notes'];
      }
      if (item['mismatch_reason'] != null) {
        _mismatchReason = item['mismatch_reason'];
      }
    });
  }

  Future<void> _searchItem(String query) async {
    if (_activeSession == null || query.trim().isEmpty) return;

    setState(() {
      _searchingItem = true;
      _selectedItem = null;
      _qtyController.clear();
      _notesController.clear();
      _mismatchReason = null;
      _suggestions = [];
    });

    try {
      final items = await ref.read(httpServiceProvider).searchInventoryItems(_activeSession!['id'], query);
      if (!mounted) return;
      if (items.isNotEmpty) {
        final exactMatch = items.firstWhere(
          (item) => item['barcode_snapshot'] == query,
          orElse: () => items.first,
        );
        _selectSuggestion(exactMatch);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("المنتج ($query) غير موجود في جلسة الجرد الحالية ⚠️", style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ في البحث عن المنتج: $e", style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _searchingItem = false;
        });
      }
    }
  }

  Future<void> _submitCount() async {
    if (_activeSession == null || _selectedItem == null) return;

    final qtyStr = _qtyController.text.trim();
    if (qtyStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("الرجاء إدخال الكمية الفعلية أولاً", style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }

    final double? countedQty = double.tryParse(qtyStr);
    if (countedQty == null || countedQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("الرجاء إدخال كمية صحيحة غير سالبة", style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.dangerRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final expectedQty = (_selectedItem!['expected_qty'] as num).toDouble();
    final hasMismatch = (countedQty - expectedQty).abs() > 0.001;

    try {
      final res = await ref.read(httpServiceProvider).updateInventoryCount(
        sessionId: _activeSession!['id'],
        itemId: _selectedItem!['id'],
        countedQty: countedQty,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        mismatchReason: hasMismatch ? _mismatchReason : null,
      );
      if (!mounted) return;

      if (res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تم تحديث الجرد بنجاح لـ: ${_selectedItem!['product_name']} ✅", style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _searchController.clear();
        setState(() {
          _selectedItem = null;
        });
        await _checkActiveSession();
        if (!mounted) return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("فشل في تحديث الجرد على الكمبيوتر ⚠️", style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ أثناء إرسال البيانات: $e", style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openBarcodeScanner() async {
    final scannedBarcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const InventoryCountScannerScreen()),
    );
    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      _searchController.text = scannedBarcode;
      _searchItem(scannedBarcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final isConnected = connectionState.status == ConnectionStatus.connected;

    ref.listen(connectionProvider, (prev, next) {
      if (next.status == ConnectionStatus.connected && prev?.status != ConnectionStatus.connected) {
        _checkActiveSession();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("جرد المخزون 📋"),
        actions: [
          IconButton(
            onPressed: _checkActiveSession,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          const CinematicBackground(),
          
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          else if (!isConnected)
            _buildStateView(
              icon: Icons.wifi_off_rounded,
              color: AppColors.dangerRed,
              title: "غير متصل بالكمبيوتر",
              description: "يرجى ربط التطبيق بجهاز الكمبيوتر المكتبي أولاً للبدء في الجرد.",
            )
          else if (_errorMessage != null)
            _buildStateView(
              icon: Icons.error_outline_rounded,
              color: AppColors.dangerRed,
              title: "خطأ في الاتصال بالخادم",
              description: _errorMessage!,
            )
          else if (_activeSession == null)
            _buildStateView(
              icon: Icons.assignment_late_rounded,
              color: AppColors.warningAmber,
              title: "لا توجد جلسة جرد نشطة",
              description: "يرجى إنشاء جلسة جرد جديدة من شاشة الجرد بالكمبيوتر المكتبي للبدء.",
            )
          else
            _buildCountView(),
        ],
      ),
    );
  }

  Widget _buildStateView({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: secondaryTextColor, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (title == "غير متصل بالكمبيوتر") ...[
                const SizedBox(height: 20),
                GlassButton(
                  onPressed: () => Navigator.of(context).pop(),
                  color: AppColors.primaryBlue,
                  label: "العودة للرئيسية",
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final sessionNum = _activeSession!['session_number'] ?? '-';
    final totalProds = _activeSession!['total_products'] ?? 0;
    final checkedCount = _activeSession!['checked_count'] ?? 0;
    final progressPct = totalProds > 0 ? (checkedCount / totalProds * 100).round() : 0;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session Info Card (Glassmorphic)
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "جلسة نشطة: ",
                            style: TextStyle(fontSize: 14, color: secondaryTextColor),
                          ),
                          Text(
                            sessionNum,
                            style: AppTheme.monospaceNumbers.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          "جاري العد",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? AppColors.borderDark : Colors.black.withValues(alpha: 0.12), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("مجرود: ", style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                          Text("$checkedCount", style: AppTheme.monospaceNumbers.copyWith(fontSize: 13, color: primaryTextColor, fontWeight: FontWeight.bold)),
                          Text(" / ", style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                          Text("$totalProds", style: AppTheme.monospaceNumbers.copyWith(fontSize: 13, color: secondaryTextColor)),
                          Text(" مادة", style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                        ],
                      ),
                      Text(
                        "$progressPct%",
                        style: AppTheme.monospaceNumbers.copyWith(fontSize: 13, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalProds > 0 ? (checkedCount / totalProds) : 0,
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search Bar & Scan Button
            Row(
              children: [
                Expanded(
                  child: GlassTextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _searchItem,
                    onChanged: _onSearchChanged,
                    hintText: "ابحث بالاسم أو الباركود...",
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                    suffixIcon: _searchingItem || _searchingSuggestions
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.search_rounded, color: secondaryTextColor),
                            onPressed: () => _searchItem(_searchController.text),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _openBarcodeScanner,
                  icon: Icon(Icons.qr_code_scanner_rounded, color: isDark ? Colors.white : AppColors.textPrimaryLight),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),

            // Suggestions dropdown
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => Divider(
                      color: isDark ? AppColors.borderDark : Colors.black.withValues(alpha: 0.12), 
                      height: 1
                    ),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      final prodName = item['product_name_snapshot'] ?? item['product_name'] ?? '-';
                      final barcode = item['barcode_snapshot'] ?? '-';
                      
                      return ListTile(
                        dense: true,
                        title: Text(
                          prodName,
                          style: TextStyle(
                            fontFamily: 'Cairo', 
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          barcode,
                          style: AppTheme.monospaceNumbers.copyWith(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                        onTap: () => _selectSuggestion(item),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Counting Sheet Form
            if (_selectedItem != null) ...[
              _buildCountingForm(),
            ] else if (!_searchingItem) ...[
              GlassCard(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 48, color: mutedTextColor),
                      const SizedBox(height: 12),
                      Text(
                        "امسح باركود الرف أو ابحث عن المنتج للبدء بالعد",
                        style: TextStyle(color: mutedTextColor, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountingForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final name = _selectedItem!['product_name'] ?? '-';
    final barcode = _selectedItem!['barcode_snapshot'] ?? '-';
    final unit = _selectedItem!['unit_name'] ?? 'قطعة';
    final expectedQty = (_selectedItem!['expected_qty'] as num).toDouble();
    
    final qtyText = _qtyController.text.trim();
    final double? currentCounted = double.tryParse(qtyText);
    final double diff = currentCounted != null ? (currentCounted - expectedQty) : 0.0;
    final hasMismatch = diff.abs() > 0.001;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text("باركود: ", style: TextStyle(fontSize: 12, color: secondaryTextColor)),
              Text(barcode, style: AppTheme.monospaceNumbers.copyWith(fontSize: 12, color: secondaryTextColor)),
              Text(" | ", style: TextStyle(fontSize: 12, color: secondaryTextColor)),
              Text("الوحدة: $unit", style: TextStyle(fontSize: 12, color: secondaryTextColor)),
            ],
          ),
          Divider(color: isDark ? AppColors.borderDark : Colors.black.withValues(alpha: 0.12), height: 24),

          // Expected Qty (System Qty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("الكمية الحالية في المخزون:", style: TextStyle(color: secondaryTextColor, fontSize: 13)),
              Row(
                children: [
                  Text(
                    "$expectedQty",
                    style: AppTheme.monospaceNumbers.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(unit, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Count input field
          Text("الكمية الفعلية المجرودة:", style: TextStyle(color: secondaryTextColor, fontSize: 13)),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            hintText: "0.00",
            isMonospace: true,
            onChanged: (val) {
              setState(() {});
            },
            suffixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Text(unit, style: TextStyle(color: secondaryTextColor, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),

          // Mismatch warnings & fields
          if (hasMismatch) ...[
            GlassCard(
              padding: const EdgeInsets.all(12),
              borderRadius: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 18),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Text(
                            "يوجد فرق جرد: ",
                            style: TextStyle(color: AppColors.warningAmber, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            "${diff > 0 ? '+' : ''}${diff.toStringAsFixed(2)}",
                            style: AppTheme.monospaceNumbers.copyWith(color: AppColors.warningAmber, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            unit,
                            style: const TextStyle(color: AppColors.warningAmber, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "سبب الاختلاف (إجباري):",
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppColors.borderDark : Colors.black.withValues(alpha: 0.18)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _mismatchReason,
                        hint: Text("اختر سبب الفارق...", style: TextStyle(color: mutedTextColor, fontSize: 12, fontFamily: 'Cairo')),
                        dropdownColor: isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: primaryTextColor),
                        style: TextStyle(color: primaryTextColor, fontFamily: 'Cairo', fontSize: 13),
                        items: _mismatchReasons.map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val, style: TextStyle(color: primaryTextColor)),
                          );
                        }).toList(),
                        onChanged: (newVal) {
                          setState(() {
                            _mismatchReason = newVal;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Notes
          Text("ملاحظات إضافية:", style: TextStyle(color: secondaryTextColor, fontSize: 13)),
          const SizedBox(height: 6),
          GlassTextField(
            controller: _notesController,
            maxLines: 2,
            hintText: "أضف أي تفاصيل أو ملاحظات حول العد هنا...",
          ),
          const SizedBox(height: 20),

          // Form buttons
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  onPressed: _submitCount,
                  icon: Icons.check_circle_rounded,
                  label: "تحديث وحفظ الجرد 💾",
                  color: AppColors.successGreen,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedItem = null;
                  });
                },
                icon: Icon(Icons.close_rounded, color: secondaryTextColor),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
