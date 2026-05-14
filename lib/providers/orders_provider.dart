import 'package:flutter/material.dart';
import 'package:naham_app/models/cart_item_model.dart';
import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/services/backend/backend_order_service.dart';

class OrdersProvider extends ChangeNotifier {
  static const Duration _cacheWindow = Duration(seconds: 90);

  OrdersProvider({BackendOrderService? orderService})
      : _orderService = orderService ?? BackendOrderService();

  final BackendOrderService _orderService;
  UserModel? _authUser;
  String _boundUserId = '';
  List<CustomerOrderModel> _orders = const [];
  bool _isLoading = false;
  bool _isPlacingOrder = false;
  String? _errorMessage;
  DateTime? _lastLoadedAt;

  List<CustomerOrderModel> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  bool get isPlacingOrder => _isPlacingOrder;
  String? get errorMessage => _errorMessage;

  void bindAuthUser(UserModel? user) {
    final nextUserId = user?.id ?? '';
    final userChanged = _boundUserId != nextUserId;
    _authUser = user;
    _boundUserId = nextUserId;
    if (userChanged) {
      _orders = const [];
      _errorMessage = null;
      _lastLoadedAt = null;
      if (nextUserId.isNotEmpty) {
        // Delay orders loading until the orders screens are actually opened.
        // This keeps startup smoother on slower devices.
      }
      notifyListeners();
    }
  }

  List<CustomerOrderModel> ordersFor(OrdersFilter filter) {
    switch (filter) {
      case OrdersFilter.active:
        return _orders
            .where(
              (order) =>
                  order.status == CustomerOrderStatus.pendingReview ||
                  order.status == CustomerOrderStatus.preparing ||
                  order.status == CustomerOrderStatus.readyForPickup ||
                  order.status == CustomerOrderStatus.outForDelivery ||
                  order.status ==
                      CustomerOrderStatus.awaitingCustomerConfirmation ||
                  order.status == CustomerOrderStatus.issueReported ||
                  order.status == CustomerOrderStatus.replacementPendingCook,
            )
            .toList();
      case OrdersFilter.completed:
        return _orders
            .where((order) => order.status == CustomerOrderStatus.delivered)
            .toList();
      case OrdersFilter.cancelled:
        return _orders
            .where((order) => order.status == CustomerOrderStatus.cancelled)
            .toList();
    }
  }

  List<CustomerOrderModel> cookPendingOrders() {
    return _orders
        .where((order) => order.status == CustomerOrderStatus.pendingReview)
        .toList(growable: false);
  }

  List<CustomerOrderModel> cookActiveOrders() {
    return _orders
        .where(
          (order) =>
              order.status == CustomerOrderStatus.preparing ||
              order.status == CustomerOrderStatus.readyForPickup ||
              order.status == CustomerOrderStatus.outForDelivery ||
              order.status ==
                  CustomerOrderStatus.awaitingCustomerConfirmation ||
              order.status == CustomerOrderStatus.issueReported ||
              order.status == CustomerOrderStatus.replacementPendingCook,
        )
        .toList(growable: false);
  }

  List<CustomerOrderModel> cookCompletedOrders() {
    return _orders
        .where(
          (order) =>
              order.status == CustomerOrderStatus.delivered ||
              order.status == CustomerOrderStatus.cancelled,
        )
        .toList(growable: false);
  }

  CustomerOrderModel? byId(String orderId) {
    for (final order in _orders) {
      if (order.id == orderId) return order;
    }

    return null;
  }

  Future<CustomerOrderModel?> fetchOrderById(String orderId) async {
    final order = await _orderService.getOrderById(orderId);
    if (order == null) return null;
    final index = _orders.indexWhere((item) => item.id == orderId);
    if (index >= 0) {
      _orders[index] = order;
    } else {
      _orders = [order, ..._orders];
    }
    notifyListeners();
    return order;
  }

