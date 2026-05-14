import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/services/aws/aws_cook_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class BackendCookService {
  BackendCookService()
      : _awsCookService =
            AwsCookService(apiClient: BackendFactory.createAwsUsersApiClient());

  final AwsCookService _awsCookService;

  Future<List<UserModel>> getAvailableCooks() async {
    return _awsCookService.getAvailableCooks();
  }
}
