import 'package:flutter_test/flutter_test.dart';
import 'package:naham_app/services/agora/agora_config.dart';

void main() {
  test('channelForCall returns an Agora-safe channel for long request ids', () {
    final channel = AgoraConfig.channelForCall(
      'call_1770000000000000_user_1234567890abcdef1234567890abcdef',
    );

    expect(channel.length, lessThan(64));
    expect(channel, matches(RegExp(r'^[A-Za-z0-9_]+$')));
    expect(
      channel,
      AgoraConfig.channelForCall(
        'call_1770000000000000_user_1234567890abcdef1234567890abcdef',
      ),
    );
  });
}
