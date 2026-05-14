// ignore_for_file: avoid_print

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('Creating test image...');
  final testImage = File('test_profile_image.jpg');
  await testImage.writeAsBytes(
      [255, 216, 255, 219, 0, 67, 0, 255, 217]); // Dummy valid JPEG

  try {
    print('1. Getting upload URL...');
    const dishesApiUrl =
        'https://yn6aki3dgl.execute-api.eu-north-1.amazonaws.com';

    final response = await http.post(
      Uri.parse('$dishesApiUrl/dishes/upload-url'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'dishId': 'profile_test',
        'fileName': 'test_profile_image.jpg',
        'contentType': 'image/jpeg',
      }),
    );

    print('Upload URL Response Code: ${response.statusCode}');
    print('Upload URL Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      dynamic payload = jsonDecode(response.body);
      if (payload is Map &&
          payload.containsKey('statusCode') &&
          payload.containsKey('body')) {
        payload = payload['body'];
        if (payload is String) payload = jsonDecode(payload);
      }

      final uploadUrl = payload['uploadUrl'] as String;
      final fileUrl = payload['fileUrl'] as String;
      final headers = payload['headers'] as Map<String, dynamic>? ?? {};

      print('Parsed Upload URL: $uploadUrl');
      print('Parsed File URL: $fileUrl');
      print('Headers: $headers');

      print('2. Uploading image to S3...');
      final Map<String, String> stringHeaders = {};
      headers.forEach((k, v) => stringHeaders[k] = v.toString());

      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: stringHeaders,
        body: await testImage.readAsBytes(),
      );

      print('S3 Upload Response Code: ${uploadResponse.statusCode}');
      if (uploadResponse.statusCode != 200) {
        print('S3 Upload Error: ${uploadResponse.body}');
      } else {
        print('✅ Image uploaded successfully!');
      }
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    if (await testImage.exists()) {
      await testImage.delete();
    }
  }
}
