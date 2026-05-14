import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:naham_app/models/hygiene_inspection_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';

class AwsHygieneService {
  AwsHygieneService({required this.apiClient});

  final AwsApiClient apiClient;

  /// Unwraps AWS API Gateway / Lambda proxy responses.
  /// Handles both direct JSON and the nested {statusCode, body} wrapper.
  Map<String, dynamic> _decodeResponsePayload(String bodyString) {
    if (bodyString.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(bodyString);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('statusCode') &&
          decoded.containsKey('body')) {
        final nested = decoded['body'];
        if (nested is String) {
          final inner = jsonDecode(nested);
          if (inner is Map<String, dynamic>) return inner;
          return <String, dynamic>{'data': inner};
        }
        if (nested is Map<String, dynamic>) return nested;
        return <String, dynamic>{};
      }
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'data': decoded};
    } catch (e) {
      debugPrint('AwsHygieneService._decodeResponsePayload error: $e');
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic> _toStringKeyMap(dynamic item) {
    if (item is Map<String, dynamic>) return item;
    if (item is Map) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  // ─── Records ──────────────────────────────────────────────────────────

  Future<List<HygieneInspectionRecord>> getRecords({String? cookId}) async {
    try {
      final response = await apiClient.get(
        '/hygiene',
        queryParameters: cookId != null ? {'cookId': cookId} : null,
      );
      final payload = _decodeResponsePayload(response.body);
      final List<dynamic> items = payload['records'] ?? [];
      return items
          .map((item) => HygieneInspectionRecord.fromMap(_toStringKeyMap(item)))
          .toList();
    } catch (e) {
      debugPrint('AwsHygieneService.getRecords error: $e');
      return <HygieneInspectionRecord>[];
    }
  }

  Future<void> saveRecord(HygieneInspectionRecord record) async {
    try {
      await apiClient.post(
        '/hygiene',
        body: record.toMap(),
      );
    } catch (e) {
      debugPrint('AwsHygieneService.saveRecord error: $e');
      rethrow;
    }
  }

  // ─── Call Requests ────────────────────────────────────────────────────

  Future<HygieneInspectionCallRequest> createCallRequest(
    HygieneInspectionCallRequest request,
  ) async {
    try {
      final response = await apiClient.post(
        '/hygiene/call-requests',
        body: request.toMap(),
      );
      final payload = _decodeResponsePayload(response.body);
      final rawRequest = payload['request'];
      if (rawRequest != null) {
        return HygieneInspectionCallRequest.fromMap(
          _toStringKeyMap(rawRequest),
        );
      }
      // If the backend echoes back a different shape, fall back to the
      // original request object (it was already saved server-side).
      return request;
    } catch (e) {
      debugPrint('AwsHygieneService.createCallRequest error: $e');
      // Return the original request so the caller still has a valid object.
      return request;
    }
  }

  Future<void> updateCallRequestStatus(
    String requestId,
    String status,
  ) async {
    try {
      await apiClient.put(
        '/hygiene/call-requests/$requestId',
        body: {'status': status},
      );
    } catch (e) {
      debugPrint('AwsHygieneService.updateCallRequestStatus error: $e');
      // Best-effort. UI state has already been updated locally.
    }
  }

  Future<List<HygieneInspectionCallRequest>> getPendingCallRequests(
    String cookId,
  ) async {
    try {
      final response = await apiClient.get(
        '/hygiene/call-requests',
        queryParameters: {'cookId': cookId},
      );
      final payload = _decodeResponsePayload(response.body);
      final List<dynamic> items = payload['requests'] ?? [];
      return items
          .map((item) =>
              HygieneInspectionCallRequest.fromMap(_toStringKeyMap(item)))
          .toList();
    } catch (e) {
      debugPrint('AwsHygieneService.getPendingCallRequests error: $e');
      return <HygieneInspectionCallRequest>[];
    }
  }
}
