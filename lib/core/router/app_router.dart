import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/screens/auth/login_screen.dart';
import 'package:naham_app/screens/auth/register_screen.dart';
import 'package:naham_app/screens/auth/role_selection_screen.dart';
import 'package:naham_app/screens/splash_screen.dart';
import 'package:naham_app/screens/customer/customer_home_screen.dart';
import 'package:naham_app/screens/customer/customer_notifications_screen.dart';
import 'package:naham_app/screens/customer/category_dishes_screen.dart';
import 'package:naham_app/screens/customer/dish_detail_screen.dart';
import 'package:naham_app/screens/customer/cook_profile_screen.dart';
import 'package:naham_app/screens/customer/search_screen.dart';
import 'package:naham_app/screens/customer/cart_screen.dart';
import 'package:naham_app/screens/customer/checkout_screen.dart';
import 'package:naham_app/screens/customer/order_tracking_screen.dart';
import 'package:naham_app/screens/customer/shipping_address_screen.dart';
import 'package:naham_app/screens/customer/customer_order_waiting_approval_screen.dart';
import 'package:naham_app/models/delivery_address_model.dart';
import 'package:naham_app/screens/cook/cook_dashboard_screen.dart';
import 'package:naham_app/screens/cook/cook_bank_account_screen.dart';
import 'package:naham_app/screens/cook/cook_hygiene_history_screen.dart';
import 'package:naham_app/screens/cook/cook_live_inspection_screen.dart';
import 'package:naham_app/screens/cook/cook_ai_pricing_screen.dart';
import 'package:naham_app/screens/cook/cook_reports_screen.dart';
import 'package:naham_app/screens/cook/cook_dish_form_screen.dart';
import 'package:naham_app/screens/cook/cook_chat_support_screen.dart';
import 'package:naham_app/screens/cook/cook_menu_screen.dart';
import 'package:naham_app/screens/cook/cook_notifications_screen.dart';
import 'package:naham_app/screens/cook/cook_orders_screen.dart';
import 'package:naham_app/screens/cook/cook_profile_screen.dart'
    as cook_profile;
import 'package:naham_app/screens/cook/cook_working_hours_screen.dart';
import 'package:naham_app/screens/cook/cook_reel_camera_screen.dart';
import 'package:naham_app/screens/cook/cook_reel_details_screen.dart';
import 'package:naham_app/screens/cook/cook_reels_screen.dart';
import 'package:naham_app/screens/cook/cook_verification_upload_screen.dart';
import 'package:naham_app/screens/cook/cook_waiting_approval_screen.dart';
import 'package:naham_app/screens/admin/admin_dashboard_screen.dart';
import 'package:naham_app/screens/admin/admin_notifications_screen.dart';
import 'package:naham_app/screens/admin/admin_orders_management_screen.dart';
import 'package:naham_app/screens/admin/admin_user_management_screen.dart';
import 'package:naham_app/screens/admin/admin_chat_support_screen.dart';
import 'package:naham_app/screens/admin/admin_pending_approvals_screen.dart';
import 'package:naham_app/screens/admin/admin_reports_screen.dart';
import 'package:naham_app/screens/admin/admin_hygiene_inspections_screen.dart';
import 'package:naham_app/screens/admin/admin_live_inspection_screen.dart';
import 'package:naham_app/screens/cook/widgets/cook_inspection_listener.dart';

class AppRouter {
  static Widget _wrapCook(Widget child) => CookInspectionListener(child: child);

  static String? resolveCookStatusRoute(UserModel? user) {
    return _getCookStatusRoute(user);
  }

