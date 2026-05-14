import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/hygiene_inspection_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/hygiene_inspection_provider.dart';
import 'package:naham_app/screens/admin/admin_live_inspection_screen.dart';
import 'package:provider/provider.dart';

class AdminHygieneInspectionsScreen extends StatefulWidget {
  const AdminHygieneInspectionsScreen({super.key});

  @override
  State<AdminHygieneInspectionsScreen> createState() =>
      _AdminHygieneInspectionsScreenState();
}

class _AdminHygieneInspectionsScreenState
    extends State<AdminHygieneInspectionsScreen> {
  _InspectionFilter _selectedFilter = _InspectionFilter.nonCompliant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HygieneInspectionProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HygieneInspectionProvider>();
    final records = _selectedFilter == _InspectionFilter.nonCompliant
        ? provider.nonCompliantRecords
        : provider.compliantRecords;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F8),
        body: Column(
          children: [
            const _HygieneHeader(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                children: [
                  _StartNewInspectionButton(
                    isBusy: provider.isLoading,
                    onTap: () => _startNewInspection(provider),
                  ),
                  const SizedBox(height: 10),
                  _InspectionFilterSwitcher(
                    selectedFilter: _selectedFilter,
                    nonCompliantCount: provider.nonCompliantRecords.length,
                    compliantCount: provider.compliantRecords.length,
                    onChanged: (value) {
                      setState(() => _selectedFilter = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (provider.isLoading && !provider.hasRecords)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7A69EF),
                        ),
                      ),
                    )
                  else if (records.isEmpty)
                    _EmptyInspectionsState(filter: _selectedFilter)
                  else
                    ...records.map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InspectionCard(record: record),
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

  Future<void> _startNewInspection(HygieneInspectionProvider provider) async {
    if (provider.isLoading) {
      return;
    }

    await provider.refreshCooks();
    if (!mounted) return;

    final cooks = provider.cooks;
    if (cooks.isEmpty) {
      _showSnack('No cook profiles found for live inspection.');
      return;
    }

    final selectedCook = await showModalBottomSheet<HygieneCookProfile>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => _CookPickerSheet(cooks: cooks),
    );
    if (!mounted || selectedCook == null) {
      return;
    }

    if (selectedCook.isOnline != true) {
      _showSnack(
        'This cook is offline. Live inspection is available only for online cooks.',
      );
      return;
    }

    final callRequest = await provider.createSurpriseCallRequest(
      cook: selectedCook,
      authProvider: context.read<AuthProvider>(),
    );
    if (!mounted) return;

    await context.push<bool>(
      AppRoutes.adminLiveInspection,
      extra: LiveInspectionSessionPayload(
        cookId: selectedCook.id,
        cookName: selectedCook.name,
        callRequestId: callRequest.id,
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _HygieneHeader extends StatelessWidget {
  const _HygieneHeader();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(10, topPadding + 8, 10, 12),
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
              'Hygiene Inspections',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _StartNewInspectionButton extends StatelessWidget {
  const _StartNewInspectionButton({
    required this.onTap,
    required this.isBusy,
  });

  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isBusy ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE4E7ED)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_outlined,
                  size: 16,
                  color: Color(0xFFC8B8EC),
                ),
                const SizedBox(width: 8),
                Text(
                  isBusy ? 'Loading...' : 'Start New Inspection',
                  style: GoogleFonts.poppins(
                    fontSize: 18 / 1.35,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xCCBFAEEA),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectionFilterSwitcher extends StatelessWidget {
  const _InspectionFilterSwitcher({
    required this.selectedFilter,
    required this.nonCompliantCount,
    required this.compliantCount,
    required this.onChanged,
  });

  final _InspectionFilter selectedFilter;
  final int nonCompliantCount;
  final int compliantCount;
  final ValueChanged<_InspectionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFC8C8C8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterTab(
              selected: selectedFilter == _InspectionFilter.nonCompliant,
              label: 'Non-Compliant ($nonCompliantCount)',
              activeColor: const Color(0xFFFF2F3F),
              icon: Icons.warning_amber_rounded,
              onTap: () => onChanged(_InspectionFilter.nonCompliant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterTab(
              selected: selectedFilter == _InspectionFilter.compliant,
              label: 'Compliant ($compliantCount)',
              activeColor: const Color(0xFF10C955),
              icon: Icons.check_circle_outline_rounded,
              onTap: () => onChanged(_InspectionFilter.compliant),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.selected,
    required this.label,
    required this.activeColor,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Color activeColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: 40,
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : const Color(0xFFF2F2F2),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14.2 / 1.2,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFFF2F2F2),
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.record});

  final HygieneInspectionRecord record;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(record.decision);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFE1E4EA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF8F97A6),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        record.cookName,
                        style: GoogleFonts.poppins(
                          fontSize: 15 / 1.12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF293140),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatRelativeTime(record.inspectedAt),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFFB5BBC7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.decision.adminListLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 14 / 1.12,
                          fontWeight: FontWeight.w500,
                          color: style.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (style.badge != null) ...[
                      const SizedBox(width: 8),
                      _StatusBadge(badge: style.badge!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.badge});

  final _InspectionBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        badge.label,
        style: GoogleFonts.poppins(
          fontSize: 11.2,
          fontWeight: FontWeight.w600,
          color: badge.textColor,
          height: 1.0,
        ),
      ),
    );
  }
}

class _EmptyInspectionsState extends StatelessWidget {
  const _EmptyInspectionsState({required this.filter});

  final _InspectionFilter filter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          filter == _InspectionFilter.nonCompliant
              ? 'No non-compliant records.'
              : 'No compliant records.',
          style: GoogleFonts.poppins(
            fontSize: 13.2,
            color: const Color(0xFF939BAA),
          ),
        ),
      ),
    );
  }
}

