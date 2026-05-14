import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'agora_config.dart';

/// Callback signatures for Agora events.
typedef AgoraUserCallback = void Function(int remoteUid);
typedef AgoraErrorCallback = void Function(String message);

/// A reusable service wrapping the Agora RTC engine for 1-to-1 video calls.
class AgoraVideoService {
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _localVideoEnabled = true;
  bool _localAudioEnabled = true;
  int? _remoteUid;

  /// Whether the engine has been initialized.
  bool get isInitialized => _isInitialized;

  /// The UID of the remote user currently in the channel, if any.
  int? get remoteUid => _remoteUid;

  /// The underlying RTC engine (for building video views).
  RtcEngine? get engine => _engine;

  bool get isLocalVideoEnabled => _localVideoEnabled;
  bool get isLocalAudioEnabled => _localAudioEnabled;

  // ── Callbacks ───────────────────────────────────────────────────────────
  AgoraUserCallback? onRemoteUserJoined;
  AgoraUserCallback? onRemoteUserLeft;
  AgoraErrorCallback? onError;
  VoidCallback? onJoinedChannel;

  // ── Lifecycle ───────────────────────────────────────────────────────────

  /// Request camera and microphone permissions.
  Future<bool> requestPermissions() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    return camera.isGranted && mic.isGranted;
  }

  /// Initialize the Agora engine.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: AgoraConfig.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint('Agora: joined channel ${connection.channelId} in ${elapsed}ms');
        onJoinedChannel?.call();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('Agora: remote user $remoteUid joined');
        _remoteUid = remoteUid;
        onRemoteUserJoined?.call(remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint('Agora: remote user $remoteUid left (reason: $reason)');
        _remoteUid = null;
        onRemoteUserLeft?.call(remoteUid);
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('Agora error: $err - $msg');
        onError?.call('$err: $msg');
      },
    ));

    await _engine!.enableVideo();
    await _engine!.startPreview();

    _isInitialized = true;
  }

  /// Join a video channel.
  Future<void> joinChannel({
    required String channelId,
    int uid = 0,
    String? token,
  }) async {
    if (_engine == null) return;

    await _engine!.joinChannel(
      token: token ?? '',
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  /// Leave the current channel.
  Future<void> leaveChannel() async {
    _remoteUid = null;
    if (_engine != null) {
      await _engine!.leaveChannel();
    }
  }

  // ── Controls ────────────────────────────────────────────────────────────

  /// Toggle local microphone on/off.
  Future<void> toggleMicrophone() async {
    if (_engine == null) return;
    _localAudioEnabled = !_localAudioEnabled;
    await _engine!.muteLocalAudioStream(!_localAudioEnabled);
  }

  /// Toggle local camera on/off.
  Future<void> toggleCamera() async {
    if (_engine == null) return;
    _localVideoEnabled = !_localVideoEnabled;
    await _engine!.muteLocalVideoStream(!_localVideoEnabled);
  }

  /// Switch between front and back cameras.
  Future<void> switchCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────

  /// Release all resources. Call this in dispose().
  Future<void> dispose() async {
    _remoteUid = null;
    _isInitialized = false;
    onRemoteUserJoined = null;
    onRemoteUserLeft = null;
    onError = null;
    onJoinedChannel = null;

    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }
  }
}
