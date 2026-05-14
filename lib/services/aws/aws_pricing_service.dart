import 'dart:convert';

import 'package:naham_app/services/aws/aws_api_client.dart';

class PricingIngredientInput {
  const PricingIngredientInput({
    required this.weightGram,
    required this.costPer100Sar,
  });

  final double weightGram;
  final double costPer100Sar;

  Map<String, dynamic> toMap() {
    return {
      'weightGram': weightGram,
      'costPer100Sar': costPer100Sar,
    };
  }
}

class PricingBreakdown {
  const PricingBreakdown({
    required this.ingredientsCost,
    required this.packagingCost,
    required this.operationalCost,
    required this.profitAmount,
    required this.demandBoost,
    required this.baseCost,
  });

  final double ingredientsCost;
  final double packagingCost;
  final double operationalCost;
  final double profitAmount;
  final double demandBoost;
  final double baseCost;
}

class PricingSuggestion {
  const PricingSuggestion({
    required this.suggestedPrice,
    required this.breakdown,
    required this.marketSignal,
    required this.insights,
    this.confidenceScore,
  });

  final double suggestedPrice;
  final PricingBreakdown breakdown;
  final String marketSignal;
  final List<String> insights;
  final double? confidenceScore;
}

class AwsPricingService {
  AwsPricingService({required this.apiClient});

  final AwsApiClient apiClient;

  Map<String, dynamic> _asJsonMap(
    dynamic value, {
    required String context,
  }) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        throw Exception('Invalid $context: empty string.');
      }
      final decoded = jsonDecode(trimmed);
      return _asJsonMap(decoded, context: '$context (decoded from string)');
    }
    throw Exception('Invalid $context. Expected JSON object.');
  }

  dynamic _decodeResponsePayload(String bodyString) {
    final decoded = jsonDecode(bodyString);
    if (decoded is List && decoded.length == 1 && decoded.first is Map) {
      return decoded.first;
    }
    if (decoded is Map<String, dynamic> &&
        decoded.containsKey('statusCode') &&
        decoded.containsKey('body') &&
        !decoded.containsKey('suggestedPrice') &&
        !decoded.containsKey('breakdown')) {
      final nested = decoded['body'];
      if (nested is String) {
        return jsonDecode(nested);
      }
      return nested;
    }
    return decoded;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  Future<PricingSuggestion> suggestPrice({
    required String categoryId,
    required int preparationMinutes,
    required List<PricingIngredientInput> ingredients,
    required String profitMode,
    required double profitValue,
    double? currentPrice,
  }) async {
    final response = await apiClient.post(
      '/pricing/suggest',
      body: {
        'categoryId': categoryId,
        'preparationMinutes': preparationMinutes,
        'ingredients': ingredients.map((item) => item.toMap()).toList(),
        'profitMode': profitMode,
        'profitValue': profitValue,
        if (currentPrice != null) 'currentPrice': currentPrice,
      },
    );

    final payload = _decodeResponsePayload(response.body);
    final body = _asJsonMap(payload, context: 'pricing suggestion response');
    final breakdownJson =
        _asJsonMap(body['breakdown'], context: 'pricing breakdown');
    final metadataJson =
        _asJsonMap(body['metadata'] ?? const {}, context: 'pricing metadata');

    final insightsRaw = metadataJson['insights'];
    final insights = insightsRaw is List
        ? insightsRaw.map((item) => item.toString()).toList()
        : const <String>[];

    return PricingSuggestion(
      suggestedPrice: _asDouble(body['suggestedPrice']),
      breakdown: PricingBreakdown(
        ingredientsCost: _asDouble(breakdownJson['ingredientsCost']),
        packagingCost: _asDouble(breakdownJson['packagingCost']),
        operationalCost: _asDouble(breakdownJson['operationalCost']),
        profitAmount: _asDouble(breakdownJson['profitAmount']),
        demandBoost: _asDouble(breakdownJson['demandBoost']),
        baseCost: _asDouble(breakdownJson['baseCost']),
      ),
      marketSignal: metadataJson['marketSignal']?.toString() ?? '',
      confidenceScore: metadataJson.containsKey('confidenceScore')
          ? _asDouble(metadataJson['confidenceScore'])
          : null,
      insights: insights,
    );
  }
}
