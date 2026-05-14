import 'dart:convert';

import 'package:http/http.dart' as http;

class AwsApiClient {
  AwsApiClient({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  final String baseUrl;
  final http.Client client;

  Uri _buildUri(String path, [Map<String, String?>? queryParameters]) {
    final uri = Uri.parse(baseUrl + path);
    if (queryParameters != null) {
      return uri.replace(
          queryParameters: {
        ...queryParameters,
      }..removeWhere((key, value) => value == null));
    }
    return uri;
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String?>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final response = await client.get(uri, headers: headers);
    _validateResponse(response, requestUri: uri);
    return response;
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final uri = _buildUri(path);
    final response = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: body == null ? null : jsonEncode(body),
      encoding: encoding,
    );
    _validateResponse(response, requestUri: uri);
    return response;
  }

  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final uri = _buildUri(path);
    final response = await client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: body == null ? null : jsonEncode(body),
      encoding: encoding,
    );
    _validateResponse(response, requestUri: uri);
    return response;
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final uri = _buildUri(path);
    final response = await client.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: body == null ? null : jsonEncode(body),
      encoding: encoding,
    );
    _validateResponse(response, requestUri: uri);
    return response;
  }

  void _validateResponse(
    http.Response response, {
    required Uri requestUri,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AwsApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response.body),
        requestUrl: requestUri.toString(),
      );
    }
  }

  String _extractErrorMessage(String body) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return 'Empty error response from API Gateway. '
          'Check Lambda handler/integration configuration.';
    }
    try {
      final data = jsonDecode(trimmedBody);
      if (data is Map<String, dynamic> && data['message'] is String) {
        final message = data['message'] as String;
        final detail = data['error'];
        if (detail is String && detail.trim().isNotEmpty) {
          return '$message: ${detail.trim()}';
        }
        return message;
      }
      if (data is Map<String, dynamic> && data['body'] is String) {
        final nestedRaw = data['body'] as String;
        final nested = jsonDecode(nestedRaw);
        if (nested is Map<String, dynamic> && nested['message'] is String) {
          final message = nested['message'] as String;
          final detail = nested['error'];
          if (detail is String && detail.trim().isNotEmpty) {
            return '$message: ${detail.trim()}';
          }
          return message;
        }
      }
      if (data is List && data.isNotEmpty && data.first is Map) {
        final first = data.first as Map;
        final rawMessage = first['message'];
        if (rawMessage is String && rawMessage.trim().isNotEmpty) {
          return rawMessage.trim();
        }
      }
    } catch (_) {
      // ignore
    }
    return trimmedBody;
  }
}

class AwsApiException implements Exception {
  AwsApiException({
    required this.statusCode,
    required this.message,
    this.requestUrl,
  });

  final int statusCode;
  final String message;
  final String? requestUrl;

  @override
  String toString() {
    final url = requestUrl;
    if (url == null || url.isEmpty) {
      return 'AwsApiException($statusCode): $message';
    }
    return 'AwsApiException($statusCode): $message [url: $url]';
  }
}
