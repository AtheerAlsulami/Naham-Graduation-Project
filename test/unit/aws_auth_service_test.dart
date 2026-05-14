import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/aws/aws_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AwsAuthService.login authenticates and persists the AWS session',
      () async {
    final authClient = _RecordingClient((request, body) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://auth.example.com/auth/login');
      expect(jsonDecode(body), {
        'email': 'customer@example.com',
        'password': 'secret123',
      });
      return _jsonResponse({
        'user': _userJson(
          id: 'customer_1',
          email: 'customer@example.com',
          role: AppConstants.roleCustomer,
        ),
        'accessToken': 'access_customer_1',
        'refreshToken': 'refresh_customer_1',
      });
    });
    final service = AwsAuthService(
      apiClient: AwsApiClient(
        baseUrl: 'https://auth.example.com',
        client: authClient,
      ),
      usersApiClient: AwsApiClient(
        baseUrl: 'https://users.example.com',
        client: _RecordingClient((_, __) async => _jsonResponse({})),
      ),
    );

    final user = await service.login(
      email: 'customer@example.com',
      password: 'secret123',
    );
    final stored = await service.getCurrentUser();
    final prefs = await SharedPreferences.getInstance();

    expect(user?.id, 'customer_1');
    expect(stored?.email, 'customer@example.com');
    expect(prefs.getString('aws_access_token'), 'access_customer_1');
    expect(prefs.getString('aws_refresh_token'), 'refresh_customer_1');
  });

  test('AwsAuthService.register sends role payload and persists cook status',
      () async {
    final authClient = _RecordingClient((request, body) async {
      expect(request.url.path, '/auth/register');
      expect(jsonDecode(body), {
        'name': 'Cook User',
        'email': 'cook@example.com',
        'password': 'secret123',
        'phone': '+966500000001',
        'role': AppConstants.roleCook,
      });
      return _jsonResponse({
        'user': _userJson(
          id: 'cook_1',
          name: 'Cook User',
          email: 'cook@example.com',
          role: AppConstants.roleCook,
          cookStatus: AppConstants.cookPendingVerification,
        ),
        'accessToken': 'access_cook_1',
      });
    });
    final service = AwsAuthService(
      apiClient: AwsApiClient(
        baseUrl: 'https://auth.example.com',
        client: authClient,
      ),
      usersApiClient: AwsApiClient(
        baseUrl: 'https://users.example.com',
        client: _RecordingClient((_, __) async => _jsonResponse({})),
      ),
    );

    final user = await service.register(
      name: 'Cook User',
      email: 'cook@example.com',
      password: 'secret123',
      phone: '+966500000001',
      role: AppConstants.roleCook,
    );
    final stored = await service.getCurrentUser();

    expect(user.cookStatus, AppConstants.cookPendingVerification);
    expect(stored?.role, AppConstants.roleCook);
    expect(stored?.cookStatus, AppConstants.cookPendingVerification);
  });

  test('AwsAuthService handles signed cook verification upload URL responses',
      () async {
    final usersClient = _RecordingClient((request, body) async {
      expect(request.method, 'POST');
      expect(
          request.url.toString(), 'https://users.example.com/users/upload-url');
      expect(jsonDecode(body), {
        'userId': 'cook_1',
        'documentType': 'health',
        'fileName': 'health.pdf',
        'contentType': 'application/pdf',
      });
      return _jsonResponse({
        'uploadUrl': 'https://s3.example.com/signed-health',
        'fileUrl': 'https://cdn.example.com/users/cook_1/health.pdf',
        'key': 'users/cook_1/verification/health/health.pdf',
        'headers': {'Content-Type': 'application/pdf'},
      });
    });
    final service = AwsAuthService(
      apiClient: AwsApiClient(
        baseUrl: 'https://auth.example.com',
        client: _RecordingClient((_, __) async => _jsonResponse({})),
      ),
      usersApiClient: AwsApiClient(
        baseUrl: 'https://users.example.com',
        client: usersClient,
      ),
    );

    final upload = await service.getUploadUrl(
      userId: 'cook_1',
      documentType: 'health',
      fileName: 'health.pdf',
      contentType: 'application/pdf',
    );

    expect(upload['uploadUrl'], startsWith('https://s3.example.com'));
    expect(upload['fileUrl'], contains('/cook_1/'));
    expect(upload['headers'], {'Content-Type': 'application/pdf'});
  });
}

Map<String, dynamic> _userJson({
  required String id,
  required String email,
  required String role,
  String name = 'Test User',
  String phone = '+966500000000',
  String? cookStatus,
}) {
  return {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'createdAt': '2026-05-11T00:00:00.000Z',
    if (cookStatus != null) 'cookStatus': cookStatus,
  };
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
