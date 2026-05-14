import 'package:naham_app/services/backend/admin_user_types.dart';
import 'package:naham_app/services/aws/aws_admin_user_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class BackendAdminUserService {
  BackendAdminUserService()
      : _awsService = AwsAdminUserService(
            apiClient: BackendFactory.createAwsUsersApiClient());

  final AwsAdminUserService _awsService;

  Future<List<AdminUserRecord>> listUsers({String? role, int limit = 500}) {
    return _awsService.listUsers(role: role, limit: limit);
  }

  Future<AdminUserRecord> createUser(CreateAdminUserRequest request) {
    return _awsService.createUser(request);
  }

  Future<AdminUserRecord?> updateUserStatus({
    required String id,
    required String status,
    String? cookStatus,
  }) {
    return _awsService.updateUserStatus(
      id: id,
      status: status,
      cookStatus: cookStatus,
    );
  }

  Future<void> deleteUser(String id) {
    return _awsService.deleteUser(id);
  }
}
