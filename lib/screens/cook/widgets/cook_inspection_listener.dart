import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/models/hygiene_inspection_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/hygiene_inspection_provider.dart';
import 'package:naham_app/screens/cook/cook_live_inspection_screen.dart';
import 'package:provider/provider.dart';

class CookInspectionListener extends StatefulWidget {
  const CookInspectionListener({super.key, required this.child});

  final Widget child;

  @override
  State<CookInspectionListener> createState() => _CookInspectionListenerState();
}

class _CookInspectionListenerState extends State<CookInspectionListener> {
  String? _handledPromptRequestId;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final inspectionProvider = context.watch<HygieneInspectionProvider>();
    final currentUser = authProvider.currentUser;

    final pendingRequest = currentUser == null
        ? null
        : inspectionProvider.pendingRequestForCook(cookId: currentUser.id);

    if (pendingRequest != null &&
        pendingRequest.id != _handledPromptRequestId &&
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handledPromptRequestId = pendingRequest.id;
        _showIncomingInspectionDialog(
          request: pendingRequest,
          provider: inspectionProvider,
        );
      });
    }

    return widget.child;
  }

  Future<void> _showIncomingInspectionDialog({
    required HygieneInspectionCallRequest request,
    required HygieneInspectionProvider provider,
  }) async {
    final action = await showDialog<_IncomingInspectionAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _IncomingInspectionDialog(request: request),
    );
    if (!mounted || action == null) {
      return;
    }

    if (action == _IncomingInspectionAction.answer) {
      await provider.markCallRequestAccepted(request.id);
      if (!mounted) return;
      await context.push<bool>(
        AppRoutes.cookLiveInspection,
        extra: CookInspectionCallPayload(
          requestId: request.id,
          cookName: request.cookName,
          adminName: request.adminName,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Live inspection ended. Admin decision will appear in your history.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
      return;
    }

    await provider.markCallRequestDeclined(request.id);
    if (!mounted) return;
    await _showDeclinedAlert();
  }

  Future<void> _showDeclinedAlert() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _DeclinedInspectionAlertDialog(),
    );
  }
}

enum _IncomingInspectionAction { answer, decline }

class _IncomingInspectionDialog extends StatelessWidget {
  const _IncomingInspectionDialog({required this.request});

  final HygieneInspectionCallRequest request;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFF1F3),
                border: Border.all(color: const Color(0xFFFFD8DD), width: 1.2),
              ),
              child: const Icon(
                Icons.gpp_bad_rounded,
                color: Color(0xFFE82642),
                size: 34,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Unexpected Inspection!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22 / 1.3,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFCA1D35),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'The admin is calling for a kitchen inspection. Do you want to answer?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.4,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFD0485D),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'If you do not answer, you will receive a warning.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE11D38),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pop(_IncomingInspectionAction.answer),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: Text(
                      'Answer',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18A84E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pop(_IncomingInspectionAction.decline),
                    icon: const Icon(Icons.call_end_rounded, size: 16),
                    label: Text(
                      'Reject/Ignore',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6324A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              request.adminName.trim().isEmpty
                  ? 'Requested by admin'
                  : 'Requested by ${request.adminName}',
              style: GoogleFonts.poppins(
                fontSize: 10.6,
                color: const Color(0xFF9FA6B4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeclinedInspectionAlertDialog extends StatelessWidget {
  const _DeclinedInspectionAlertDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE7203D),
                size: 34,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You declined the verification request',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17 / 1.1,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE7203D),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action will be recorded and may affect your account standing.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.2,
                color: const Color(0xFFDE5168),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE80E2D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Understood',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
