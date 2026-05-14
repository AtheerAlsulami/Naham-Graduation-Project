import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/chat_model.dart';
import 'package:naham_app/providers/chat_provider.dart';
import 'package:provider/provider.dart';

class CustomerChatScreen extends StatefulWidget {
  const CustomerChatScreen({
    super.key,
    required this.selectedConversationId,
    required this.onConversationSelected,
    required this.onBackToList,
    this.referenceImageUrl,
  });

  final String? selectedConversationId;
  final ValueChanged<String> onConversationSelected;
  final VoidCallback onBackToList;
  final String? referenceImageUrl;

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chatProvider = context.read<ChatProvider>();
      chatProvider.initializeIfNeeded();
      final selectedId = widget.selectedConversationId;
      if (selectedId != null) {
        chatProvider.loadMessages(selectedId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant CustomerChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedConversationId != oldWidget.selectedConversationId &&
        widget.selectedConversationId != null) {
      context.read<ChatProvider>().loadMessages(widget.selectedConversationId!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.selectedConversationId;
    if (selectedId == null) {
      return _ChatListView(
        onConversationSelected: widget.onConversationSelected,
      );
    }

    final conversation =
        context.watch<ChatProvider>().conversationById(selectedId);
    if (conversation == null) {
      return _ChatListView(
        onConversationSelected: widget.onConversationSelected,
      );
    }

    return _ChatThreadView(
      conversation: conversation,
      scrollController: _scrollController,
      messageController: _messageController,
      isSending: _isSending,
      onBackTap: widget.onBackToList,
      onSendTap: () => _sendMessage(conversation.id),
      onEmojiTap: _insertEmoji,
      onVoiceTap: () => _sendVoiceNote(conversation.id),
      onAttachTap: () => _showAttachmentSheet(conversation.id),
      onCallTap: () => _showSnack('Calling ${conversation.title}...'),
      onVideoTap: conversation.isSupport
          ? null
          : () =>
              _showSnack('Starting video call with ${conversation.title}...'),
      onConversationActionTap: () => _copyContact(conversation),
    );
  }

  Future<void> _sendMessage(String conversationId) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });
    _messageController.clear();

