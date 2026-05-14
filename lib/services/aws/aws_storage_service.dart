import 'dart:io';

import 'package:naham_app/services/aws/aws_api_client.dart';

class AwsStorageService {
  AwsStorageService({required this.apiClient});

  final AwsApiClient apiClient;

  Future<String> uploadProfileImage({
    required File imageFile,
    required String userId,
  }) async {
    throw UnimplementedError(
      'Upload via AWS Storage is not configured yet. Implement using a signed URL or Amplify storage endpoint.',
    );
  }

  Future<String> uploadDishImage({
    required File imageFile,
    required String dishId,
  }) async {
    throw UnimplementedError(
      'Upload via AWS Storage is not configured yet. Implement using a signed URL or Amplify storage endpoint.',
    );
  }

  Future<String> uploadReelFile({
    required File file,
    required String reelId,
    required String fileName,
  }) async {
    throw UnimplementedError(
      'Upload via AWS Storage is not configured yet. Implement using a signed URL or Amplify storage endpoint.',
    );
  }
}
