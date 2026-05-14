// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl =
      'https://yn6aki3dgl.execute-api.eu-north-1.amazonaws.com/pricing/suggest';
  final random = Random();

  final categories = ['sweets', 'baked', 'najdi', 'western'];
  final category = categories[random.nextInt(categories.length)];
  final prepTime = 15 + random.nextInt(100);

  // Generate 2-4 random ingredients
  final ingredients = List.generate(
      2 + random.nextInt(3),
      (index) => {
            'weightGram': 50 + random.nextInt(450),
            'costPer100Sar': 2.0 + random.nextDouble() * 15.0,
          });

  final requestBody = {
    'categoryId': category,
    'preparationMinutes': prepTime,
    'ingredients': ingredients,
    'profitMode': 'percentage',
    'profitValue': 10 + random.nextInt(20),
    'currentPrice': random.nextBool() ? 40.0 + random.nextInt(60) : null,
  };

  if (kDebugMode) {
    print('--- Testing Pricing Suggestion API ---');
  }
  print('Target URL: $baseUrl');
  print('Input Data: ${jsonEncode(requestBody)}');
  print('--------------------------------------');

  try {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    print('Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Success! Result:');
      print('Suggested Price: ${data['suggestedPrice']} SAR');
      print('Market Signal: ${data['metadata']?['marketSignal']}');
      print('AI Insights:');
      final insights = data['metadata']?['insights'];
      if (insights is List) {
        for (var insight in insights) {
          print(' - $insight');
        }
      }
      print(
          'AI Reasoning Snippet: ${data['aiReasoning']?.toString().substring(0, min(100, data['aiReasoning']?.toString().length ?? 0))}...');
    } else {
      print('Failed with error:');
      print(response.body);
    }
  } catch (e) {
    print('Error occurred while testing: $e');
  }
}