    await context.read<ChatProvider>().sendText(
          conversationId: conversationId,
          text: text,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
    });
    _scrollToBottom();
  }

  Future<void> _sendVoiceNote(String conversationId) async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    await context.read<ChatProvider>().sendText(
          conversationId: conversationId,
          text: 'Voice note sent',
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
    });
    _showSnack('Voice note sent');
    _scrollToBottom();
  }

  Future<void> _showAttachmentSheet(String conversationId) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.homeDivider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              _AttachmentActionTile(
                icon: Icons.image_rounded,
                title: 'Choose from gallery',
                subtitle: 'Send a photo from your phone.',
                onTap: () => Navigator.of(context).pop('gallery'),
              ),
              if (widget.referenceImageUrl != null &&
                  widget.referenceImageUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _AttachmentActionTile(
                  icon: Icons.fastfood_rounded,
                  title: 'Send order photo',
                  subtitle: 'Share the image of the order.',
                  onTap: () => Navigator.of(context).pop('order_image'),
                ),
              ],
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'gallery') {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        setState(() => _isSending = true);
        try {
          await context.read<ChatProvider>().sendImageFile(
                conversationId: conversationId,
                imageFile: File(pickedFile.path),
              );
          if (mounted) _showSnack('Photo sent');
        } catch (e) {
          if (mounted) {
            _showSnack(
                'Failed to send photo: ${e.toString().replaceAll('Exception: ', '')}');
          }
        } finally {
          if (mounted) setState(() => _isSending = false);
          _scrollToBottom();
        }
      }
    } else if (action == 'order_image') {
      setState(() => _isSending = true);
      try {
        await context.read<ChatProvider>().sendImage(
              conversationId: conversationId,
              imageUrl: widget.referenceImageUrl!,
            );
        if (mounted) _showSnack('Order photo sent');
      } finally {
        if (mounted) setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _insertEmoji() {
    final current = _messageController.text;
    _messageController.text = current.isEmpty ? '🙂' : '$current 🙂';
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Future<void> _copyContact(ChatConversationModel conversation) async {
    final value = conversation.phoneNumber ?? conversation.title;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    _showSnack('Contact copied');
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ChatListView extends StatelessWidget {
  const _ChatListView({
    required this.onConversationSelected,
  });

  final ValueChanged<String> onConversationSelected;

  @override
  Widget build(BuildContext context) {
    final conversations = context.watch<ChatProvider>().cookConversations;

    return Column(
      children: [
        const _ChatListTopBar(),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _ConversationTile(
                conversation: conversation,
                onTap: () {
                  context.read<ChatProvider>().markRead(conversation.id);
                  onConversationSelected(conversation.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatListTopBar extends StatelessWidget {
  const _ChatListTopBar();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(18, topPadding + 12, 18, 13),
      color: AppColors.homeChrome,
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/naham_logo.png',
                width: 27,
                height: 27,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'chat',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 46),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ChatConversationModel conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 76,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border(
              left: BorderSide(
                color: conversation.unreadCount > 0
                    ? AppColors.authButtonEnd
                    : Colors.transparent,
                width: 3,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _ChatAvatar(conversation: conversation, size: 46),
                  if (conversation.unreadCount > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF405C),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${conversation.unreadCount}',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF6F7785),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _relativeTime(conversation.lastMessageAt),
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  color: const Color(0xFF9AA1AD),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) {
      return 'now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mins ago';
    }
    return '${diff.inHours} hours ago';
  }
}

class _ChatThreadView extends StatelessWidget {
  const _ChatThreadView({
    required this.conversation,
    required this.scrollController,
    required this.messageController,
    required this.isSending,
    required this.onBackTap,
    required this.onSendTap,
    required this.onEmojiTap,
    required this.onVoiceTap,
    required this.onAttachTap,
    required this.onCallTap,
    required this.onVideoTap,
    required this.onConversationActionTap,
  });

  final ChatConversationModel conversation;
  final ScrollController scrollController;
  final TextEditingController messageController;
  final bool isSending;
  final VoidCallback onBackTap;
  final VoidCallback onSendTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onAttachTap;
  final VoidCallback onCallTap;
  final VoidCallback? onVideoTap;
  final VoidCallback onConversationActionTap;

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<ChatProvider>().messagesFor(conversation.id);

    return Column(
      children: [
        _ChatThreadTopBar(
          conversation: conversation,
          onBackTap: onBackTap,
          onCallTap: onCallTap,
          onVideoTap: onVideoTap,
          onAvatarTap: onConversationActionTap,
        ),
        Expanded(
          child: Container(
            color: conversation.isSupport
                ? const Color(0xFFF8F8FA)
                : AppColors.homePageBackground,
            child: ListView.builder(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
              itemCount: messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const _DayChip();
                }
                final message = messages[index - 1];
                return _MessageBubble(
                  conversation: conversation,
                  message: message,
                );
              },
            ),
          ),
        ),
        _MessageComposer(
          controller: messageController,
          isSending: isSending,
          isSupport: conversation.isSupport,
          onAttachTap: onAttachTap,
          onEmojiTap: onEmojiTap,
          onVoiceTap: onVoiceTap,
          onSendTap: onSendTap,
        ),
      ],
    );
  }
}

class _ChatThreadTopBar extends StatelessWidget {
  const _ChatThreadTopBar({
    required this.conversation,
    required this.onBackTap,
    required this.onCallTap,
    required this.onVideoTap,
    required this.onAvatarTap,
  });

  final ChatConversationModel conversation;
  final VoidCallback onBackTap;
  final VoidCallback onCallTap;
  final VoidCallback? onVideoTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 10),
      color: AppColors.homeChrome,
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAvatarTap,
            child: _ChatAvatar(
              conversation: conversation,
              size: conversation.isSupport ? 38 : 40,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: conversation.isSupport ? 15 : 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                if (!conversation.isSupport) ...[
                  const SizedBox(height: 5),
                  Text(
                    conversation.isOnline ? 'online' : 'away',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      color: Colors.white.withValues(alpha: 0.74),
                      height: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'today',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8D929C),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.conversation,
    required this.message,
  });

  final ChatConversationModel conversation;
  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final maxWidth = MediaQuery.of(context).size.width * 0.62;
    final bubbleColor = isMe
        ? (conversation.isSupport
            ? const Color(0xFFC9B3F2)
            : AppColors.primaryDark)
        : (conversation.isSupport ? Colors.white : AppColors.homeMintSurface);
    final textColor = isMe
        ? Colors.white
        : (conversation.isSupport ? AppColors.textPrimary : AppColors.primary);

    return Padding(
      padding: EdgeInsets.only(
        bottom: 10,
        left: isMe ? 52 : 0,
        right: isMe ? 0 : 52,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe && !conversation.isSupport) ...[
            _ChatAvatar(conversation: conversation, size: 22),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      message.hasImage ? 4 : 12,
                      message.hasImage ? 4 : 9,
                      message.hasImage ? 4 : 12,
                      9,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(13),
                        topRight: const Radius.circular(13),
                        bottomLeft: Radius.circular(isMe ? 13 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 13),
                      ),
                      boxShadow: conversation.isSupport && !isMe
                          ? const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 12,
                                offset: Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe && conversation.isSupport)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              'Naham Support',
                              style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.homeChrome,
                              ),
                            ),
                          ),
                        if (message.hasImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: message.imageUrl!,
                              height: 112,
                              width: maxWidth,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 112,
                                color: AppColors.homeDivider,
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 112,
                                color: AppColors.homeDivider,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          ),
                        if (message.text.trim().isNotEmpty) ...[
                          if (message.hasImage) const SizedBox(height: 7),
                          Text(
                            message.text,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                              height: 1.22,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      color: isMe
                          ? const Color(0xFF8D929C)
                          : const Color(0xFF9AA1AD),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime value) {
    final hour = value.hour > 12 ? value.hour - 12 : value.hour;
    final safeHour = hour == 0 ? 12 : hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$safeHour:$minute $period';
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.isSupport,
    required this.onAttachTap,
    required this.onEmojiTap,
    required this.onVoiceTap,
    required this.onSendTap,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isSupport;
  final VoidCallback onAttachTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onSendTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, isSupport ? 12 : 10),
      color: isSupport ? Colors.white : AppColors.homeChrome,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _ComposerIconButton(
              icon: isSupport ? Icons.attach_file_rounded : Icons.add_rounded,
              color: isSupport ? AppColors.textSecondary : AppColors.primary,
              onTap: onAttachTap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE8E9F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 2,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSendTap(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: isSupport
                              ? 'Type your message...'
                              : 'Type a message...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: const Color(0xFFA6ABB7),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                    _ComposerIconButton(
                      icon: Icons.emoji_emotions_outlined,
                      color: AppColors.primary,
                      onTap: onEmojiTap,
                    ),
                    _ComposerIconButton(
                      icon: Icons.mic_rounded,
                      color: AppColors.primary,
                      onTap: onVoiceTap,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isSending ? null : onSendTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      isSupport ? AppColors.homeChrome : AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.homeMintSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.homeCardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.authButtonEnd),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.conversation,
    required this.size,
  });

  final ChatConversationModel conversation;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (conversation.avatarUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: conversation.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _fallbackAvatar(),
          errorWidget: (context, url, error) => _fallbackAvatar(),
        ),
      );
    }

    if (conversation.avatarAsset != null) {
      return ClipOval(
        child: Image.asset(
          conversation.avatarAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final isSupport = conversation.isSupport;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSupport ? Colors.white : const Color(0xFFFFE6C7),
        shape: BoxShape.circle,
        border: isSupport
            ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2)
            : null,
      ),
      child: Center(
        child: isSupport
            ? Text(
                conversation.supportInitial ?? 'C',
                style: GoogleFonts.poppins(
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.w700,
                  color: AppColors.homeChrome,
                ),
              )
            : Icon(
                Icons.person_outline_rounded,
                size: size * 0.52,
                color: const Color(0xFFC49B67),
              ),
      ),
    );
  }
}
