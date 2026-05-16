import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naham_app/services/agora/agora_video_service.dart';

void main() {
  test('initialize does not block joining on a stuck local preview', () async {
    final fakeEngine = _FakeAgoraRtcEngineAdapter();
    final service = AgoraVideoService(
      engineFactory: () => fakeEngine,
      previewStartTimeout: const Duration(milliseconds: 1),
    );

    await service.initialize().timeout(const Duration(seconds: 1));
    expect(service.isInitialized, true);
    expect(fakeEngine.startPreviewCalled, true);

    await service.joinChannel(channelId: 'inspection_channel', uid: 1);

    expect(fakeEngine.joinedChannelId, 'inspection_channel');
    expect(fakeEngine.joinedUid, 1);
    expect(fakeEngine.joinOptions?.clientRoleType,
        ClientRoleType.clientRoleBroadcaster);
  });
}

class _FakeAgoraRtcEngineAdapter implements AgoraRtcEngineAdapter {
  final Completer<void> _stuckPreview = Completer<void>();

  bool startPreviewCalled = false;
  String? joinedChannelId;
  int? joinedUid;
  ChannelMediaOptions? joinOptions;

  @override
  RtcEngine? get rawEngine => null;

  @override
  Future<void> enableVideo() async {}

  @override
  Future<void> initialize(RtcEngineContext context) async {}

  @override
  Future<void> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    required ChannelMediaOptions options,
  }) async {
    joinedChannelId = channelId;
    joinedUid = uid;
    joinOptions = options;
  }

  @override
  Future<void> leaveChannel() async {}

  @override
  Future<void> muteLocalAudioStream(bool mute) async {}

  @override
  Future<void> muteLocalVideoStream(bool mute) async {}

  @override
  void registerEventHandler(RtcEngineEventHandler handler) {}

  @override
  Future<void> release() async {}

  @override
  Future<void> startPreview() {
    startPreviewCalled = true;
    return _stuckPreview.future;
  }

  @override
  Future<void> switchCamera() async {}
}
