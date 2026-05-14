import 'dart:math' as math;

import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/services/backend/admin_user_types.dart';

class AdminReportSnapshot {
  const AdminReportSnapshot({
    required this.monthRevenue,
    required this.netProfit,
    required this.totalOrders,
    required this.lossRefunds,
    required this.revenueChangePercent,
    required this.netProfitChangePercent,
    required this.ordersChangePercent,
    required this.lossRefundsChangePercent,
    required this.onlinePaymentPercent,
    required this.cashPaymentPercent,
    required this.dailyRevenuePoints,
    required this.highestDay,
    required this.lowestDay,
    required this.monthGrowth,
    required this.topCooksByRevenue,
    required this.topCooksByOrders,
  });

  final double monthRevenue;
  final double netProfit;
  final int totalOrders;
  final double lossRefunds;
  final double revenueChangePercent;
  final double netProfitChangePercent;
  final double ordersChangePercent;
  final double lossRefundsChangePercent;
  final int onlinePaymentPercent;
  final int cashPaymentPercent;
  final List<double> dailyRevenuePoints;
  final AdminReportDayMetric highestDay;
  final AdminReportDayMetric lowestDay;
  final List<AdminReportMonthRow> monthGrowth;
  final List<AdminReportRankItem> topCooksByRevenue;
  final List<AdminReportRankItem> topCooksByOrders;

  factory AdminReportSnapshot.empty({DateTime? now}) {
    return AdminReportSnapshot.fromData(
      orders: const [],
      users: const [],
      now: now ?? DateTime.now(),
    );
  }

  factory AdminReportSnapshot.fromData({
    required List<CustomerOrderModel> orders,
    required List<AdminUserRecord> users,
    required DateTime now,
  }) {
    final currentMonth = _MonthKey.fromDate(now);
    final previousMonth = currentMonth.previous;
    final currentMonthOrders = orders
        .where((order) =>
            _MonthKey.fromDate(_orderDate(order, now)) == currentMonth)
        .toList(growable: false);
    final previousMonthOrders = orders
        .where((order) =>
            _MonthKey.fromDate(_orderDate(order, now)) == previousMonth)
        .toList(growable: false);

    final monthRevenue = _revenueFor(currentMonthOrders);
    final previousRevenue = _revenueFor(previousMonthOrders);
    final netProfit = _profitFor(currentMonthOrders);
    final previousProfit = _profitFor(previousMonthOrders);
    final lossRefunds = _lossFor(currentMonthOrders);
    final previousLoss = _lossFor(previousMonthOrders);
    final totalOrders = currentMonthOrders.length;

    final paymentMix = _paymentMixFor(currentMonthOrders);
    final dailyRevenue = _dailyRevenueFor(currentMonthOrders, now);
    final highestDay = _highestDayFrom(dailyRevenue);
    final lowestDay = _lowestDayFrom(dailyRevenue);

    return AdminReportSnapshot(
      monthRevenue: monthRevenue,
      netProfit: netProfit,
      totalOrders: totalOrders,
      lossRefunds: lossRefunds,
      revenueChangePercent: _changePercent(monthRevenue, previousRevenue),
      netProfitChangePercent: _changePercent(netProfit, previousProfit),
      ordersChangePercent: _changePercent(
          totalOrders.toDouble(), previousMonthOrders.length.toDouble()),
      lossRefundsChangePercent: _changePercent(lossRefunds, previousLoss),
      onlinePaymentPercent: paymentMix.onlinePercent,
      cashPaymentPercent: paymentMix.cashPercent,
      dailyRevenuePoints: _normalizeDailyRevenue(dailyRevenue),
      highestDay: highestDay,
      lowestDay: lowestDay,
      monthGrowth: _buildMonthGrowth(orders, now),
      topCooksByRevenue: _rankCooksByRevenue(currentMonthOrders, users),
      topCooksByOrders: _rankCooksByOrders(currentMonthOrders, users),
    );
  }

  static DateTime _orderDate(CustomerOrderModel order, DateTime fallback) {
    return order.createdAt ?? order.deliveredAt ?? order.acceptedAt ?? fallback;
  }

  static double _orderAmount(CustomerOrderModel order) {
    if (order.totalAmount > 0) return order.totalAmount;
    if (order.subtotal + order.deliveryFee > 0) {
      return order.subtotal + order.deliveryFee;
    }
    return math.max(order.price, 0);
  }

