class PayoutModel {
  const PayoutModel({
    required this.id,
    required this.orderId,
    required this.cookId,
    required this.amount,
    required this.currency,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderId;
  final String cookId;
  final double amount;
  final String currency;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'pending_transfer';

  static double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  factory PayoutModel.fromMap(Map<String, dynamic> map) {
    return PayoutModel(
      id: (map['id'] ?? '').toString(),
      orderId: (map['orderId'] ?? '').toString(),
      cookId: (map['cookId'] ?? '').toString(),
      amount: _readDouble(map['amount']),
      currency: (map['currency'] ?? 'SAR').toString(),
      status: (map['status'] ?? 'pending_transfer').toString(),
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
    );
  }
}
