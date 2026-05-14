/// Agora RTC configuration for live video inspection.
class AgoraConfig {
  AgoraConfig._();

  /// Agora App ID – No token mode (testing/development).
  static const String appId = '9a43f9e282874791861d793d14beb206';

  /// Generate a stable Agora-safe channel name for a hygiene inspection call.
  static String channelForCall(String callRequestId) {
    final normalized = callRequestId.trim();
    final source = normalized.isEmpty ? 'unknown_call' : normalized;
    return 'hyg_${_fnv1a64(source)}';
  }

  static String _fnv1a64(String input) {
    const int fnvPrime = 0x100000001b3;
    const int mask64 = 0xffffffffffffffff;
    var hash = 0xcbf29ce484222325;

    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & mask64;
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }
}
