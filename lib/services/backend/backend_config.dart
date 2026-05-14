class BackendConfig {
  BackendConfig._();

  static const String awsAuthBaseUrl = String.fromEnvironment(
    'AWS_API_BASE_URL',
    defaultValue: 'https://4m3cxo5831.execute-api.eu-north-1.amazonaws.com',
  );
  static const String awsReelsBaseUrl = String.fromEnvironment(
    'AWS_REELS_API_BASE_URL',
    defaultValue: 'https://lw0yawe0s5.execute-api.eu-north-1.amazonaws.com',
  );
  static const String awsDishesBaseUrl = String.fromEnvironment(
    'AWS_DISHES_API_BASE_URL',
    defaultValue: 'https://yn6aki3dgl.execute-api.eu-north-1.amazonaws.com',
  );
  static const String awsPricingBaseUrl = String.fromEnvironment(
    'AWS_PRICING_API_BASE_URL',
    defaultValue: 'https://yn6aki3dgl.execute-api.eu-north-1.amazonaws.com',
  );
  static const String awsChatBaseUrl = String.fromEnvironment(
    'AWS_CHAT_API_BASE_URL',
    defaultValue: 'https://3n7bie90aj.execute-api.eu-north-1.amazonaws.com',
  );
  static const String awsOrdersBaseUrl = String.fromEnvironment(
    'AWS_ORDERS_API_BASE_URL',
    defaultValue: 'https://u016pks2hb.execute-api.eu-north-1.amazonaws.com',
  );
  static const String awsUsersBaseUrl = String.fromEnvironment(
    'AWS_USERS_API_BASE_URL',
    defaultValue: 'https://1tt7d22248.execute-api.eu-north-1.amazonaws.com',
  );
  static const String awsHygieneBaseUrl = String.fromEnvironment(
    'AWS_HYGIENE_API_BASE_URL',
    defaultValue: 'https://qyu1ipfryh.execute-api.eu-north-1.amazonaws.com',
  );
  static const String awsNotificationsBaseUrl = String.fromEnvironment(
    'AWS_NOTIFICATIONS_API_BASE_URL',
    defaultValue: 'https://mqz3ibp0nk.execute-api.eu-north-1.amazonaws.com',
  );

  static const String pricingAiProvider = String.fromEnvironment(
    'PRICING_AI_PROVIDER',
    defaultValue: 'groqDirect',
  );
  static const String hardcodedGroqApiKey =
      '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';
  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: hardcodedGroqApiKey,
  );
  static const String groqModel = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'llama-3.1-8b-instant',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '259916602357-70cgo29dd0f069ja9qg1t6mr0k8lk77g.apps.googleusercontent.com',
  );
}
