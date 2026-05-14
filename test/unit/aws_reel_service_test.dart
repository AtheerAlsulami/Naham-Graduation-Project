import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naham_app/models/cook_reel_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';
import 'package:naham_app/services/aws/aws_reel_service.dart';

void main() {
  test('AwsReelService.saveReel sends like increment metadata', () async {
    final client = _RecordingClient((request, body) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/reels');
      final payload = jsonDecode(body) as Map<String, dynamic>;
      expect(payload['id'], 'reel_1');
      expect(payload['likedByUserId'], 'customer_1');
      expect(payload['likeDelta'], 1);
      return _jsonResponse({'reel': payload});
    });
    final service = AwsReelService(
      apiClient: AwsApiClient(
        baseUrl: 'https://reels.example.com',
        client: client,
      ),
    );

    await service.saveReel(
      _reel(likes: 11, isLiked: true),
      likedByUserId: 'customer_1',
      likeDelta: 1,
    );
  });

  test('AwsReelService.saveReel sends like decrement metadata', () async {
    final client = _RecordingClient((request, body) async {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      expect(payload['likedByUserId'], 'customer_1');
      expect(payload['likeDelta'], -1);
      expect(payload['likes'], 10);
      return _jsonResponse({'reel': payload});
    });
    final service = AwsReelService(
      apiClient: AwsApiClient(
        baseUrl: 'https://reels.example.com',
        client: client,
      ),
    );

    await service.saveReel(
      _reel(likes: 10, isLiked: false),
      likedByUserId: 'customer_1',
      likeDelta: -1,
    );
  });

  test('AwsReelService.watchReels emits initial and polling refresh values',
      () async {
    var calls = 0;
    final client = _RecordingClient((request, body) async {
      calls += 1;
      return _jsonResponse({
        'reels': [
          _reel(id: 'reel_$calls', likes: calls).toMap(),
        ],
      });
    });
    final service = AwsReelService(
      apiClient: AwsApiClient(
        baseUrl: 'https://reels.example.com',
        client: client,
      ),
    );

    final stream = service.watchReels(
      pollInterval: const Duration(milliseconds: 20),
    );

    final emissions = await stream.take(2).toList();

    expect(emissions.first.single.id, 'reel_1');
    expect(emissions.last.single.id, 'reel_2');
    expect(calls, greaterThanOrEqualTo(2));
  });
}

CookReelModel _reel({
  String id = 'reel_1',
  int likes = 10,
  bool isLiked = false,
}) {
  return CookReelModel(
    id: id,
    creatorId: 'cook_1',
    creatorName: 'Cook',
    title: 'Kabsa reel',
    description: 'Cooking clip',
    videoPath: 'https://cdn.example.com/reel.mp4',
    audioLabel: 'Original Audio',
    likes: likes,
    comments: 0,
    shares: 0,
    isMine: false,
    isFollowing: false,
    isLiked: isLiked,
    isPaused: false,
    isBookmarked: false,
    isDraft: false,
    createdAt: DateTime.parse('2026-05-11T09:00:00.000Z'),
  );
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request, String body)
      handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final response = await handler(request, body);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