class _CookPickerSheet extends StatelessWidget {
  const _CookPickerSheet({required this.cooks});

  final List<HygieneCookProfile> cooks;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select cook for surprise call',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E3442),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: ListView.separated(
                itemCount: cooks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final cook = cooks[index];
                  final isOnline = cook.isOnline == true;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isOnline
                          ? () => Navigator.of(context).pop(cook)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFFF7F8FB)
                              : const Color(0xFFF0F1F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE4E7ED)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFFE6E9EF),
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF8A93A2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cook.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: isOnline
                                          ? const Color(0xFF2E3442)
                                          : const Color(0xFF8D95A3),
                                    ),
                                  ),
                                  Text(
                                    'Status: ${_normalizeCookStatusLabel(cook)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.2,
                                      color: const Color(0xFF8F97A6),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  _CookOnlineBadge(isOnline: isOnline),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.call_rounded,
                              color: isOnline
                                  ? const Color(0xFF735FEF)
                                  : const Color(0xFFB8BEC9),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _CookOnlineBadge extends StatelessWidget {
  const _CookOnlineBadge({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? const Color(0xFF1BAA55) : const Color(0xFF98A0AE);
    final background =
        isOnline ? const Color(0xFFE8F7EF) : const Color(0xFFE8EAEE);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: GoogleFonts.poppins(
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

enum _InspectionFilter { nonCompliant, compliant }

class _InspectionBadge {
  const _InspectionBadge._({
    required this.label,
    required this.textColor,
    required this.background,
  });

  static const warning = _InspectionBadge._(
    label: 'Warning',
    textColor: Color(0xFFEB8834),
    background: Color(0xFFFFF0E5),
  );

  static const revoked = _InspectionBadge._(
    label: 'Revoked',
    textColor: Color(0xFFE35A72),
    background: Color(0xFFFFEEF2),
  );

  final String label;
  final Color textColor;
  final Color background;
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.textColor,
    this.badge,
  });

  final Color textColor;
  final _InspectionBadge? badge;
}

_StatusPresentation _statusStyle(HygieneInspectionDecision decision) {
  switch (decision) {
    case HygieneInspectionDecision.readyAndClean:
      return const _StatusPresentation(textColor: Color(0xFF22B263));
    case HygieneInspectionDecision.needsCleanup:
      return const _StatusPresentation(
        textColor: Color(0xFFF19A34),
        badge: _InspectionBadge.warning,
      );
    case HygieneInspectionDecision.warningIssued:
      return const _StatusPresentation(
        textColor: Color(0xFFEF3E4A),
        badge: _InspectionBadge.warning,
      );
    case HygieneInspectionDecision.serviceRevoked:
      return const _StatusPresentation(
        textColor: Color(0xFFD6405B),
        badge: _InspectionBadge.revoked,
      );
  }
}

String _formatRelativeTime(DateTime timestamp) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('M/d/yyyy').format(timestamp);
}

String _normalizeCookStatusLabel(HygieneCookProfile cook) {
  final status = cook.cookStatus.trim().toLowerCase();
  switch (status) {
    case 'approved':
      return 'Approved';
    case 'pending_verification':
      return 'Follow-up needed';
    case 'frozen':
      return 'Warning';
    case 'blocked':
      return 'Revoked';
    default:
      return 'Unknown';
  }
}
