class ReelCommentModel {
  final String id;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String text;
  final DateTime createdAt;

  ReelCommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReelCommentModel.fromMap(Map<String, dynamic> map) {
    return ReelCommentModel(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? 'User',
      userImageUrl: map['userImageUrl']?.toString(),
      text: map['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
