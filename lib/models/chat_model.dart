import 'package:flutter/material.dart';

enum ChatParticipantType { cook, support }

class ChatConversationModel {
  const ChatConversationModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.participantType,
    this.avatarUrl,
    this.avatarAsset,
    this.unreadCount = 0,
    this.isOnline = false,
    this.phoneNumber,
    this.supportInitial,
    this.participantIds,
    this.avatarBackground,
    this.avatarIcon,
    this.avatarIconColor,
    this.hasPriorityBorder = false,
    this.isComplaint = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String>? participantIds;
  final String lastMessage;
  final DateTime lastMessageAt;
  final ChatParticipantType participantType;
  final String? avatarUrl;
  final String? avatarAsset;
  final int unreadCount;
  final bool isOnline;
  final String? phoneNumber;
  final String? supportInitial;
  final Color? avatarBackground;
  final IconData? avatarIcon;
  final Color? avatarIconColor;
  final bool hasPriorityBorder;
  final bool isComplaint;

  bool get isSupport => participantType == ChatParticipantType.support;

  ChatConversationModel copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isOnline,
  }) {
    return ChatConversationModel(
      id: id,
      title: title,
      subtitle: subtitle,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      participantType: participantType,
      avatarUrl: avatarUrl,
      avatarAsset: avatarAsset,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      phoneNumber: phoneNumber,
      supportInitial: supportInitial,
      participantIds: participantIds,
      avatarBackground: avatarBackground,
      avatarIcon: avatarIcon,
      avatarIconColor: avatarIconColor,
      hasPriorityBorder: hasPriorityBorder,
      isComplaint: isComplaint,
    );
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.createdAt,
    required this.isMe,
    this.senderName,
    this.imageUrl,
  });

  final String id;
  final String conversationId;
  final String text;
  final DateTime createdAt;
  final bool isMe;
  final String? senderName;
  final String? imageUrl;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
