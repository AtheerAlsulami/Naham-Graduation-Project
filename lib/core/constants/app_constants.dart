class AppConstants {
  // App Info
  static const String appName = 'Naham';
  static const String appNameEn = 'Naham';
  static const String appTagline = 'Homemade meals at your door';

  // User Roles
  static const String roleCustomer = 'customer';
  static const String roleCook = 'cook';
  static const String roleAdmin = 'admin';

  // Temporary Admin (for local/system bootstrap)
  static const String tempAdminEmail = 'admin@naham.local';
  static const String tempAdminPassword = 'Admin@123456';
  static const String tempAdminName = 'System Admin';
  static const String tempAdminPhone = '+966500000000';

  // Order Status
  static const String orderPending = 'pending';
  static const String orderConfirmed = 'confirmed';
  static const String orderPreparing = 'preparing';
  static const String orderReadyForPickup = 'ready_for_pickup';
  static const String orderDelivered = 'delivered';
  static const String orderCancelled = 'cancelled';

  // Cook Status
  static const String cookPendingVerification = 'pending_verification';
  static const String cookApproved = 'approved';
  static const String cookRejected = 'rejected';
  static const String cookFrozen = 'frozen';
  static const String cookBlocked = 'blocked';

  // Payment Methods
  static const String paymentMada = 'mada';
  static const String paymentStcPay = 'stc_pay';
  static const String paymentCash = 'cash';

  // Kitchen Verification
  static const String verificationPending = 'pending';
  static const String verificationApproved = 'approved';
  static const String verificationFailed = 'failed';

  // SharedPreferences Keys
  static const String prefUserRole = 'user_role';
  static const String prefUserId = 'user_id';
  static const String prefOnboardingComplete = 'onboarding_complete';
  static const String prefIsLoggedIn = 'is_logged_in';

  // Food Categories
  static const List<Map<String, String>> foodCategories = [
    {'id': 'northern', 'name': 'Northern Dishes', 'icon': 'N'},
    {'id': 'southern', 'name': 'Southern Dishes', 'icon': 'S'},
    {'id': 'seafood', 'name': 'Seafood', 'icon': 'SF'},
    {'id': 'sweets', 'name': 'Sweets', 'icon': 'SW'},
    {'id': 'healthy', 'name': 'Healthy', 'icon': 'H'},
    {'id': 'traditional', 'name': 'Traditional', 'icon': 'T'},
    {'id': 'grilled', 'name': 'Grilled', 'icon': 'G'},
    {'id': 'breakfast', 'name': 'Breakfast', 'icon': 'B'},
  ];

  // Cuisine Regions
  static const List<String> saudiRegions = [
    'Riyadh',
    'Jeddah',
    'Makkah',
    'Madinah',
    'Dammam',
    'Taif',
    'Al Ahsa',
    'Tabuk',
    'Abha',
    'Qassim',
  ];

  // Durations
  static const int splashDurationSeconds = 3;
  static const int maxOrderCancellationMinutes = 5;
}

class AppRoutes {
  static const String splash = '/';

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/auth/role-selection';

  // Customer
  static const String customerHome = '/customer/home';
  static const String cookProfile = '/customer/cook-profile';
  static const String dishDetail = '/customer/dish-detail';
  static const String categoryDishes = '/customer/category';
  static const String search = '/customer/search';
  static const String cart = '/customer/cart';
  static const String checkout = '/customer/checkout';
  static const String shippingAddress = '/customer/shipping-address';
  static const String payment = '/customer/payment';
  static const String myOrders = '/customer/orders';
  static const String orderTracking = '/customer/order-tracking';
  static const String orderWaitingApproval = '/customer/order-waiting-approval';
  static const String rateReview = '/customer/rate-review';
  static const String customerProfile = '/customer/profile';
  static const String chat = '/customer/chat';
  static const String customerNotifications = '/customer/notifications';

  // Cook
  static const String cookReels = '/cook/reels';
  static const String cookReelCamera = '/cook/reels/camera';
  static const String cookReelDetails = '/cook/reels/details';
  static const String cookDashboard = '/cook/dashboard';
  static const String cookWorkingHours = '/cook/working-hours';
  static const String myMenu = '/cook/menu';
  static const String addEditDish = '/cook/add-dish';
  static const String cookOrders = '/cook/orders';
  static const String cookOrderDetail = '/cook/order-detail';
  static const String cookAnalytics = '/cook/analytics';
  static const String cookAiPricing = '/cook/ai-pricing';
  static const String cookReports = '/cook/reports';
  static const String cookHygieneHistory = '/cook/hygiene-history';
  static const String cookLiveInspection = '/cook/hygiene-live';
  static const String cookPublicProfile = '/cook/profile';
  static const String cookChat = '/cook/chat';
  static const String cookNotifications = '/cook/notifications';
  static const String cookBankAccount = '/cook/bank-account';
  static const String cookVerificationUpload = '/cook/verification-upload';
  static const String cookWaitingApproval = '/cook/waiting-approval';

  // Admin
  static const String adminDashboard = '/admin/dashboard';
  static const String adminNotifications = '/admin/notifications';
  static const String cookVerification = '/admin/cook-verification';
  static const String adminOrders = '/admin/orders';
  static const String userManagement = '/admin/users';
  static const String adminChatSupport = '/admin/chat-support';
  static const String adminCashManagement = '/admin/cash-management';
  static const String adminReports = '/admin/reports';
  static const String adminHygieneInspections = '/admin/hygiene-inspections';
  static const String adminLiveInspection = '/admin/hygiene-inspections/live';
}
