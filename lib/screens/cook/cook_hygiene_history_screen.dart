import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/hygiene_inspection_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/hygiene_inspection_provider.dart';
import 'package:provider/provider.dart';

class CookHygieneHistoryScreen extends StatefulWidget {
  const CookHygieneHistoryScreen({super.key});

  @override
  State<CookHygieneHistoryScreen> createState() =>
      _CookHygieneHistoryScreenState();
}

class _CookHygieneHistoryScreenState extends State<CookHygieneHistoryScreen> {
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
    final topPadding = MediaQuery.of(context).padding.top;
    final authProvider = context.watch<AuthProvider>();
    final inspectionProvider = context.watch<HygieneInspectionProvider>();
    final currentUser = authProvider.currentUser;
    final currentName = currentUser?.name ?? '';
    final records = currentUser == null
        ? const <HygieneInspectionRecord>[]
        : inspectionProvider.recordsForCook(
            cookId: currentUser.id,
            cookName: currentName,
          );

    final readyAndCleanCount = records
        .where(
            (item) => item.decision == HygieneInspectionDecision.readyAndClean)
        .length;
    final needsCleanupCount = records
        .where(
            (item) => item.decision == HygieneInspectionDecision.needsCleanup)
        .length;
    final warningCount = records
        .where(
            (item) => item.decision == HygieneInspectionDecision.warningIssued)
        .length;
    final revokedCount = records
        .where(
            (item) => item.decision == HygieneInspectionDecision.serviceRevoked)
        .length;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Column(
          children: [
            _TopBar(
              topPadding: topPadding,
              onBackTap: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                children: [
                  _WarningCard(
                    warningCount: warningCount,
                    revokedCount: revokedCount,
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StatusCountCard(
                        value: '$readyAndCleanCount',
                        label: 'Ready & Clean',
                        icon: Icons.check_rounded,
                        borderColor: const Color(0xFFBFE8CB),
                        backgroundColor: const Color(0xFFF1FBF4),
                        valueColor: const Color(0xFF24A75D),
                        iconColor: const Color(0xFF24A75D),
                      ),
                      _StatusCountCard(
                        value: '$needsCleanupCount',
                        label: 'Needs Cleanup',
                        icon: Icons.cleaning_services_outlined,
                        borderColor: const Color(0xFFF0D889),
                        backgroundColor: const Color(0xFFFFFAEB),
                        valueColor: const Color(0xFFC18A06),
                        iconColor: const Color(0xFFC18A06),
                      ),
                      _StatusCountCard(
                        value: '$warningCount',
                        label: 'Warning',
                        icon: Icons.warning_amber_rounded,
                        borderColor: const Color(0xFFFFD5A9),
                        backgroundColor: const Color(0xFFFFF2E2),
                        valueColor: const Color(0xFFE4831D),
                        iconColor: const Color(0xFFE4831D),
                      ),
                      _StatusCountCard(
                        value: '$revokedCount',
                        label: 'Revoked',
                        icon: Icons.block_rounded,
                        borderColor: const Color(0xFFF2C7CF),
                        backgroundColor: const Color(0xFFFFEFF2),
                        valueColor: const Color(0xFFD34B62),
                        iconColor: const Color(0xFFD34B62),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _SurpriseChecksCard(),
                  const SizedBox(height: 12),
                  Text(
                    'Recent Verifications',
                    style: GoogleFonts.poppins(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (inspectionProvider.isLoading && records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF735FEF),
                        ),
                      ),
                    )
                  else if (records.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE3E7ED)),
                      ),
                      child: Text(
                        'No inspections recorded yet.',
                        style: GoogleFonts.poppins(
                          fontSize: 13.2,
                          color: const Color(0xFF7D8798),
                        ),
                      ),
                    )
                  else
                    ...records.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _VerificationCard(item: item),
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.topPadding,
    required this.onBackTap,
  });

