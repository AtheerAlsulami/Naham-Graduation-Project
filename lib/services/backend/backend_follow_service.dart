import 'package:naham_app/services/aws/aws_follow_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class BackendFollowService {
  BackendFollowService()
      : _awsFollowService = AwsFollowService(
          apiClient: BackendFactory.createAwsUsersApiClient(),
        );

  final AwsFollowService _awsFollowService;

  Future<void> followCook({
    required String customerId,
    required String cookId,
  }) {
    return _awsFollowService.followCook(
      customerId: customerId,
      cookId: cookId,
    );
  }

  Future<void> unfollowCook({
    required String customerId,
    required String cookId,
  }) {
    return _awsFollowService.unfollowCook(
      customerId: customerId,
      cookId: cookId,
    );
  }

  Future<Set<String>> listFollowedCookIds(String customerId) {
    return _awsFollowService.listFollowedCookIds(customerId);
  }
}
