import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/http_service.dart';
import '../../shared/components/cinematic_background.dart';
import '../../shared/components/glass_card.dart';
import '../../shared/components/glass_text_field.dart';
import 'product_enrichment_screen.dart';

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  ConsumerState<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _isScanningBarcode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch("");
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await ref.read(httpServiceProvider).searchProducts(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "تعذر جلب المنتجات: $e";
        _isLoading = false;
      });
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final barcode = barcodes.first.rawValue!;
      setState(() {
        _isScanningBarcode = false;
        _searchController.text = barcode;
      });
      _performSearch(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text("البحث عن منتج لإثرائه"),
      ),
      body: Stack(
        children: [
          const CinematicBackground(),

          SafeArea(
            child: Column(
              children: [
                // Search Input & Scan button block
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassTextField(
                          controller: _searchController,
                          hintText: "اسم المنتج أو الباركود...",
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded, color: secondaryTextColor),
                                  onPressed: () {
                                    _searchController.clear();
                                    _performSearch("");
                                  },
                                )
                              : null,
                          onChanged: (val) => _performSearch(val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // Barcode Scan Button
                      IconButton.filled(
                        onPressed: () {
                          setState(() {
                            _isScanningBarcode = !_isScanningBarcode;
                          });
                        },
                        icon: Icon(
                          _isScanningBarcode ? Icons.close_rounded : Icons.qr_code_scanner_rounded,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Inline scanner view when active
                if (_isScanningBarcode)
                  GlassCard(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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

                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_error!, style: const TextStyle(color: AppColors.dangerRed)),
                  ),

                // Section Title
                if (!_isLoading && _searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _searchController.text.trim().isEmpty
                            ? "المنتجات المضافة حديثاً"
                            : "نتائج البحث",
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                // Results list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                      : _searchResults.isEmpty
                          ? Center(
                              child: Text(
                                "لا توجد نتائج بحث. جرب كتابة اسم منتج أو مسح باركوده.",
                                style: TextStyle(color: mutedTextColor),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemBuilder: (context, index) {
                                 final product = _searchResults[index];
                                 final hasBarcode = product['barcode'] != null && product['barcode'].toString().isNotEmpty;

                                 return GlassCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProductEnrichmentScreen(product: product),
                                      ),
                                    );
                                  },
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    title: Text(
                                      product['name'],
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            "السعر: ",
                                            style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                          ),
                                          Text(
                                            "${product['price']}",
                                            style: AppTheme.monospaceNumbers.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            " د.ج | المخزون: ",
                                            style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                          ),
                                          Text(
                                            "${product['quantity']}",
                                            style: AppTheme.monospaceNumbers.copyWith(color: secondaryTextColor, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!hasBarcode)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.warningAmber.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.3)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  "بلا باركود",
                                                  style: TextStyle(color: AppColors.warningAmber, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.chevron_left_rounded, color: secondaryTextColor),
                                      ],
                                    ),
                                  ),
                                );
                              },
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
