import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/aws/aws_pricing_service.dart';

void main() {
  test('AwsPricingService parses Lambda pricing response and metadata',
      () async {
    final client = _RecordingClient((request, body) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/pricing/suggest');
      final payload = jsonDecode(body) as Map<String, dynamic>;
      expect(payload['categoryId'], 'najdi');
      expect(payload['ingredients'], hasLength(2));
      return _jsonResponse({
        'suggestedPrice': 44.5,
        'breakdown': {
          'ingredientsCost': 18.0,
          'packagingCost': 1.2,
          'operationalCost': 7.5,
          'profitAmount': 8.0,
          'demandBoost': 2.0,
          'baseCost': 26.7,
        },
        'metadata': {
          'marketSignal': 'high_demand',
          'confidenceScore': 0.85,
          'insights': ['High demand potential in this category.'],
        },
      });
    });
    final service = AwsPricingService(
      apiClient: AwsApiClient(
        baseUrl: 'https://pricing.example.com',
        client: client,
      ),
    );

    final suggestion = await service.suggestPrice(
      categoryId: 'najdi',
      preparationMinutes: 45,
      ingredients: const [
        PricingIngredientInput(weightGram: 300, costPer100Sar: 4),
        PricingIngredientInput(weightGram: 200, costPer100Sar: 3),
      ],
      profitMode: 'percentage',
      profitValue: 25,
    );

    expect(suggestion.suggestedPrice, 44.5);
    expect(suggestion.breakdown.baseCost, 26.7);
    expect(suggestion.marketSignal, 'high_demand');
    expect(suggestion.insights.single, contains('High demand'));
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request, String body)
      handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final response = await handler(request, body);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
