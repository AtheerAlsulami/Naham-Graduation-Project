import 'package:flutter_test/flutter_test.dart';
import 'package:naham_app/models/admin_report_model.dart';
import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/services/backend/admin_user_types.dart';

void main() {
  test('builds admin report metrics from orders and cooks', () {
    final snapshot = AdminReportSnapshot.fromData(
      now: DateTime(2026, 5, 7),
      users: const [
        AdminUserRecord(
          id: 'cook_1',
          name: 'Salma',
          email: 'salma@example.com',
          phone: '+9661',
          role: 'cook',
          status: 'active',
          rating: 4.8,
          orders: 0,
          cookStatus: 'approved',
        ),
        AdminUserRecord(
          id: 'cook_2',
          name: 'Huda',
          email: 'huda@example.com',
          phone: '+9662',
          role: 'cook',
          status: 'active',
          rating: 4.5,
          orders: 0,
          cookStatus: 'approved',
        ),
      ],
      orders: [
        _order(
          id: 'order_1',
          cookId: 'cook_1',
          cookName: 'Salma',
          totalAmount: 100,
          cookEarnings: 80,
          status: CustomerOrderStatus.delivered,
          paymentMethod: 'credit_card',
          createdAt: DateTime(2026, 5, 1),
        ),
        _order(
          id: 'order_2',
          cookId: 'cook_1',
          cookName: 'Salma',
          totalAmount: 200,
          cookEarnings: 170,
          status: CustomerOrderStatus.delivered,
          paymentMethod: 'cash',
          createdAt: DateTime(2026, 5, 2),
        ),
        _order(
          id: 'order_3',
          cookId: 'cook_2',
          cookName: 'Huda',
          totalAmount: 50,
          cookEarnings: 40,
          status: CustomerOrderStatus.cancelled,
          paymentMethod: 'cash',
          createdAt: DateTime(2026, 5, 3),
        ),
        _order(
          id: 'order_4',
          cookId: 'cook_2',
          cookName: 'Huda',
          totalAmount: 100,
          cookEarnings: 80,
          status: CustomerOrderStatus.delivered,
          paymentMethod: 'credit_card',
          createdAt: DateTime(2026, 4, 3),
        ),
      ],
    );

    expect(snapshot.monthRevenue, 300);
    expect(snapshot.netProfit, 50);
    expect(snapshot.totalOrders, 3);
    expect(snapshot.lossRefunds, 50);
    expect(snapshot.onlinePaymentPercent, 50);
    expect(snapshot.cashPaymentPercent, 50);
    expect(snapshot.dailyRevenuePoints[0], 0.5);
    expect(snapshot.dailyRevenuePoints[1], 1.0);
    expect(snapshot.highestDay.dayLabel, '2');
    expect(snapshot.lowestDay.dayLabel, '1');
    expect(snapshot.topCooksByRevenue.first.name, 'Salma');
    expect(snapshot.topCooksByRevenue.first.value, 300);
    expect(snapshot.topCooksByOrders.first.value, 2);
    expect(snapshot.monthGrowth.first.monthLabel, 'May 2026');
    expect(snapshot.monthGrowth.first.growthPercent, 200);
  });
}

CustomerOrderModel _order({
  required String id,
  required String cookId,
  required String cookName,
  required double totalAmount,
  required double cookEarnings,
  required CustomerOrderStatus status,
  required String paymentMethod,
  required DateTime createdAt,
}) {
  return CustomerOrderModel(
    id: id,
    displayId: id,
    dishId: 'dish_$id',
    dishName: 'Dish',
    cookName: cookName,
    imageUrl: '',
    price: totalAmount,
    status: status,
    infoLabel: '',
    infoValue: '',
    cookId: cookId,
    totalAmount: totalAmount,
    cookEarnings: cookEarnings,
    paymentMethod: paymentMethod,
    createdAt: createdAt,
  );
}
