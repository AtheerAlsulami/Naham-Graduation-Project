import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naham_app/models/google_account_draft.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/backend/backend_config.dart';

enum GoogleAuthIntent { login, register }

class AwsAuthService {
  AwsAuthService({
    required this.apiClient,
    AwsApiClient? usersApiClient,
  }) : usersApiClient = usersApiClient ??
            AwsApiClient(baseUrl: BackendConfig.awsUsersBaseUrl);

  static const String _userStorageKey = 'aws_current_user';
  static const String _accessTokenKey = 'aws_access_token';
  static const String _refreshTokenKey = 'aws_refresh_token';

  final AwsApiClient apiClient;
  final AwsApiClient usersApiClient;
  final GoogleSignIn _googleSignIn = _createGoogleSignIn();

  static GoogleSignIn _createGoogleSignIn() {
    final serverClientId = BackendConfig.googleWebClientId.trim();
    return GoogleSignIn(
      scopes: const ['email', 'openid', 'profile'],
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
  }

  Map<String, dynamic> _asJsonMap(
    dynamic value, {
    required String context,
  }) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        throw Exception('Invalid $context: empty string.');
      }
      if (trimmed.contains('Hello from Lambda')) {
        throw Exception(
          'AWS auth routes are not connected correctly. '
          'The endpoint returned "$trimmed" instead of auth JSON. '
          'Configure API Gateway routes for /auth/register, /auth/login, and /auth/google-signin.',
        );
      }
      try {
        final decoded = jsonDecode(trimmed);
        return _asJsonMap(
          decoded,
          context: '$context (decoded from JSON string)',
        );
      } catch (_) {
        throw Exception(
          'Invalid $context. Expected JSON object but received string: $trimmed',
        );
      }
    }
    throw Exception(
      'Invalid $context. Expected JSON object but got ${value.runtimeType}.',
    );
  }

  Map<String, dynamic> _decodeResponseBody(String bodyString) {
    final decoded = (() {
      try {
        return jsonDecode(bodyString);
      } on FormatException {
        final snippet =
            bodyString.trim().isEmpty ? '<empty body>' : bodyString.trim();
        throw Exception(
          'Invalid response from AWS auth API. '
          'Expected JSON object but got: $snippet',
        );
      }
    })();
    if (decoded is List && decoded.length == 1) {
      return _asJsonMap(decoded.first, context: 'AWS auth response body');
    }
    final body = _asJsonMap(decoded, context: 'AWS auth response body');

    final looksLikeProxyEnvelope = body.containsKey('statusCode') &&
        body.containsKey('body') &&
        !body.containsKey('user');
    if (looksLikeProxyEnvelope) {
      return _asJsonMap(body['body'], context: 'AWS proxy response body');
    }

    return body;
  }

  Map<String, dynamic> _extractUserJson(Map<String, dynamic> body) {
    final userPayload = body['user'];
    if (userPayload == null) {
      throw Exception('AWS auth API response is missing the "user" field.');
    }
    return _asJsonMap(userPayload, context: 'AWS auth user payload');
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final storedJson = prefs.getString(_userStorageKey);
    if (storedJson == null || storedJson.isEmpty) {
      return null;
    }
    try {
      final data = _asJsonMap(
        jsonDecode(storedJson),
        context: 'stored AWS user session',
      );
      return UserModel.fromMap(data);
    } catch (_) {
      await _clearStoredAuth();
      return null;
    }
  }

  Future<UserModel> refreshCurrentUser(UserModel currentUser) async {
    final response = await usersApiClient.get(
      '/users',
      queryParameters: {'id': currentUser.id},
    );

    final body = _decodeResponseBody(response.body);
    final updatedUser = UserModel.fromMap(_extractUserJson(body));
    await _saveUser(updatedUser);
    return updatedUser;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    final response = await apiClient.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role,
      },
    );

    final body = _decodeResponseBody(response.body);
    final user = UserModel.fromMap(_extractUserJson(body));
    await _saveUser(user);
    await _saveTokens(body);
    return user;
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    final body = _decodeResponseBody(response.body);
    final user = UserModel.fromMap(_extractUserJson(body));
    await _saveUser(user);
    await _saveTokens(body);
    return user;
  }

  Future<UserModel?> signInWithGoogle({
    String role = 'customer',
    GoogleAuthIntent intent = GoogleAuthIntent.login,
  }) async {
    try {
      // Force account chooser so user can pick a different Google account.
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = (googleAuth.idToken ?? '').trim();
      final accessToken = (googleAuth.accessToken ?? '').trim();
      if (idToken.isEmpty && accessToken.isEmpty) {
        throw Exception(
          'Google Sign-In did not return identity tokens. '
          'Configure GOOGLE_WEB_CLIENT_ID with your Web OAuth client id.',
        );
      }

      final response = await apiClient.post(
        '/auth/google-signin',
        body: {
          'idToken': idToken,
          'accessToken': accessToken,
          'role': role,
          'intent': intent == GoogleAuthIntent.register ? 'register' : 'login',
        },
      );

      final body = _decodeResponseBody(response.body);
      final user = UserModel.fromMap(_extractUserJson(body));
      await _saveUser(user);
      await _saveTokens(body);
      return user;
    } catch (error) {
      final message = error.toString();
      if (_isGoogleCancelError(message)) {
        return null;
      }
      throw Exception('Google Sign-In failed: $message');
    }
  }

  Future<GoogleAccountDraft?> pickGoogleAccountDraft() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final draft = GoogleAccountDraft(
        name: _resolveGoogleDraftName(googleUser),
        email: googleUser.email.trim(),
        phone: '',
        countryCode: '+966',
        photoUrl: googleUser.photoUrl,
      );

      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      return draft;
    } catch (error) {
      final message = error.toString();
      if (_isGoogleCancelError(message)) {
        return null;
      }
      throw Exception('Google account selection failed: $message');
    }
  }

  bool _isGoogleCancelError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('popup closed') ||
        normalized.contains('cancelled') ||
        normalized.contains('user aborted');
  }

  String _resolveGoogleDraftName(GoogleSignInAccount googleUser) {
    if ((googleUser.displayName ?? '').isNotEmpty) {
      return googleUser.displayName!;
    }
    return googleUser.email.split('@').first;
  }

  Future<void> _saveTokens(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = body['accessToken']?.toString();
    final refreshToken = body['refreshToken']?.toString();
    if (accessToken != null) {
      await prefs.setString(_accessTokenKey, accessToken);
    }
    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<void> _clearStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userStorageKey);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await apiClient.post(
      '/auth/password-reset',
      body: {
        'email': email,
      },
    );
  }

  Future<void> logout() async {
    await _clearStoredAuth();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<UserModel> updateProfile({
    required UserModel currentUser,
    required String name,
    required String phone,
    String? displayName,
    String? address,
    String? profileImageUrl,
  }) async {
    final response = await usersApiClient.put(
      '/users/${Uri.encodeComponent(currentUser.id)}',
      body: {
        'name': name,
        'phone': phone,
        'displayName': displayName,
        'address': address,
        'profileImageUrl': profileImageUrl,
      },
    );

    final body = _decodeResponseBody(response.body);
    final updatedUser = UserModel.fromMap(_extractUserJson(body));
    await _saveUser(updatedUser);
    return updatedUser;
  }

  Future<UserModel> updateCookSettings({
    required UserModel currentUser,
    bool? isOnline,
    int? dailyCapacity,
    Map<String, dynamic>? workingHours,
    String? cookStatus,
    String? verificationIdUrl,
    String? verificationHealthUrl,
  }) async {
    final payload = <String, dynamic>{};
    if (isOnline != null) payload['isOnline'] = isOnline;
    if (dailyCapacity != null) payload['dailyCapacity'] = dailyCapacity;
    if (workingHours != null) payload['workingHours'] = workingHours;
    if (cookStatus != null) payload['cookStatus'] = cookStatus;
    if (verificationIdUrl != null && verificationIdUrl.isNotEmpty) {
      payload['verificationIdUrl'] = verificationIdUrl;
    }
    if (verificationHealthUrl != null && verificationHealthUrl.isNotEmpty) {
      payload['verificationHealthUrl'] = verificationHealthUrl;
    }

    if (payload.isEmpty) {
      throw Exception('No cook settings to update.');
    }

    final response = await usersApiClient.put(
      '/users/${Uri.encodeComponent(currentUser.id)}',
      body: payload,
    );

    final body = _decodeResponseBody(response.body);
    final updatedUser = UserModel.fromMap(_extractUserJson(body));
    await _saveUser(updatedUser);
    return updatedUser;
  }

  Future<Map<String, dynamic>> getUploadUrl({
    required String userId,
    required String documentType,
    required String fileName,
    String? contentType,
  }) async {
    final response = await usersApiClient.post(
      '/users/upload-url',
      body: {
        'userId': userId,
        'documentType': documentType,
        'fileName': fileName,
        if (contentType != null) 'contentType': contentType,
      },
    );

    final body = _decodeResponseBody(response.body);
    return _asJsonMap(body, context: 'upload URL response');
  }

  Future<void> _saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userStorageKey, jsonEncode(user.toMap()));
  }
}
