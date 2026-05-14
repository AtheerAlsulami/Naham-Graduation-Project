import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/services/aws/aws_pricing_service.dart';
import 'package:naham_app/services/backend/backend_pricing_service.dart';

class CookAiPricingPayload {
  const CookAiPricingPayload({
    required this.categoryId,
    required this.preparationMinutes,
    this.currentPrice,
  });

  final String categoryId;
  final int preparationMinutes;
  final double? currentPrice;
}

enum _ProfitMode {
  percentage,
  fixedAmount,
}

enum _AiPricingStage {
  form,
  reviewing,
  recommendation,
}

class CookAiPricingScreen extends StatefulWidget {
  const CookAiPricingScreen({
    super.key,
    required this.payload,
  });

  final CookAiPricingPayload payload;

  @override
  State<CookAiPricingScreen> createState() => _CookAiPricingScreenState();
}

class _CookAiPricingScreenState extends State<CookAiPricingScreen> {
  static const List<String> _reviewMessages = [
    'Reviewing packaging cost...',
    'Reviewing operational expenses...',
    'Reviewing competitor landscape...',
    'Generating smart recommendation...',
  ];

  late final List<_IngredientDraft> _ingredients = _seedIngredients();
  final _profitValueController = TextEditingController();
  final BackendPricingService _pricingService = BackendPricingService();
  _ProfitMode _profitMode = _ProfitMode.percentage;
  _AiPricingStage _stage = _AiPricingStage.form;
  _AiPriceBreakdown? _resultBreakdown;
  int _reviewMessageIndex = 0;
  Timer? _reviewTicker;
  Timer? _reviewFinishTimer;

