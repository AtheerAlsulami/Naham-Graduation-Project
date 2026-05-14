import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

class ReelVideoSurface extends StatefulWidget {
  const ReelVideoSurface({
    super.key,
    required this.source,
    required this.isPaused,
  });

  final String source;
  final bool isPaused;

  @override
  State<ReelVideoSurface> createState() => _ReelVideoSurfaceState();
}

class _ReelVideoSurfaceState extends State<ReelVideoSurface>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Object? _initializeError;
  int _activeTicket = 0;

  /// True when the app is in the background (paused/inactive).
  bool _appInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant ReelVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _initializeController();
      return;
    }
    _syncPlaybackState();
  }

  // ── App lifecycle ──

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlaybackState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasBg = _appInBackground;
    _appInBackground =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;

    if (_appInBackground != wasBg) {
      _syncPlaybackState();
    }
  }

  // ── Video controller ──

  bool get _shouldPause {
    final isRouteActive = ModalRoute.of(context)?.isCurrent ?? true;
    return widget.isPaused || _appInBackground || !isRouteActive;
  }

  Future<void> _initializeController() async {
    final ticket = ++_activeTicket;
    final previous = _controller;
    _controller = null;
    _initializeError = null;
    setState(() {});
    await previous?.dispose();

    VideoPlayerController controller;
    if (_isRemote(widget.source)) {
      try {
        final file = await DefaultCacheManager().getSingleFile(widget.source);
        if (!mounted || ticket != _activeTicket) return;
        controller = VideoPlayerController.file(file);
      } catch (e) {
        debugPrint('Video cache failed, falling back to network: $e');
        final uri = Uri.tryParse(widget.source);
        if (uri == null) {
          _initializeError = Exception('Invalid remote video URL.');
          if (mounted && ticket == _activeTicket) setState(() {});
          return;
        }
        controller = VideoPlayerController.networkUrl(uri);
      }
    } else {
      controller = VideoPlayerController.file(File(widget.source));
    }

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await _applyPauseState(controller);
    } catch (error) {
      debugPrint('ReelVideoSurface init failed for ${widget.source}: $error');
      await controller.dispose();
      if (!mounted || ticket != _activeTicket) {
        return;
      }
      _initializeError = error;
      setState(() {});
      return;
    }

    if (!mounted || ticket != _activeTicket) {
      await controller.dispose();
      return;
    }

    _controller = controller;
    setState(() {});
  }

  Future<void> _syncPlaybackState() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    await _applyPauseState(controller);
  }

  Future<void> _applyPauseState(VideoPlayerController controller) async {
    if (_shouldPause) {
      if (controller.value.isPlaying) {
        await controller.pause();
      }
      return;
    }
    if (!controller.value.isPlaying) {
      await controller.play();
    }
  }

  bool _isRemote(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializeError != null) {
      return const ColoredBox(
        color: Color(0xFF1E1D20),
        child: Center(
          child: Icon(
            Icons.error_outline_rounded,
            color: Colors.white70,
            size: 44,
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Color(0xFF1E1D20),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final videoSize = controller.value.size;
    final hasValidSize = videoSize.width > 0 && videoSize.height > 0;
    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: hasValidSize ? videoSize.width : 16,
          height: hasValidSize ? videoSize.height : 9,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
