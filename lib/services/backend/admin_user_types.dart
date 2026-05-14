class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.rating,
    required this.orders,
    this.complaints,
    this.cookStatus,
    this.createdAt,
    this.verificationIdUrl,
    this.verificationHealthUrl,
    this.documents,
    this.isOnline,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final double rating;
  final int orders;
  final int? complaints;
  final String? cookStatus;
  final DateTime? createdAt;
  final String? verificationIdUrl;
  final String? verificationHealthUrl;
  final List<AdminUserDocument>? documents;
  final bool? isOnline;
}

class AdminUserDocument {
  const AdminUserDocument({
    required this.title,
    required this.url,
    required this.type,
  });

  final String title;
  final String url;
  final String type;
}

class CreateAdminUserRequest {
  const CreateAdminUserRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    required this.status,
    required this.rating,
    required this.orders,
    this.complaints,
  });

  final String name;
  final String email;
  final String phone;
  final String password;
  final String role;
  final String status;
  final double rating;
  final int orders;
  final int? complaints;
}