  @override
  void dispose() {
    _cancelReviewTimers();
    for (final item in _ingredients) {
      item.dispose();
    }
    _profitValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Column(
          children: [
            _AiTopBar(
              topPadding: topPadding,
              onBackTap: _handleBackTap,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
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
    final preview = _previewBreakdown;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      child: Column(
        children: [
          _IngredientsCard(
            ingredients: _ingredients,
            onAddTap: _addIngredient,
            onRemoveTap: _removeIngredientAt,
            onInputChanged: _refresh,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          _PreviewCard(
            categoryId: widget.payload.categoryId,
            preparationMinutes: widget.payload.preparationMinutes,
            breakdown: preview,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewingStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Color(0xFF8A2CFF),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _reviewMessages[_reviewMessageIndex],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: isNarrow ? 20 : 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B3FA0),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationStage() {
    final breakdown = _resultBreakdown;
    if (breakdown == null) {
      return const SizedBox.shrink();
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 360;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFEFE9FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF8A2CFF),
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Smart Price Recommendation',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: isNarrow ? 24 : 26,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF432C6B),
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Our AI analyzed market trends, ingredient costs, and category performance to find the sweet spot for your profit.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: isNarrow ? 12.5 : 13.5,
                  color: const Color(0xFF7A6B9B),
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC4A8F7), Color(0xFFB38FEF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI SUGGESTED PRICE',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        breakdown.suggestedPrice.toStringAsFixed(0),
                        style: GoogleFonts.poppins(
                          fontSize: isNarrow ? 44 : 50,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'SAR',
                          style: GoogleFonts.poppins(
                            fontSize: isNarrow ? 20 : 25,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (breakdown.insights.isNotEmpty) ...[
            Text(
              'AI Analysis',
              style: GoogleFonts.poppins(
                fontSize: isNarrow ? 18 : 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2A2F3B),
              ),
            ),
            const SizedBox(height: 8),
            ...breakdown.insights.map((insight) {
              final lowerInsight = insight.toLowerCase();
              final isNegative = lowerInsight.contains('low') ||
                  lowerInsight.contains('decline') ||
                  lowerInsight.contains('loss') ||
                  lowerInsight.contains('down');
              final isPositive = !isNegative;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InsightBox(
                  background: isPositive
                      ? const Color(0xFFE4F8EF)
                      : const Color(0xFFFFF4F4),
                  titleColor: isPositive
                      ? const Color(0xFF1E8A5D)
                      : const Color(0xFFD32F2F),
                  textColor: isPositive
                      ? const Color(0xFF3E6C59)
                      : const Color(0xFF7A4B4B),
                  title: isPositive ? 'Positive Signal' : 'Market Alert',
                  subtitle: insight,
                ),
              );
            }),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3D6F8), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _PriceLine(
                    label: 'Components Cost', value: breakdown.ingredientsCost),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, color: Color(0xFFF1F0F7))),
                _PriceLine(
                    label: 'Packaging & Ops',
                    value: breakdown.packagingCost + breakdown.operationalCost),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, color: Color(0xFFF1F0F7))),
                _PriceLine(
                    label: 'Your Target Profit', value: breakdown.profitAmount),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, color: Color(0xFFF1F0F7))),
                _PriceLine(
                    label: 'AI Market Boost',
                    value: breakdown.demandBoost,
                    isBoost: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (_stage == _AiPricingStage.reviewing) {
      return null;
    }

    final preview = _previewBreakdown;
    final isForm = _stage == _AiPricingStage.form;
    final ctaLabel = isForm
        ? (preview == null
            ? 'Apply Price'
            : 'Apply Price (${preview.suggestedPrice.toStringAsFixed(0)} SAR)')
        : 'Apply Price';

    return Container(
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A2CFF), Color(0xFF6B3FA0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8A2CFF).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: isForm ? _applyPrice : _confirmAndReturnPrice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: Text(
                ctaLabel,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_IngredientDraft> _seedIngredients() {
    if (widget.payload.categoryId == 'sweets') {
      return [
        _IngredientDraft(name: '', weightG: '', costPer100: ''),
        _IngredientDraft(name: '', weightG: '', costPer100: ''),
        _IngredientDraft(name: '', weightG: '', costPer100: ''),
        _IngredientDraft(name: '', weightG: '', costPer100: ''),
      ];
    }
    if (widget.payload.categoryId == 'baked') {
      return [
        _IngredientDraft(name: '', weightG: '', costPer100: ''),
        _IngredientDraft(name: '', weightG: '', costPer100: ''),
        _IngredientDraft(name: '', weightG: '', costPer100: ''),
        _IngredientDraft(name: '', weightG: '', costPer100: ''),
      ];
    }
    return [
      _IngredientDraft(name: '', weightG: '', costPer100: ''),
      _IngredientDraft(name: '', weightG: '', costPer100: ''),
      _IngredientDraft(name: '', weightG: '', costPer100: ''),
      _IngredientDraft(name: '', weightG: '', costPer100: ''),
    ];
  }

  _AiPriceBreakdown? get _previewBreakdown {
    final parsed = _tryParseIngredients(requireCompleteRows: false);
    if (parsed == null || parsed.isEmpty) {
      return null;
    }
    final profitValue = _parseNumber(_profitValueController.text);
    if (profitValue == null || profitValue < 0) {
      return null;
    }
    return _calculateBreakdown(parsed, profitValue);
  }

  List<_IngredientCostItem>? _tryParseIngredients({
    required bool requireCompleteRows,
  }) {
    final items = <_IngredientCostItem>[];
    for (var i = 0; i < _ingredients.length; i++) {
      final draft = _ingredients[i];
      final name = draft.nameController.text.trim();
      final weightText = draft.weightController.text.trim();
      final costText = draft.costController.text.trim();

      final rowHasInput =
          name.isNotEmpty || weightText.isNotEmpty || costText.isNotEmpty;
      if (!rowHasInput) {
        continue;
      }

      final weight = _parseNumber(weightText);
      final costPer100 = _parseNumber(costText);
      final isValid =
          name.isNotEmpty && weight != null && weight > 0 && costPer100 != null;

      if (!isValid) {
        if (requireCompleteRows) {
          _showSnack('Component row ${i + 1} is incomplete');
          return null;
        }
        continue;
      }

      items.add(
        _IngredientCostItem(
          weightGram: weight,
          costPer100Sar: costPer100.clamp(0, 10000).toDouble(),
        ),
      );
    }
    return items;
  }

  _AiPriceBreakdown _calculateBreakdown(
    List<_IngredientCostItem> ingredients,
    double profitInput,
  ) {
    final ingredientsCost = ingredients.fold<double>(
      0,
      (sum, item) => sum + ((item.weightGram / 100) * item.costPer100Sar),
    );

    final packagingCost = _packagingCost(
      widget.payload.categoryId,
      ingredientsCount: ingredients.length,
      ingredientsCost: ingredientsCost,
    );

    final prepOperationalCost =
        (widget.payload.preparationMinutes.clamp(5, 240) / 60.0) * 4.0;
    final categoryOperationalCost =
        _categoryOperationalCost(widget.payload.categoryId);
    final operationalCost = prepOperationalCost + categoryOperationalCost;
    final baseCost = ingredientsCost + packagingCost + operationalCost;

    final profitAmount = _profitMode == _ProfitMode.percentage
        ? baseCost * (profitInput.clamp(0, 250).toDouble() / 100)
        : profitInput.clamp(0, 5000).toDouble();
    final demandBoost =
        _demandBoost(widget.payload.categoryId, baseCost + profitAmount);
    final suggested =
        (baseCost + profitAmount + demandBoost).clamp(1, 5000).toDouble();

    return _AiPriceBreakdown(
      ingredientsCost: ingredientsCost,
      packagingCost: packagingCost,
      operationalCost: operationalCost,
      profitAmount: profitAmount,
      demandBoost: demandBoost,
      suggestedPrice: suggested,
      marketSignal: 'preview',
      insights: const [],
    );
  }

  double _packagingCost(
    String categoryId, {
    required int ingredientsCount,
    required double ingredientsCost,
  }) {
    final categoryBase = switch (categoryId) {
      'sweets' => 0.9,
      'baked' => 1.0,
      'najdi' => 1.4,
      'eastern' => 1.2,
      'northern' => 1.2,
      'southern' => 1.1,
      'western' => 1.15,
      _ => 1.0,
    };
    final perIngredient = (ingredientsCount * 0.12).clamp(0.2, 1.0).toDouble();
    final ingredientShare = ingredientsCost * 0.03;
    return (categoryBase + perIngredient + ingredientShare)
        .clamp(0.6, 12.0)
        .toDouble();
  }

  double _categoryOperationalCost(String categoryId) {
    return switch (categoryId) {
      'najdi' => 5.5,
      'northern' => 5.0,
      'eastern' => 4.8,
      'southern' => 4.6,
      'western' => 4.9,
      'sweets' => 3.2,
      'baked' => 3.8,
      _ => 4.5,
    };
  }

  double _demandBoost(String categoryId, double subtotal) {
    final percentage = switch (categoryId) {
      'sweets' => 0.08,
      'baked' => 0.06,
      'najdi' => 0.07,
      _ => 0.05,
    };
    return (subtotal * percentage).clamp(0.8, 12).toDouble();
  }

  double? _parseNumber(String raw) {
    var normalized = raw.trim().replaceAll(',', '.');
    const arabicDigits = [
      '\u0660',
      '\u0661',
      '\u0662',
      '\u0663',
      '\u0664',
      '\u0665',
      '\u0666',
      '\u0667',
      '\u0668',
      '\u0669',
    ];
    for (int i = 0; i < arabicDigits.length; i++) {
      normalized = normalized.replaceAll(arabicDigits[i], i.toString());
    }
    return double.tryParse(normalized);
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientDraft());
    });
  }

  void _removeIngredientAt(int index) {
    if (_ingredients.length == 1) {
      _showSnack('At least one component is required');
      return;
    }
    if (index < 0 || index >= _ingredients.length) return;
    setState(() {
      final removed = _ingredients.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _applyPrice() async {
    final profitValue = _parseNumber(_profitValueController.text);
    if (profitValue == null || profitValue < 0) {
      _showSnack('Enter a valid profit value');
      return;
    }

    final ingredients = _tryParseIngredients(requireCompleteRows: true);
    if (ingredients == null) {
      return;
    }
    if (ingredients.isEmpty) {
      _showSnack('Add at least one complete component row');
      return;
    }

    try {
      final suggestion = await _pricingService.suggestPrice(
        categoryId: widget.payload.categoryId,
        preparationMinutes: widget.payload.preparationMinutes,
        ingredients: ingredients
            .map(
              (item) => PricingIngredientInput(
                weightGram: item.weightGram,
                costPer100Sar: item.costPer100Sar,
              ),
            )
            .toList(),
        profitMode: _profitMode == _ProfitMode.percentage
            ? 'percentage'
            : 'fixedAmount',
        profitValue: profitValue,
        currentPrice: widget.payload.currentPrice,
      );

      if (!mounted) return;
      final breakdown = _AiPriceBreakdown(
        ingredientsCost: suggestion.breakdown.ingredientsCost,
        packagingCost: suggestion.breakdown.packagingCost,
        operationalCost: suggestion.breakdown.operationalCost,
        profitAmount: suggestion.breakdown.profitAmount,
        demandBoost: suggestion.breakdown.demandBoost,
        suggestedPrice: suggestion.suggestedPrice,
        marketSignal: suggestion.marketSignal,
        insights: suggestion.insights,
      );
      _startReviewFlow(breakdown);
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        "AI pricing failed: ${error.toString().replaceFirst('Exception: ', '')}",
      );
    }
  }

  void _startReviewFlow(_AiPriceBreakdown breakdown) {
    _cancelReviewTimers();
    setState(() {
      _resultBreakdown = breakdown;
      _stage = _AiPricingStage.reviewing;
      _reviewMessageIndex = 0;
    });

    _reviewTicker = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_reviewMessageIndex >= _reviewMessages.length - 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _reviewMessageIndex += 1;
      });
    });

