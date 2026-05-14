import 'dart:io';
import 'package:flutter/material.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/models/google_account_draft.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/providers/auth_error_message.dart';
import 'package:naham_app/services/backend/backend_auth_service.dart';
import 'package:http/http.dart' as http;

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider({BackendAuthService? authService})
      : _authService = authService ?? BackendAuthService();

  final BackendAuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  Future<void> checkAuthStatus({bool notifyLoading = true}) async {
    _status = AuthStatus.loading;
    if (notifyLoading) {
      notifyListeners();
    }

    try {
      _currentUser = await _authService.getCurrentUser();
      _errorMessage = null;
      _status = _currentUser == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } catch (error) {
      _currentUser = null;
      _errorMessage = formatAuthErrorMessage(error);
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
        role: role,
      );

      _currentUser = user;
      _status =
          user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
      notifyListeners();
      return user != null;
    } catch (error) {
      _currentUser = null;
      _errorMessage = formatAuthErrorMessage(error);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.login(
        email: email,
        password: password,
      );

      _currentUser = user;
      _status =
          user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
      if (user == null) {
        _errorMessage = formatAuthErrorMessage('Invalid credentials.');
      }
      notifyListeners();
      return user != null;
    } catch (error) {
      _currentUser = null;
      _errorMessage = formatAuthErrorMessage(error);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> refreshCurrentUser() async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      _errorMessage = 'No active user session.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authService.refreshCurrentUser(currentUser);
      _currentUser = updatedUser;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = formatAuthErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle({
    String role = AppConstants.roleCustomer,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle(role: role);
      if (user == null) {
        _status = AuthStatus.unauthenticated;
        _currentUser = null;
        _errorMessage = null;
        notifyListeners();
        return false;
      }

      _currentUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (error) {
      _currentUser = null;
      _errorMessage = formatAuthErrorMessage(error);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<GoogleAccountDraft?> pickGoogleAccountDraft() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final draft = await _authService.pickGoogleAccountDraft();
      _status = _currentUser == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return draft;
    } catch (error) {
      _errorMessage = formatAuthErrorMessage(error);
      _status = AuthStatus.error;
      notifyListeners();
      return null;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email: email);
      _status = _currentUser == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = formatAuthErrorMessage(error);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String phone,
    String? displayName,
    String? address,
    String? profileImageUrl,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      _errorMessage = 'No active user session.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authService.updateProfile(
        currentUser: currentUser,
        name: name,
        phone: phone,
        displayName: displayName,
        address: address,
        profileImageUrl: profileImageUrl,
      );
      _currentUser = updatedUser;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = formatAuthErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCookSettings({
    bool? isOnline,
    int? dailyCapacity,
    Map<String, dynamic>? workingHours,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      _errorMessage = 'No active user session.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authService.updateCookSettings(
        currentUser: currentUser,
        isOnline: isOnline,
        dailyCapacity: dailyCapacity,
        workingHours: workingHours,
      );
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = formatAuthErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> submitCookVerification({
    required File idFile,
    required File healthFile,
  }) async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      _errorMessage = 'No active user session.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get upload URLs for both files
      final idUploadUrlResponse = await _authService.getUploadUrl(
        userId: currentUser.id,
        documentType: 'id',
        fileName: 'id_document.pdf',
        contentType: 'application/pdf',
      );
      final healthUploadUrlResponse = await _authService.getUploadUrl(
        userId: currentUser.id,
        documentType: 'health',
        fileName: 'health_certificate.pdf',
        contentType: 'application/pdf',
      );

      // Upload files to S3
      final idUploadUrl = idUploadUrlResponse['uploadUrl'] as String;
      final healthUploadUrl = healthUploadUrlResponse['uploadUrl'] as String;
      final idFileUrl = idUploadUrlResponse['fileUrl'] as String;
      final healthFileUrl = healthUploadUrlResponse['fileUrl'] as String;

      final responses = await Future.wait([
        http.put(
          Uri.parse(idUploadUrl),
          headers: {
            'Content-Type': 'application/pdf',
          },
          body: idFile.readAsBytesSync(),
        ),
        http.put(
          Uri.parse(healthUploadUrl),
          headers: {
            'Content-Type': 'application/pdf',
          },
          body: healthFile.readAsBytesSync(),
        ),
      ]);

      for (final response in responses) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Failed to upload verification documents.');
        }
      }

      // Update user with document URLs and status
      final updatedUser = await _authService.updateCookSettings(
        currentUser: currentUser,
        cookStatus: AppConstants.cookPendingVerification,
        verificationIdUrl: idFileUrl,
        verificationHealthUrl: healthFileUrl,
      );
      _currentUser = updatedUser;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = formatAuthErrorMessage(error);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  void updateUser(UserModel updatedUser) {
    _currentUser = updatedUser;
    notifyListeners();
  }

  void clearError() {
    final hadErrorMessage = _errorMessage != null;
    final wasErrorState = _status == AuthStatus.error;
    _errorMessage = null;
    if (wasErrorState) {
      _status = _currentUser == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    }
    if (hadErrorMessage || wasErrorState) {
      notifyListeners();
    }
  }
}
