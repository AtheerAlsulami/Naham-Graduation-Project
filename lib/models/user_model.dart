import 'dart:convert';

import 'package:naham_app/core/constants/app_constants.dart';

class UserModel {
  final String id;
  final String name;
  final String? displayName;
  final String email;
  final String phone;
  final String role; // customer | cook | admin
  final String? profileImageUrl;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  // Cook-specific fields
  final String?
      cookStatus; // pending_verification | approved | rejected | frozen | blocked
  final double? rating;
  final int? totalOrders;
  final Map<String, int> monthlyOrderCounts;
  final int currentMonthOrders;
  final int followersCount;
  final int reelLikesCount;
  final int ordersPlacedCount;
  final int likedReelsCount;
  final int followingCooksCount;
  final bool? isOnline;
  final int? dailyCapacity;
  final Map<String, dynamic>? workingHours;
  final String? specialty;
  final String? priceRange;
  final String? deliveryTime;
  final String? verificationIdUrl;
  final String? verificationHealthUrl;

  const UserModel({
    required this.id,
    required this.name,
    this.displayName,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    this.address,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.cookStatus,
    this.rating,
    this.totalOrders,
    this.monthlyOrderCounts = const {},
    this.currentMonthOrders = 0,
    this.followersCount = 0,
    this.reelLikesCount = 0,
    this.ordersPlacedCount = 0,
    this.likedReelsCount = 0,
    this.followingCooksCount = 0,
    this.isOnline,
    this.dailyCapacity,
    this.workingHours,
    this.specialty,
    this.priceRange,
    this.deliveryTime,
    this.verificationIdUrl,
    this.verificationHealthUrl,
  });

  bool get isCustomer => role == AppConstants.roleCustomer;
  bool get isCook => role == AppConstants.roleCook;
  bool get isAdmin => role == AppConstants.roleAdmin;
  bool get isCookApproved => cookStatus == AppConstants.cookApproved;

  UserModel copyWith({
    String? id,
    String? name,
    String? displayName,
    String? email,
    String? phone,
    String? role,
    String? profileImageUrl,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    String? cookStatus,
    double? rating,
    int? totalOrders,
    Map<String, int>? monthlyOrderCounts,
    int? currentMonthOrders,
    int? followersCount,
    int? reelLikesCount,
    int? ordersPlacedCount,
    int? likedReelsCount,
    int? followingCooksCount,
    bool? isOnline,
    int? dailyCapacity,
    Map<String, dynamic>? workingHours,
    String? specialty,
    String? priceRange,
    String? deliveryTime,
    String? verificationIdUrl,
    String? verificationHealthUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      cookStatus: cookStatus ?? this.cookStatus,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      monthlyOrderCounts: monthlyOrderCounts ?? this.monthlyOrderCounts,
      currentMonthOrders: currentMonthOrders ?? this.currentMonthOrders,
      followersCount: followersCount ?? this.followersCount,
      reelLikesCount: reelLikesCount ?? this.reelLikesCount,
      ordersPlacedCount: ordersPlacedCount ?? this.ordersPlacedCount,
      likedReelsCount: likedReelsCount ?? this.likedReelsCount,
      followingCooksCount: followingCooksCount ?? this.followingCooksCount,
      isOnline: isOnline ?? this.isOnline,
      dailyCapacity: dailyCapacity ?? this.dailyCapacity,
      workingHours: workingHours ?? this.workingHours,
      specialty: specialty ?? this.specialty,
      priceRange: priceRange ?? this.priceRange,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      verificationIdUrl: verificationIdUrl ?? this.verificationIdUrl,
      verificationHealthUrl:
          verificationHealthUrl ?? this.verificationHealthUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
      'cookStatus': cookStatus,
      'rating': rating,
      'totalOrders': totalOrders,
      'monthlyOrderCounts': monthlyOrderCounts,
      'currentMonthOrders': currentMonthOrders,
      'followersCount': followersCount,
      'reelLikesCount': reelLikesCount,
      'ordersPlacedCount': ordersPlacedCount,
      'likedReelsCount': likedReelsCount,
      'followingCooksCount': followingCooksCount,
      'isOnline': isOnline,
      'dailyCapacity': dailyCapacity,
      'workingHours': workingHours,
      'specialty': specialty,
      'priceRange': priceRange,
      'deliveryTime': deliveryTime,
      'verificationIdUrl': verificationIdUrl,
      'verificationHealthUrl': verificationHealthUrl,
    };
  }

  static double? _readDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static bool? _readBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _readWorkingHours(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, item) => MapEntry(key.toString(), item));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Map<String, int> _readIntMap(dynamic value) {
    if (value == null) {
      return const {};
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return const {};
      }
      try {
        return _readIntMap(jsonDecode(trimmed));
      } catch (_) {
        return const {};
      }
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _readInt(item) ?? 0),
      );
    }
    return const {};
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      displayName: map['displayName'],
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? AppConstants.roleCustomer,
      profileImageUrl: map['profileImageUrl'],
      address: map['address'],
      latitude: _readDouble(map['latitude']),
      longitude: _readDouble(map['longitude']),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      cookStatus: map['cookStatus'],
      rating: _readDouble(map['rating']),
      totalOrders: _readInt(map['totalOrders']),
      monthlyOrderCounts: _readIntMap(map['monthlyOrderCounts']),
      currentMonthOrders: _readInt(map['currentMonthOrders']) ?? 0,
      followersCount: _readInt(map['followersCount']) ?? 0,
      reelLikesCount: _readInt(map['reelLikesCount']) ?? 0,
      ordersPlacedCount: _readInt(map['ordersPlacedCount']) ?? 0,
      likedReelsCount: _readInt(map['likedReelsCount']) ?? 0,
      followingCooksCount: _readInt(map['followingCooksCount']) ?? 0,
      isOnline: _readBool(map['isOnline']),
      dailyCapacity: _readInt(map['dailyCapacity']),
      workingHours: _readWorkingHours(map['workingHours']),
      specialty: map['specialty']?.toString(),
      priceRange: map['priceRange']?.toString(),
      deliveryTime: map['deliveryTime']?.toString(),
      verificationIdUrl: map['verificationIdUrl']?.toString(),
      verificationHealthUrl: map['verificationHealthUrl']?.toString(),
    );
  }
}
