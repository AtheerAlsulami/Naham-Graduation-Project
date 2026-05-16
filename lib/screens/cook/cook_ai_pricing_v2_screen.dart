import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/services/backend/backend_pricing_service.dart';
import 'package:naham_app/screens/cook/cook_ai_pricing_screen.dart'; // Import payload

enum _ProfitMode {
  percentage,
  fixedAmount,
}

enum _AiPricingStage {
  form,
  reviewing,
  recommendation,
}

class CookAiPricingV2Screen extends StatefulWidget {
  const CookAiPricingV2Screen({
    super.key,
    required this.payload,
  });

  final CookAiPricingPayload payload;

  @override
  State<CookAiPricingV2Screen> createState() => _CookAiPricingV2ScreenState();
}

class _CookAiPricingV2ScreenState extends State<CookAiPricingV2Screen> {
  static const List<String> _reviewMessages = [
    'Reviewing dish composition...',
    'Analyzing market trends...',
    'Calculating optimal profit...',
    'Generating smart recommendation...',
  ];

  final _descriptionController = TextEditingController();
  final _profitValueController = TextEditingController();
  final BackendPricingService _pricingService = BackendPricingService();
  _ProfitMode _profitMode = _ProfitMode.percentage;
  _AiPricingStage _stage = _AiPricingStage.form;
  _AiPriceBreakdownV2? _resultBreakdown;
  int _reviewMessageIndex = 0;
  Timer? _reviewTicker;
  Timer? _reviewFinishTimer;
  TextDirection _descriptionDirection = TextDirection.ltr;

  @override
  void dispose() {
    _cancelReviewTimers();
    _descriptionController.dispose();
    _profitValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7), // Match Add Dish Screen
        body: Column(
          children: [
            _AiTopBar(
              topPadding: topPadding,
              onBackTap: _handleBackTap,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                child: KeyedSubtree(
                  key: ValueKey(_stage),
                  child: _buildStageBody(),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildStageBody() {
    return switch (_stage) {
      _AiPricingStage.form => _buildFormStage(),
      _AiPricingStage.reviewing => _buildReviewingStage(),
      _AiPricingStage.recommendation => _buildRecommendationStage(),
    };
  }

  Widget _buildFormStage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DishDetailsCard(
            controller: _descriptionController,
            textDirection: _descriptionDirection,
            onChanged: _onDescriptionChanged,
          ),
          const SizedBox(height: 16),
          _ProfitCard(
            selectedMode: _profitMode,
            profitController: _profitValueController,
            onModeChanged: (mode) {
              if (mode == _profitMode) return;
              setState(() {
                _profitMode = mode;
              });
            },
            onInputChanged: _refresh,
          ),
          const SizedBox(height: 20),
          _InfoNote(),
        ],
      ),
    );
  }