    _reviewFinishTimer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _stage = _AiPricingStage.recommendation;
      });
    });
  }

  void _confirmAndReturnPrice() {
    final breakdown = _resultBreakdown;
    if (breakdown == null) {
      return;
    }
    context.pop(<String, dynamic>{
      'price': breakdown.suggestedPrice,
      'ingredientsCost': breakdown.ingredientsCost,
      'packagingCost': breakdown.packagingCost,
      'operationalCost': breakdown.operationalCost,
      'profitAmount': breakdown.profitAmount,
      'demandBoost': breakdown.demandBoost,
    });
  }

  void _refresh() {
    if (!mounted || _stage != _AiPricingStage.form) return;
    setState(() {});
  }

  void _handleBackTap() {
    if (_stage == _AiPricingStage.reviewing ||
        _stage == _AiPricingStage.recommendation) {
      _cancelReviewTimers();
      setState(() {
        _stage = _AiPricingStage.form;
      });
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({
    required this.ingredients,
    required this.onAddTap,
    required this.onRemoveTap,
    required this.onInputChanged,
  });

  final List<_IngredientDraft> ingredients;
  final VoidCallback onAddTap;
  final ValueChanged<int> onRemoveTap;
  final VoidCallback onInputChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3D6F8), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _StepBadge(number: 1),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cost Estimator',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'Enter components to calculate base cost',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onAddTap,
                icon: const Icon(Icons.add_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEFE9FF),
                  foregroundColor: const Color(0xFF8A2CFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(ingredients.length, (index) {
            final ingredient = ingredients[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IngredientEntryCard(
                draft: ingredient,
                index: index,
                onDelete: () => onRemoveTap(index),
                onChanged: onInputChanged,
              ),
            );
          }),
          Center(
            child: OutlinedButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                'Add Component',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8A2CFF),
                side: const BorderSide(color: Color(0xFFE3D6F8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientEntryCard extends StatelessWidget {
  const _IngredientEntryCard({
    required this.draft,
    required this.index,
    required this.onDelete,
    required this.onChanged,
  });

  final _IngredientDraft draft;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDF0F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8, bottom: 2),
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFE9FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8A2CFF),
                    height: 1,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldHint(text: 'Component Title'),
                    const SizedBox(height: 4),
                    _AiInput(
                      controller: draft.nameController,
                      hint: 'Enter component title',
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF4D5C),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldHint(text: 'Component'),
                    const SizedBox(height: 4),
                    _AiInput(
                      controller: draft.weightController,
                      hint: '0',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldHint(text: 'Cost/100g (SAR)'),
                    const SizedBox(height: 4),
                    _AiInput(
                      controller: draft.costController,
                      hint: '0',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                ),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3D6F8), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _StepBadge(number: 2),
              const SizedBox(width: 8),
              Text(
                'Desired Profit',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: '% Profit Margin',
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
          const SizedBox(height: 12),
          _FieldHint(
            text: isPercentage ? 'Profit Margin (%)' : 'Fixed Profit (SAR)',
          ),
          const SizedBox(height: 4),
          _AiInput(
            controller: profitController,
            hint: isPercentage ? '5' : '10',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onInputChanged(),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.categoryId,
    required this.preparationMinutes,
    required this.breakdown,
  });

  final String categoryId;
  final int preparationMinutes;
  final _AiPriceBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3D6F8), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Pricing Preview',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Category: ${_categoryLabel(categoryId)} | Prep: $preparationMinutes min',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (breakdown == null)
            Text(
              'Complete component rows and profit value to preview price.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: const Color(0xFF9AA1AF),
              ),
            )
          else ...[
            _PriceLine(
                label: 'Components Cost', value: breakdown!.ingredientsCost),
            const SizedBox(height: 5),
            _PriceLine(
                label: 'Packaging Cost', value: breakdown!.packagingCost),
            const SizedBox(height: 5),
            _PriceLine(
                label: 'Operational Cost', value: breakdown!.operationalCost),
            const SizedBox(height: 5),
            _PriceLine(label: 'Profit', value: breakdown!.profitAmount),
            const SizedBox(height: 5),
            _PriceLine(label: 'Demand Boost', value: breakdown!.demandBoost),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE9E4F5)),
            const SizedBox(height: 8),
            _PriceLine(
              label: 'Suggested Selling Price',
              value: breakdown!.suggestedPrice,
              emphasize: true,
            ),
          ],
        ],
      ),
    );
  }

  String _categoryLabel(String id) {
    return switch (id) {
      'northern' => 'Northern',
      'eastern' => 'Eastern',
      'southern' => 'Southern',
      'najdi' => 'Najdi',
      'western' => 'Western',
      'sweets' => 'Sweets',
      'baked' => 'Baked',
      _ => 'Other',
    };
  }
}

