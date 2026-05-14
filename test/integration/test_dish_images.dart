// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Quick diagnostic to see what image URLs the backend returns for dishes
/// and test whether they are accessible.
void main() async {
  const baseUrl = 'https://yn6aki3dgl.execute-api.eu-north-1.amazonaws.com';

  print('╔══════════════════════════════════════════════════╗');
  print('║  Dish Image URL Diagnostic                      ║');
  print('╠══════════════════════════════════════════════════╣');
  print('║  Base URL: $baseUrl');
  print('╚══════════════════════════════════════════════════╝');
  print('');

  // Step 1: Load all dishes
  print('── Step 1: Fetching dishes from backend ──');
  try {
    final resp = await http.get(
      Uri.parse('$baseUrl/dishes?limit=10&sort=newest'),
      headers: {'Content-Type': 'application/json'},
    );

    print('  Status: ${resp.statusCode}');

    dynamic decoded = jsonDecode(resp.body);

    // Unwrap proxy envelope if present
    if (decoded is Map &&
        decoded.containsKey('statusCode') &&
        decoded.containsKey('body')) {
      decoded = decoded['body'];
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
    }

    // Extract items list
    List dishes;
    if (decoded is List) {
      dishes = decoded;
    } else if (decoded is Map) {
      dishes = (decoded['items'] ?? decoded['dishes'] ?? decoded['data'] ?? [])
          as List;
    } else {
      print('  ⚠ Unexpected response type: ${decoded.runtimeType}');
      return;
    }

    print('  Found ${dishes.length} dishes');
    print('');

    if (dishes.isEmpty) {
      print('  ℹ No dishes found - nothing to test.');
      return;
    }

    // Step 2: Inspect image fields
    print('── Step 2: Inspecting image fields ──');
    for (int i = 0; i < dishes.length && i < 5; i++) {
      final dish = dishes[i] as Map<String, dynamic>;
      final name = dish['name'] ?? '(no name)';
      final imageUrl = (dish['imageUrl'] ?? '').toString();
      final imageKey = (dish['imageKey'] ?? dish['image_key'] ?? '').toString();

      print('');
      print('  Dish ${i + 1}: $name');
      print('    imageUrl: ${imageUrl.isEmpty ? "(empty)" : imageUrl}');
      print('    imageKey: ${imageKey.isEmpty ? "(empty)" : imageKey}');

      // Step 3: Test if image URL is accessible
      if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
        try {
          final imgResp = await http
              .head(
                Uri.parse(imageUrl),
              )
              .timeout(const Duration(seconds: 10));
          final status = imgResp.statusCode;
          final contentType = imgResp.headers['content-type'] ?? 'unknown';

          if (status >= 200 && status < 300) {
            print('    ✅ Image accessible (HTTP $status, type: $contentType)');
          } else if (status == 403) {
            print(
                '    ❌ Image FORBIDDEN (HTTP 403) - S3 bucket/object not public!');
          } else if (status == 404) {
            print('    ❌ Image NOT FOUND (HTTP 404) - Object does not exist');
          } else {
            print('    ⚠ Image response: HTTP $status');
          }
        } catch (e) {
          print('    ❌ Failed to reach image URL: $e');
        }
      } else if (imageUrl.isEmpty) {
        print('    ⚠ No imageUrl stored - image was never uploaded');
      } else {
        print('    ⚠ imageUrl is not a valid HTTP URL: $imageUrl');
      }
    }

    print('');
    print('── Summary ──');
    final withImage =
        dishes.where((d) => (d['imageUrl'] ?? '').toString().isNotEmpty).length;
    final withKey = dishes
        .where((d) =>
            (d['imageKey'] ?? d['image_key'] ?? '').toString().isNotEmpty)
        .length;
    print('  Dishes with imageUrl: $withImage/${dishes.length}');
    print('  Dishes with imageKey: $withKey/${dishes.length}');
  } catch (e) {
    print('  ❌ Error: $e');
  }
}