  Widget _buildReviewingStage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    color: const Color(0xFF7A4DFF),
                    backgroundColor: const Color(0xFF7A4DFF).withValues(alpha: 0.1),
                  ),
                ),
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF7A4DFF),
                  size: 32,
                ),
              ],
            ),
            const SizedBox(height: 40),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _reviewMessages[_reviewMessageIndex],
                key: ValueKey(_reviewMessageIndex),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF39584A),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Our AI is processing your request...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFFA5ABB5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationStage() {
    final breakdown = _resultBreakdown;
    if (breakdown == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7A4DFF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF7A4DFF),
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'AI Smart Recommendation',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF39584A),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7A4DFF), Color(0xFF9B7AD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9B7AD1).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'SUGGESTED PRICE',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      breakdown.suggestedPrice.toStringAsFixed(0),
                      style: GoogleFonts.poppins(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'SAR',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (breakdown.insights.isNotEmpty) ...[
            Text(
              'AI Analysis',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF39584A),
              ),
            ),
            const SizedBox(height: 12),
            ...breakdown.insights.map((insight) => _InsightCard(text: insight)),
          ],
          const SizedBox(height: 24),
          _CostBreakdownCard(breakdown: breakdown),
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (_stage == _AiPricingStage.reviewing) return null;

    final isForm = _stage == _AiPricingStage.form;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isForm ? _applyAiPricing : _confirmPrice,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B7AD1), // Match "Add Dish" button
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isForm ? Icons.auto_awesome : Icons.check_circle_outline, size: 20),
                const SizedBox(width: 10),
                Text(
                  isForm ? 'Get Price Suggestion' : 'Apply Suggested Price',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyAiPricing() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showSnack('Please enter dish details first');
      return;
    }

    final profitValue = _parseNumber(_profitValueController.text);
    if (profitValue == null || profitValue < 0) {
      _showSnack('Please enter a valid profit value');
      return;
    }

    try {
      setState(() {
        _stage = _AiPricingStage.reviewing;
        _reviewMessageIndex = 0;
      });

      _startReviewTimers();

      final suggestion = await _pricingService.suggestPriceV2(
        categoryId: widget.payload.categoryId,
        preparationMinutes: widget.payload.preparationMinutes,
        dishDescription: description,
        profitMode: _profitMode == _ProfitMode.percentage ? 'percentage' : 'fixedAmount',
        profitValue: profitValue,
        currentPrice: widget.payload.currentPrice,
      );

      if (!mounted) return;

      setState(() {
        _resultBreakdown = _AiPriceBreakdownV2(
          ingredientsCost: suggestion.breakdown.ingredientsCost,
          packagingCost: suggestion.breakdown.packagingCost,
          operationalCost: suggestion.breakdown.operationalCost,
          profitAmount: suggestion.breakdown.profitAmount,
          demandBoost: suggestion.breakdown.demandBoost,
          suggestedPrice: suggestion.suggestedPrice,
          insights: suggestion.insights,
        );
      });
    } catch (e) {
      if (!mounted) return;
      _cancelReviewTimers();
      setState(() => _stage = _AiPricingStage.form);
      _showSnack('AI pricing failed: $e');
    }
  }

  void _startReviewTimers() {
    _reviewTicker = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_reviewMessageIndex >= _reviewMessages.length - 1) {
        timer.cancel();
        return;
      }
      setState(() => _reviewMessageIndex++);
    });

    _reviewFinishTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      if (_resultBreakdown != null) {
        setState(() => _stage = _AiPricingStage.recommendation);
      } else {
        _reviewFinishTimer = Timer(const Duration(milliseconds: 1000), () {
          if (mounted && _resultBreakdown != null) {
            setState(() => _stage = _AiPricingStage.recommendation);
          }
        });
      }
    });
  }

  void _confirmPrice() {
    if (_resultBreakdown == null) return;
    context.pop({
      'price': _resultBreakdown!.suggestedPrice,
      'ingredientsCost': _resultBreakdown!.ingredientsCost,
      'packagingCost': _resultBreakdown!.packagingCost,
      'operationalCost': _resultBreakdown!.operationalCost,
      'profitAmount': _resultBreakdown!.profitAmount,
      'demandBoost': _resultBreakdown!.demandBoost,
    });
  }

  void _handleBackTap() {
    if (_stage != _AiPricingStage.form) {
      _cancelReviewTimers();
      setState(() => _stage = _AiPricingStage.form);
      return;
    }
    context.pop();
  }

  void _cancelReviewTimers() {
    _reviewTicker?.cancel();
    _reviewTicker = null;
    _reviewFinishTimer?.cancel();
    _reviewFinishTimer = null;
  }

  void _refresh() => setState(() {});

  void _onDescriptionChanged(String value) {
    if (value.isEmpty) {
      setState(() => _descriptionDirection = TextDirection.ltr);
      return;
    }

    final firstChar = value.trim().characters.firstOrNull ?? '';
    final isArabic = RegExp(r'^[\u0600-\u06FF]').hasMatch(firstChar);

    setState(() {
      _descriptionDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    });
  }

  double? _parseNumber(String raw) {
    var normalized = raw.trim().replaceAll(',', '.');
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabicDigits.length; i++) {
      normalized = normalized.replaceAll(arabicDigits[i], i.toString());
    }
    return double.tryParse(normalized);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _DishDetailsCard extends StatelessWidget {
  const _DishDetailsCard({
    required this.controller,
    required this.textDirection,
    required this.onChanged,
  });
  final TextEditingController controller;
  final TextDirection textDirection;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E3E9), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: Color(0xFF7A4DFF), size: 24),
              const SizedBox(width: 12),
              Text(
                'Order Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF39584A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter dish ingredients, weights, and any details to help AI estimate the cost.',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: const Color(0xFFA5ABB5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 10,
            textDirection: textDirection,
            onChanged: onChanged,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Example: 2kg Lamb meat, 5 cups Basmati rice, premium spices...',
              hintStyle: GoogleFonts.poppins(color: const Color(0xFFB8BEC9), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF0F2F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.homeChrome, width: 1.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitCard extends StatelessWidget {
  const _ProfitCard({
    required this.selectedMode,
    required this.profitController,
    required this.onModeChanged,
    required this.onInputChanged,
  });

  final _ProfitMode selectedMode;
  final TextEditingController profitController;
  final ValueChanged<_ProfitMode> onModeChanged;
  final VoidCallback onInputChanged;

  @override
  Widget build(BuildContext context) {
    final isPercentage = selectedMode == _ProfitMode.percentage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E3E9), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on_outlined, color: Color(0xFF7A4DFF), size: 24),
              const SizedBox(width: 12),
              Text(
                'Desired Profit',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF39584A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: 'Percentage',
                    selected: isPercentage,
                    onTap: () => onModeChanged(_ProfitMode.percentage),
                  ),
                ),
                Expanded(
                  child: _ModeChip(
                    label: 'Fixed Amount',
                    selected: !isPercentage,
                    onTap: () => onModeChanged(_ProfitMode.fixedAmount),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: profitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onInputChanged(),
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: isPercentage ? 'Example: 20%' : 'Example: 50 SAR',
              prefixIcon: const Icon(Icons.percent, size: 20, color: Color(0xFFA7ACB6)),
              suffixText: isPercentage ? '%' : 'SAR',
              filled: true,
              fillColor: const Color(0xFFF0F2F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.homeChrome, width: 1.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? const Color(0xFF7A4DFF) : const Color(0xFFA5ABB5),
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0E3FF), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFF0066FF), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: const Color(0xFF003366),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostBreakdownCard extends StatelessWidget {
  const _CostBreakdownCard({required this.breakdown});
  final _AiPriceBreakdownV2 breakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E3E9)),
      ),
      child: Column(
        children: [
          _BreakdownRow(label: 'Estimated Cost', value: breakdown.ingredientsCost),
          const Divider(height: 24, color: Color(0xFFF1F0F7)),
          _BreakdownRow(label: 'Packaging & Operations', value: breakdown.packagingCost + breakdown.operationalCost),
          const Divider(height: 24, color: Color(0xFFF1F0F7)),
          _BreakdownRow(label: 'Net Profit', value: breakdown.profitAmount, isHighlight: true),
          const Divider(height: 24, color: Color(0xFFF1F0F7)),
          _BreakdownRow(label: 'AI Market Adjustment', value: breakdown.demandBoost, isPositive: true),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value, this.isPositive = false, this.isHighlight = false});
  final String label;
  final double value;
  final bool isPositive;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13, 
              color: isHighlight ? const Color(0xFF7A4DFF) : const Color(0xFFA5ABB5), 
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500
            ),
          ),
        ),
        Text(
          '${isPositive ? '+' : ''}${value.toStringAsFixed(2)} SAR',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isPositive ? const Color(0xFF40916C) : const Color(0xFF1A2B22),
          ),
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB38100), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI analyzes the description and estimates costs based on current market prices in Saudi Arabia.',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF664D00), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTopBar extends StatelessWidget {
  const _AiTopBar({required this.topPadding, required this.onBackTap});
  final double topPadding;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topPadding + 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome, // Match Add Dish Screen
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            splashRadius: 22,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              'AI Smart Pricing',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24, // Consistent with Add Dish Screen (adjusted to 24 for title)
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _AiPriceBreakdownV2 {
  const _AiPriceBreakdownV2({
    required this.ingredientsCost,
    required this.packagingCost,
    required this.operationalCost,
    required this.profitAmount,
    required this.demandBoost,
    required this.suggestedPrice,
    required this.insights,
  });

  final double ingredientsCost;
  final double packagingCost;
  final double operationalCost;
  final double profitAmount;
  final double demandBoost;
  final double suggestedPrice;
  final List<String> insights;
}
