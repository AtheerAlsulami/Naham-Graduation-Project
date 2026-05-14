import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/chat_model.dart';
import 'package:naham_app/providers/chat_provider.dart';
import 'package:naham_app/screens/customer/customer_chat_screen.dart';
import 'package:provider/provider.dart';

class AdminChatSupportScreen extends StatefulWidget {
  const AdminChatSupportScreen({super.key});

  @override
  State<AdminChatSupportScreen> createState() => _AdminChatSupportScreenState();
}

class _AdminChatSupportScreenState extends State<AdminChatSupportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().initializeIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.supportConversations;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        body: Column(
          children: [
            const _ChatHeader(),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return _ConversationCard(
                    conversation: conversation,
                    onTap: () async {
                      final chatProvider = context.read<ChatProvider>();
                      await chatProvider.markRead(conversation.id);
                      await chatProvider.loadMessages(conversation.id);
                      if (!mounted) {
                        return;
                      }
                      // ignore: use_build_context_synchronously
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => Scaffold(
                            body: CustomerChatScreen(
                              selectedConversationId: conversation.id,
                              onConversationSelected: (_) {},
                              onBackToList: () =>
                                  Navigator.of(context).maybePop(),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            splashRadius: 22,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              'Chat & Support',
              style: GoogleFonts.poppins(
                fontSize: 31 / 1.35,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
  });

  final ChatConversationModel conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE2E5EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: conversation.hasPriorityBorder ? 2.5 : 0,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6E5BFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: conversation.avatarBackground,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          conversation.avatarIcon,
                          color: conversation.avatarIconColor,
                          size: 22,
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B4A),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${conversation.unreadCount}',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversation.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 22 / 1.45,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2E3544),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _relativeTime(conversation.lastMessageAt),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFFA8AFBC),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (conversation.isComplaint)
                          const _TypePill(
                            label: 'Complaint',
                            background: Color(0xFFFF4C59),
                            color: Colors.white,
                          ),
                        const SizedBox(height: 6),
                        Text(
                          conversation.lastMessage,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF5F6777),
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.background,
    required this.color,
  });

  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

enum _ChatFilter {
  all,
  customer,
  cook;

  String get label {
    switch (this) {
      case _ChatFilter.all:
        return 'All';
      case _ChatFilter.customer:
        return 'Customer';
      case _ChatFilter.cook:
        return 'Cook';
    }
  }

  List<_ConversationItem> get items {
    switch (this) {
      case _ChatFilter.all:
        return _allConversations;
      case _ChatFilter.customer:
        return _customerConversations;
      case _ChatFilter.cook:
        return _cookConversations;
    }
  }
}

class _ConversationItem {
  const _ConversationItem({
    required this.name,
    required this.timeLabel,
    required this.roleLabel,
    required this.roleBadgeBackground,
    required this.roleBadgeTextColor,
    required this.message,
    required this.avatarBackground,
    required this.avatarIcon,
    required this.avatarIconColor,
    this.unreadCount = 0,
    this.isComplaint = false,
    this.hasPriorityBorder = false,
  });

  final String name;
  final String timeLabel;
  final String roleLabel;
  final Color roleBadgeBackground;
  final Color roleBadgeTextColor;
  final String message;
  final Color avatarBackground;
  final IconData avatarIcon;
  final Color avatarIconColor;
  final int unreadCount;
  final bool isComplaint;
  final bool hasPriorityBorder;
}

const List<_ConversationItem> _customerConversations = [
  _ConversationItem(
    name: 'Nadia Salem',
    timeLabel: '4 hours ago',
    roleLabel: 'Customer',
    roleBadgeBackground: Color(0xFFF0E7FF),
    roleBadgeTextColor: Color(0xFF9A53FF),
    message: 'Please hurry, food will get cold',
    avatarBackground: Color(0xFFECE5FF),
    avatarIcon: Icons.person_outline_rounded,
    avatarIconColor: Color(0xFF6A63DB),
    unreadCount: 1,
    hasPriorityBorder: true,
  ),
  _ConversationItem(
    name: 'Hassan Abdullah',
    timeLabel: '8 hours ago',
    roleLabel: 'Customer',
    roleBadgeBackground: Color(0xFFF0E7FF),
    roleBadgeTextColor: Color(0xFF9A53FF),
    message: 'Missing 2 items from order - dessert and drink',
    avatarBackground: Color(0xFFFFECEF),
    avatarIcon: Icons.error_outline_rounded,
    avatarIconColor: Color(0xFFFC3D4D),
    unreadCount: 1,
    isComplaint: true,
    hasPriorityBorder: true,
  ),
  _ConversationItem(
    name: 'Ahmad Ali',
    timeLabel: '4 hours ago',
    roleLabel: 'Customer',
    roleBadgeBackground: Color(0xFFF0E7FF),
    roleBadgeTextColor: Color(0xFF9A53FF),
    message: 'Yes, I will make it mild for you',
    avatarBackground: Color(0xFFF3ECFF),
    avatarIcon: Icons.person_outline_rounded,
    avatarIconColor: Color(0xFF8E96A8),
  ),
];

const List<_ConversationItem> _cookConversations = [
  _ConversationItem(
    name: "Maria's Kitchen",
    timeLabel: '4 hours ago',
    roleLabel: 'Cook',
    roleBadgeBackground: Color(0xFFFFECCC),
    roleBadgeTextColor: Color(0xFFEF9A3B),
    message: 'I ran out of packaging material. Can I use',
    avatarBackground: Color(0xFFFFF2DF),
    avatarIcon: Icons.person_outline_rounded,
    avatarIconColor: Color(0xFF7D8698),
  ),
  _ConversationItem(
    name: 'Fatima Al-Rashid',
    timeLabel: '6 hours ago',
    roleLabel: 'Cook',
    roleBadgeBackground: Color(0xFFFFECCC),
    roleBadgeTextColor: Color(0xFFEF9A3B),
    message: 'The customer did not show up to pick up the food.',
    avatarBackground: Color(0xFFFFF2DF),
    avatarIcon: Icons.error_outline_rounded,
    avatarIconColor: Color(0xFF7D8698),
    isComplaint: true,
  ),
];



const List<_ConversationItem> _allConversations = [
  _ConversationItem(
    name: 'Nadia Salem',
    timeLabel: '4 hours ago',
    roleLabel: 'Customer',
    roleBadgeBackground: Color(0xFFF0E7FF),
    roleBadgeTextColor: Color(0xFF9A53FF),
    message: 'Please hurry, food will get cold',
    avatarBackground: Color(0xFFECE5FF),
    avatarIcon: Icons.person_outline_rounded,
    avatarIconColor: Color(0xFF6A63DB),
    unreadCount: 1,
    hasPriorityBorder: true,
  ),
  _ConversationItem(
    name: 'Fatima Al-Rashid',
    timeLabel: '6 hours ago',
    roleLabel: 'Cook',
    roleBadgeBackground: Color(0xFFFFECCC),
    roleBadgeTextColor: Color(0xFFEF9A3B),
    message: 'The customer did not show up to pick up the food.',
    avatarBackground: Color(0xFFFFF2DF),
    avatarIcon: Icons.error_outline_rounded,
    avatarIconColor: Color(0xFF7D8698),
    isComplaint: true,
  ),
  _ConversationItem(
    name: "Maria's Kitchen",
    timeLabel: '4 hours ago',
    roleLabel: 'Cook',
    roleBadgeBackground: Color(0xFFFFECCC),
    roleBadgeTextColor: Color(0xFFEF9A3B),
    message: 'I ran out of packaging material. Can I use',
    avatarBackground: Color(0xFFFFF2DF),
    avatarIcon: Icons.person_outline_rounded,
    avatarIconColor: Color(0xFF7D8698),
  ),
];
