import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/models/chat_model.dart';
import 'package:naham_app/models/user_model.dart';
import 'package:naham_app/services/aws/aws_chat_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class ChatProvider extends ChangeNotifier {
  static const String supportConversationId = 'support';
  static const String _supportParticipantId = '__support__';

  ChatProvider({
    AwsChatService? chatService,
  }) : _chatService = chatService ?? BackendFactory.createAwsChatService();

  final AwsChatService _chatService;

  final List<ChatConversationModel> _conversations = [];
  final Map<String, List<ChatMessageModel>> _messages = {};

  UserModel? _currentUser;
  Timer? _pollTimer;
  Future<void>? _bootstrapFuture;
  String? _activeConversationId;
  String? _supportActualConversationId;
  bool _bootstrapped = false;
  bool _isRefreshingConversations = false;
  bool _disposed = false;

  bool get _isAdmin => _currentUser?.role == AppConstants.roleAdmin;
  String get _currentUserName {
    final user = _currentUser;
    if (user == null) {
      return '';
    }
    return (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : user.name.trim();
  }

  void bindAuthUser(UserModel? user) {
    if (user == null) {
      _clearState();
      return;
    }

    final hadUser = _currentUser != null;
    final sameUser = _currentUser?.id == user.id;
    final roleChanged = _currentUser?.role != user.role;

    final changed = !hadUser || !sameUser || roleChanged;
    _currentUser = user;
    if (changed) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _activeConversationId = null;
      _supportActualConversationId = null;
      _conversations.clear();
      _messages.clear();
      _bootstrapped = false;
      _bootstrapFuture = null;
      _safeNotify();
    }
  }

  List<ChatConversationModel> get allConversations =>
      List.unmodifiable(_sortedConversations(_conversations));

  List<ChatConversationModel> get supportConversations {
    return _sortedConversations(
      _conversations.where((item) => item.isSupport).toList(),
    );
  }

  int get unreadSupportCount {
    return supportConversations.fold<int>(
      0,
      (sum, item) => sum + item.unreadCount,
    );
  }

  List<ChatConversationModel> get cookConversations {
    return _sortedConversations(
      _conversations
          .where((item) => item.participantType == ChatParticipantType.cook)
          .toList(),
    );
  }

  ChatConversationModel? conversationById(String id) {
    for (final conversation in _conversations) {
      if (conversation.id == id) {
        return conversation;
      }
    }
    return null;
  }

  List<ChatMessageModel> messagesFor(String conversationId) {
    return List.unmodifiable(_messages[conversationId] ?? const []);
  }

  Future<void> initializeIfNeeded({bool force = false}) async {
    if (_currentUser == null) {
      return;
    }
    if (!force && _bootstrapped) {
      return;
    }
    final running = _bootstrapFuture;
    if (running != null) {
      await running;
      return;
    }

    _bootstrapFuture = _bootstrapForUser();
    try {
      await _bootstrapFuture;
    } finally {
      _bootstrapFuture = null;
    }
  }

  Future<void> _bootstrapForUser() async {
    try {
      await refreshConversations();
      _startPolling();
      _bootstrapped = true;
    } catch (_) {
      // Bootstrap failures should not crash the app.
      _bootstrapped = false;
    }
  }

  Future<void> refreshConversations() async {
    final user = _currentUser;
    if (user == null || _isRefreshingConversations) {
      return;
    }

    _isRefreshingConversations = true;
    try {
      final conversations = await _chatService.listConversations(
        userId: user.id,
        userRole: user.role,
        userName: _currentUserName,
        userAvatarUrl: user.profileImageUrl,
        userPhone: user.phone,
      );

      _supportActualConversationId = null;
      final mapped = conversations.map(_mapConversationFromAws).toList();
      _conversations
        ..clear()
        ..addAll(_sortedConversations(mapped));

      if (_activeConversationId != null &&
          conversationById(_activeConversationId!) == null) {
        _activeConversationId = null;
      }

      _safeNotify();
    } finally {
      _isRefreshingConversations = false;
    }
  }

  Future<String> ensureSupportConversation() async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    await initializeIfNeeded();

    final existing = conversationById(supportConversationId);
    if (existing != null) {
      return supportConversationId;
    }

    await _chatService.createConversation(
      userId: user.id,
      userRole: user.role,
      userName: _currentUserName,
      userAvatarUrl: user.profileImageUrl,
      userPhone: user.phone,
      type: 'support',
    );

    await refreshConversations();
    return supportConversationId;
  }

  Future<void> loadMessages(String conversationId) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }
    await initializeIfNeeded();

    final resolvedConversationId = _resolveConversationIdForApi(conversationId);
    if (resolvedConversationId.isEmpty) {
      return;
    }

    final messages = await _chatService.listMessages(
      conversationId: resolvedConversationId,
      userId: user.id,
      userRole: user.role,
      limit: 350,
    );

    final mapped = messages
        .map(
          (item) => ChatMessageModel(
            id: item.id,
            conversationId: conversationId,
            text: item.text,
            createdAt: item.createdAt,
            isMe: item.senderId == user.id,
            senderName: item.senderName.isEmpty ? null : item.senderName,
            imageUrl: item.imageUrl.isEmpty ? null : item.imageUrl,
          ),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _messages[conversationId] = mapped;
    _activeConversationId = conversationId;
    _safeNotify();
  }

  Future<void> sendText({
    required String conversationId,
    required String text,
  }) async {
    final user = _currentUser;
    final cleanText = text.trim();
    if (user == null || cleanText.isEmpty) {
      return;
    }

    final resolvedConversationId = _resolveConversationIdForApi(conversationId);
    if (resolvedConversationId.isEmpty) {
      return;
    }

    await _chatService.sendMessage(
      conversationId: resolvedConversationId,
      senderId: user.id,
      senderRole: user.role,
      senderName: _currentUserName,
      text: cleanText,
    );

    await loadMessages(conversationId);
    await refreshConversations();
  }

  Future<void> sendImage({
    required String conversationId,
    required String imageUrl,
  }) async {
    final user = _currentUser;
    final cleanImageUrl = imageUrl.trim();
    if (user == null || cleanImageUrl.isEmpty) {
      return;
    }

    final resolvedConversationId = _resolveConversationIdForApi(conversationId);
    if (resolvedConversationId.isEmpty) {
      return;
    }

    await _chatService.sendMessage(
      conversationId: resolvedConversationId,
      senderId: user.id,
      senderRole: user.role,
      senderName: _currentUserName,
      imageUrl: cleanImageUrl,
    );

    await loadMessages(conversationId);
    await refreshConversations();
  }

  Future<void> sendImageFile({
    required String conversationId,
    required File imageFile,
  }) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    final resolvedConversationId = _resolveConversationIdForApi(conversationId);
    if (resolvedConversationId.isEmpty) {
      return;
    }

    final imageUrl =
        await _chatService.uploadImage(imageFile, resolvedConversationId);
    await sendImage(conversationId: conversationId, imageUrl: imageUrl);
  }

  Future<void> markRead(String conversationId) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    final resolvedConversationId = _resolveConversationIdForApi(conversationId);
    if (resolvedConversationId.isEmpty) {
      return;
    }

    await _chatService.markRead(
      conversationId: resolvedConversationId,
      userId: user.id,
      userRole: user.role,
    );

    final index =
        _conversations.indexWhere((item) => item.id == conversationId);
    if (index != -1) {
      final updated = _conversations[index].copyWith(unreadCount: 0);
      _conversations[index] = updated;
      _safeNotify();
    }
  }

  Future<String> createConversation({
    required String otherUserId,
    required String otherUserName,
    required ChatParticipantType type,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (type == ChatParticipantType.support) {
      return ensureSupportConversation();
    }

    final existingIndex = _conversations.indexWhere(
      (item) =>
          !item.isSupport &&
          (item.participantIds?.contains(otherUserId) ?? false),
    );
    if (existingIndex != -1) {
      return _conversations[existingIndex].id;
    }

    final created = await _chatService.createConversation(
      userId: user.id,
      userRole: user.role,
      userName: _currentUserName,
      userAvatarUrl: user.profileImageUrl,
      userPhone: user.phone,
      type: 'cook',
      otherUserId: otherUserId,
      otherUserRole: AppConstants.roleCook,
      otherUserName: otherUserName,
    );

    await refreshConversations();
    return created.id;
  }

  ChatConversationModel _mapConversationFromAws(AwsChatConversation source) {
    final user = _currentUser!;
    final currentUserId = user.id;

    var id = source.id;
    var title = 'Conversation';
    var participantType = ChatParticipantType.cook;
    String? avatarUrl;
    String? phoneNumber;
    String? supportInitial;
    var isOnline = false;

    if (source.isSupport) {
      participantType = ChatParticipantType.support;
      if (_isAdmin) {
        final externalParticipantId = source.participantIds.firstWhere(
          (item) => item != _supportParticipantId,
          orElse: () => '',
        );
        title =
            source.participantNames[externalParticipantId]?.trim().isNotEmpty ==
                    true
                ? source.participantNames[externalParticipantId]!.trim()
                : 'Support ticket';
        avatarUrl = source.participantAvatars[externalParticipantId];
        phoneNumber = source.phoneNumbers[externalParticipantId];
      } else {
        _supportActualConversationId = source.id;
        id = supportConversationId;
        title =
            source.participantNames[_supportParticipantId]?.trim().isNotEmpty ==
                    true
                ? source.participantNames[_supportParticipantId]!.trim()
                : 'Naham Support';
        avatarUrl = source.participantAvatars[_supportParticipantId];
        phoneNumber = source.phoneNumbers[_supportParticipantId];
        supportInitial = 'S';
      }
    } else {
      final otherParticipantId = source.participantIds.firstWhere(
        (item) => item != currentUserId,
        orElse: () => '',
      );
      title =
          source.participantNames[otherParticipantId]?.trim().isNotEmpty == true
              ? source.participantNames[otherParticipantId]!.trim()
              : 'Unknown';
      avatarUrl = source.participantAvatars[otherParticipantId];
      phoneNumber = source.phoneNumbers[otherParticipantId];
      final otherRole =
          source.participantRoles[otherParticipantId]?.trim().toLowerCase();
      isOnline = otherRole == AppConstants.roleCook;
    }

    final unreadCount = _isAdmin && source.isSupport
        ? source.unreadByUser[_supportParticipantId] ?? 0
        : source.unreadByUser[currentUserId] ?? 0;

    return ChatConversationModel(
      id: id,
      title: title,
      subtitle: source.lastMessage,
      lastMessage: source.lastMessage,
      lastMessageAt: source.lastMessageAt,
      participantType: participantType,
      avatarUrl: (avatarUrl ?? '').isEmpty ? null : avatarUrl,
      unreadCount: unreadCount,
      isOnline: isOnline,
      phoneNumber: (phoneNumber ?? '').isEmpty ? null : phoneNumber,
      supportInitial: supportInitial,
      avatarBackground: const Color(0xFFECE5FF),
      avatarIcon: Icons.person_outline_rounded,
      avatarIconColor: const Color(0xFF6A63DB),
      hasPriorityBorder: source.hasPriorityBorder,
      isComplaint: source.isComplaint,
      participantIds: source.participantIds,
    );
  }

  List<ChatConversationModel> _sortedConversations(
    List<ChatConversationModel> items,
  ) {
    items.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return items;
  }

  String _resolveConversationIdForApi(String uiConversationId) {
    if (uiConversationId == supportConversationId) {
      return _supportActualConversationId ?? '';
    }
    return uiConversationId;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (_currentUser == null) {
      return;
    }
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollTick(),
    );
  }

  Future<void> _pollTick() async {
    if (_currentUser == null || _isRefreshingConversations) {
      return;
    }
    try {
      await refreshConversations();
      final activeConversationId = _activeConversationId;
      if (activeConversationId != null) {
        await loadMessages(activeConversationId);
      }
    } catch (_) {
      // Ignore polling failures to keep UI responsive.
    }
  }

  void _clearState() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _bootstrapFuture = null;
    _bootstrapped = false;
    _currentUser = null;
    _activeConversationId = null;
    _supportActualConversationId = null;
    _conversations.clear();
    _messages.clear();
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