  final double topPadding;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topPadding + 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            splashRadius: 22,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              'Hygiene inspection history',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.warningCount,
    required this.revokedCount,
  });

  final int warningCount;
  final int revokedCount;

  @override
  Widget build(BuildContext context) {
    final isCritical = revokedCount > 0;
    final title = isCritical ? 'Eligibility Revoked' : 'Warning';
    final bodyText = isCritical
        ? 'Your eligibility to provide service has been revoked. Contact admin support to request re-evaluation.'
        : 'If you miss another call in the kitchen tab, the following will happen:';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFFEFF2) : const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? const Color(0xFFF2C7CF) : const Color(0xFFF0D889),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCritical
                      ? const Color(0xFFFFDDE4)
                      : const Color(0xFFFFF2C8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCritical
                      ? Icons.block_rounded
                      : Icons.warning_amber_rounded,
                  size: 20,
                  color: isCritical
                      ? const Color(0xFFD34B62)
                      : const Color(0xFFC18A06),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isCritical
                        ? const Color(0xFFD34B62)
                        : const Color(0xFFB07A00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bodyText,
            style: GoogleFonts.poppins(
              fontSize: 12.2,
              fontWeight: FontWeight.w500,
              color: isCritical
                  ? const Color(0xFFB94A61)
                  : const Color(0xFFB07A00),
              height: 1.35,
            ),
          ),
          if (!isCritical) ...[
            const SizedBox(height: 5),
            _WarningLine(
                text: '• If you miss 1 call, your account gets warning.'),
            _WarningLine(
                text: '• If you miss again, account can be frozen 7 days.'),
            _WarningLine(
                text: '• If you miss another call, service may be blocked.'),
            if (warningCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Current warning count: $warningCount',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB07A00),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11.6,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFB07A00),
          height: 1.3,
        ),
      ),
    );
  }
}

class _StatusCountCard extends StatelessWidget {
  const _StatusCountCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.borderColor,
    required this.backgroundColor,
    required this.valueColor,
    required this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color borderColor;
  final Color backgroundColor;
  final Color valueColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.2,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SurpriseChecksCard extends StatelessWidget {
  const _SurpriseChecksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBCD7FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF397FF1),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Surprise Checks',
                  style: GoogleFonts.poppins(
                    fontSize: 14.2,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3D547C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unexpected weekly video checks are enabled.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3D547C),
                  ),
                ),
                Text(
                  'Keep your kitchen and hygiene standards ready at any time.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.35,
                    color: const Color(0xFF5A6C8C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.item});

  final HygieneInspectionRecord item;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(item.decision);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                palette.icon,
                color: palette.iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(item.inspectedAt),
                      style: GoogleFonts.poppins(
                        fontSize: 14.2,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF47505D),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${DateFormat('h:mm a').format(item.inspectedAt)} - ${_formatDuration(item.callDurationSeconds)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.6,
                        color: const Color(0xFF8A929F),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.badgeBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.decision.popupLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w600,
                    color: palette.badgeText,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF626C79),
                  height: 1.3,
                ),
                children: [
                  const TextSpan(
                    text: 'Admin Notes: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: item.note.trim().isEmpty
                        ? item.decision.popupHint
                        : item.note.trim(),
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

class _DecisionPalette {
  const _DecisionPalette({
    required this.border,
    required this.background,
    required this.badgeBackground,
    required this.badgeText,
    required this.icon,
    required this.iconColor,
  });

  final Color border;
  final Color background;
  final Color badgeBackground;
  final Color badgeText;
  final IconData icon;
  final Color iconColor;
}

_DecisionPalette _palette(HygieneInspectionDecision decision) {
  switch (decision) {
    case HygieneInspectionDecision.readyAndClean:
      return const _DecisionPalette(
        border: Color(0xFFBCE8C9),
        background: Color(0xFFF1FBF4),
        badgeBackground: Color(0xFFD8F5E0),
        badgeText: Color(0xFF22A45D),
        icon: Icons.check_circle_rounded,
        iconColor: Color(0xFF22A45D),
      );
    case HygieneInspectionDecision.needsCleanup:
      return const _DecisionPalette(
        border: Color(0xFFF3D8A2),
        background: Color(0xFFFFFAEF),
        badgeBackground: Color(0xFFFFF1D7),
        badgeText: Color(0xFFC38710),
        icon: Icons.cleaning_services_outlined,
        iconColor: Color(0xFFC38710),
      );
    case HygieneInspectionDecision.warningIssued:
      return const _DecisionPalette(
        border: Color(0xFFFFD5AE),
        background: Color(0xFFFFF3E6),
        badgeBackground: Color(0xFFFFE7CF),
        badgeText: Color(0xFFD57D1A),
        icon: Icons.warning_amber_rounded,
        iconColor: Color(0xFFD57D1A),
      );
    case HygieneInspectionDecision.serviceRevoked:
      return const _DecisionPalette(
        border: Color(0xFFF0C0CB),
        background: Color(0xFFFFEFF2),
        badgeBackground: Color(0xFFFFDBE3),
        badgeText: Color(0xFFD14860),
        icon: Icons.block_rounded,
        iconColor: Color(0xFFD14860),
      );
  }
}

String _formatDuration(int seconds) {
  if (seconds <= 0) return '0m';
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  if (minutes <= 0) return '${remaining}s';
  return '${minutes}m ${remaining}s';
}