  static bool _isDelivered(CustomerOrderModel order) {
    return order.status == CustomerOrderStatus.delivered;
  }

  static bool _isCancelled(CustomerOrderModel order) {
    return order.status == CustomerOrderStatus.cancelled;
  }

  static double _revenueFor(List<CustomerOrderModel> orders) {
    return orders
        .where(_isDelivered)
        .fold<double>(0, (sum, order) => sum + _orderAmount(order));
  }

  static double _profitFor(List<CustomerOrderModel> orders) {
    return orders.where(_isDelivered).fold<double>(0, (sum, order) {
      if (order.cookEarnings <= 0) return sum;
      return sum + math.max(_orderAmount(order) - order.cookEarnings, 0);
    });
  }

  static double _lossFor(List<CustomerOrderModel> orders) {
    return orders
        .where(_isCancelled)
        .fold<double>(0, (sum, order) => sum + _orderAmount(order));
  }

  static double _changePercent(double current, double previous) {
    if (previous == 0) {
      return current == 0 ? 0 : 100;
    }
    return ((current - previous) / previous) * 100;
  }

  static _PaymentMix _paymentMixFor(List<CustomerOrderModel> orders) {
    final paidOrders = orders.where(_isDelivered).toList(growable: false);
    if (paidOrders.isEmpty) {
      return const _PaymentMix(onlinePercent: 0, cashPercent: 0);
    }

    final cashCount = paidOrders
        .where((order) => order.paymentMethod.trim().toLowerCase() == 'cash')
        .length;
    final cashPercent = ((cashCount / paidOrders.length) * 100).round();
    return _PaymentMix(
      onlinePercent: 100 - cashPercent,
      cashPercent: cashPercent,
    );
  }

  static List<double> _dailyRevenueFor(
    List<CustomerOrderModel> orders,
    DateTime now,
  ) {
    final days = DateTime(now.year, now.month + 1, 0).day;
    final values = List<double>.filled(days, 0);
    for (final order in orders.where(_isDelivered)) {
      final date = _orderDate(order, now);
      final index = date.day - 1;
      if (index >= 0 && index < values.length) {
        values[index] += _orderAmount(order);
      }
    }
    return values;
  }

  static List<double> _normalizeDailyRevenue(List<double> values) {
    if (values.isEmpty) return const [];
    final maxValue = values.fold<double>(0, math.max);
    if (maxValue <= 0) {
      return List<double>.filled(values.length, 0);
    }
    return values.map((value) => value / maxValue).toList(growable: false);
  }

