import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/models/cook_reel_model.dart';
import 'package:naham_app/models/customer_order_model.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/aws/aws_auth_service.dart';
import 'package:naham_app/services/aws/aws_notification_service.dart';
import 'package:naham_app/services/aws/aws_order_service.dart';
import 'package:naham_app/services/aws/aws_pricing_service.dart';
import 'package:naham_app/services/aws/aws_reel_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Flutter login flow uses AwsApiClient and stores Auth Lambda session',
      () async {
    final client = _WorkflowClient((request, body) async {
      expect(request.url.path, '/auth/login');
      expect(jsonDecode(body)['email'], 'customer@example.com');
      return _jsonResponse({
        'user': _userJson(
          id: 'customer_1',
          email: 'customer@example.com',
          role: AppConstants.roleCustomer,
        ),
        'accessToken': 'token_customer_1',
      });
    });
    final service = AwsAuthService(
      apiClient: AwsApiClient(
        baseUrl: 'https://auth.example.com',
        client: client,
      ),
      usersApiClient: AwsApiClient(
        baseUrl: 'https://users.example.com',
        client: _WorkflowClient((_, __) async => _jsonResponse({})),
      ),
    );

    final user = await service.login(
      email: 'customer@example.com',
      password: 'secret123',
    );
    final persisted = await service.getCurrentUser();

    expect(user?.id, 'customer_1');
    expect(persisted?.email, 'customer@example.com');
  });

  test('Order lifecycle creates, accepts, confirms received, and rates order',
      () async {
    final states = <String>[];
    final client = _WorkflowClient((request, body) async {
      if (request.url.path == '/orders') {
        states.add('created');
        return _jsonResponse({'order': _orderJson(status: 'pending_review')});
      }
      final payload = jsonDecode(body) as Map<String, dynamic>;
      switch (payload['action']) {
        case 'accept':
          states.add('accepted');
          return _jsonResponse({'order': _orderJson(status: 'in_progress')});
        case 'mark_arrived':
          states.add('arrived');
          return _jsonResponse({
            'order': _orderJson(status: 'awaiting_customer_confirmation'),
          });
        case 'confirm_received':
          states.add('confirmed');
          return _jsonResponse({
            'order': _orderJson(
              status: 'delivered',
              deliveredAt: '2026-05-11T10:00:00.000Z',
              confirmedReceivedAt: '2026-05-11T10:00:00.000Z',
            ),
          });
        case 'rate':
          states.add('rated');
          return _jsonResponse({
            'order': _orderJson(
              status: 'delivered',
              deliveredAt: '2026-05-11T10:00:00.000Z',
              cookRating: 5,
              serviceRating: 4,
            ),
          });
      }
      return _jsonResponse({'message': 'unexpected action'}, statusCode: 400);
    });
    final service = AwsOrderService(
      apiClient: AwsApiClient(
        baseUrl: 'https://orders.example.com',
        client: client,
      ),
    );

    final created = await service.createOrder(payload: {'customerId': 'c1'});
    final accepted = await service.updateOrderStatus(
      orderId: created.id,
      action: 'accept',
    );
    await service.updateOrderStatus(
      orderId: accepted.id,
      action: 'mark_arrived',
    );
    final delivered = await service.updateOrderStatus(
      orderId: accepted.id,
      action: 'confirm_received',
    );
    final rated = await service.updateOrderStatus(
      orderId: delivered.id,
      action: 'rate',
      cookRating: 5,
      serviceRating: 4,
    );

    expect(states, ['created', 'accepted', 'arrived', 'confirmed', 'rated']);
    expect(delivered.status, CustomerOrderStatus.delivered);
    expect(rated.cookRating, 5);
    expect(rated.serviceRating, 4);
  });

  test('Cook verification flow gets upload URLs then updates cookStatus',
      () async {
    final requests = <String>[];
    final usersClient = _WorkflowClient((request, body) async {
      requests.add(request.url.path);
      if (request.url.path == '/users/upload-url') {
        final payload = jsonDecode(body) as Map<String, dynamic>;
        return _jsonResponse({
          'uploadUrl': 'https://s3.example.com/${payload['documentType']}',
          'fileUrl':
              'https://cdn.example.com/users/cook_1/${payload['documentType']}.pdf',
          'headers': {'Content-Type': payload['contentType']},
        });
      }
      if (request.url.path == '/users/cook_1') {
        final payload = jsonDecode(body) as Map<String, dynamic>;
        expect(payload['cookStatus'], AppConstants.cookPendingVerification);
        return _jsonResponse({
          'user': _userJson(
            id: 'cook_1',
            email: 'cook@example.com',
            role: AppConstants.roleCook,
            cookStatus: AppConstants.cookPendingVerification,
          ),
        });
      }
      return _jsonResponse({'message': 'unexpected request'}, statusCode: 400);
    });
    final service = AwsAuthService(
      apiClient: AwsApiClient(
        baseUrl: 'https://auth.example.com',
        client: _WorkflowClient((_, __) async => _jsonResponse({})),
      ),
      usersApiClient: AwsApiClient(
        baseUrl: 'https://users.example.com',
        client: usersClient,
      ),
    );
    final currentCook = _userJson(
      id: 'cook_1',
      email: 'cook@example.com',
      role: AppConstants.roleCook,
      cookStatus: AppConstants.cookRejected,
    );

    final idUpload = await service.getUploadUrl(
      userId: 'cook_1',
      documentType: 'id',
      fileName: 'id.pdf',
      contentType: 'application/pdf',
    );
    final healthUpload = await service.getUploadUrl(
      userId: 'cook_1',
      documentType: 'health',
      fileName: 'health.pdf',
      contentType: 'application/pdf',
    );
    final updated = await service.updateCookSettings(
      currentUser: _userFromJson(currentCook),
      cookStatus: AppConstants.cookPendingVerification,
      verificationIdUrl: idUpload['fileUrl'] as String,
      verificationHealthUrl: healthUpload['fileUrl'] as String,
    );

    expect(requests, [
      '/users/upload-url',
      '/users/upload-url',
      '/users/cook_1',
    ]);
    expect(updated.cookStatus, AppConstants.cookPendingVerification);
  });

  test('AI pricing flow parses pricing endpoint response', () async {
    final service = AwsPricingService(
      apiClient: AwsApiClient(
        baseUrl: 'https://pricing.example.com',
        client: _WorkflowClient((request, body) async {
          expect(request.url.path, '/pricing/suggest');
          return _jsonResponse({
            'suggestedPrice': 39,
            'breakdown': {
              'ingredientsCost': 12,
              'packagingCost': 1,
              'operationalCost': 6,
              'profitAmount': 5,
              'demandBoost': 2,
              'baseCost': 19,
            },
            'metadata': {
              'marketSignal': 'stable_demand',
              'confidenceScore': 0.85,
              'insights': ['Balanced pricing is recommended.'],
            },
          });
        }),
      ),
    );

    final suggestion = await service.suggestPrice(
      categoryId: 'baked',
      preparationMinutes: 30,
      ingredients: const [
        PricingIngredientInput(weightGram: 200, costPer100Sar: 3),
      ],
      profitMode: 'fixed',
      profitValue: 5,
    );

    expect(suggestion.suggestedPrice, 39);
    expect(suggestion.marketSignal, 'stable_demand');
  });

  test('Reels workflow loads feed, likes reel, and refreshes feed', () async {
    var liked = false;
    final service = AwsReelService(
      apiClient: AwsApiClient(
        baseUrl: 'https://reels.example.com',
        client: _WorkflowClient((request, body) async {
          if (request.method == 'GET') {
            return _jsonResponse({
              'reels': [
                _reel(likes: liked ? 6 : 5, isLiked: liked).toMap(),
              ],
            });
          }
          final payload = jsonDecode(body) as Map<String, dynamic>;
          liked = payload['likeDelta'] == 1;
          return _jsonResponse({'reel': payload});
        }),
      ),
    );

    final before = await service.getReels();
    await service.saveReel(
      before.single.copyWithForTest(likes: 6, isLiked: true),
      likedByUserId: 'customer_1',
      likeDelta: 1,
    );
    final after = await service.getReels();

    expect(before.single.likes, 5);
    expect(after.single.likes, 6);
    expect(after.single.isLiked, isTrue);
  });

  test('Notification workflow creates, fetches, and marks notification read',
      () async {
    var isRead = false;
    final service = AwsNotificationService(
      apiClient: AwsApiClient(
        baseUrl: 'https://notifications.example.com',
        client: _WorkflowClient((request, body) async {
          if (request.url.path == '/notificationsSave') {
            return _jsonResponse(
              {'notification': _notificationJson(isRead: false)},
              statusCode: 201,
            );
          }
          if (request.url.path == '/notificationsList') {
            return _jsonResponse({
              'notifications': [_notificationJson(isRead: isRead)],
            });
          }
          if (request.url.path == '/notificationsMarkRead') {
            isRead = true;
            return _jsonResponse(
                {'notification': _notificationJson(isRead: true)});
          }
          return _jsonResponse({'message': 'unexpected request'},
              statusCode: 400);
        }),
      ),
    );

    final created = await service.createNotification(
      userId: 'customer_1',
      userType: 'customer',
      title: 'Order update',
      type: 'order',
      data: {'orderId': 'order_1'},
    );
    final fetched = await service.getNotifications(
      userId: 'customer_1',
      userType: 'customer',
    );
    final read = await service.markAsRead(created.id);

    expect(fetched.single.isRead, isFalse);
    expect(read.isRead, isTrue);
  });
}