  static GoRouter createRouter(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isLoading = authProvider.status == AuthStatus.initial ||
            authProvider.status == AuthStatus.loading;

        if (isLoading) return null;

        final isAuthenticated = authProvider.isAuthenticated;
        final currentPath = state.uri.path;

        final publicRoutes = [
          AppRoutes.splash,
          AppRoutes.login,
          AppRoutes.register,
          AppRoutes.roleSelection,
        ];

        if (!isAuthenticated &&
            !publicRoutes.contains(currentPath) &&
            !currentPath.startsWith(AppRoutes.login) &&
            !currentPath.startsWith(AppRoutes.register) &&
            !currentPath.startsWith(AppRoutes.roleSelection)) {
          return AppRoutes.login;
        }

        if (isAuthenticated &&
            (currentPath.startsWith(AppRoutes.login) ||
                currentPath.startsWith(AppRoutes.register) ||
                currentPath.startsWith(AppRoutes.roleSelection))) {
          return _getHomeRoute(authProvider.currentUser);
        }

        final cookRedirect = _getCookAccessRedirect(
          authProvider.currentUser,
          currentPath,
        );
        if (cookRedirect != null) {
          return cookRedirect;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) {
            final registration = state.extra is PendingRegistration
                ? state.extra as PendingRegistration
                : null;
            return RegisterScreen(initialData: registration);
          },
        ),
        GoRoute(
          path: AppRoutes.roleSelection,
          builder: (context, state) {
            final registration = state.extra is PendingRegistration
                ? state.extra as PendingRegistration
                : null;
            return RoleSelectionScreen(registration: registration);
          },
        ),

