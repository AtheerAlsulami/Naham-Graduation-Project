import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/services/backend/admin_user_types.dart';
import 'package:naham_app/services/backend/backend_admin_user_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminPendingApprovalsScreen extends StatefulWidget {
  const AdminPendingApprovalsScreen({super.key});

  @override
  State<AdminPendingApprovalsScreen> createState() =>
      _AdminPendingApprovalsScreenState();
}

class _AdminPendingApprovalsScreenState
    extends State<AdminPendingApprovalsScreen> {
  final BackendAdminUserService _adminUserService = BackendAdminUserService();
  final Set<String> _processingIds = {};
  List<AdminUserRecord> _cookRequests = const [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final allUsers = await _adminUserService.listUsers(
        role: 'cook',
        limit: 1000,
      );
      final cooks = allUsers
          .where((user) => user.cookStatus == 'pending_verification')
          .toList();

      if (!mounted) return;
      setState(() {
        _cookRequests = cooks;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDecision(AdminUserRecord request, bool approved) async {
    if (_processingIds.contains(request.id)) return;

    setState(() {
      _processingIds.add(request.id);
    });

    final newStatus = approved ? 'active' : 'warning';
    final newCookStatus = approved ? 'approved' : 'rejected';

    try {
      await _adminUserService.updateUserStatus(
        id: request.id,
        status: newStatus,
        cookStatus: newCookStatus,
      );

      if (!mounted) return;
      final action = approved ? 'approved' : 'rejected';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${request.name} $action',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
      await _loadPendingApprovals();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Failed to update status: ${error.toString()}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(request.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F8),
        body: Column(
          children: [
            _PendingApprovalsHeader(cookCount: _cookRequests.length),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _errorMessage;
    if (error != null) {
      return _MessageState(
        message: error,
        color: const Color(0xFFB00020),
        actionLabel: 'Retry',
        onAction: _loadPendingApprovals,
      );
    }

    if (_cookRequests.isEmpty) {
      return const _MessageState(
        message: 'No pending cook approvals.',
        color: Color(0xFF8A92A1),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingApprovals,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        itemCount: _cookRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final request = _cookRequests[index];
          final isProcessing = _processingIds.contains(request.id);
          return _ApprovalCard(
            request: request,
            isProcessing: isProcessing,
            onApprove: () => _handleDecision(request, true),
            onReject: () => _handleDecision(request, false),
          );
        },
      ),
    );
  }
}

class _PendingApprovalsHeader extends StatelessWidget {
  const _PendingApprovalsHeader({required this.cookCount});

  final int cookCount;

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
      child: Column(
        children: [
          Row(
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
                  'Pending Approvals',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFB6A0E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TopTab(label: 'COOK ($cookCount)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Ink(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 17 / 1.3,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF7B67E8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.request,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final AdminUserRecord request;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Not specified';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    }
    return 'Now';
  }

  @override
  Widget build(BuildContext context) {
    final documents = request.documents ?? const <AdminUserDocument>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E4EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F2FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F4FC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE8E5F5)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.name.isEmpty ? 'Cook' : request.name,
                        style: GoogleFonts.poppins(
                          fontSize: 25 / 1.45,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF505765),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _InfoText(
                        icon: Icons.phone_outlined,
                        value:
                            request.phone.isEmpty ? 'No phone' : request.phone,
                      ),
                      const SizedBox(height: 2),
                      _InfoText(
                        icon: Icons.email_outlined,
                        value:
                            request.email.isEmpty ? 'No email' : request.email,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _timeAgo(request.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9654FF),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: documents.isEmpty
                ? const _MissingDocumentsTile()
                : Column(
                    children: [
                      for (int i = 0; i < documents.length; i++) ...[
                        _DocumentTile(document: documents[i]),
                        if (i != documents.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : onApprove,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF63BE70),
                        disabledBackgroundColor: const Color(0xFFB4D7BA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const _DecisionButtonContent(
                        icon: Icons.check_circle_outline,
                        label: 'APPROVE',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: isProcessing ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF544F),
                        side: const BorderSide(color: Color(0xFFFF6A64)),
                        disabledForegroundColor: const Color(0xFFFFB0AD),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const _DecisionButtonContent(
                        icon: Icons.cancel_outlined,
                        label: 'REJECT',
                        color: Color(0xFFFF544F),
                      ),
                    ),
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

class _DecisionButtonContent extends StatelessWidget {
  const _DecisionButtonContent({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: GoogleFonts.poppins(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8F96A3)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF666E7D),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final AdminUserDocument document;

  String get _normalizedType => document.type.toLowerCase().trim();

  String get _title {
    if (_normalizedType == 'id') return 'National ID';
    if (_normalizedType == 'health' || _normalizedType == 'certificate') {
      return 'Food License';
    }
    final title = document.title.trim();
    return title.isEmpty ? 'Document' : title;
  }

  String get _subtitle {
    if (_normalizedType == 'id') return 'Tap to view';
    if (_normalizedType == 'health' || _normalizedType == 'certificate') {
      return 'Optional';
    }
    return 'Tap to view';
  }

  IconData get _icon {
    if (_normalizedType == 'id') return Icons.badge_outlined;
    if (_normalizedType == 'health' || _normalizedType == 'certificate') {
      return Icons.description_outlined;
    }
    return Icons.file_copy_outlined;
  }

  Color get _iconColor {
    if (_normalizedType == 'id') return const Color(0xFF8B61E7);
    if (_normalizedType == 'health' || _normalizedType == 'certificate') {
      return const Color(0xFF2DBE66);
    }
    return const Color(0xFF8F96A3);
  }

  Color get _iconBackground {
    if (_normalizedType == 'id') return const Color(0xFFF2ECFF);
    if (_normalizedType == 'health' || _normalizedType == 'certificate') {
      return const Color(0xFFE5F7EC);
    }
    return const Color(0xFFF0F2F5);
  }

  Future<void> _openDocument(BuildContext context) async {
    final url = Uri.tryParse(document.url.trim());
    if (url == null || !url.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Document link is missing.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
      return;
    }

    final opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Could not open $_title',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDocument(context),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE1E4EA)),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _iconBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _icon,
                  size: 14,
                  color: _iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5A6170),
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF9CA4B3),
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.file_copy_outlined,
                size: 16,
                color: Color(0xFFAEB5C1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingDocumentsTile extends StatelessWidget {
  const _MissingDocumentsTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E4EA)),
      ),
      child: Text(
        'No documents attached.',
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: const Color(0xFF9CA4B3),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: color,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
