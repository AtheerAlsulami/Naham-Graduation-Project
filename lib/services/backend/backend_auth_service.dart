import 'package:naham_app/models/google_account_draft.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/services/aws/aws_auth_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class BackendAuthService {
  BackendAuthService()
      : _awsAuthService =
            AwsAuthService(apiClient: BackendFactory.createAwsApiClient());

  final AwsAuthService _awsAuthService;

  Future<UserModel?> getCurrentUser() async {
    return _awsAuthService.getCurrentUser();
  }

  Future<UserModel> refreshCurrentUser(UserModel currentUser) async {
    return _awsAuthService.refreshCurrentUser(currentUser);
  }

  Future<UserModel?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
  }) async {
    return _awsAuthService.register(
      name: name,
      email: email,
      password: password,
      phone: phone,
      role: role,
    );
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    return _awsAuthService.login(
      email: email,
      password: password,
    );
  }

  Future<UserModel?> signInWithGoogle({
    String role = 'customer',
    bool createIfMissing = false,
  }) async {
    return _awsAuthService.signInWithGoogle(
      role: role,
      intent:
          createIfMissing ? GoogleAuthIntent.register : GoogleAuthIntent.login,
    );
  }

  Future<void> logout() async {
    return _awsAuthService.logout();
  }

  Future<GoogleAccountDraft?> pickGoogleAccountDraft() async {
    return _awsAuthService.pickGoogleAccountDraft();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _awsAuthService.sendPasswordResetEmail(email: email);
  }

  Future<UserModel> updateProfile({
    required UserModel currentUser,
    required String name,
    required String phone,
    String? displayName,
    String? address,
    String? profileImageUrl,
  }) async {
    return _awsAuthService.updateProfile(
      currentUser: currentUser,
      name: name,
      phone: phone,
      displayName: displayName,
      address: address,
      profileImageUrl: profileImageUrl,
    );
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
    return _awsAuthService.updateCookSettings(
      currentUser: currentUser,
      isOnline: isOnline,
      dailyCapacity: dailyCapacity,
      workingHours: workingHours,
      cookStatus: cookStatus,
      verificationIdUrl: verificationIdUrl,
      verificationHealthUrl: verificationHealthUrl,
    );
  }

  Future<Map<String, dynamic>> getUploadUrl({
    required String userId,
    required String documentType,
    required String fileName,
    String? contentType,
  }) async {
    return _awsAuthService.getUploadUrl(
      userId: userId,
      documentType: documentType,
      fileName: fileName,
      contentType: contentType,
    );
  }
}
