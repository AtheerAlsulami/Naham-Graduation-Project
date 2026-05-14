import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:naham_app/services/aws/aws_api_client.dart';

class AwsChatConversation {
  const AwsChatConversation({
    required this.id,
    required this.isSupport,
    required this.participantIds,
    required this.participantRoles,
    required this.participantNames,
    required this.participantAvatars,
    required this.phoneNumbers,
    required this.unreadByUser,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.hasPriorityBorder,
    required this.isComplaint,
  });

  final String id;
  final bool isSupport;
  final List<String> participantIds;
  final Map<String, String> participantRoles;
  final Map<String, String> participantNames;
  final Map<String, String> participantAvatars;
  final Map<String, String> phoneNumbers;
  final Map<String, int> unreadByUser;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool hasPriorityBorder;
  final bool isComplaint;
}

class AwsChatMessage {
  const AwsChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String text;
  final String imageUrl;
  final DateTime createdAt;
}

class AwsChatService {
  AwsChatService({required this.apiClient});

  final AwsApiClient apiClient;

  Map<String, dynamic> _asJsonMap(
    dynamic value, {
    required String context,
  }) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        throw Exception('Invalid $context: empty string.');
      }
      final decoded = jsonDecode(trimmed);
      return _asJsonMap(
        decoded,
        context: '$context (decoded from string)',
      );
    }
    throw Exception('Invalid $context. Expected JSON object.');
  }

  dynamic _decodeResponsePayload(String bodyString) {
    final decoded = jsonDecode(bodyString);
    if (decoded is List && decoded.length == 1 && decoded.first is Map) {
      return decoded.first;
    }
    if (decoded is Map<String, dynamic> &&
        decoded.containsKey('statusCode') &&
        decoded.containsKey('body')) {
      final nested = decoded['body'];
      if (nested is String) {
        return jsonDecode(nested);
      }
      return nested;
    }
    return decoded;
  }

  List<dynamic> _extractItems(dynamic payload, {required String context}) {
    if (payload is List) {
      if (payload.length == 1 && payload.first is Map) {
        final wrapper = payload.first;
        if (wrapper is Map) {
          final items = wrapper['items'];
          if (items is List) {
            return items;
          }
        }
      }
      return payload;
    }
    final body = _asJsonMap(payload, context: context);
    final value = body['items'];
    if (value is List) {
      return value;
    }
    return const [];
  }

  String _asString(dynamic value, [String fallback = '']) {
    if (value == null) {
      return fallback;
    }
    return value.toString().trim();
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
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
    return fallback;
  }

  DateTime _asDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    final asString = _asString(value);
    if (asString.isEmpty) {
      return DateTime.now();
    }
    return DateTime.tryParse(asString)?.toLocal() ?? DateTime.now();
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => _asString(item)).where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }

  Map<String, String> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, item) => MapEntry(key, _asString(item)));
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _asString(item)),
      );
    }
    return const {};
  }

  Map<String, int> _asIntMap(dynamic value) {
    if (value is! Map) {
      return const {};
    }
    return value.map((key, item) {
      if (item is int) {
        return MapEntry(key.toString(), item);
      }
      if (item is num) {
        return MapEntry(key.toString(), item.toInt());
      }
      return MapEntry(key.toString(), int.tryParse(item.toString()) ?? 0);
    });
  }

  AwsChatConversation _conversationFromPayload(dynamic raw) {
    final map = _asJsonMap(raw, context: 'chat conversation item');
    return AwsChatConversation(
      id: _asString(map['conversationId']),
      isSupport: _asBool(map['isSupport']),
      participantIds: _asStringList(map['participantIds']),
      participantRoles: _asStringMap(map['participantRoles']),
      participantNames: _asStringMap(map['participantNames']),
      participantAvatars: _asStringMap(map['participantAvatars']),
      phoneNumbers: _asStringMap(map['phoneNumbers']),
      unreadByUser: _asIntMap(map['unreadByUser']),
      lastMessage: _asString(map['lastMessage']),
      lastMessageAt: _asDateTime(map['lastMessageAt']),
      hasPriorityBorder: _asBool(map['hasPriorityBorder']),
      isComplaint: _asBool(map['isComplaint']),
    );
  }

  AwsChatMessage _messageFromPayload(dynamic raw) {
    final map = _asJsonMap(raw, context: 'chat message item');
    return AwsChatMessage(
      id: _asString(map['id']),
      conversationId: _asString(map['conversationId']),
      senderId: _asString(map['senderId']),
      senderRole: _asString(map['senderRole']),
      senderName: _asString(map['senderName']),
      text: _asString(map['text']),
      imageUrl: _asString(map['imageUrl']),
      createdAt: _asDateTime(map['createdAt']),
    );
  }

  Future<List<AwsChatConversation>> listConversations({
    required String userId,
    required String userRole,
    String? userName,
    String? userAvatarUrl,
    String? userPhone,
  }) async {
    final response = await apiClient.get(
      '/chat/conversations',
      queryParameters: {
        'userId': userId,
        'role': userRole,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'userPhone': userPhone,
      },
    );
    final payload = _decodeResponsePayload(response.body);
    final items = _extractItems(
      payload,
      context: 'chat conversations response',
    );
    return items.map(_conversationFromPayload).toList();
  }

  Future<AwsChatConversation> createConversation({
    required String userId,
    required String userRole,
    required String userName,
    required String type,
    String? userAvatarUrl,
    String? userPhone,
    String? otherUserId,
    String? otherUserRole,
    String? otherUserName,
    String? otherUserAvatarUrl,
    String? otherUserPhone,
  }) async {
    final response = await apiClient.post(
      '/chat/conversations',
      body: {
        'userId': userId,
        'userRole': userRole,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'userPhone': userPhone,
        'type': type,
        'otherUserId': otherUserId,
        'otherUserRole': otherUserRole,
        'otherUserName': otherUserName,
        'otherUserAvatarUrl': otherUserAvatarUrl,
        'otherUserPhone': otherUserPhone,
      },
    );
    final payload = _decodeResponsePayload(response.body);
    final body = _asJsonMap(payload, context: 'create conversation response');
    return _conversationFromPayload(body['conversation']);
  }

  Future<List<AwsChatMessage>> listMessages({
    required String conversationId,
    required String userId,
    required String userRole,
    int limit = 300,
  }) async {
    final response = await apiClient.get(
      '/chat/conversations/$conversationId/messages',
      queryParameters: {
        'userId': userId,
        'role': userRole,
        'limit': '$limit',
      },
    );
    final payload = _decodeResponsePayload(response.body);
    final items = _extractItems(payload, context: 'chat messages response');
    return items.map(_messageFromPayload).toList();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String senderName,
    String text = '',
    String imageUrl = '',
  }) async {
    await apiClient.post(
      '/chat/conversations/$conversationId/messages',
      body: {
        'senderId': senderId,
        'senderRole': senderRole,
        'senderName': senderName,
        'text': text,
        'imageUrl': imageUrl,
      },
    );
  }

  Future<void> markRead({
    required String conversationId,
    required String userId,
    required String userRole,
  }) async {
    await apiClient.post(
      '/chat/conversations/$conversationId/read',
      body: {
        'userId': userId,
        'userRole': userRole,
      },
    );
  }

  Future<String> uploadImage(File imageFile, String conversationId) async {
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    final ext = imageFile.uri.pathSegments.isNotEmpty
        ? imageFile.uri.pathSegments.last.split('.').last.toLowerCase()
        : 'jpg';
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$ext';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

    http.Response response;
    try {
      response = await apiClient.post(
        '/chat/upload-url',
        body: {
          'conversationId': conversationId,
          'fileName': fileName,
          'contentType': contentType,
        },
      );
    } catch (e) {
      // Fallback to dish upload endpoint if chat upload is not yet deployed
      if (e.toString().contains('403') || e.toString().contains('404')) {
        response = await apiClient.post(
          '/dishes/upload-url',
          body: {
            'dishId': 'chat_image_$conversationId',
            'fileName': fileName,
            'contentType': contentType,
          },
        );
      } else {
        rethrow;
      }
    }

    final payload = _decodeResponsePayload(response.body);
    final body = _asJsonMap(payload, context: 'chat upload-url response');

    final uploadUrl = (body['uploadUrl'] ?? '').toString();
    final fileUrl = (body['fileUrl'] ?? '').toString();
    if (uploadUrl.isEmpty || fileUrl.isEmpty) {
      throw Exception('Invalid upload-url response. Missing uploadUrl or fileUrl.');
    }

    final rawHeaders = body['headers'];
    final Map<String, String> uploadHeaders = {
      'Content-Type': contentType,
    };
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        uploadHeaders[entry.key.toString()] = entry.value.toString();
      }
    }

    final bytes = await imageFile.readAsBytes();
    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: uploadHeaders,
      body: bytes,
    );

    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception('Image upload failed (${uploadResponse.statusCode}).');
    }

    return fileUrl;
  }
}
