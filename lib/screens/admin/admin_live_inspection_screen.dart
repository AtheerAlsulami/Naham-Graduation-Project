import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/models/hygiene_inspection_model.dart';
import 'package:naham_app/providers/auth_provider.dart';
import 'package:naham_app/providers/hygiene_inspection_provider.dart';
import 'package:naham_app/services/agora/agora_config.dart';
import 'package:naham_app/services/agora/agora_video_service.dart';
import 'package:provider/provider.dart';

class LiveInspectionSessionPayload {
  const LiveInspectionSessionPayload({
    required this.cookId,
    required this.cookName,
    this.callRequestId,
  });

  final String cookId;
  final String cookName;
  final String? callRequestId;
}

class AdminLiveInspectionScreen extends StatefulWidget {
  const AdminLiveInspectionScreen({
    super.key,
    this.payload,
  });

  final LiveInspectionSessionPayload? payload;

  @override
  State<AdminLiveInspectionScreen> createState() =>
      _AdminLiveInspectionScreenState();
}

class _AdminLiveInspectionScreenState extends State<AdminLiveInspectionScreen> {
  final AgoraVideoService _agora = AgoraVideoService();
  Timer? _ticker;
  final DateTime _sessionStart = DateTime.now();
  bool _endingCall = false;
  bool _agoraReady = false;
  String? _errorMessage;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _startTicker();
    _initAgora();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _agora.dispose();
    super.dispose();
  }

  Future<void> _initAgora() async {
    try {
      final granted = await _agora.requestPermissions();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Camera and microphone permissions are required.';
        });
        return;
      }

      _agora.onRemoteUserJoined = (uid) {
        if (!mounted) return;
        setState(() => _remoteUid = uid);
      };

      _agora.onRemoteUserLeft = (uid) {
        if (!mounted) return;
        setState(() => _remoteUid = null);
      };

      _agora.onJoinedChannel = () {
        if (!mounted) return;
        setState(() => _agoraReady = true);
      };

      _agora.onError = (msg) {
        debugPrint('Agora error: $msg');
        if (!mounted) return;
        setState(() => _errorMessage = msg);
      };

      await _agora.initialize();

      final channelId = AgoraConfig.channelForCall(
        widget.payload?.callRequestId ??
            'admin_${DateTime.now().millisecondsSinceEpoch}',
      );
      // Admin joins with uid=1
      await _agora.joinChannel(channelId: channelId, uid: 1);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to start video: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final cookName = widget.payload?.cookName ?? 'Selected cook';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF06122A),
        body: Stack(
          children: [
            // Remote video (cook) — full screen
            Positioned.fill(child: _buildRemoteVideo()),

            // Local video (admin) — small PIP
            Positioned(
              right: 14,
              top: safeTop + 80,
              width: 110,
              height: 155,
              child: _buildLocalVideo(),
            ),

            // LIVE badge
            Positioned(
              left: 14,
              top: safeTop + 8,
              right: 14,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3556),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE INSPECTION',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                            letterSpacing: 0.2,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      _elapsedTimeLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Cook name
            Positioned(
              left: 18,
              right: 18,
              top: safeTop + 44,
              child: Text(
                cookName,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(18, 14, 18, safeBottom + 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlButton(
                      size: 42,
                      background: const Color(0xFFF3F4F6),
                      iconColor: const Color(0xFF7A818E),
                      icon: Icons.cameraswitch_outlined,
                      onTap: () => _agora.switchCamera(),
                    ),
                    _ControlButton(
                      size: 56,
                      background: _agora.isLocalAudioEnabled
                          ? const Color(0xFF2F6B43)
                          : const Color(0xFFE0E0E0),
                      iconColor: _agora.isLocalAudioEnabled
                          ? Colors.white
                          : const Color(0xFF7A818E),
                      icon: _agora.isLocalAudioEnabled
                          ? Icons.mic_none_rounded
                          : Icons.mic_off_rounded,
                      iconSize: 28,
                      onTap: () async {
                        await _agora.toggleMicrophone();
                        if (mounted) setState(() {});
                      },
                    ),
                    _ControlButton(
                      size: 42,
                      background: const Color(0xFFFFEEF2),
                      iconColor: const Color(0xFFE26680),
                      icon: _endingCall
                          ? Icons.hourglass_bottom_rounded
                          : Icons.call_end_rounded,
                      onTap: _endingCall ? () {} : _endInspectionCall,
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

  Widget _buildRemoteVideo() {
    if (_errorMessage != null) {
      return _buildMessage(_errorMessage!);
    }

    if (_remoteUid != null && _agora.engine != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _agora.engine!,
          canvas: VideoCanvas(uid: _remoteUid!),
          connection: RtcConnection(
            channelId: AgoraConfig.channelForCall(
              widget.payload?.callRequestId ?? '',
            ),
          ),
        ),
      );
    }

    return _buildMessage(
      _agoraReady ? 'Waiting for cook to join...' : 'Connecting...',
    );
  }

  Widget _buildLocalVideo() {
    if (_agora.engine == null || !_agoraReady) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _agora.engine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(String text) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF061026), Color(0xFF0A1940)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_errorMessage.toString().contains('permission'))
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: CircularProgressIndicator(color: Colors.white54),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13.2,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _elapsedTimeLabel {
    final elapsed = DateTime.now().difference(_sessionStart);
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _endInspectionCall() async {
    final submission = await showModalBottomSheet<_InspectionSubmission>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => const _InspectionDecisionSheet(),
    );
    if (!mounted || submission == null) {
      return;
    }

    final provider = context.read<HygieneInspectionProvider>();
    final authProvider = context.read<AuthProvider>();
    final payload = widget.payload;
    final cook = payload == null
        ? const HygieneCookProfile(
            id: 'unknown_cook',
            name: 'Selected cook',
            accountStatus: 'active',
            cookStatus: 'approved',
          )
        : provider.findCookById(payload.cookId) ??
            HygieneCookProfile(
              id: payload.cookId,
              name: payload.cookName,
              accountStatus: 'active',
              cookStatus: 'approved',
            );

    setState(() => _endingCall = true);
    try {
      // Leave the Agora channel first
      await _agora.leaveChannel();

      await provider.registerInspection(
        cook: cook,
        decision: submission.decision,
        callDurationSeconds: DateTime.now().difference(_sessionStart).inSeconds,
        authProvider: authProvider,
        note: submission.note,
      );
      final callRequestId = payload?.callRequestId;
      if (callRequestId != null && callRequestId.trim().isNotEmpty) {
        await provider.markCallRequestCompleted(callRequestId);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _endingCall = false);
      }
    }
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.size,
    required this.background,
    required this.iconColor,
    required this.icon,
    required this.onTap,
    this.iconSize = 22,
  });

  final double size;
  final Color background;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}