Map<String, dynamic> _userJson({
  required String id,
  required String email,
  required String role,
  String? cookStatus,
}) {
  return {
    'id': id,
    'name': role == AppConstants.roleCook ? 'Cook' : 'Customer',
    'email': email,
    'phone': '+966500000000',
    'role': role,
    'createdAt': '2026-05-11T00:00:00.000Z',
    if (cookStatus != null) 'cookStatus': cookStatus,
  };
}

UserModel _userFromJson(Map<String, dynamic> data) {
  return UserModel.fromMap(data);
}

Map<String, dynamic> _orderJson({
  required String status,
  String? deliveredAt,
  String? confirmedReceivedAt,
  int? cookRating,
  int? serviceRating,
}) {
  return {
    'id': 'order_1',
    'displayId': '#ORD-1',
    'customerId': 'customer_1',
    'customerName': 'Customer',
    'cookId': 'cook_1',
    'cookName': 'Cook',
    'status': status,
    'dishId': 'dish_1',
    'dishName': 'Kabsa',
    'imageUrl': '',
    'itemCount': 1,
    'items': [
      {'dishId': 'dish_1', 'dishName': 'Kabsa', 'quantity': 1, 'price': 30},
    ],
    'subtotal': 30,
    'deliveryFee': 5,
    'totalAmount': 35,
    'cookEarnings': 28.5,
    'rating': cookRating ?? 0,
    if (cookRating != null) 'cookRating': cookRating,
    if (serviceRating != null) 'serviceRating': serviceRating,
    if (deliveredAt != null) 'deliveredAt': deliveredAt,
    if (confirmedReceivedAt != null) 'confirmedReceivedAt': confirmedReceivedAt,
    'createdAt': '2026-05-11T09:00:00.000Z',
  };
}

