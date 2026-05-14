import 'package:flutter/material.dart';
import 'package:naham_app/services/backend/backend_follow_service.dart';

class FollowProvider extends ChangeNotifier {
  FollowProvider({BackendFollowService? followService})
      : _followService = followService ?? BackendFollowService();

  final BackendFollowService _followService;

  String? _currentUserId;
  Set<String> _followedCookIds = {};
  bool _isLoading = false;
  String? _error;

  Set<String> get followedCookIds => _followedCookIds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void bindAuthUser(String? userId) {
    final nextId = userId?.trim() ?? '';
    if (_currentUserId == nextId) return;
    _currentUserId = nextId;
    _followedCookIds = {};
    if (nextId.isNotEmpty) {
      loadFollows();
    } else {
      notifyListeners();
    }
  }

  Future<void> refresh() => loadFollows();

  Future<void> loadFollows() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final follows = await _followService.listFollowedCookIds(_currentUserId!);
      _followedCookIds = follows;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isFollowing(String cookId) {
    final id = cookId.trim();
    if (id.isEmpty) return false;
    return _followedCookIds.contains(id);
  }

  Future<void> toggleFollow({
    required String cookId,
    bool shouldFollow = true,
  }) async {
    final id = cookId.trim();
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    if (id.isEmpty) return;

    final wasFollowing = _followedCookIds.contains(id);
    if (wasFollowing == shouldFollow) return;

    _error = null;
    // Optimistic UI update
    if (shouldFollow) {
      _followedCookIds.add(id);
    } else {
      _followedCookIds.remove(id);
    }
    notifyListeners();

    try {
      if (shouldFollow) {
        await _followService.followCook(
          customerId: _currentUserId!,
          cookId: id,
        );
      } else {
        await _followService.unfollowCook(
          customerId: _currentUserId!,
          cookId: id,
        );
      }
    } catch (e) {
      // Revert on error
      if (shouldFollow) {
        _followedCookIds.remove(id);
      } else {
        _followedCookIds.add(id);
      }
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