        // ─── Customer ───
        GoRoute(
          path: AppRoutes.customerHome,
          builder: (context, state) => CustomerHomeScreen(
            initialTab: state.uri.queryParameters['tab'],
            initialConversationId: state.uri.queryParameters['conversation'],
            initialOrderImage: state.uri.queryParameters['orderImage'],
          ),
        ),
        GoRoute(
          path: '${AppRoutes.dishDetail}/:id',
          builder: (context, state) {
            final dishId = state.pathParameters['id'] ?? '';
            return DishDetailScreen(dishId: dishId);
          },
        ),
        GoRoute(
          path: '${AppRoutes.categoryDishes}/:id',
          builder: (context, state) {
            final categoryId = state.pathParameters['id'] ?? '';
            return CategoryDishesScreen(categoryId: categoryId);
          },
        ),
        GoRoute(
          path: AppRoutes.cookProfile,
          builder: (context, state) {
            final cookData = state.extra as Map<String, dynamic>? ?? {};
            return CookProfileScreen(cookData: cookData);
          },
        ),

        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: AppRoutes.customerNotifications,
          builder: (context, state) => const CustomerNotificationsScreen(),
        ),
        GoRoute(
          path: AppRoutes.cart,
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: AppRoutes.checkout,
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: AppRoutes.shippingAddress,
          builder: (context, state) {
            final address = state.extra as DeliveryAddressModel? ??
                const DeliveryAddressModel(
                  country: 'Saudi Arabia',
                  address: 'King Abdullah Street,Apt 4B',
                  city: 'Riyadh',
                  postcode: '16000',
                );
            return ShippingAddressScreen(initialAddress: address);
          },
        ),
        GoRoute(
          path: '${AppRoutes.orderTracking}/:id',
          builder: (context, state) {
            final orderId = state.pathParameters['id'] ?? '';
            return OrderTrackingScreen(orderId: orderId);
          },
        ),
        GoRoute(
          path: '${AppRoutes.orderWaitingApproval}/:id',
          builder: (context, state) {
            final orderId = state.pathParameters['id'] ?? '';
            return CustomerOrderWaitingApprovalScreen(orderId: orderId);
          },
        ),

        // ─── Cook ───
        GoRoute(
          path: AppRoutes.cookReels,
          builder: (context, state) => _wrapCook(const CookReelsScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookReelCamera,
          builder: (context, state) => _wrapCook(const CookReelCameraScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookReelDetails,
          builder: (context, state) {
            final videoPath = state.extra as String? ?? '';
            return _wrapCook(CookReelDetailsScreen(videoPath: videoPath));
          },
        ),
        GoRoute(
          path: AppRoutes.cookDashboard,
          builder: (context, state) => _wrapCook(const CookDashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookVerificationUpload,
          builder: (context, state) => _wrapCook(const CookVerificationUploadScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookWaitingApproval,
          builder: (context, state) => _wrapCook(const CookWaitingApprovalScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookWorkingHours,
          builder: (context, state) => _wrapCook(const CookWorkingHoursScreen()),
        ),
        GoRoute(
          path: AppRoutes.myMenu,
          builder: (context, state) => _wrapCook(const CookMenuScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookOrders,
          builder: (context, state) => _wrapCook(const CookOrdersScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookAiPricing,
          builder: (context, state) {
            final payload = state.extra is CookAiPricingPayload
                ? state.extra as CookAiPricingPayload
                : const CookAiPricingPayload(
                    categoryId: 'najdi',
                    preparationMinutes: 25,
                  );
            return _wrapCook(CookAiPricingScreen(payload: payload));
          },
        ),
        GoRoute(
          path: AppRoutes.cookChat,
          builder: (context, state) {
            final tab = CookChatListFilter.fromQuery(
              state.uri.queryParameters['tab'],
            );
            final conversationId = state.uri.queryParameters['conversation'];
            return _wrapCook(CookChatSupportScreen(
              initialFilter: tab,
              initialConversationId: conversationId,
            ));
          },
        ),
        GoRoute(
          path: AppRoutes.addEditDish,
          builder: (context, state) {
            final payload = state.extra is CookDishFormPayload
                ? state.extra as CookDishFormPayload
                : const CookDishFormPayload.add();
            return _wrapCook(CookDishFormScreen(payload: payload));
          },
        ),
        GoRoute(
          path: AppRoutes.cookNotifications,
          builder: (context, state) => _wrapCook(const CookNotificationsScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookBankAccount,
          builder: (context, state) => _wrapCook(const CookBankAccountScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookHygieneHistory,
          builder: (context, state) => _wrapCook(const CookHygieneHistoryScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookLiveInspection,
          builder: (context, state) {
            final payload = state.extra is CookInspectionCallPayload
                ? state.extra as CookInspectionCallPayload
                : const CookInspectionCallPayload(
                    requestId: 'local_preview',
                    cookName: 'Cook',
                    adminName: 'System Admin',
                  );
            return CookLiveInspectionScreen(payload: payload);
          },
        ),
        GoRoute(
          path: AppRoutes.cookReports,
          builder: (context, state) => _wrapCook(const CookReportsScreen()),
        ),
        GoRoute(
          path: AppRoutes.cookPublicProfile,
          builder: (context, state) => _wrapCook(const cook_profile.CookProfileScreen()),
        ),

        // ─── Admin ───
        GoRoute(
          path: AppRoutes.adminDashboard,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminNotifications,
          builder: (context, state) => const AdminNotificationsScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminOrders,
          builder: (context, state) => const AdminOrdersManagementScreen(),
        ),
        GoRoute(
          path: AppRoutes.cookVerification,
          builder: (context, state) => const AdminPendingApprovalsScreen(),
        ),
        GoRoute(
          path: AppRoutes.userManagement,
          builder: (context, state) => const AdminUserManagementScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminChatSupport,
          builder: (context, state) => const AdminChatSupportScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminReports,
          builder: (context, state) => const AdminReportsScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminHygieneInspections,
          builder: (context, state) => const AdminHygieneInspectionsScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminLiveInspection,
          builder: (context, state) {
            final payload = state.extra is LiveInspectionSessionPayload
                ? state.extra as LiveInspectionSessionPayload
                : null;
            return AdminLiveInspectionScreen(payload: payload);
          },
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Page not found: ${state.uri}'),
        ),
      ),
    );
  }

  static String? _getHomeRoute(UserModel? user) {
    if (user == null) return AppRoutes.login;
    final role = user.role;

    switch (role) {
      case AppConstants.roleCustomer:
        return AppRoutes.customerHome;
      case AppConstants.roleCook:
        return _getCookStatusRoute(user);
      case AppConstants.roleAdmin:
        return AppRoutes.adminDashboard;
      default:
        return AppRoutes.login;
    }
  }

  static String? _getCookAccessRedirect(UserModel? user, String currentPath) {
    if (user?.role != AppConstants.roleCook || !_isCookRoute(currentPath)) {
      return null;
    }

    final allowedRoute = _getCookStatusRoute(user);
    if (allowedRoute == null || currentPath == allowedRoute) {
      return null;
    }

    if (user!.cookStatus == AppConstants.cookApproved &&
        currentPath != AppRoutes.cookVerificationUpload &&
        currentPath != AppRoutes.cookWaitingApproval) {
      return null;
    }

    return allowedRoute;
  }

  static String? _getCookStatusRoute(UserModel? user) {
    final status = user?.cookStatus;
    if (status == AppConstants.cookApproved) {
      return AppRoutes.cookDashboard;
    }
    if (status == AppConstants.cookPendingVerification) {
      return AppRoutes.cookWaitingApproval;
    }
    return AppRoutes.cookVerificationUpload;
  }

  static bool _isCookRoute(String path) {
    return path == '/cook' || path.startsWith('/cook/');
  }
}