  Future<void> loadOrders({bool force = false}) async {
    if (_isLoading) {
      return;
    }

    final user = _authUser;
    if (user == null) {
      _orders = const [];
      _errorMessage = null;
      _lastLoadedAt = null;
      notifyListeners();
      return;
    }

    final recentlyLoaded = _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < _cacheWindow;
    if (!force && _orders.isNotEmpty && recentlyLoaded) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (user.isCook) {
        _orders = await _orderService.listOrders(
          cookId: user.id,
          limit: 500,
        );
      } else {
        _orders = await _orderService.listOrders(
          customerId: user.id,
          limit: 500,
        );
      }
      _lastLoadedAt = DateTime.now();
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CustomerOrderModel> placeOrderFromCart({
    required List<CartItemModel> cartItems,
    required double subtotal,
    required double totalAmount,
    required String paymentMethodId,
    required String paymentCardMask,
    String? cookRegion,
    String? deliveryAddress,
    String note = '',
  }) async {
    final user = _authUser;
    if (user == null) {
      throw Exception('No active user session.');
    }
    if (cartItems.isEmpty) {
      throw Exception('Cart is empty.');
    }

    final customerRegion = user.address?.trim() ?? '';
    if (customerRegion.isEmpty) {
      throw Exception('Select your region before placing an order.');
    }

    final normalizedCookRegion = cookRegion?.trim() ?? '';
    if (normalizedCookRegion.isEmpty) {
      throw Exception('Unable to verify the cook region.');
    }

    if (normalizedCookRegion != customerRegion) {
      throw Exception('You can only order from cooks in your region.');
    }

    final firstDish = cartItems.first.dish;
    final itemsPayload = cartItems
        .map((item) => {
              'dishId': item.dish.id,
              'dishName': item.dish.name,
              'imageUrl': item.dish.imageUrl,
              'quantity': item.quantity,
              'price': item.dish.price,
              'preparationTimeMin': item.dish.preparationTimeMin,
              'preparationTimeMax': item.dish.preparationTimeMax,
              'note': item.specialInstructions ?? '',
            })
        .toList(growable: false);

    final payload = {
      'customerId': user.id,
      'customerName': user.displayName ?? user.name,
      'customerPhone': user.phone,
      'cookId': firstDish.cookId,
      'cookName': firstDish.cookName,
      'dishId': firstDish.id,
      'dishName': firstDish.name,
      'imageUrl': firstDish.imageUrl,
      'items': itemsPayload,
      'itemCount': cartItems.fold<int>(0, (sum, item) => sum + item.quantity),
      'subtotal': subtotal,
      'totalAmount': totalAmount,
      'cookEarnings': totalAmount,
      'note': note,
      'payment': {
        'method': paymentMethodId,
        'cardMask': paymentCardMask,
        'status': 'paid',
      },
      'deliveryAddress': deliveryAddress ?? customerRegion,
      'status': 'pending_review',
    };

    _isPlacingOrder = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _orderService.createOrder(payload: payload);
      _orders = [created, ..._orders];
      return created;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isPlacingOrder = false;
      notifyListeners();
    }
  }

  Future<void> cancelPreparingOrder(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'cancel');
  }

  Future<void> submitRating(
    String orderId, {
    required int cookRating,
    required int serviceRating,
    String reviewComment = '',
  }) async {
    await _updateOrderLocalAndRemote(
      orderId,
      action: 'rate',
      rating: cookRating,
      cookRating: cookRating,
      serviceRating: serviceRating,
      reviewComment: reviewComment,
    );
  }

  Future<void> moveToInProgress(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'accept');
  }

  Future<void> rejectOrder(String orderId, {String reason = ''}) async {
    await _updateOrderLocalAndRemote(
      orderId,
      action: 'reject',
      issueReason: reason,
    );
  }

  Future<void> markReadyForPickup(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'mark_ready_for_pickup');
  }

  Future<void> markOutForDelivery(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'mark_out_for_delivery');
  }

  Future<void> markArrived(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'mark_arrived');
  }

  Future<void> confirmReceived(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'confirm_received');
  }

  Future<void> nudgeLate(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'nudge_late');
  }

  Future<void> reportIssue(String orderId,
      {required String issueReason}) async {
    await _updateOrderLocalAndRemote(
      orderId,
      action: 'report_issue',
      issueReason: issueReason,
    );
  }

  Future<void> reportNotReceived(String orderId) async {
    await _updateOrderLocalAndRemote(
      orderId,
      action: 'report_not_received',
      issueReason: 'Customer reports order not received.',
    );
  }

  Future<void> resolveIssue(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'resolve_issue');
  }

  Future<void> finishOrder(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'finish_order');
  }

  Future<void> requestReplacement(
    String orderId, {
    required List<Map<String, dynamic>> replacementItems,
    String issueReason = '',
  }) async {
    await _updateOrderLocalAndRemote(
      orderId,
      action: 'request_replacement',
      replacementItems: replacementItems,
      issueReason: issueReason,
    );
  }

  Future<void> approveReplacement(String orderId) async {
    await _updateOrderLocalAndRemote(orderId, action: 'approve_replacement');
  }

  Future<void> moveToDelivered(String orderId) async {
    await markArrived(orderId);
  }

  Future<void> _updateOrderLocalAndRemote(
    String orderId, {
    String? status,
    String? action,
    int? rating,
    int? cookRating,
    int? serviceRating,
    String? reviewComment,
    String? issueReason,
    List<Map<String, dynamic>>? replacementItems,
  }) async {
    final updated = await _orderService.updateOrderStatus(
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
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index >= 0) {
      _orders[index] = updated;
    } else {
      _orders = [updated, ..._orders];
    }
    notifyListeners();
  }
}

enum OrdersFilter {
  active,
  completed,
  cancelled,
}
