import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/services/agora/agora_config.dart';
import 'package:naham_app/services/agora/agora_video_service.dart';

class CookInspectionCallPayload {
  const CookInspectionCallPayload({
    required this.requestId,
    required this.cookName,
    required this.adminName,
  });

  final String requestId;
  final String cookName;
  final String adminName;
}

class CookLiveInspectionScreen extends StatefulWidget {
  const CookLiveInspectionScreen({
    super.key,
    required this.payload,
  });

  final CookInspectionCallPayload payload;

  @override
  State<CookLiveInspectionScreen> createState() =>
      _CookLiveInspectionScreenState();
}

class _CookLiveInspectionScreenState extends State<CookLiveInspectionScreen> {
  final AgoraVideoService _agora = AgoraVideoService();
  Timer? _ticker;
  final DateTime _startedAt = DateTime.now();
  bool _isEnding = false;
  bool _agoraReady = false;
  String? _errorMessage;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
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
        // Admin left the call — automatically end
        _onAdminLeft();
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

      final channelId = AgoraConfig.channelForCall(widget.payload.requestId);
      // Cook joins with uid=2
      await _agora.joinChannel(channelId: channelId, uid: 2);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to start video: $e');
    }
  }

  void _onAdminLeft() {
    if (!mounted || _isEnding) return;
    // Give a moment then auto-close
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF041029),
        body: Stack(
          children: [
            // Remote video (admin) — full screen
            Positioned.fill(child: _buildRemoteVideo()),

            // Local video (cook) — small PIP
            Positioned(
              right: 14,
              top: safeTop + 80,
              width: 110,
              height: 155,
              child: _buildLocalVideo(),
            ),

            // LIVE badge + timer
            Positioned(
              left: 14,
              top: safeTop + 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF73545),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE INSPECTION',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: safeTop + 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                child: Text(
                  _elapsedLabel,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ),
            ),

            // Cook/Admin info
            Positioned(
              left: 20,
              right: 20,
              top: safeTop + 52,
              child: Column(
                children: [
                  Text(
                    widget.payload.cookName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Inspection started by ${widget.payload.adminName}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12.4,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                      background: _agora.isLocalVideoEnabled
                          ? const Color(0xFFF3F4F6)
                          : const Color(0xFFE0E0E0),
                      iconColor: const Color(0xFF7A818E),
                      icon: _agora.isLocalVideoEnabled
                          ? Icons.videocam_outlined
                          : Icons.videocam_off_rounded,
                      onTap: () async {
                        await _agora.toggleCamera();
                        if (mounted) setState(() {});
                      },
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
                      icon: _isEnding
                          ? Icons.hourglass_bottom_rounded
                          : Icons.call_end_rounded,
                      onTap: _isEnding ? () {} : _endCall,
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
            channelId: AgoraConfig.channelForCall(widget.payload.requestId),
          ),
        ),
      );
    }

    return _buildMessage(
      _agoraReady
          ? 'Waiting for admin to join...'
          : 'Connecting...',
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF05112B),
            Color(0xFF061B42),
            Color(0xFF031028),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage == null)
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

  String get _elapsedLabel {
    final elapsed = DateTime.now().difference(_startedAt);
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _endCall() async {
    setState(() => _isEnding = true);
    await _agora.leaveChannel();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
