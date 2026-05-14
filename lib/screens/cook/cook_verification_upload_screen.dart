import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class CookVerificationUploadScreen extends StatefulWidget {
  const CookVerificationUploadScreen({super.key});

  @override
  State<CookVerificationUploadScreen> createState() =>
      _CookVerificationUploadScreenState();
}

class _CookVerificationUploadScreenState
    extends State<CookVerificationUploadScreen> {
  File? _idFile;
  File? _healthFile;
  bool _isSubmitting = false;

  Future<void> _pickFile(bool isId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        if (isId) {
          _idFile = File(result.files.single.path!);
        } else {
          _healthFile = File(result.files.single.path!);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_idFile == null || _healthFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload all required files.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.submitCookVerification(
      idFile: _idFile!,
      healthFile: _healthFile!,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        context.go(AppRoutes.cookWaitingApproval);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Account Verification',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout, color: AppColors.error),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'One step left!',
                style: GoogleFonts.tajawal(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'To start cooking on Naham, we need to verify your identity and health certificate.',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _UploadCard(
                title: 'Personal ID',
                subtitle: 'Please upload a clear PDF copy of your ID.',
                file: _idFile,
                onTap: () => _pickFile(true),
              ),
              const SizedBox(height: 20),
              _UploadCard(
                title: 'Health Certificate',
                subtitle: 'Please upload the approved health certificate.',
                file: _healthFile,
                onTap: () => _pickFile(false),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandSage,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Submit for Review',
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.title,
    required this.subtitle,
    required this.file,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: file != null
              ? AppColors.brandSage.withValues(alpha: 0.05)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null ? AppColors.brandSage : Colors.grey[300]!,
            width: 1.5,
            style: file != null ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: file != null ? AppColors.brandSage : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                file != null ? Icons.check : Icons.picture_as_pdf_outlined,
                color: file != null ? Colors.white : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file != null
                        ? 'Selected file: ${file!.path.split('/').last}'
                        : subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color:
                          file != null ? AppColors.brandSage : Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (file == null)
              Icon(Icons.add_circle_outline,
                  color: AppColors.brandSage, size: 28),
          ],
        ),
      ),
    );
  }
}
