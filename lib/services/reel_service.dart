import 'package:naham_app/models/cook_reel_model.dart';
import 'package:naham_app/services/aws/aws_reel_service.dart';
import 'package:naham_app/services/backend/backend_factory.dart';

class ReelService {
  static final ReelService instance = ReelService._();

  ReelService._()
      : _awsService =
            AwsReelService(apiClient: BackendFactory.createAwsReelsApiClient());

  final AwsReelService _awsService;

  Future<List<CookReelModel>> getReels({bool newestFirst = true}) {
    return _awsService.getReels(newestFirst: newestFirst);
  }

  Stream<List<CookReelModel>> watchReels({bool newestFirst = true}) {
    return _awsService.watchReels(newestFirst: newestFirst);
  }

  Future<String> uploadVideoFile(
    String localPath,
    String reelId,
    String fileName, {
    void Function(double)? onProgress,
  }) {
    return _awsService.uploadVideoFile(
      localPath,
      reelId,
      fileName,
      onProgress: onProgress,
    );
  }

  Future<void> saveReel(
    CookReelModel reel, {
    String? likedByUserId,
    int likeDelta = 0,
  }) {
    return _awsService.saveReel(
      reel,
      likedByUserId: likedByUserId,
      likeDelta: likeDelta,
    );
  }

  Future<void> deleteReel(String id) {
    return _awsService.deleteReel(id);
  }
}
