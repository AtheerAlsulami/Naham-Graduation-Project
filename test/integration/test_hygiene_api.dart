/// Hygiene Inspection System – End-to-End Verification Script
///
/// Run with:
///   cd h:\work\naham_app\naham_app
///   dart run test_hygiene_api.dart
///
/// This script simulates:
///   1. Admin creates an inspection record  (POST /hygiene)
///   2. Verify the record appears           (GET  /hygiene?cookId=...)
///   3. Admin creates a surprise call       (POST /hygiene/call-requests)
///   4. Cook polls for pending calls        (GET  /hygiene/call-requests?cookId=...)
///   5. Cook accepts the call               (PUT  /hygiene/call-requests/{id})
///   6. Verify the call is no longer pending
///
/// Each step prints ✅ or ❌ with details so you can pinpoint failures.
// ignore_for_file: avoid_print

library;

import 'dart:convert';
import 'package:http/http.dart' as http;

// ──────────────────────────────────────────────────────────────────────────────
// CONFIGURATION – update this to match your API Gateway endpoint
// ──────────────────────────────────────────────────────────────────────────────
const String baseUrl =
    'https://qyu1ipfryh.execute-api.eu-north-1.amazonaws.com';

// Fake IDs for testing
const String testCookId = 'test_cook_001';
const String testCookName = 'Test Cook';
const String testAdminId = 'test_admin_001';
const String testAdminName = 'System Admin';

// ──────────────────────────────────────────────────────────────────────────────
int _passed = 0;
int _failed = 0;

void pass(String label, [String? detail]) {
  _passed++;
  print('  ✅ $label${detail != null ? ' → $detail' : ''}');
}

void fail(String label, String reason) {
  _failed++;
  print('  ❌ $label → $reason');
}

Future<http.Response> _get(String path, {Map<String, String>? queryParams}) {
  final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
  return http.get(uri, headers: {'Content-Type': 'application/json'});
}

