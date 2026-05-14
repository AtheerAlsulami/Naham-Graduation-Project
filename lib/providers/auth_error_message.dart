import 'package:naham_app/services/aws/aws_api_client.dart';

String formatAuthErrorMessage(Object error) {
  final raw = _cleanRawError(error);
  final normalized = raw.toLowerCase();

  if (normalized.contains('email already exists') ||
      normalized.contains('already exists') ||
      normalized.contains('already registered')) {
    return 'This email address is already in use.';
  }

  if (normalized.contains('invalid credentials') ||
      normalized.contains('email or password is incorrect')) {
    return 'The email address or password is incorrect.';
  }

  if (normalized.contains('no account found')) {
    return 'No account exists for this email address.';
  }

  if (normalized.contains('created with google') ||
      normalized.contains('use continue with google')) {
    return 'This account uses Google sign-in. Continue with Google instead.';
  }

  if (normalized.contains('registered with password') ||
      normalized.contains('use email login')) {
    return 'This email is already registered. Sign in with email and password.';
  }

  if (normalized.contains('missing required') ||
      normalized.contains('required fields')) {
    return 'Please complete all required fields.';
  }

  if (normalized.contains('password must be at least')) {
    return 'Password must be at least 6 characters.';
  }

  if (normalized.contains('invalid email')) {
    return 'Please enter a valid email address.';
  }

  if (normalized.contains('socketexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('connection refused') ||
      normalized.contains('timed out')) {
    return 'Unable to connect to the server. Check your internet connection and try again.';
  }

  if (normalized.contains('internal server error')) {
    return 'A server error occurred. Please try again later.';
  }

  if (normalized.contains('google sign-in failed') ||
      normalized.contains('google account selection failed')) {
    return 'Unable to complete Google sign-in. Please try again.';
  }

  return raw.isEmpty ? 'An unexpected error occurred. Please try again.' : raw;
}

String _cleanRawError(Object error) {
  final source = error is AwsApiException ? error.message : error.toString();
  return source
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^AwsApiException\(\d+\):\s*'), '')
      .replaceAll(RegExp(r'\s*\[url:\s*[^\]]+\]'), '')
      .replaceFirst(RegExp(r'^Google Sign-In failed:\s*'), '')
      .replaceFirst(RegExp(r'^Google account selection failed:\s*'), '')
      .trim();
}
