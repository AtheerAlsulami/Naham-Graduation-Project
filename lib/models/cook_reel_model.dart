import 'package:naham_app/models/reel_comment_model.dart';

class CookReelModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorImageUrl;
  final String title;
  final String description;
  final String? imageUrl;
  final String videoPath;
  final String audioLabel;
  final int likes;
  final int comments;
  final int shares;
  final bool isMine;
  final bool isFollowing;
  final bool isLiked;
  final bool isPaused;
  final bool isBookmarked;
  final bool isDraft;
  final List<ReelCommentModel> commentItems;
  final DateTime createdAt;

  CookReelModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorImageUrl,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.videoPath,
    required this.audioLabel,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isMine,
    required this.isFollowing,
    required this.isLiked,
    required this.isPaused,
    required this.isBookmarked,
    required this.isDraft,
    this.commentItems = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorImageUrl': creatorImageUrl,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'videoPath': videoPath,
      'audioLabel': audioLabel,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'isMine': isMine,
      'isFollowing': isFollowing,
      'isLiked': isLiked,
      'isPaused': isPaused,
      'isBookmarked': isBookmarked,
      'isDraft': isDraft,
      'commentItems': commentItems.map((c) => c.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CookReelModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) {
        return value;
      }
      if (value is int) {
        // Supports both unix-seconds and unix-milliseconds formats.
        final isSeconds = value.abs() < 1000000000000;
        return DateTime.fromMillisecondsSinceEpoch(
          isSeconds ? value * 1000 : value,
          isUtc: true,
        ).toLocal();
      }
      if (value is Map<String, dynamic>) {
        final seconds = value['seconds'] ?? value['_seconds'];
        final nanos = value['nanoseconds'] ?? value['_nanoseconds'] ?? 0;
        if (seconds is int) {
          final millis = (seconds * 1000) + ((nanos is int ? nanos : 0) ~/ 1000000);
          return DateTime.fromMillisecondsSinceEpoch(
            millis,
            isUtc: true,
          ).toLocal();
        }
      }
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
      return DateTime.now();
    }

    int parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value.trim()) ?? 0;
      }
      return 0;
    }

    bool parseBool(dynamic value) {
      if (value is bool) {
        return value;
      }
      if (value is int) {
        return value == 1;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == '0') {
          return false;
        }
      }
      return false;
    }

    String? parseOptionalString(dynamic value) {
      if (value == null) {
        return null;
      }
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final fallbackTitle =
        (map['title']?.toString().trim().isNotEmpty ?? false)
            ? map['title'].toString()
            : 'Cooking Reel';
    final fallbackDescription =
        map['description']?.toString() ?? 'Short cooking clip';

    return CookReelModel(
      id: map['id']?.toString() ?? '',
      creatorId: map['creatorId']?.toString() ?? '',
      creatorName: map['creatorName']?.toString() ?? '@cook',
      creatorImageUrl: parseOptionalString(
        map['creatorImageUrl'] ?? map['profileImageUrl'],
      ),
      title: fallbackTitle,
      description: fallbackDescription,
      imageUrl: parseOptionalString(map['imageUrl']),
      videoPath:
          map['videoPath']?.toString() ?? map['videoUrl']?.toString() ?? '',
      audioLabel: map['audioLabel']?.toString() ?? 'Original Audio',
      likes: parseInt(map['likes']),
      comments: parseInt(map['comments']),
      shares: parseInt(map['shares']),
      isMine: parseBool(map['isMine']),
      isFollowing: parseBool(map['isFollowing']),
      isLiked: parseBool(map['isLiked']),
      isPaused: parseBool(map['isPaused']),
      isBookmarked: parseBool(map['isBookmarked']),
      isDraft: parseBool(map['isDraft']),
      commentItems: (map['commentItems'] as List? ?? [])
          .map((c) => ReelCommentModel.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      createdAt: parseDate(map['createdAt']),
    );
  }
}