Future<http.Response> _post(String path, Map<String, dynamic> body) {
  final uri = Uri.parse('$baseUrl$path');
  return http.post(uri,
      headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
}

Future<http.Response> _put(String path, Map<String, dynamic> body) {
  final uri = Uri.parse('$baseUrl$path');
  return http.put(uri,
      headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
}

dynamic _decode(http.Response res) {
  if (res.body.trim().isEmpty) return null;
  final decoded = jsonDecode(res.body);
  // Unwrap Lambda proxy wrapper if present
  if (decoded is Map &&
      decoded.containsKey('statusCode') &&
      decoded.containsKey('body')) {
    final nested = decoded['body'];
    if (nested is String) return jsonDecode(nested);
    return nested;
  }
  return decoded;
}

// ──────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final inspectionId = 'test_insp_$timestamp';
  final callRequestId = 'test_call_$timestamp';

  print('');
  print('╔══════════════════════════════════════════════════════╗');
  print('║  Naham Hygiene API – End-to-End Verification        ║');
  print('╠══════════════════════════════════════════════════════╣');
  print('║  Base URL: $baseUrl');
  print('║  Cook ID:  $testCookId');
  print('╚══════════════════════════════════════════════════════╝');
  print('');

  // ── Step 1: Save an inspection record ───────────────────────────────────
  print('── Step 1: Save inspection record (POST /hygiene) ──');
  try {
    final res = await _post('/hygiene', {
      'id': inspectionId,
      'cookId': testCookId,
      'cookName': testCookName,
      'decision': 'ready_and_clean',
      'inspectedAt': DateTime.now().toIso8601String(),
      'callDurationSeconds': 120,
      'adminId': testAdminId,
      'adminName': testAdminName,
      'note': 'Kitchen is spotless. Well done!',
    });

    if (res.statusCode >= 200 && res.statusCode < 300) {
      pass('POST /hygiene', 'Status ${res.statusCode}');
    } else {
      fail('POST /hygiene', 'Status ${res.statusCode}: ${res.body}');
    }
  } catch (e) {
    fail('POST /hygiene', 'Network error: $e');
  }

  // ── Step 2: List records for the cook ───────────────────────────────────
  print('');
  print('── Step 2: List inspection records (GET /hygiene?cookId=...) ──');
  try {
    final res = await _get('/hygiene', queryParams: {'cookId': testCookId});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = _decode(res);
      final records = data?['records'];
      if (records is List && records.isNotEmpty) {
        final found = records.any((r) => r['id'] == inspectionId);
        if (found) {
          pass(
              'GET /hygiene', '${records.length} records, test record found ✓');
        } else {
          fail('GET /hygiene',
              '${records.length} records returned but test record NOT found');
        }
      } else {
        fail('GET /hygiene', 'Empty records list or unexpected shape: $data');
      }
    } else {
      fail('GET /hygiene', 'Status ${res.statusCode}: ${res.body}');
    }
  } catch (e) {
    fail('GET /hygiene', 'Network error: $e');
  }

  // ── Step 3: Create a surprise call request ──────────────────────────────
  print('');
  print('── Step 3: Create call request (POST /hygiene/call-requests) ──');
  try {
    final res = await _post('/hygiene/call-requests', {
      'id': callRequestId,
      'cookId': testCookId,
      'cookName': testCookName,
      'adminId': testAdminId,
      'adminName': testAdminName,
      'requestedAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    });

    if (res.statusCode >= 200 && res.statusCode < 300) {
      pass('POST /hygiene/call-requests', 'Status ${res.statusCode}');
    } else {
      fail('POST /hygiene/call-requests',
          'Status ${res.statusCode}: ${res.body}');
    }
  } catch (e) {
    fail('POST /hygiene/call-requests', 'Network error: $e');
  }

  // ── Step 4: Cook polls for pending calls ────────────────────────────────
  print('');
  print(
      '── Step 4: Poll pending calls (GET /hygiene/call-requests?cookId=...) ──');
  try {
    final res = await _get('/hygiene/call-requests',
        queryParams: {'cookId': testCookId});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = _decode(res);
      final requests = data?['requests'];
      if (requests is List && requests.isNotEmpty) {
        final found = requests.any((r) => r['id'] == callRequestId);
        if (found) {
          pass('GET /hygiene/call-requests',
              '${requests.length} pending, test call found ✓');
        } else {
          fail('GET /hygiene/call-requests',
              '${requests.length} pending but test call NOT found');
        }
      } else {
        fail('GET /hygiene/call-requests',
            'Empty requests list or unexpected shape: $data');
      }
    } else {
      fail('GET /hygiene/call-requests',
          'Status ${res.statusCode}: ${res.body}');
    }
  } catch (e) {
    fail('GET /hygiene/call-requests', 'Network error: $e');
  }

  // ── Step 5: Cook accepts the call ───────────────────────────────────────
  print('');
  print(
      '── Step 5: Accept call (PUT /hygiene/call-requests/$callRequestId) ──');
  try {
    final res = await _put(
      '/hygiene/call-requests/$callRequestId',
      {'status': 'accepted'},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = _decode(res);
      final updatedStatus = data?['request']?['status'];
      if (updatedStatus == 'accepted') {
        pass('PUT call-requests', 'Status updated to "accepted" ✓');
      } else {
        pass('PUT call-requests',
            'Status ${res.statusCode} (response status: $updatedStatus)');
      }
    } else {
      fail('PUT call-requests', 'Status ${res.statusCode}: ${res.body}');
    }
  } catch (e) {
    fail('PUT call-requests', 'Network error: $e');
  }

  // ── Step 6: Verify call is no longer pending ────────────────────────────
  print('');
  print('── Step 6: Verify call no longer pending ──');
  try {
    final res = await _get('/hygiene/call-requests',
        queryParams: {'cookId': testCookId});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = _decode(res);
      final requests = data?['requests'] as List? ?? [];
      final stillPending = requests.any((r) => r['id'] == callRequestId);
      if (!stillPending) {
        pass('Pending check', 'Accepted call no longer in pending list ✓');
      } else {
        fail('Pending check',
            'Call is STILL in pending list after accepting it');
      }
    } else {
      fail('Pending check', 'Status ${res.statusCode}: ${res.body}');
    }
  } catch (e) {
    fail('Pending check', 'Network error: $e');
  }

  // ── Summary ─────────────────────────────────────────────────────────────
  print('');
  print('╔══════════════════════════════════════════════════════╗');
  print(
      '║  RESULTS: $_passed passed, $_failed failed${_failed == 0 ? '  🎉' : '  ⚠️'}');
  print('╚══════════════════════════════════════════════════════╝');
  print('');

  if (_failed > 0) {
    print('💡 Troubleshooting:');
    print('   1. Check that API Gateway routes are configured:');
    print('      GET  /hygiene          → hygieneList Lambda');
    print('      POST /hygiene          → hygieneSave Lambda');
    print(
        '      GET  /hygiene/call-requests         → hygieneCallRequests Lambda');
    print(
        '      POST /hygiene/call-requests         → hygieneCallRequests Lambda');
    print(
        '      PUT  /hygiene/call-requests/{id}    → hygieneCallRequests Lambda');
    print('   2. Check Lambda environment variables:');
    print('      HYGIENE_TABLE       = naham_hygiene');
    print('      HYGIENE_CALLS_TABLE = naham_hygiene_calls');
    print('   3. Check DynamoDB tables exist with partition key "id" (String)');
    print('   4. Check Lambda IAM role has DynamoDB read/write permissions');
    print('   5. Check CORS is enabled in API Gateway');
    print('');
  }
}
