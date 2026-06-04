import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/components/cinematic_background.dart';
import '../../shared/components/glass_card.dart';
import '../../shared/providers/connection_provider.dart';
import '../scanner/pos_scanner_screen.dart';
import '../enrichment/product_search_screen.dart';
import '../invoice/smart_invoice_assistant_screen.dart';
import '../inventory_count/inventory_count_screen.dart';
import '../connection/connection_status_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionProvider);
    final isConnected = connectionState.status == ConnectionStatus.connected;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'logo',
              child: Image.asset(
                'assets/logo.png',
                width: 28,
                height: 28,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.business_rounded,
                  color: isConnected ? AppColors.primaryBlue : secondaryTextColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text("YKMS ERP"),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectionStatusScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _PulsatingIndicator(isConnected: isConnected),
            ),
          ),
        ],
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
                  const SizedBox(height: 10),
                  Text(
                    "مرحباً بك في مساعد ERP",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isConnected 
                      ? "جهازك مرتبط حالياً بـ ${connectionState.serverName}"
                      : "يرجى توصيل التطبيق ببرنامج Electron للبدء",
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Mode Grid
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Card 1: POS Scanner
                        _buildFeatureCard(
                          context: context,
                          title: "مسح باركود للـ POS",
                          description: "امسح باركود المنتجات لإضافتها مباشرة في فاتورة البيع المفتوحة بالكمبيوتر.",
                          icon: Icons.qr_code_scanner_rounded,
                          gradientColor: AppColors.primaryBlue,
                          isEnabled: isConnected,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PosScannerScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Card 2: Product Enrichment
                        _buildFeatureCard(
                          context: context,
                          title: "إثراء صور وباركود المنتج",
                          description: "ابحث عن منتج بالاسم أو الباركود لإضافة صور جديدة أو ربط باركود بديل.",
                          icon: Icons.add_photo_alternate_rounded,
                          gradientColor: AppColors.successGreen,
                          isEnabled: isConnected,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Card 3: Smart AI Invoice Assistant
                        _buildFeatureCard(
                          context: context,
                          title: "مساعد الفواتير الذكي (AI)",
                          description: "صوّر الفاتورة الورقية أو الصق كود الـ JSON الناتج لتفتح فاتورة شراء تلقائياً.",
                          icon: Icons.auto_awesome_rounded,
                          gradientColor: AppColors.warningAmber,
                          isEnabled: isConnected,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SmartInvoiceAssistantScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Card 4: Inventory Count
                        _buildFeatureCard(
                          context: context,
                          title: "جرد المخزون 📋",
                          description: "ابحث بالاسم أو امسح الباركود لتسجيل الكميات وتحديث الفروقات فورياً بالرفوف.",
                          icon: Icons.assignment_rounded,
                          gradientColor: AppColors.infoCyan,
                          isEnabled: isConnected,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const InventoryCountScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color gradientColor,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: isEnabled ? onTap : null,
      animateOnTap: isEnabled,
      padding: const EdgeInsets.all(20.0),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.45,
        child: Row(
          children: [
            // Left color bar / Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gradientColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: gradientColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 28,
                color: gradientColor,
              ),
            ),
            const SizedBox(width: 16),

            // Center Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right Arrow Indicator
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsatingIndicator extends StatefulWidget {
  final bool isConnected;
  const _PulsatingIndicator({required this.isConnected});

  @override
  State<_PulsatingIndicator> createState() => _PulsatingIndicatorState();
}

class _PulsatingIndicatorState extends State<_PulsatingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isConnected ? AppColors.successGreen : AppColors.dangerRed;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.04 + (_controller.value * 0.08)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.3 + (_controller.value * 0.5)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _controller.value * 0.12),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color,
                      blurRadius: 4 * _controller.value,
                      spreadRadius: 1 * _controller.value,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isConnected ? "متصل" : "غير متصل",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
