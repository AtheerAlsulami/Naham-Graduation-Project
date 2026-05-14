import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/aws/aws_auth_service.dart';
import 'package:naham_app/services/aws/aws_chat_service.dart';
import 'package:naham_app/services/aws/aws_hygiene_service.dart';
import 'package:naham_app/services/backend/backend_config.dart';

class BackendFactory {
  BackendFactory._();

  static AwsApiClient createAwsApiClient() {
    return AwsApiClient(baseUrl: BackendConfig.awsAuthBaseUrl);
  }

  static AwsApiClient createAwsReelsApiClient() {
    return AwsApiClient(baseUrl: BackendConfig.awsReelsBaseUrl);
  }

  static AwsApiClient createAwsDishesApiClient() {
    return AwsApiClient(baseUrl: BackendConfig.awsDishesBaseUrl);
  }

  static AwsApiClient createAwsPricingApiClient() {
    return AwsApiClient(baseUrl: BackendConfig.awsPricingBaseUrl);
  }

  static AwsApiClient createAwsChatApiClient() {
    return AwsApiClient(baseUrl: BackendConfig.awsChatBaseUrl);
  }

  static AwsApiClient createAwsOrdersApiClient() {
    return AwsApiClient(baseUrl: BackendConfig.awsOrdersBaseUrl);
  }

  static AwsApiClient createAwsNotificationsApiClient() {
    return AwsApiClient(baseUrl: BackendConfig.awsNotificationsBaseUrl);
  }

  static AwsApiClient createAwsUsersApiClient() {
    return AwsApiClient(baseUrl: BackendConfig.awsUsersBaseUrl);
  }

  static AwsAuthService createAwsAuthService() {
    return AwsAuthService(apiClient: createAwsApiClient());
  }

  static AwsChatService createAwsChatService() {
    return AwsChatService(apiClient: createAwsChatApiClient());
  }

  static AwsApiClient createAwsHygieneApiClient() {
    return AwsApiClient(baseUrl: BackendConfig.awsHygieneBaseUrl);
  }

  static AwsHygieneService createAwsHygieneService() {
    return AwsHygieneService(apiClient: createAwsHygieneApiClient());
  }
}
