import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/services/aws/aws_admin_user_service.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';

void main() {
  test('listUsers maps cook online status from backend payload', () async {
    final service = AwsAdminUserService(
      apiClient: AwsApiClient(
        baseUrl: 'https://users.example.com',
        client: _RecordingClient((request, body) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/users');
          return _jsonResponse({
            'items': [
              {
                'id': 'cook_1',
                'name': 'Online Cook',
                'email': 'cook@example.com',
                'phone': '+966500000001',
                'role': AppConstants.roleCook,
                'status': 'active',
                'cookStatus': AppConstants.cookApproved,
                'isOnline': true,
              },
            ],
          });
        }),
      ),
    );

    final users = await service.listUsers(role: AppConstants.roleCook);

    expect(users, hasLength(1));
    expect(users.single.isOnline, isTrue);
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
