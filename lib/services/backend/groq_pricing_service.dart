import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:naham_app/services/aws/aws_pricing_service.dart';

class GroqPricingService {
  GroqPricingService({
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static final Uri _chatCompletionsUri = Uri.parse(
    'https://api.groq.com/openai/v1/chat/completions',
  );

  final String apiKey;
  final String model;
  final http.Client _client;

  Future<PricingSuggestion> suggestPrice({
    required String categoryId,
    required int preparationMinutes,
    required List<PricingIngredientInput> ingredients,
    required String profitMode,
    required double profitValue,
    double? currentPrice,
  }) async {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw Exception(
        'GROQ_API_KEY is missing. Run with --dart-define=GROQ_API_KEY=...',
      );
    }
    if (!normalizedKey.startsWith('gsk_')) {
      throw Exception('GROQ_API_KEY format is invalid.');
    }

    final prompt = _buildPrompt(
      categoryId: categoryId,
      preparationMinutes: preparationMinutes,
      ingredients: ingredients,
      profitMode: profitMode,
      profitValue: profitValue,
      currentPrice: currentPrice,
    );

    final response = await _client.post(
      _chatCompletionsUri,
      headers: {
        'Authorization': 'Bearer $normalizedKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model.trim().isEmpty ? 'llama-3.1-8b-instant' : model.trim(),
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.4,
        'max_completion_tokens': 700,
      }),
    );
    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Groq pricing failed (${response.statusCode}): '
        '${_extractErrorMessage(responseBody)}',
      );
    }

    final content = _extractAssistantText(responseBody);
    final suggestedPrice = _parseSuggestedPrice(content);
    if (suggestedPrice == null || suggestedPrice <= 0) {
      throw Exception('Groq pricing returned an unparseable price.');
    }

    final breakdown = _calculateBreakdown(
      categoryId: categoryId,
      preparationMinutes: preparationMinutes,
      ingredients: ingredients,
      profitMode: profitMode,
      profitValue: profitValue,
    );

    return PricingSuggestion(
      suggestedPrice: suggestedPrice.clamp(1, 5000).toDouble(),
      breakdown: breakdown,
      marketSignal: 'groq_direct',
      confidenceScore: 0.86,
      insights: _buildInsights(categoryId, content),
    );
  }

  String _buildPrompt({
    required String categoryId,
    required int preparationMinutes,
    required List<PricingIngredientInput> ingredients,
    required String profitMode,
    required double profitValue,
    double? currentPrice,
  }) {
    final totalIngredientsCost = ingredients.fold<double>(
      0,
      (sum, item) => sum + (item.weightGram / 100) * item.costPer100Sar,
    );
    final ingredientsText = ingredients
        .map(
          (item) =>
              '- ${item.weightGram}g costs ${((item.weightGram / 100) * item.costPer100Sar).toStringAsFixed(2)} SAR',
        )
        .join('\n');

    return '''
You are a pricing expert for a food delivery app in Saudi Arabia.
Suggest a fair market price for this dish.

Category: $categoryId
Preparation time: $preparationMinutes minutes
Ingredients cost: ${totalIngredientsCost.toStringAsFixed(2)} SAR
Ingredients:
$ingredientsText
Profit mode: $profitMode
Profit value: $profitValue ${profitMode == 'percentage' ? '%' : 'SAR'}
Current price: ${currentPrice == null || currentPrice <= 0 ? 'Not set' : '${currentPrice.toStringAsFixed(2)} SAR'}

Consider Saudi market rates, packaging, delivery-platform pressure,
competitor pricing, customer expectations, and profit margin.

Reply exactly in this format:
Suggested price: [number] SAR
Reasoning: [brief Arabic explanation]
'''
        .trim();
  }

  String _extractAssistantText(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw Exception('Invalid Groq response.');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('Groq response has no choices.');
    }

    final first = choices.first;
    if (first is! Map) {
      throw Exception('Invalid Groq choice.');
    }

    final message = first['message'];
    if (message is Map && message['content'] is String) {
      final content = (message['content'] as String).trim();
      if (content.isNotEmpty) return content;
    }

    throw Exception('Groq response has no assistant content.');
  }

  String _extractErrorMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return 'Empty response body';

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        if (decoded['message'] is String) {
          return decoded['message'] as String;
        }
      }
    } catch (_) {
      // Return the raw body below.
    }

    return trimmed;
  }

  double? _parseSuggestedPrice(String content) {
    final explicit = RegExp(
      r'suggested price[:\s]*(\d+(?:[.,]\d+)?)',
      caseSensitive: false,
    ).firstMatch(content);
    final rawNumber = explicit?.group(1) ??
        RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(content)?.group(1);

    if (rawNumber == null) return null;
    return double.tryParse(rawNumber.replaceAll(',', '.'));
  }

  PricingBreakdown _calculateBreakdown({
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

    return PricingBreakdown(
      ingredientsCost: ingredientsCost,
      packagingCost: packCost,
      operationalCost: opsCost,
      profitAmount: profitAmount,
      demandBoost: boost,
      baseCost: baseCost,
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

  List<String> _buildInsights(String categoryId, String aiReasoning) {
    final trimmedReasoning = aiReasoning.trim();
    return [
      if (trimmedReasoning.isNotEmpty) trimmedReasoning,
      ...switch (categoryId) {
        'sweets' || 'najdi' => const [
            'High demand potential in this category.',
            'A small market premium may be acceptable.',
          ],
        'baked' => const [
            'Demand is stable; balanced pricing is recommended.',
            'Packaging quality can increase perceived value.',
          ],
        _ => const [
            'Keep the price competitive to improve conversion.',
            'Use strong photos and a clear dish description.',
          ],
      },
    ];
  }
}
