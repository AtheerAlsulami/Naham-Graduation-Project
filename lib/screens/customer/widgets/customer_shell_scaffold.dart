import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';

class CustomerShellScaffold extends StatelessWidget {
  const CustomerShellScaffold({
    super.key,
    required this.body,
    required this.title,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onSearchTap,
    required this.onCartTap,
    required this.onNotificationsTap,
    this.cartCount = 0,
    this.notificationCount = 0,
    this.topBar,
    this.showBottomNav = true,
  });

  final Widget body;
  final String title;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationsTap;
  final int cartCount;
  final int notificationCount;
  final Widget? topBar;
  final bool showBottomNav;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.homePageBackground,
        body: Column(
          children: [
            topBar ??
                CustomerTopBar(
                  title: title,
                  cartCount: cartCount,
                  notificationCount: notificationCount,
                  onCartTap: onCartTap,
                  onSearchTap: onSearchTap,
                  onNotificationsTap: onNotificationsTap,
                ),
            Expanded(child: body),
          ],
        ),
        bottomNavigationBar: showBottomNav
            ? CustomerBottomNavBar(
                currentIndex: currentIndex,
                onTap: onTabSelected,
              )
            : null,
      ),
    );
  }
}

class CustomerTopBar extends StatelessWidget {
  const CustomerTopBar({
    super.key,
    required this.title,
    required this.onSearchTap,
    required this.onCartTap,
    required this.onNotificationsTap,
    required this.cartCount,
    required this.notificationCount,
  });

  final String title;
  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationsTap;
  final int cartCount;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(14, topPadding + 10, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Image.asset(
                  'assets/naham_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TopBarIconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: onNotificationsTap,
                  badgeCount: notificationCount,
                ),
                const SizedBox(width: 6),
                _TopBarIconButton(
                  icon: Icons.shopping_bag_outlined,
                  onTap: onCartTap,
                  badgeCount: cartCount,
                ),
                const SizedBox(width: 6),
                _TopBarIconButton(
                  icon: Icons.search_rounded,
                  onTap: onSearchTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                icon,
                size: 20,
                color: Colors.white,
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: AppColors.homeBadgeRed,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.homeChrome, width: 1),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CustomerBottomNavBar extends StatelessWidget {
  const CustomerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavEntry> _entries = [
    _NavEntry(index: 0, icon: Icons.play_arrow_rounded, label: 'Reels'),
    _NavEntry(index: 1, icon: Icons.receipt_long_rounded, label: 'Order'),
    _NavEntry(index: 3, icon: Icons.chat_bubble_outline_rounded, label: 'Chat'),
    _NavEntry(index: 4, icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 72,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
              decoration: const BoxDecoration(
                color: AppColors.homeChrome,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 18,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _NavButton(
                          entry: _entries[0],
                          currentIndex: currentIndex,
                          onTap: onTap)),
                  Expanded(
                      child: _NavButton(
                          entry: _entries[1],
                          currentIndex: currentIndex,
                          onTap: onTap)),
                  const SizedBox(width: 68),
                  Expanded(
                      child: _NavButton(
                          entry: _entries[2],
                          currentIndex: currentIndex,
                          onTap: onTap)),
                  Expanded(
                      child: _NavButton(
                          entry: _entries[3],
                          currentIndex: currentIndex,
                          onTap: onTap)),
                ],
              ),
            ),
          ),
          Positioned(
            top: -4,
            child: GestureDetector(
              onTap: () => onTap(2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentIndex == 2
                        ? AppColors.homeChrome
                        : Colors.white.withValues(alpha: 0.9),
                    width: 4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.home_rounded,
                  size: 24,
                  color: currentIndex == 2
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.entry,
    required this.currentIndex,
    required this.onTap,
  });

  final _NavEntry entry;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == entry.index;

    return InkWell(
      onTap: () => onTap(entry.index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              entry.icon,
              size: 19,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 2),
            Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.72),
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavEntry {
  const _NavEntry({
    required this.index,
    required this.icon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final String label;
}