CookReelModel _reel({required int likes, required bool isLiked}) {
  return CookReelModel(
    id: 'reel_1',
    creatorId: 'cook_1',
    creatorName: 'Cook',
    title: 'Kabsa reel',
    description: 'Cooking clip',
    videoPath: 'https://cdn.example.com/reel.mp4',
    audioLabel: 'Original Audio',
    likes: likes,
    comments: 0,
    shares: 0,
    isMine: false,
    isFollowing: false,
    isLiked: isLiked,
    isPaused: false,
    isBookmarked: false,
    isDraft: false,
    createdAt: DateTime.parse('2026-05-11T09:00:00.000Z'),
  );
}

Map<String, dynamic> _notificationJson({required bool isRead}) {
  return {
    'id': 'notif_1',
    'userId': 'customer_1',
    'userType': 'customer',
    'title': 'Order update',
    'subtitle': '',
    'type': 'order',
    'data': {'orderId': 'order_1'},
    'isRead': isRead,
    'createdAt': '2026-05-11T09:00:00.000Z',
  };
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

class _WorkflowClient extends http.BaseClient {
  _WorkflowClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request, String body)
      handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final response = await handler(request, body);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

extension on CookReelModel {
  CookReelModel copyWithForTest({
    required int likes,
    required bool isLiked,
  }) {
    return CookReelModel(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorImageUrl: creatorImageUrl,
      title: title,
      description: description,
      imageUrl: imageUrl,
      videoPath: videoPath,
      audioLabel: audioLabel,
      likes: likes,
      comments: comments,
      shares: shares,
      isMine: isMine,
      isFollowing: isFollowing,
      isLiked: isLiked,
      isPaused: isPaused,
      isBookmarked: isBookmarked,
      isDraft: isDraft,
      commentItems: commentItems,
      createdAt: createdAt,
    );
  }
}
