import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/router/app_router.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/cart_provider.dart';
import 'package:naham_app/providers/chat_provider.dart';
import 'package:naham_app/providers/cook_provider.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:naham_app/providers/hygiene_inspection_provider.dart';
import 'package:naham_app/providers/orders_provider.dart';
import 'package:naham_app/providers/follow_provider.dart';
import 'package:naham_app/core/providers/notifications_provider.dart';
import 'package:naham_app/services/backend/backend_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NahamApp());
}

class NahamApp extends StatelessWidget {
  const NahamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProxyProvider<AuthProvider, OrdersProvider>(
          create: (_) => OrdersProvider(),
          update: (_, authProvider, ordersProvider) {
            final provider = ordersProvider ?? OrdersProvider();
            provider.bindAuthUser(authProvider.currentUser);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, authProvider, chatProvider) {
            final provider = chatProvider ?? ChatProvider();
            provider.bindAuthUser(authProvider.currentUser);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, HygieneInspectionProvider>(
          create: (_) => HygieneInspectionProvider(),
          update: (_, authProvider, hygieneProvider) {
            final provider = hygieneProvider ?? HygieneInspectionProvider();
            final user = authProvider.currentUser;
            if (user != null && user.role == AppConstants.roleCook) {
              provider.bindCook(user.id);
            } else {
              provider.bindCook(null);
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => CookProvider()),
        ChangeNotifierProvider(create: (_) => DishProvider()),
        ChangeNotifierProxyProvider<AuthProvider, FollowProvider>(
          create: (_) => FollowProvider(),
          update: (_, authProvider, followProvider) {
            final provider = followProvider ?? FollowProvider();
            provider.bindAuthUser(authProvider.currentUser?.id);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationsProvider>(
          create: (_) => NotificationsProvider(BackendNotificationService()),
          update: (_, authProvider, notificationsProvider) {
            final provider = notificationsProvider ??
                NotificationsProvider(BackendNotificationService());
            final user = authProvider.currentUser;
            provider.bindAuthUser(userId: user?.id, userType: user?.role);
            return provider;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.createRouter(context),
          );
        },
      ),
    );
  }
}
