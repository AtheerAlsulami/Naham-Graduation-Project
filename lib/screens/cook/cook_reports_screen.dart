import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/cook_document_model.dart';
import 'package:naham_app/providers/auth_provider.dart';

class CookReportsScreen extends StatefulWidget {
  const CookReportsScreen({super.key});

  @override
  State<CookReportsScreen> createState() => _CookReportsScreenState();
}

class _CookReportsScreenState extends State<CookReportsScreen> {
  Future<void> _refreshDocuments() async {
    await context.read<AuthProvider>().refreshCurrentUser();
  }

  int _countByStatus(
    List<CookDocumentItem> documents,
    CookDocumentStatus status,
  ) {
    return documents.where((doc) => doc.status == status).length;
  }

  Future<void> _openDocument(CookDocumentItem document) async {
    final url = Uri.tryParse(document.url.trim());
    if (url == null || !url.hasScheme) {
      _showSnack('Document link is missing.');
      return;
    }

    final opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _showSnack('Could not open ${document.title}.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final auth = context.watch<AuthProvider>();
    final documents = buildCookDocumentsFromUser(auth.currentUser);
    final verifiedCount = _countByStatus(
      documents,
      CookDocumentStatus.verified,
    );
    final pendingCount = _countByStatus(
      documents,
      CookDocumentStatus.pending,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Column(
          children: [
            Container(
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
                    onPressed: () => context.pop(),
                    splashRadius: 22,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Documents',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshDocuments,
                color: AppColors.homeChrome,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _CountCard(
                            count: verifiedCount,
                            label: 'Verified',
                            borderColor: const Color(0xFFC8E8D2),
                            backgroundColor: const Color(0xFFF2FBF6),
                            countColor: const Color(0xFF23A05D),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CountCard(
                            count: pendingCount,
                            label: 'Pending',
                            borderColor: const Color(0xFFF4DD97),
                            backgroundColor: const Color(0xFFFFF9E8),
                            countColor: const Color(0xFFC08A05),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CountCard(
                            count: documents.length,
                            label: 'Total',
                            borderColor: const Color(0xFFE0E4EC),
                            backgroundColor: Colors.white,
                            countColor: const Color(0xFF5F6B7A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _DocumentRequirementsCard(),
                    const SizedBox(height: 16),
                    Text(
                      'Your Documents',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (documents.isEmpty)
                      const _EmptyDocumentsCard()
                    else
                      ...documents.map(
                        (doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DocumentCard(
                            document: doc,
                            onViewTap: () => _openDocument(doc),
                            onDownloadTap: () => _openDocument(doc),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Pull down to refresh after admin approval.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.count,
    required this.label,
    required this.borderColor,
    required this.backgroundColor,
    required this.countColor,
  });

  final int count;
  final String label;
  final Color borderColor;
  final Color backgroundColor;
  final Color countColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                color: countColor,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRequirementsCard extends StatelessWidget {
  const _DocumentRequirementsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCCDDFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.description_outlined,
              color: Color(0xFF4F82FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document Requirements',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2F4A7E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only your National ID and Health Certificate are required for cook verification.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.35,
                    color: const Color(0xFF4E6695),
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.onViewTap,
    required this.onDownloadTap,
  });

  final CookDocumentItem document;
  final VoidCallback onViewTap;
  final VoidCallback onDownloadTap;

  @override
  Widget build(BuildContext context) {
    final (surface, border, iconColor, badgeBg, badgeText, badgeIcon) =
        switch (document.status) {
      CookDocumentStatus.verified => (
          const Color(0xFFF1FBF4),
          const Color(0xFFBDE6C9),
          const Color(0xFF1EA35B),
          const Color(0xFFD6F5DF),
          const Color(0xFF1EA35B),
          Icons.check_rounded,
        ),
      CookDocumentStatus.pending => (
          const Color(0xFFFFFAEE),
          const Color(0xFFF4D77D),
          const Color(0xFFC08A05),
          const Color(0xFFFFEEBD),
          const Color(0xFFC08A05),
          Icons.schedule_rounded,
        ),
    };
    final documentIcon = document.type == 'health'
        ? Icons.health_and_safety_outlined
        : Icons.badge_outlined;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.3),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  documentIcon,
                  size: 15,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                badgeIcon,
                                size: 13,
                                color: badgeText,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                document.status == CookDocumentStatus.verified
                                    ? 'Verified'
                                    : 'Pending',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.8,
                                  fontWeight: FontWeight.w600,
                                  color: badgeText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      document.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      document.status == CookDocumentStatus.verified
                          ? 'Approved by admin'
                          : 'Waiting for admin review',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4D525D),
                    side: const BorderSide(color: Color(0xFFE1E5EC)),
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(
                    'View',
                    style: GoogleFonts.poppins(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDownloadTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4D525D),
                    side: const BorderSide(color: Color(0xFFE1E5EC)),
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: Text(
                    'Download',
                    style: GoogleFonts.poppins(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDocumentsCard extends StatelessWidget {
  const _EmptyDocumentsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E5EC)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.folder_off_outlined,
            size: 30,
            color: Color(0xFF9AA3B2),
          ),
          const SizedBox(height: 8),
          Text(
            'No uploaded documents found',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your National ID and Health Certificate will appear here after they are uploaded to your account.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
