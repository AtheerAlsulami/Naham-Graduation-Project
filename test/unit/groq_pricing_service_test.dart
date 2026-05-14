import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naham_app/services/aws/aws_pricing_service.dart';
import 'package:naham_app/services/backend/groq_pricing_service.dart';

void main() {
  test('GroqPricingService posts chat completion and parses suggested price',
      () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;
    late Map<String, dynamic> capturedBody;

    final service = GroqPricingService(
      apiKey: 'gsk_test_key',
      model: 'llama-3.1-8b-instant',
      client: MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      'Suggested price: 42.50 SAR\nReasoning: سعر مناسب للسوق.'
                }
              }
            ]
          })),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );

    final suggestion = await service.suggestPrice(
      categoryId: 'baked',
      preparationMinutes: 33,
      ingredients: const [
        PricingIngredientInput(weightGram: 394, costPer100Sar: 4),
        PricingIngredientInput(weightGram: 300, costPer100Sar: 4),
      ],
      profitMode: 'percentage',
      profitValue: 21,
    );

    expect(capturedUri.toString(),
        'https://api.groq.com/openai/v1/chat/completions');
    final normalizedHeaders = capturedHeaders.map(
      (key, value) => MapEntry(key.toLowerCase(), value),
    );
    expect(normalizedHeaders['authorization'], 'Bearer gsk_test_key');
    expect(capturedBody['model'], 'llama-3.1-8b-instant');
    expect(capturedBody['messages'], isA<List<dynamic>>());
    expect(suggestion.suggestedPrice, 42.5);
    expect(suggestion.marketSignal, 'groq_direct');
    expect(suggestion.breakdown.ingredientsCost, closeTo(27.76, 0.01));
    expect(suggestion.insights.first, contains('سعر مناسب'));
  });
}
