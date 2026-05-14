import 'package:naham_app/models/payout_model.dart';
import 'package:naham_app/services/aws/aws_payout_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class BackendPayoutService {
  BackendPayoutService()
      : _awsPayoutService = AwsPayoutService(
          apiClient: BackendFactory.createAwsOrdersApiClient(),
        );

  final AwsPayoutService _awsPayoutService;

  Future<List<PayoutModel>> listPayouts({required String cookId}) {
    return _awsPayoutService.listPayouts(cookId: cookId);
  }
}
