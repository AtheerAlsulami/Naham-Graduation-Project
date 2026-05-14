import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/chat_model.dart';
import 'package:naham_app/providers/chat_provider.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:naham_app/screens/cook/cook_dashboard_screen.dart';
import 'package:provider/provider.dart';

enum CookChatListFilter {
  support('support'),
  customer('customer');

  const CookChatListFilter(this.queryValue);

  final String queryValue;

  static CookChatListFilter fromQuery(String? value) {
    if (value == support.queryValue) {
      return support;
    }
    return customer;
  }
}

class CookChatSupportScreen extends StatefulWidget {
  const CookChatSupportScreen({
    super.key,
    this.initialFilter = CookChatListFilter.customer,
    this.initialConversationId,
  });

  final CookChatListFilter initialFilter;
  final String? initialConversationId;

  @override
  State<CookChatSupportScreen> createState() => _CookChatSupportScreenState();
}

class _CookChatSupportScreenState extends State<CookChatSupportScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  late CookChatListFilter _activeFilter;
  String? _selectedConversationId;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter;
    _selectedConversationId = widget.initialConversationId;
    if (_selectedConversationId == ChatProvider.supportConversationId) {
      _activeFilter = CookChatListFilter.support;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().initializeIfNeeded();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedConversationId = _selectedConversationId;
    if (selectedConversationId != null) {
      final conversation = context
          .watch<ChatProvider>()
          .conversationById(selectedConversationId);
      if (conversation != null) {
        return _buildThreadView(conversation);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _selectedConversationId = null);
      });
    }
    return _buildListView();
  }

  Widget _buildListView() {
    final chatProvider = context.watch<ChatProvider>();
    final supportConversation =
        chatProvider.conversationById(ChatProvider.supportConversationId);
    final conversations = _activeFilter == CookChatListFilter.support
        ? (supportConversation == null
            ? const <ChatConversationModel>[]
            : <ChatConversationModel>[supportConversation])
        : chatProvider.cookConversations;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.homePageBackground,
        body: Column(
          children: [
            _CookChatListTopBar(
              activeFilter: _activeFilter,
              onFilterChanged: (value) {
                if (value == _activeFilter) {
                  return;
                }
                setState(() => _activeFilter = value);
              },
            ),
            Expanded(
              child: conversations.isEmpty
                  ? const _EmptyConversations()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        return _ConversationTile(
                          conversation: conversation,
                          onTap: () => _openConversation(conversation.id),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: CookBottomNavBar(
          currentIndex: 3,
          onTap: _handleBottomNavTap,
        ),
      ),
    );
  }

  Widget _buildThreadView(ChatConversationModel conversation) {
    final messages = context.watch<ChatProvider>().messagesFor(conversation.id);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.homePageBackground,
        body: Column(
          children: [
            _ChatThreadTopBar(
              conversation: conversation,
              onBackTap: () => setState(() => _selectedConversationId = null),
              onCallTap: () => _showSnack('Calling ${conversation.title}...'),
              onAvatarTap: () => _copyContact(conversation),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF8F8FA),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
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
              controller: _messageController,
              isSending: _isSending,
              onAttachTap: () => _showAttachmentSheet(conversation.id),
              onSendTap: () => _sendMessage(conversation.id),
            ),
          ],
        ),
      ),
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
                title: 'Send dish photo',
                subtitle: 'Share the latest ordered dish image.',
                onTap: () => Navigator.of(context).pop('image'),
              ),
              const SizedBox(height: 10),
              _AttachmentActionTile(
                icon: Icons.receipt_long_rounded,
                title: 'Share order number',
                subtitle: 'Send #ORD-2025-001 to this chat.',
                onTap: () => Navigator.of(context).pop('order'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'image') {
      final dishProvider = context.read<DishProvider>();
      final dish = dishProvider.customerDishes.firstOrNull ??
          dishProvider.cookDishes.firstOrNull;

      if (dish != null) {
        await context.read<ChatProvider>().sendImage(
              conversationId: conversationId,
              imageUrl: dish.imageUrl,
            );
        _showSnack('Dish photo sent');
      } else {
        _showSnack('No dishes available to send');
      }
    } else {
      await context.read<ChatProvider>().sendText(
            conversationId: conversationId,
            text: 'Order number: #ORD-2025-001',
          );
      _showSnack('Order number shared');
    }
    _scrollToBottom();
  }

  Future<void> _copyContact(ChatConversationModel conversation) async {
    final value = conversation.phoneNumber ?? conversation.title;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    _showSnack('Contact copied');
  }

  void _openConversation(String conversationId) {
    context.read<ChatProvider>().markRead(conversationId);
    context.read<ChatProvider>().loadMessages(conversationId);
    setState(() {
      _selectedConversationId = conversationId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _handleBottomNavTap(int index) {
    if (index == 3) {
      if (_selectedConversationId != null) {
        setState(() => _selectedConversationId = null);
      }
      return;
    }
    if (index == 0) {
      context.go(AppRoutes.cookReels);
      return;
    }
    if (index == 1) {
      context.go(AppRoutes.cookOrders);
      return;
    }
    if (index == 2) {
      context.go(AppRoutes.cookDashboard);
      return;
    }
    if (index == 4) {
      context.go(AppRoutes.myMenu);
      return;
    }
    if (index == 5) {
      context.go(AppRoutes.cookPublicProfile);
    }
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

class _CookChatListTopBar extends StatelessWidget {
  const _CookChatListTopBar({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final CookChatListFilter activeFilter;
  final ValueChanged<CookChatListFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 14),
      color: AppColors.homeChrome,
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: Center(
              child: Text(
                'Chat & Support',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 184,
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterSegmentButton(
                      label: 'Support',
                      isSelected: activeFilter == CookChatListFilter.support,
                      onTap: () => onFilterChanged(CookChatListFilter.support),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _FilterSegmentButton(
                      label: 'Customer',
                      isSelected: activeFilter == CookChatListFilter.customer,
                      onTap: () => onFilterChanged(CookChatListFilter.customer),
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
}

class _FilterSegmentButton extends StatelessWidget {
  const _FilterSegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? AppColors.homeChrome
                  : Colors.white.withValues(alpha: 0.88),
              height: 1.0,
            ),
          ),
        ),
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
          height: 80,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                  _ChatAvatar(conversation: conversation, size: 42),
                  if (conversation.unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
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
              const SizedBox(width: 12),
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
                    const SizedBox(height: 7),
                    Text(
                      conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF6F7785),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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

class _ChatThreadTopBar extends StatelessWidget {
  const _ChatThreadTopBar({
    required this.conversation,
    required this.onBackTap,
    required this.onCallTap,
    required this.onAvatarTap,
  });

  final ChatConversationModel conversation;
  final VoidCallback onBackTap;
  final VoidCallback onCallTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(10, topPadding + 8, 10, 10),
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
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: onAvatarTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _ChatAvatar(conversation: conversation, size: 34),
                      if (conversation.isOnline && !conversation.isSupport)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C95B),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.0,
                      ),
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
    final maxWidth = MediaQuery.of(context).size.width * 0.66;
    final bubbleColor = isMe ? const Color(0xFFC9B3F2) : Colors.white;
    final textColor = isMe ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 10,
        left: isMe ? 56 : 0,
        right: isMe ? 0 : 56,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
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
                      boxShadow: !isMe
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
                              height: 1.24,
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
                      color: const Color(0xFF9AA1AD),
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
    required this.onAttachTap,
    required this.onSendTap,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onAttachTap;
  final VoidCallback onSendTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _ComposerIconButton(
              icon: Icons.attach_file_rounded,
              color: AppColors.textSecondary,
              onTap: onAttachTap,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE8E9F0)),
                ),
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
                    hintText: 'Type your message...',
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
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isSending ? null : onSendTap,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.homeChrome,
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
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
        color: isSupport ? Colors.white : const Color(0xFFE8EFFF),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isSupport
            ? Icon(
                Icons.shield_outlined,
                size: size * 0.56,
                color: AppColors.homeChrome,
              )
            : Icon(
                Icons.person_outline_rounded,
                size: size * 0.52,
                color: const Color(0xFF5E77A1),
              ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          'No conversations yet.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
