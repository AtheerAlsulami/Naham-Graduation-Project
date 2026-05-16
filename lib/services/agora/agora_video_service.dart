import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'agora_config.dart';

/// Callback signatures for Agora events.
typedef AgoraUserCallback = void Function(int remoteUid);
typedef AgoraErrorCallback = void Function(String message);

abstract class AgoraRtcEngineAdapter {
  RtcEngine? get rawEngine;

  Future<void> initialize(RtcEngineContext context);
  void registerEventHandler(RtcEngineEventHandler handler);
  Future<void> enableVideo();
  Future<void> startPreview();
  Future<void> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    required ChannelMediaOptions options,
  });
  Future<void> leaveChannel();
  Future<void> release();
  Future<void> muteLocalAudioStream(bool mute);
  Future<void> muteLocalVideoStream(bool mute);
  Future<void> switchCamera();
}

class _AgoraRtcEngineAdapter implements AgoraRtcEngineAdapter {
  _AgoraRtcEngineAdapter(this._engine);

  final RtcEngine _engine;

  @override
  RtcEngine get rawEngine => _engine;

  @override
  Future<void> initialize(RtcEngineContext context) {
    return _engine.initialize(context);
  }

  @override
  void registerEventHandler(RtcEngineEventHandler handler) {
    _engine.registerEventHandler(handler);
  }

  @override
  Future<void> enableVideo() {
    return _engine.enableVideo();
  }

  @override
  Future<void> startPreview() {
    return _engine.startPreview();
  }

  @override
  Future<void> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    required ChannelMediaOptions options,
  }) {
    return _engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: options,
    );
  }

  @override
  Future<void> leaveChannel() {
    return _engine.leaveChannel();
  }

  @override
  Future<void> release() {
    return _engine.release();
  }

  @override
  Future<void> muteLocalAudioStream(bool mute) {
    return _engine.muteLocalAudioStream(mute);
  }

  @override
  Future<void> muteLocalVideoStream(bool mute) {
    return _engine.muteLocalVideoStream(mute);
  }

  @override
  Future<void> switchCamera() {
    return _engine.switchCamera();
  }
}

/// A reusable service wrapping the Agora RTC engine for 1-to-1 video calls.
class AgoraVideoService {
  AgoraVideoService({
    AgoraRtcEngineAdapter Function()? engineFactory,
    Duration previewStartTimeout = const Duration(seconds: 2),
  })  : _engineFactory = engineFactory ??
            (() => _AgoraRtcEngineAdapter(createAgoraRtcEngine())),
        _previewStartTimeout = previewStartTimeout;

  final AgoraRtcEngineAdapter Function() _engineFactory;
  final Duration _previewStartTimeout;

  AgoraRtcEngineAdapter? _engine;
  bool _isInitialized = false;
  bool _localVideoEnabled = true;
  bool _localAudioEnabled = true;
  int? _remoteUid;

  /// Whether the engine has been initialized.
  bool get isInitialized => _isInitialized;

  /// The UID of the remote user currently in the channel, if any.
  int? get remoteUid => _remoteUid;

  /// The underlying RTC engine (for building video views).
  RtcEngine? get engine => _engine?.rawEngine;

  bool get isLocalVideoEnabled => _localVideoEnabled;
  bool get isLocalAudioEnabled => _localAudioEnabled;

  AgoraUserCallback? onRemoteUserJoined;
  AgoraUserCallback? onRemoteUserLeft;
  AgoraErrorCallback? onError;
  VoidCallback? onJoinedChannel;

  /// Request camera and microphone permissions.
  Future<bool> requestPermissions() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    return camera.isGranted && mic.isGranted;
  }

  /// Initialize the Agora engine.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _engine = _engineFactory();
    await _engine!.initialize(
      RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint(
            'Agora: joined channel ${connection.channelId} in ${elapsed}ms',
          );
          onJoinedChannel?.call();
        },
        onUserJoined: (
          RtcConnection connection,
          int remoteUid,
          int elapsed,
        ) {
          debugPrint(
            'Agora: remote user $remoteUid joined ${connection.channelId}',
          );
          _remoteUid = remoteUid;
          onRemoteUserJoined?.call(remoteUid);
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          debugPrint(
            'Agora: remote user $remoteUid left ${connection.channelId} '
            '(reason: $reason)',
          );
          _remoteUid = null;
          onRemoteUserLeft?.call(remoteUid);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora error: $err - $msg');
          onError?.call('$err: $msg');
        },
        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          debugPrint(
            'Agora: connection state ${connection.channelId} '
            '$state (reason: $reason)',
          );
        },
        onPermissionError: (PermissionType permissionType) {
          debugPrint('Agora permission error: $permissionType');
          onError?.call('Agora permission error: $permissionType');
        },
      ),
    );

    await _engine!.enableVideo();
    _isInitialized = true;
    _startLocalPreviewBestEffort();
  }

  void _startLocalPreviewBestEffort() {
    final engine = _engine;
    if (engine == null) return;

    unawaited(
      engine
          .startPreview()
          .timeout(_previewStartTimeout)
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint('Agora local preview could not start: $error');
      }),
    );
  }

  /// Join a video channel.
  Future<void> joinChannel({
    required String channelId,
    int uid = 0,
    String? token,
  }) async {
    final engine = _engine;
    if (engine == null) return;

    await engine.joinChannel(
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
    final engine = _engine;
    if (engine != null) {
      await engine.leaveChannel();
    }
  }

  /// Toggle local microphone on/off.
  Future<void> toggleMicrophone() async {
    final engine = _engine;
    if (engine == null) return;
    _localAudioEnabled = !_localAudioEnabled;
    await engine.muteLocalAudioStream(!_localAudioEnabled);
  }

  /// Toggle local camera on/off.
  Future<void> toggleCamera() async {
    final engine = _engine;
    if (engine == null) return;
    _localVideoEnabled = !_localVideoEnabled;
    await engine.muteLocalVideoStream(!_localVideoEnabled);
  }

  /// Switch between front and back cameras.
  Future<void> switchCamera() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.switchCamera();
  }

  /// Release all resources. Call this in dispose().
  Future<void> dispose() async {
    _remoteUid = null;
    _isInitialized = false;
    onRemoteUserJoined = null;
    onRemoteUserLeft = null;
    onError = null;
    onJoinedChannel = null;

    final engine = _engine;
    if (engine != null) {
      await engine.leaveChannel();
      await engine.release();
      _engine = null;
    }
  }
}
