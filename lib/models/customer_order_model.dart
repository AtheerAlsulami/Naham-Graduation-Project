class CustomerOrderItemModel {
  const CustomerOrderItemModel({
    required this.dishId,
    required this.dishName,
    required this.imageUrl,
    required this.quantity,
    required this.price,
    this.preparationTimeMin = 0,
    this.preparationTimeMax = 0,
    this.note,
  });

  final String dishId;
  final String dishName;
  final String imageUrl;
  final int quantity;
  final double price;
  final int preparationTimeMin;
  final int preparationTimeMax;
  final String? note;

  double get total => quantity * price;

  Map<String, dynamic> toMap() {
    return {
      'dishId': dishId,
      'dishName': dishName,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'price': price,
      'preparationTimeMin': preparationTimeMin,
      'preparationTimeMax': preparationTimeMax,
      'note': note,
    };
  }

  factory CustomerOrderItemModel.fromMap(Map<String, dynamic> map) {
    int quantity = 1;
    final dynamic quantityRaw = map['quantity'];
    if (quantityRaw is num) {
      quantity = quantityRaw.toInt();
    } else if (quantityRaw is String) {
      quantity = int.tryParse(quantityRaw.trim()) ?? 1;
    }
    if (quantity <= 0) quantity = 1;

    double price = 0;
    final dynamic priceRaw = map['price'];
    if (priceRaw is num) {
      price = priceRaw.toDouble();
    } else if (priceRaw is String) {
      price = double.tryParse(priceRaw.trim()) ?? 0;
    }
    if (price < 0) price = 0;

    return CustomerOrderItemModel(
      dishId: (map['dishId'] ?? '').toString(),
      dishName: (map['dishName'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      quantity: quantity,
      price: price,
      preparationTimeMin: _readInt(map['preparationTimeMin']),
      preparationTimeMax: _readInt(map['preparationTimeMax']),
      note: map['note']?.toString(),
    );
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }
}

enum CustomerOrderStatus {
  pendingReview,
  preparing,
  readyForPickup,
  outForDelivery,
  awaitingCustomerConfirmation,
  issueReported,
  replacementPendingCook,
  delivered,
  cancelled,
}

CustomerOrderStatus customerOrderStatusFromValue(String value) {
  switch (value.trim().toLowerCase()) {
    case 'pending_review':
    case 'pending':
    case 'confirmed':
      return CustomerOrderStatus.pendingReview;
    case 'in_progress':
    case 'preparing':
      return CustomerOrderStatus.preparing;
    case 'ready_for_pickup':
    case 'out_for_delivery':
      return CustomerOrderStatus.readyForPickup;
    case 'awaiting_customer_confirmation':
      return CustomerOrderStatus.awaitingCustomerConfirmation;
    case 'issue_reported':
      return CustomerOrderStatus.issueReported;
    case 'replacement_pending_cook':
      return CustomerOrderStatus.replacementPendingCook;
    case 'delivered':
      return CustomerOrderStatus.delivered;
    case 'cancelled':
      return CustomerOrderStatus.cancelled;
    default:
      return CustomerOrderStatus.pendingReview;
  }
}

String customerOrderStatusToValue(CustomerOrderStatus status) {
  switch (status) {
    case CustomerOrderStatus.pendingReview:
      return 'pending_review';
    case CustomerOrderStatus.preparing:
      return 'in_progress';
    case CustomerOrderStatus.readyForPickup:
      return 'ready_for_pickup';
    case CustomerOrderStatus.outForDelivery:
      return 'out_for_delivery';
    case CustomerOrderStatus.awaitingCustomerConfirmation:
      return 'awaiting_customer_confirmation';
    case CustomerOrderStatus.issueReported:
      return 'issue_reported';
    case CustomerOrderStatus.replacementPendingCook:
      return 'replacement_pending_cook';
    case CustomerOrderStatus.delivered:
      return 'delivered';
    case CustomerOrderStatus.cancelled:
      return 'cancelled';
  }
}

class CustomerOrderModel {
  const CustomerOrderModel({
    required this.id,
    required this.displayId,
    required this.dishId,
    required this.dishName,
    required this.cookName,
    required this.imageUrl,
    required this.price,
    required this.status,
    required this.infoLabel,
    required this.infoValue,
    this.contactName,
    this.contactRole,
    this.contactPhone,
    this.rating,
    this.customerId = '',
    this.customerName = '',
    this.cookId = '',
    this.statusValue = '',
    this.itemCount = 1,
    this.items = const [],
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.totalAmount = 0,
    this.cookEarnings = 0,
    this.note = '',
    this.paymentMethod = '',
    this.paymentCardMask = '',
    this.paymentStatus = '',
    this.addressCountry = '',
    this.addressCity = '',
    this.addressLine = '',
    this.addressPostcode = '',
    this.customerLat = 0,
    this.customerLng = 0,
    this.pickupLat = 0,
    this.pickupLng = 0,
    this.prepEstimateMinutes = 45,
    this.nudgeCount = 0,
    this.issueReason = '',
    this.replacementHistory = const [],
    this.statusHistory = const [],
    this.payoutId = '',
    this.cookRating,
    this.serviceRating,
    this.reviewComment = '',
    this.createdAt,
    this.approvalExpiresAt,
    this.acceptedAt,
    this.deliveryDueAt,
    this.outForDeliveryAt,
    this.arrivedAt,
    this.confirmedReceivedAt,
    this.lastNudgedAt,
    this.deliveredAt,
    this.cancelledAt,
    this.ratedAt,
  });

  final String id;
  final String displayId;
  final String dishId;
  final String dishName;
  final String cookName;
  final String imageUrl;
  final double price;
  final CustomerOrderStatus status;
  final String infoLabel;
  final String infoValue;
  final String? contactName;
  final String? contactRole;
  final String? contactPhone;
  final int? rating;

  final String customerId;
  final String customerName;
  final String cookId;
  final String statusValue;
  final int itemCount;
  final List<CustomerOrderItemModel> items;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final double cookEarnings;
  final String note;
  final String paymentMethod;
  final String paymentCardMask;
  final String paymentStatus;
  final String addressCountry;
  final String addressCity;
  final String addressLine;
  final String addressPostcode;
  final double customerLat;
  final double customerLng;
  final double pickupLat;
  final double pickupLng;
  final int prepEstimateMinutes;
  final int nudgeCount;
  final String issueReason;
  final List<Map<String, dynamic>> replacementHistory;
  final List<Map<String, dynamic>> statusHistory;
  final String payoutId;
  final int? cookRating;
  final int? serviceRating;
  final String reviewComment;
  final DateTime? createdAt;
  final DateTime? approvalExpiresAt;
  final DateTime? acceptedAt;
  final DateTime? deliveryDueAt;
  final DateTime? outForDeliveryAt;
  final DateTime? arrivedAt;
  final DateTime? confirmedReceivedAt;
  final DateTime? lastNudgedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime? ratedAt;

  bool get isRated => rating != null && rating! > 0;
  bool get isLateForDelivery =>
      deliveryDueAt != null &&
      DateTime.now().isAfter(deliveryDueAt!) &&
      (status == CustomerOrderStatus.readyForPickup ||
          status == CustomerOrderStatus.outForDelivery ||
          status == CustomerOrderStatus.awaitingCustomerConfirmation);
  bool get canNudgeLate {
    if (!isLateForDelivery) return false;
    final last = lastNudgedAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= const Duration(minutes: 10);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayId': displayId,
      'dishId': dishId,
      'dishName': dishName,
      'cookName': cookName,
      'imageUrl': imageUrl,
      'price': price,
      'status': statusValue.isEmpty ? customerOrderStatusToValue(status) : statusValue,
      'infoLabel': infoLabel,
      'infoValue': infoValue,
      'contactName': contactName,
      'contactRole': contactRole,
      'contactPhone': contactPhone,
      'rating': rating,
      'customerId': customerId,
      'customerName': customerName,
      'cookId': cookId,
      'itemCount': itemCount,
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'totalAmount': totalAmount,
      'cookEarnings': cookEarnings,
      'note': note,
      'payment': {
        'method': paymentMethod,
        'cardMask': paymentCardMask,
        'status': paymentStatus,
      },
      'deliveryAddress': {
        'country': addressCountry,
        'city': addressCity,
        'address': addressLine,
        'postcode': addressPostcode,
        'lat': customerLat,
        'lng': customerLng,
      },
      'tracking': {
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'customerLat': customerLat,
        'customerLng': customerLng,
      },
      'prepEstimateMinutes': prepEstimateMinutes,
      'approvalExpiresAt': approvalExpiresAt?.toIso8601String(),
      'deliveryDueAt': deliveryDueAt?.toIso8601String(),
      'outForDeliveryAt': outForDeliveryAt?.toIso8601String(),
      'arrivedAt': arrivedAt?.toIso8601String(),
      'confirmedReceivedAt': confirmedReceivedAt?.toIso8601String(),
      'lastNudgedAt': lastNudgedAt?.toIso8601String(),
      'nudgeCount': nudgeCount,
      'issueReason': issueReason,
      'replacementHistory': replacementHistory,
      'statusHistory': statusHistory,
      'payoutId': payoutId,
      'cookRating': cookRating,
      'serviceRating': serviceRating,
      'reviewComment': reviewComment,
      'createdAt': createdAt?.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'ratedAt': ratedAt?.toIso8601String(),
    };
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return {};
  }

  static List<CustomerOrderItemModel> _readItems(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, itemValue) => MapEntry(key.toString(), itemValue)))
        .map(CustomerOrderItemModel.fromMap)
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _readMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, itemValue) => MapEntry(key.toString(), itemValue)))
        .toList(growable: false);
  }

  static (String, String) _resolveInfo(
    CustomerOrderStatus status, {
    DateTime? createdAt,
    DateTime? deliveredAt,
    DateTime? acceptedAt,
  }) {
    switch (status) {
      case CustomerOrderStatus.pendingReview:
        return ('Review status', 'Pending cook approval');
      case CustomerOrderStatus.preparing:
        if (acceptedAt != null) {
          return ('Cooking started', '${acceptedAt.hour.toString().padLeft(2, '0')}:${acceptedAt.minute.toString().padLeft(2, '0')}');
        }
        return ('Prep time', 'In progress');
      case CustomerOrderStatus.readyForPickup:
        return ('Pickup', 'Ready for pickup');
      case CustomerOrderStatus.outForDelivery:
        return ('Pickup', 'Ready for pickup');
      case CustomerOrderStatus.awaitingCustomerConfirmation:
        return ('Receipt', 'Please confirm receipt');
      case CustomerOrderStatus.issueReported:
        return ('Issue', 'Cook is handling the issue');
      case CustomerOrderStatus.replacementPendingCook:
        return ('Replacement', 'Waiting for cook approval');
      case CustomerOrderStatus.delivered:
        if (deliveredAt != null) {
          return ('Order Delivered', '${deliveredAt.hour.toString().padLeft(2, '0')}:${deliveredAt.minute.toString().padLeft(2, '0')}');
        }
        return ('Order Delivered', 'Delivered');
      case CustomerOrderStatus.cancelled:
        return ('Order status', 'Cancelled');
    }
  }

  factory CustomerOrderModel.fromMap(Map<String, dynamic> map) {
    final statusValue = (map['status'] ?? '').toString();
    final status = customerOrderStatusFromValue(statusValue);
    final items = _readItems(map['items']);
    final firstItem = items.isNotEmpty ? items.first : null;
    final createdAt = _readDate(map['createdAt']);
    final approvalExpiresAt = _readDate(map['approvalExpiresAt']);
    final acceptedAt = _readDate(map['acceptedAt']);
    final deliveryDueAt = _readDate(map['deliveryDueAt']);
    final outForDeliveryAt = _readDate(map['outForDeliveryAt']);
    final arrivedAt = _readDate(map['arrivedAt']);
    final confirmedReceivedAt = _readDate(map['confirmedReceivedAt']);
    final lastNudgedAt = _readDate(map['lastNudgedAt']);
    final deliveredAt = _readDate(map['deliveredAt']);
    final cancelledAt = _readDate(map['cancelledAt']);
    final ratedAt = _readDate(map['ratedAt']);

    final payment = _readMap(map['payment']);
    final deliveryAddress = _readMap(map['deliveryAddress']);
    final tracking = _readMap(map['tracking']);
    final info = _resolveInfo(
      status,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      deliveredAt: deliveredAt,
    );

    final totalAmount = _readDouble(map['totalAmount'], fallback: 0);
    final price = _readDouble(
      map['price'],
      fallback: totalAmount > 0
          ? totalAmount
          : (firstItem?.price ?? 0),
    );

    return CustomerOrderModel(
      id: (map['id'] ?? '').toString(),
      displayId: (map['displayId'] ?? '').toString(),
      dishId: (map['dishId'] ?? firstItem?.dishId ?? '').toString(),
      dishName: (map['dishName'] ?? firstItem?.dishName ?? '').toString(),
      cookName: (map['cookName'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? firstItem?.imageUrl ?? '').toString(),
      price: price,
      status: status,
      infoLabel: (map['infoLabel'] ?? info.$1).toString(),
      infoValue: (map['infoValue'] ?? info.$2).toString(),
      contactName: (map['contactName'] ?? map['cookName'])?.toString(),
      contactRole: map['contactRole']?.toString(),
      contactPhone: map['contactPhone']?.toString(),
      rating: _readInt(map['rating'], fallback: 0) > 0
          ? _readInt(map['rating'], fallback: 0)
          : null,
      customerId: (map['customerId'] ?? '').toString(),
      customerName: (map['customerName'] ?? '').toString(),
      cookId: (map['cookId'] ?? '').toString(),
      statusValue: statusValue,
      itemCount: _readInt(
        map['itemCount'],
        fallback: items.fold<int>(0, (sum, item) => sum + item.quantity),
      ),
      items: items,
      subtotal: _readDouble(map['subtotal'], fallback: 0),
      deliveryFee: _readDouble(map['deliveryFee'], fallback: 0),
      totalAmount: totalAmount,
      cookEarnings: _readDouble(map['cookEarnings'], fallback: 0),
      note: (map['note'] ?? '').toString(),
      paymentMethod: (payment['method'] ?? '').toString(),
      paymentCardMask: (payment['cardMask'] ?? '').toString(),
      paymentStatus: (payment['status'] ?? '').toString(),
      addressCountry: (deliveryAddress['country'] ?? '').toString(),
      addressCity: (deliveryAddress['city'] ?? '').toString(),
      addressLine: (deliveryAddress['address'] ?? '').toString(),
      addressPostcode: (deliveryAddress['postcode'] ?? '').toString(),
      customerLat: _readDouble(deliveryAddress['lat'], fallback: 0),
      customerLng: _readDouble(deliveryAddress['lng'], fallback: 0),
      pickupLat: _readDouble(tracking['pickupLat'], fallback: 0),
      pickupLng: _readDouble(tracking['pickupLng'], fallback: 0),
      prepEstimateMinutes: _readInt(map['prepEstimateMinutes'], fallback: 45),
      nudgeCount: _readInt(map['nudgeCount'], fallback: 0),
      issueReason: (map['issueReason'] ?? '').toString(),
      replacementHistory: _readMapList(map['replacementHistory']),
      statusHistory: _readMapList(map['statusHistory']),
      payoutId: (map['payoutId'] ?? '').toString(),
      cookRating: _readInt(map['cookRating'], fallback: 0) > 0
          ? _readInt(map['cookRating'], fallback: 0)
          : null,
      serviceRating: _readInt(map['serviceRating'], fallback: 0) > 0
          ? _readInt(map['serviceRating'], fallback: 0)
          : null,
      reviewComment: (map['reviewComment'] ?? '').toString(),
      createdAt: createdAt,
      approvalExpiresAt: approvalExpiresAt,
      acceptedAt: acceptedAt,
      deliveryDueAt: deliveryDueAt,
      outForDeliveryAt: outForDeliveryAt,
      arrivedAt: arrivedAt,
      confirmedReceivedAt: confirmedReceivedAt,
      lastNudgedAt: lastNudgedAt,
      deliveredAt: deliveredAt,
      cancelledAt: cancelledAt,
      ratedAt: ratedAt,
    );
  }

  CustomerOrderModel copyWith({
    String? id,
    String? displayId,
    String? dishId,
    String? dishName,
    String? cookName,
    String? imageUrl,
    double? price,
    CustomerOrderStatus? status,
    String? infoLabel,
    String? infoValue,
    String? contactName,
    String? contactRole,
    String? contactPhone,
    int? rating,
    bool clearRating = false,
    String? customerId,
    String? customerName,
    String? cookId,
    String? statusValue,
    int? itemCount,
    List<CustomerOrderItemModel>? items,
    double? subtotal,
    double? deliveryFee,
    double? totalAmount,
    double? cookEarnings,
    String? note,
    String? paymentMethod,
    String? paymentCardMask,
    String? paymentStatus,
    String? addressCountry,
    String? addressCity,
    String? addressLine,
    String? addressPostcode,
    double? customerLat,
    double? customerLng,
    double? pickupLat,
    double? pickupLng,
    int? prepEstimateMinutes,
    int? nudgeCount,
    String? issueReason,
    List<Map<String, dynamic>>? replacementHistory,
    List<Map<String, dynamic>>? statusHistory,
    String? payoutId,
    int? cookRating,
    bool clearCookRating = false,
    int? serviceRating,
    bool clearServiceRating = false,
    String? reviewComment,
    DateTime? createdAt,
    DateTime? approvalExpiresAt,
    DateTime? acceptedAt,
    DateTime? deliveryDueAt,
    DateTime? outForDeliveryAt,
    DateTime? arrivedAt,
    DateTime? confirmedReceivedAt,
    DateTime? lastNudgedAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    DateTime? ratedAt,
  }) {
    return CustomerOrderModel(
      id: id ?? this.id,
      displayId: displayId ?? this.displayId,
      dishId: dishId ?? this.dishId,
      dishName: dishName ?? this.dishName,
      cookName: cookName ?? this.cookName,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      status: status ?? this.status,
      infoLabel: infoLabel ?? this.infoLabel,
      infoValue: infoValue ?? this.infoValue,
      contactName: contactName ?? this.contactName,
      contactRole: contactRole ?? this.contactRole,
      contactPhone: contactPhone ?? this.contactPhone,
      rating: clearRating ? null : (rating ?? this.rating),
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      cookId: cookId ?? this.cookId,
      statusValue: statusValue ?? this.statusValue,
      itemCount: itemCount ?? this.itemCount,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      totalAmount: totalAmount ?? this.totalAmount,
      cookEarnings: cookEarnings ?? this.cookEarnings,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentCardMask: paymentCardMask ?? this.paymentCardMask,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      addressCountry: addressCountry ?? this.addressCountry,
      addressCity: addressCity ?? this.addressCity,
      addressLine: addressLine ?? this.addressLine,
      addressPostcode: addressPostcode ?? this.addressPostcode,
      customerLat: customerLat ?? this.customerLat,
      customerLng: customerLng ?? this.customerLng,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      prepEstimateMinutes: prepEstimateMinutes ?? this.prepEstimateMinutes,
      nudgeCount: nudgeCount ?? this.nudgeCount,
      issueReason: issueReason ?? this.issueReason,
      replacementHistory: replacementHistory ?? this.replacementHistory,
      statusHistory: statusHistory ?? this.statusHistory,
      payoutId: payoutId ?? this.payoutId,
      cookRating: clearCookRating ? null : (cookRating ?? this.cookRating),
      serviceRating: clearServiceRating
          ? null
          : (serviceRating ?? this.serviceRating),
      reviewComment: reviewComment ?? this.reviewComment,
      createdAt: createdAt ?? this.createdAt,
      approvalExpiresAt: approvalExpiresAt ?? this.approvalExpiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      deliveryDueAt: deliveryDueAt ?? this.deliveryDueAt,
      outForDeliveryAt: outForDeliveryAt ?? this.outForDeliveryAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      confirmedReceivedAt: confirmedReceivedAt ?? this.confirmedReceivedAt,
      lastNudgedAt: lastNudgedAt ?? this.lastNudgedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      ratedAt: ratedAt ?? this.ratedAt,
    );
  }
}
