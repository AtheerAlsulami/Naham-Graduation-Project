import 'dart:convert';

import 'package:naham_app/models/hygiene_inspection_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HygieneInspectionStorageService {
  static const String _storageKey = 'hygiene_inspection_records_v1';
  static const String _callRequestsStorageKey =
      'hygiene_inspection_call_requests_v1';

  Future<List<HygieneInspectionRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_storageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const <HygieneInspectionRecord>[];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return const <HygieneInspectionRecord>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => HygieneInspectionRecord.fromMap(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ))
          .toList();
    } catch (_) {
      return const <HygieneInspectionRecord>[];
    }
  }

  Future<void> saveRecords(List<HygieneInspectionRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = records.map((item) => item.toMap()).toList();
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  Future<List<HygieneInspectionCallRequest>> loadCallRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_callRequestsStorageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const <HygieneInspectionCallRequest>[];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return const <HygieneInspectionCallRequest>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => HygieneInspectionCallRequest.fromMap(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      return const <HygieneInspectionCallRequest>[];
    }
  }

  Future<void> saveCallRequests(
    List<HygieneInspectionCallRequest> callRequests,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = callRequests.map((item) => item.toMap()).toList();
    await prefs.setString(_callRequestsStorageKey, jsonEncode(payload));
  }
}