class _InspectionDecisionSheet extends StatefulWidget {
  const _InspectionDecisionSheet();

  @override
  State<_InspectionDecisionSheet> createState() =>
      _InspectionDecisionSheetState();
}

class _InspectionDecisionSheetState extends State<_InspectionDecisionSheet> {
  final TextEditingController _noteController = TextEditingController();
  HygieneInspectionDecision _decision = HygieneInspectionDecision.readyAndClean;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insetBottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.fromLTRB(14, 6, 14, insetBottom + 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inspection result',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E3442),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose one of the four actions after this surprise call.',
              style: GoogleFonts.poppins(
                fontSize: 12.8,
                color: const Color(0xFF7E8795),
              ),
            ),
            const SizedBox(height: 10),
            ...HygieneInspectionDecision.values.map(
              (decision) => RadioListTile<HygieneInspectionDecision>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: decision,
                // ignore: deprecated_member_use
                groupValue: _decision,
                activeColor: const Color(0xFF735FEF),
                // ignore: deprecated_member_use
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _decision = value);
                },
                title: Text(
                  decision.popupLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14.2,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF303746),
                  ),
                ),
                subtitle: Text(
                  decision.popupHint,
                  style: GoogleFonts.poppins(
                    fontSize: 12.1,
                    color: const Color(0xFF7E8795),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add inspection note (optional)',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12.4,
                  color: const Color(0xFFA4ABBA),
                ),
                filled: true,
                fillColor: const Color(0xFFF7F8FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4E7ED)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4E7ED)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF8A77F3)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    _InspectionSubmission(
                      decision: _decision,
                      note: _noteController.text.trim(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF735FEF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Save result',
                  style: GoogleFonts.poppins(
                    fontSize: 14.2,
                    fontWeight: FontWeight.w600,
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

class _InspectionSubmission {
  const _InspectionSubmission({
    required this.decision,
    required this.note,
  });

  final HygieneInspectionDecision decision;
  final String note;
}
