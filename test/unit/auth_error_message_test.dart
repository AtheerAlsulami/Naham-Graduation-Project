import 'package:flutter_test/flutter_test.dart';
import 'package:naham_app/providers/auth_error_message.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';

void main() {
  test('formats duplicate email errors without API details', () {
    final message = formatAuthErrorMessage(
      AwsApiException(
        statusCode: 409,
        message: 'Email already exists.',
        requestUrl: 'https://example.com/auth/register',
      ),
    );

    expect(message, 'هذا البريد الإلكتروني مستخدم بالفعل.');
    expect(message, isNot(contains('AwsApiException')));
    expect(message, isNot(contains('https://')));
  });

  test('formats invalid login credentials', () {
    expect(
      formatAuthErrorMessage(
        AwsApiException(
          statusCode: 401,
          message: 'Invalid credentials.',
          requestUrl: 'https://example.com/auth/login',
        ),
      ),
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
    );
  });

  test('formats raw exception strings from older call sites', () {
    final message = formatAuthErrorMessage(
      'AwsApiException(404): No account found for this email. Create a new account first. [url: https://example.com/auth/login]',
    );

    expect(message, 'لا يوجد حساب بهذا البريد الإلكتروني.');
    expect(message, isNot(contains('url:')));
  });
}
