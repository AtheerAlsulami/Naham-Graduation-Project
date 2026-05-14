import 'package:naham_app/models/admin_report_model.dart';
import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/services/backend/admin_user_types.dart';
import 'package:naham_app/services/backend/backend_admin_user_service.dart';
import 'package:naham_app/services/backend/backend_order_service.dart';

class BackendAdminReportService {
  BackendAdminReportService({
    BackendOrderService? orderService,
    BackendAdminUserService? adminUserService,
  })  : _orderService = orderService ?? BackendOrderService(),
        _adminUserService = adminUserService ?? BackendAdminUserService();

  final BackendOrderService _orderService;
  final BackendAdminUserService _adminUserService;

  Future<AdminReportSnapshot> loadReport({DateTime? now}) async {
    final ordersFuture = _orderService.listOrders(limit: 1000);
    final usersFuture = _adminUserService.listUsers(limit: 1000);

    final List<CustomerOrderModel> orders = await ordersFuture;
    final List<AdminUserRecord> users = await usersFuture;

    return AdminReportSnapshot.fromData(
      orders: orders,
      users: users,
      now: now ?? DateTime.now(),
    );
  }
}