  static AdminReportDayMetric _highestDayFrom(List<double> values) {
    if (values.isEmpty) {
      return const AdminReportDayMetric(dayLabel: '-', revenue: 0);
    }
    var dayIndex = 0;
    var highest = values.first;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > highest) {
        highest = values[i];
        dayIndex = i;
      }
    }
    if (highest <= 0) {
      return const AdminReportDayMetric(dayLabel: '-', revenue: 0);
    }
    return AdminReportDayMetric(dayLabel: '${dayIndex + 1}', revenue: highest);
  }

  static AdminReportDayMetric _lowestDayFrom(List<double> values) {
    final nonZeroEntries = <MapEntry<int, double>>[];
    for (var i = 0; i < values.length; i++) {
      if (values[i] > 0) {
        nonZeroEntries.add(MapEntry(i, values[i]));
      }
    }
    if (nonZeroEntries.isEmpty) {
      return const AdminReportDayMetric(dayLabel: '-', revenue: 0);
    }
    var lowest = nonZeroEntries.first;
    for (final entry in nonZeroEntries.skip(1)) {
      if (entry.value < lowest.value) {
        lowest = entry;
      }
    }
    return AdminReportDayMetric(
      dayLabel: '${lowest.key + 1}',
      revenue: lowest.value,
    );
  }

  static List<AdminReportMonthRow> _buildMonthGrowth(
    List<CustomerOrderModel> orders,
    DateTime now,
  ) {
    final rows = <AdminReportMonthRow>[];
    for (var offset = 0; offset < 4; offset++) {
      final month = _MonthKey(now.year, now.month - offset).normalized;
      final previousMonth = month.previous;
      final monthOrders = orders
          .where((order) => _MonthKey.fromDate(_orderDate(order, now)) == month)
          .toList(growable: false);
      final previousOrders = orders
          .where((order) =>
              _MonthKey.fromDate(_orderDate(order, now)) == previousMonth)
          .toList(growable: false);
      final revenue = _revenueFor(monthOrders);
      rows.add(
        AdminReportMonthRow(
          monthLabel: month.label,
          revenue: revenue,
          profit: _profitFor(monthOrders),
          growthPercent: _changePercent(revenue, _revenueFor(previousOrders)),
        ),
      );
    }
    return rows;
  }

  static Map<String, _CookReportBucket> _cookBuckets(
    List<CustomerOrderModel> orders,
    List<AdminUserRecord> users,
  ) {
    final buckets = <String, _CookReportBucket>{};
    for (final user in users.where((user) => user.role == 'cook')) {
      buckets[user.id] = _CookReportBucket(
        id: user.id,
        name: user.name.trim().isEmpty ? 'Cook' : user.name.trim(),
      );
    }

    for (final order in orders.where(_isDelivered)) {
      final key = order.cookId.trim().isNotEmpty
          ? order.cookId.trim()
          : order.cookName.trim().toLowerCase();
      if (key.isEmpty) continue;
      final bucket = buckets.putIfAbsent(
        key,
        () => _CookReportBucket(
          id: key,
          name: order.cookName.trim().isEmpty ? 'Cook' : order.cookName.trim(),
        ),
      );
      bucket.revenue += _orderAmount(order);
      bucket.orders += 1;
    }
    return buckets;
  }

  static List<AdminReportRankItem> _rankCooksByRevenue(
    List<CustomerOrderModel> orders,
    List<AdminUserRecord> users,
  ) {
    final items = _cookBuckets(orders, users).values.toList()
      ..sort((a, b) {
        final revenueCompare = b.revenue.compareTo(a.revenue);
        if (revenueCompare != 0) return revenueCompare;
        return a.name.compareTo(b.name);
      });
    return items
        .take(5)
        .map(
            (item) => AdminReportRankItem(name: item.name, value: item.revenue))
        .toList(growable: false);
  }

  static List<AdminReportRankItem> _rankCooksByOrders(
    List<CustomerOrderModel> orders,
    List<AdminUserRecord> users,
  ) {
    final items = _cookBuckets(orders, users).values.toList()
      ..sort((a, b) {
        final ordersCompare = b.orders.compareTo(a.orders);
        if (ordersCompare != 0) return ordersCompare;
        return a.name.compareTo(b.name);
      });
    return items
        .take(5)
        .map((item) => AdminReportRankItem(
              name: item.name,
              value: item.orders.toDouble(),
            ))
        .toList(growable: false);
  }
}

class AdminReportDayMetric {
  const AdminReportDayMetric({
    required this.dayLabel,
    required this.revenue,
  });

  final String dayLabel;
  final double revenue;
}

class AdminReportMonthRow {
  const AdminReportMonthRow({
    required this.monthLabel,
    required this.revenue,
    required this.profit,
    required this.growthPercent,
  });

  final String monthLabel;
  final double revenue;
  final double profit;
  final double growthPercent;
}

class AdminReportRankItem {
  const AdminReportRankItem({
    required this.name,
    required this.value,
  });

  final String name;
  final double value;
}

class _PaymentMix {
  const _PaymentMix({
    required this.onlinePercent,
    required this.cashPercent,
  });

  final int onlinePercent;
  final int cashPercent;
}

class _CookReportBucket {
  _CookReportBucket({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
  double revenue = 0;
  int orders = 0;
}

class _MonthKey {
  const _MonthKey(this.year, this.month);

  factory _MonthKey.fromDate(DateTime date) => _MonthKey(date.year, date.month);

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final int year;
  final int month;

  _MonthKey get normalized {
    final date = DateTime(year, month);
    return _MonthKey(date.year, date.month);
  }

  _MonthKey get previous {
    final date = DateTime(year, month - 1);
    return _MonthKey(date.year, date.month);
  }

  String get label {
    final current = normalized;
    return '${_monthNames[current.month - 1]} ${current.year}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _MonthKey &&
        other.normalized.year == normalized.year &&
        other.normalized.month == normalized.month;
  }

  @override
  int get hashCode => Object.hash(normalized.year, normalized.month);
}
