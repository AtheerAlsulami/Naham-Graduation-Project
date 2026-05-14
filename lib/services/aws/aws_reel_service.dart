import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:naham_app/models/cook_reel_model.dart';
import 'package:naham_app/services/aws/aws_api_client.dart';

class AwsReelService {
  AwsReelService({required this.apiClient});

  final AwsApiClient apiClient;

  Map<String, dynamic> _asJsonMap(
    dynamic value, {
    required String context,
  }) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        throw Exception('Invalid $context: empty string.');
      }
      final decoded = jsonDecode(trimmed);
      return _asJsonMap(decoded, context: '$context (decoded from string)');
    }
    throw Exception('Invalid $context. Expected JSON object.');
  }

  dynamic _decodeResponsePayload(String bodyString) {
    final decoded = jsonDecode(bodyString);
    if (decoded is List && decoded.length == 1 && decoded.first is Map) {
      return decoded.first;
    }
    if (decoded is Map<String, dynamic> &&
        decoded.containsKey('statusCode') &&
        decoded.containsKey('body') &&
        !decoded.containsKey('reels') &&
        !decoded.containsKey('uploadUrl')) {
      final nested = decoded['body'];
      if (nested is String) {
        return jsonDecode(nested);
      }
      return nested;
    }
    return decoded;
  }

  List<Map<String, dynamic>> _extractReels(dynamic payload) {
    if (payload is List) {
      if (payload.length == 1 && payload.first is Map) {
        final wrapper = payload.first;
        if (wrapper is Map) {
          final wrappedItems =
              wrapper['reels'] ?? wrapper['items'] ?? wrapper['data'];
          if (wrappedItems is List) {
            return wrappedItems
                .whereType<Map>()
                .map((item) => item.map(
                      (key, value) => MapEntry(key.toString(), value),
                    ))
                .toList();
          }
        }
      }
      return payload
          .whereType<Map>()
          .map((item) => item.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList();
    }

    final body = _asJsonMap(payload, context: 'reels response');
    final candidates =
        body['reels'] ?? body['items'] ?? body['data'] ?? const [];
    if (candidates is! List) {
      return const [];
    }
    return candidates
        .whereType<Map>()
        .map((item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList();
  }

  Future<List<CookReelModel>> getReels({bool newestFirst = true}) async {
    final response = await apiClient.get(
      '/reels',
      queryParameters: {
        'sort': newestFirst ? 'newest' : 'oldest',
      },
    );
    final payload = _decodeResponsePayload(response.body);
    final reels = _extractReels(payload);
    return reels.map(CookReelModel.fromMap).toList();
  }

  Stream<List<CookReelModel>> watchReels({
    bool newestFirst = true,
    Duration pollInterval = const Duration(seconds: 5),
  }) {
    late Timer timer;
    final controller = StreamController<List<CookReelModel>>();

    Future<void> emit() async {
      try {
        final reels = await getReels(newestFirst: newestFirst);
        if (!controller.isClosed) {
          controller.add(reels);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller.onListen = () {
      emit();
      timer = Timer.periodic(pollInterval, (_) => emit());
    };
    controller.onCancel = () {
      timer.cancel();
    };

    return controller.stream;
  }

  String _detectContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    }
    if (lower.endsWith('.mov')) {
      return 'video/quicktime';
    }
    if (lower.endsWith('.webm')) {
      return 'video/webm';
    }
    return 'application/octet-stream';
  }

  Future<String> uploadVideoFile(
    String localPath,
    String reelId,
    String fileName, {
    void Function(double)? onProgress,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Video file does not exist: $localPath');
    }

    final contentType = _detectContentType(fileName);
    final response = await apiClient.post(
      '/reels/upload-url',
      body: {
        'reelId': reelId,
        'fileName': fileName,
        'contentType': contentType,
      },
    );

    final payload = _decodeResponsePayload(response.body);
    final body = _asJsonMap(payload, context: 'reel upload-url response');

    final uploadUrl = (body['uploadUrl'] ?? '').toString();
    final fileUrl = (body['fileUrl'] ?? '').toString();
    if (uploadUrl.isEmpty || fileUrl.isEmpty) {
      throw Exception(
        'Invalid upload-url response. Missing uploadUrl or fileUrl.',
      );
    }

    final rawHeaders = body['headers'];
    final Map<String, String> uploadHeaders = {
      'Content-Type': contentType,
    };
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        uploadHeaders[entry.key.toString()] = entry.value.toString();
      }
    }

    final totalBytes = await file.length();
    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
    request.headers.addAll(uploadHeaders);
    request.contentLength = totalBytes;

    int bytesSent = 0;
    final fileStream = file.openRead();

    fileStream.listen(
      (chunk) {
        bytesSent += chunk.length;
        if (onProgress != null) {
          onProgress(bytesSent / totalBytes);
        }
        request.sink.add(chunk);
      },
      onDone: () => request.sink.close(),
      onError: (err) => request.sink.addError(err),
      cancelOnError: true,
    );

    final streamedResponse = await request.send();
    final uploadResponse = await http.Response.fromStream(streamedResponse);

    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception(
        'Video upload failed (${uploadResponse.statusCode}). ${uploadResponse.body}',
      );
    }

    return fileUrl;
  }

  Future<void> saveReel(
    CookReelModel reel, {
    String? likedByUserId,
    int likeDelta = 0,
  }) async {
    final payload = reel.toMap();
    payload['createdAt'] = reel.createdAt.toIso8601String();
    if (likedByUserId != null && likedByUserId.trim().isNotEmpty) {
      payload['likedByUserId'] = likedByUserId.trim();
    }
    if (likeDelta != 0) {
      payload['likeDelta'] = likeDelta;
    }
    await apiClient.post('/reels', body: payload);
  }

  Future<void> deleteReel(String id) async {
    await apiClient.delete('/reels/$id');
  }
}
