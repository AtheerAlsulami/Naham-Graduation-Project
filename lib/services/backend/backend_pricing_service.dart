import 'package:naham_app/services/aws/aws_pricing_service.dart';
import 'package:naham_app/services/backend/backend_config.dart';
import 'package:naham_app/services/backend/backend_factory.dart';
import 'package:naham_app/services/backend/groq_pricing_service.dart';

class BackendPricingService {
  BackendPricingService()
      : _awsPricingService = AwsPricingService(
          apiClient: BackendFactory.createAwsPricingApiClient(),
        ),
        _groqPricingService = GroqPricingService(
          apiKey: BackendConfig.groqApiKey,
          model: BackendConfig.groqModel,
        );

  final AwsPricingService _awsPricingService;
  final GroqPricingService _groqPricingService;

  Future<PricingSuggestion> suggestPrice({
    required String categoryId,
    required int preparationMinutes,
    required List<PricingIngredientInput> ingredients,
    required String profitMode,
    required double profitValue,
    double? currentPrice,
  }) async {
    final provider = BackendConfig.pricingAiProvider.trim().toLowerCase();
    if (provider == 'groqdirect' || provider == 'groq') {
      return _groqPricingService.suggestPrice(
        categoryId: categoryId,
        preparationMinutes: preparationMinutes,
        ingredients: ingredients,
        profitMode: profitMode,
        profitValue: profitValue,
        currentPrice: currentPrice,
      );
    }

    try {
      return _awsPricingService.suggestPrice(
        categoryId: categoryId,
        preparationMinutes: preparationMinutes,
        ingredients: ingredients,
        profitMode: profitMode,
        profitValue: profitValue,
        currentPrice: currentPrice,
      );
    } catch (_) {
      return _localSuggestPrice(
        categoryId: categoryId,
        preparationMinutes: preparationMinutes,
        ingredients: ingredients,
        profitMode: profitMode,
        profitValue: profitValue,
      );
    }
  }

  Future<PricingSuggestion> suggestPriceV2({
    required String categoryId,
    required int preparationMinutes,
    required String dishDescription,
    required String profitMode,
    required double profitValue,
    double? currentPrice,
  }) async {
    final provider = BackendConfig.pricingAiProvider.trim().toLowerCase();
    if (provider == 'groqdirect' || provider == 'groq') {
      return _groqPricingService.suggestPriceV2(
        categoryId: categoryId,
        preparationMinutes: preparationMinutes,
        dishDescription: dishDescription,
        profitMode: profitMode,
        profitValue: profitValue,
        currentPrice: currentPrice,
      );
    }

    // Fallback to local logic if Groq is not selected or fails
    return _localSuggestPrice(
      categoryId: categoryId,
      preparationMinutes: preparationMinutes,
      ingredients: const [],
      profitMode: profitMode,
      profitValue: profitValue,
    );
  }

  PricingSuggestion _localSuggestPrice({
    required String categoryId,
    required int preparationMinutes,
    required List<PricingIngredientInput> ingredients,
    required String profitMode,
    required double profitValue,
  }) {
    final ingredientsCost = ingredients.fold<double>(
      0,
      (sum, item) => sum + ((item.weightGram / 100) * item.costPer100Sar),
    );
    final packCost = _packagingCost(
      categoryId,
      ingredientsCount: ingredients.length,
      ingredientsCost: ingredientsCost,
    );
    final prepOperationalCost = (preparationMinutes.clamp(5, 240) / 60.0) * 4.0;
    final opsCost = prepOperationalCost + _categoryOperationalCost(categoryId);
    final baseCost = ingredientsCost + packCost + opsCost;
    final normalizedMode = profitMode.trim().toLowerCase();
    final profitAmount =
        normalizedMode == 'fixedamount' || normalizedMode == 'fixed'
            ? profitValue.clamp(0, 5000).toDouble()
            : baseCost * (profitValue.clamp(0, 250).toDouble() / 100);
    final boost = _demandBoost(categoryId, baseCost + profitAmount);
    final suggestedPrice =
        (baseCost + profitAmount + boost).clamp(1, 5000).toDouble();

    return PricingSuggestion(
      suggestedPrice: suggestedPrice,
      breakdown: PricingBreakdown(
        ingredientsCost: ingredientsCost,
        packagingCost: packCost,
        operationalCost: opsCost,
        profitAmount: profitAmount,
        demandBoost: boost,
        baseCost: baseCost,
      ),
      marketSignal: 'local_simulated',
      confidenceScore: 0.95,
      insights: const [
        'Price analysis is based on current ingredient costs and the target profit margin.',
        'A market boost was added based on the dish category.',
        'The suggested price covers operating and packaging costs.',
      ],
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
}