class _AiTopBar extends StatelessWidget {
  const _AiTopBar({
    required this.topPadding,
    required this.onBackTap,
  });

  final double topPadding;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topPadding + 10, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFBA9CFF), Color(0xFF8D82FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x338D82FF),
            blurRadius: 15,
            offset: Offset(0, 5),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  'AI Smart Pricing',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _InsightBox extends StatelessWidget {
  const _InsightBox({
    required this.background,
    required this.titleColor,
    required this.textColor,
    required this.title,
    required this.subtitle,
  });

  final Color background;
  final Color titleColor;
  final Color textColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.isBoost = false,
  });

  final String label;
  final double value;
  final bool emphasize;
  final bool isBoost;

  @override
  Widget build(BuildContext context) {
    final color = emphasize
        ? const Color(0xFF8A2CFF)
        : (isBoost ? const Color(0xFF1E8A5D) : AppColors.textPrimary);
    final fontWeight = emphasize ? FontWeight.w800 : FontWeight.w600;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          '${isBoost ? "+" : ""}${value.toStringAsFixed(2)} SAR',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: fontWeight,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Color(0xFF8A2CFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8A2CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF8E95A3),
          ),
        ),
      ),
    );
  }
}

class _FieldHint extends StatelessWidget {
  const _FieldHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11.2,
        color: const Color(0xFF9AA1AF),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _AiInput extends StatelessWidget {
  const _AiInput({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: const Color(0xFFB8BEC9),
        ),
        filled: true,
        fillColor: const Color(0xFFF0F2F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.homeChrome, width: 1.1),
        ),
      ),
    );
  }
}

class _IngredientDraft {
  _IngredientDraft({
    String name = '',
    String weightG = '',
    String costPer100 = '',
  })  : nameController = TextEditingController(text: name),
        weightController = TextEditingController(text: weightG),
        costController = TextEditingController(text: costPer100);

  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController costController;

  void dispose() {
    nameController.dispose();
    weightController.dispose();
    costController.dispose();
  }
}

class _IngredientCostItem {
  const _IngredientCostItem({
    required this.weightGram,
    required this.costPer100Sar,
  });

  final double weightGram;
  final double costPer100Sar;
}

class _AiPriceBreakdown {
  const _AiPriceBreakdown({
    required this.ingredientsCost,
    required this.packagingCost,
    required this.operationalCost,
    required this.profitAmount,
    required this.demandBoost,
    required this.suggestedPrice,
    required this.marketSignal,
    required this.insights,
  });

  final double ingredientsCost;
  final double packagingCost;
  final double operationalCost;
  final double profitAmount;
  final double demandBoost;
  final double suggestedPrice;
  final String marketSignal;
  final List<String> insights;
}
