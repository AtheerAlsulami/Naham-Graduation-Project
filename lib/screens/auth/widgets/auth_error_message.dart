import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthErrorMessage extends StatelessWidget {
  const AuthErrorMessage({
    super.key,
    required this.message,
    this.onDarkBackground = false,
  });

  final String message;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final background = onDarkBackground
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFFFFEFF2);
    final borderColor = onDarkBackground
        ? Colors.white.withValues(alpha: 0.26)
        : const Color(0xFFF4BBC5);
    final foreground =
        onDarkBackground ? Colors.white : const Color(0xFFD9233E);
    final iconBackground = onDarkBackground
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFFFDCE3);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: foreground,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                textAlign: TextAlign.right,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
