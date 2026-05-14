import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/services/aws/aws_order_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class BackendOrderService {
  BackendOrderService()
      : _awsOrderService =
            AwsOrderService(apiClient: BackendFactory.createAwsOrdersApiClient());

  final AwsOrderService _awsOrderService;

  Future<CustomerOrderModel> createOrder({
    required Map<String, dynamic> payload,
  }) async {
    return _awsOrderService.createOrder(payload: payload);
  }

  Future<List<CustomerOrderModel>> listOrders({
    String? customerId,
    String? cookId,
    String? status,
    int limit = 200,
  }) async {
    return _awsOrderService.listOrders(
      customerId: customerId,
      cookId: cookId,
      status: status,
      limit: limit,
    );
  }

  Future<CustomerOrderModel?> getOrderById(String orderId) async {
    return _awsOrderService.getOrderById(orderId);
  }

  Future<CustomerOrderModel> updateOrderStatus({
    required String orderId,
    String? status,
    String? action,
    int? rating,
    int? cookRating,
    int? serviceRating,
    String? reviewComment,
    String? issueReason,
    List<Map<String, dynamic>>? replacementItems,
  }) async {
    return _awsOrderService.updateOrderStatus(
      orderId: orderId,
      status: status,
      action: action,
      rating: rating,
      cookRating: cookRating,
      serviceRating: serviceRating,
      reviewComment: reviewComment,
      issueReason: issueReason,
      replacementItems: replacementItems,
    );
  }
}
