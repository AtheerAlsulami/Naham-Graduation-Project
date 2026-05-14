import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naham_app/core/constants/app_constants.dart';

void main() {
  test('customer notifications route is registered with the app router', () {
    expect(AppRoutes.customerNotifications, '/customer/notifications');

    final routerSource =
        File('lib/core/router/app_router.dart').readAsStringSync();
    expect(routerSource, contains('CustomerNotificationsScreen'));
    expect(routerSource, contains('path: AppRoutes.customerNotifications'));
  });
}
