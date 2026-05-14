import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:permission_handler/permission_handler.dart';

class CookReelCameraScreen extends StatefulWidget {
  const CookReelCameraScreen({super.key});

  @override
  State<CookReelCameraScreen> createState() => _CookReelCameraScreenState();
}

class _CookReelCameraScreenState extends State<CookReelCameraScreen> {
  final ImagePicker _picker = ImagePicker();
  static const List<ResolutionPreset> _resolutionFallback = [
    ResolutionPreset.high,
    ResolutionPreset.medium,
    ResolutionPreset.low,
  ];
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _activeCameraIndex = 0;
  Timer? _recordingTimer;
  String _duration = '15s';
  bool _isInitializingCamera = true;
  bool _isRecording = false;
  bool _flashEnabled = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraSurface(),
            const _CameraFocusFrame(),
            _CameraTopBar(onClose: () => context.pop()),
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + 66,
              child: _CameraToolsRail(
                flashEnabled: _flashEnabled,
                onFlipTap: _switchCamera,
                onSpeedTap: () => _showSnack('Speed options will open next'),
                onBeautyTap: () => _showSnack('Beauty filter applied'),
                onFiltersTap: () => _showSnack('Filters will open next'),
                onTimerTap: () => _showSnack('Timer set to 3 seconds'),
                onFlashTap: _toggleFlash,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: _CameraBottomControls(
                duration: _duration,
                isRecording: _isRecording,
                onDurationChanged: (value) => setState(() => _duration = value),
                onEffectsTap: () => _showSnack('Effects will open next'),
                onRecordTap: _recordVideo,
                onUploadTap: _pickVideoFromGallery,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSurface() {
    final controller = _cameraController;
    if (_isInitializingCamera) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_cameraError != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              _cameraError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(
            Icons.videocam_off_rounded,
            color: Colors.white70,
            size: 56,
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    try {
      final hasRecordingPermissions = await _requestRecordingPermissions();
      if (!hasRecordingPermissions) {
        if (mounted) {
          setState(() {
            _isInitializingCamera = false;
            _cameraError =
                'Camera and microphone permissions are required to record reels.';
          });
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          _showSnack('No camera found on this device');
          setState(() => _isInitializingCamera = false);
        }
        return;
      }

      _cameras = cameras;
      if (_activeCameraIndex >= _cameras.length) {
        _activeCameraIndex = 0;
      }

      await _cameraController?.dispose();
      final controller = await _createControllerWithFallback(
        _cameras[_activeCameraIndex],
      );

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() {
        _isInitializingCamera = false;
        _cameraError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializingCamera = false;
        _cameraError =
            'Camera preview is not available on this device. ${error.toString()}';
      });
    }
  }

  Future<CameraController> _createControllerWithFallback(
    CameraDescription description,
  ) async {
    Object? lastError;
    for (final preset in _resolutionFallback) {
      final controller = CameraController(
        description,
        preset,
        enableAudio: true,
      );
      try {
        await controller.initialize();
        return controller;
      } catch (error) {
        lastError = error;
        await controller.dispose();
      }
    }
    throw lastError ?? Exception('No supported camera resolution found');
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializingCamera) {
      return;
    }
    _activeCameraIndex = (_activeCameraIndex + 1) % _cameras.length;
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      _showSnack('Camera is not ready yet');
      return;
    }

    try {
      final nextEnabled = !_flashEnabled;
      await controller.setFlashMode(
        nextEnabled ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) return;
      setState(() => _flashEnabled = nextEnabled);
      _showSnack(nextEnabled ? 'Flash enabled' : 'Flash disabled');
    } catch (_) {
      _showSnack('Flash is not supported on this camera');
    }
  }

  Future<void> _recordVideo() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      _showSnack('Camera is not ready yet');
      return;
    }
    final hasPermission = await _requestRecordingPermissions(silent: true);
    if (!hasPermission) return;

    try {
      if (controller.value.isRecordingVideo) {
        await _stopRecordingAndSave();
        return;
      }

      await controller.startVideoRecording();
      if (mounted) {
        setState(() => _isRecording = true);
      }

      _recordingTimer?.cancel();
      final seconds = _duration == '60s' ? 60 : 15;
      _recordingTimer = Timer(Duration(seconds: seconds), () async {
        if (!mounted) return;
        final activeController = _cameraController;
        if (activeController == null ||
            !activeController.value.isRecordingVideo) {
          return;
        }
        await _stopRecordingAndSave();
      });
    } catch (_) {
      _showSnack('Failed to start recording');
    }
  }

  Future<void> _stopRecordingAndSave() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) {
      return;
    }

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final recordedVideo = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
      await _saveReel(recordedVideo.path, recordedVideo.name);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRecording = false);
      _showSnack('Failed to stop recording');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final hasPermission = await _requestGalleryPermissions();
    if (!hasPermission) return;

    try {
      final pickedVideo = await _picker.pickVideo(source: ImageSource.gallery);
      if (!mounted) return;
      if (pickedVideo == null) {
        _showSnack('Upload cancelled');
        return;
      }
      await _saveReel(pickedVideo.path, pickedVideo.name);
    } catch (_) {
      if (mounted) {
        _showSnack('Gallery video picker is not available');
      }
    }
  }

  Future<void> _handleVideoCaptured(String videoPath) async {
    if (!mounted) return;

    // Navigate to details screen to enter title/description
    final result =
        await context.push(AppRoutes.cookReelDetails, extra: videoPath);

    if (result == true && mounted) {
      // If upload was successful, we can pop back to the reels list
      context.pop(true);
    }
  }

  // Renamed _saveReel to _handleVideoCaptured and simplified
  Future<void> _saveReel(String videoPath, String fileName) async {
    await _handleVideoCaptured(videoPath);
  }

  Future<bool> _requestRecordingPermissions({bool silent = false}) async {
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();

    final missingPermissions = <String>[];
    if (!cameraStatus.isGranted) {
      missingPermissions.add('camera');
    }
    if (!microphoneStatus.isGranted) {
      missingPermissions.add('microphone');
    }
    if (missingPermissions.isNotEmpty) {
      if (!silent) {
        _showSnack('Please grant: ${missingPermissions.join(', ')}');
      }
      return false;
    }
    return true;
  }

  Future<bool> _requestGalleryPermissions() async {
    final mediaStatus = await _requestVideoLibraryPermission();
    if (!mediaStatus) {
      _showSnack('Please grant media library access');
    }
    return mediaStatus;
  }

  Future<bool> _requestVideoLibraryPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final videoStatus = await Permission.videos.request();
    if (videoStatus.isGranted) {
      return true;
    }

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _CameraTopBar extends StatelessWidget {
  const _CameraTopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 0),
        child: Row(
          children: [
            Tooltip(
              message: 'Close camera',
              child: Semantics(
                button: true,
                label: 'Close camera',
                child: IconButton(
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 38,
                    height: 38,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Sounds',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 38, height: 38),
          ],
        ),
      ),
    );
  }
}

class _CameraToolsRail extends StatelessWidget {
  const _CameraToolsRail({
    required this.flashEnabled,
    required this.onFlipTap,
    required this.onSpeedTap,
    required this.onBeautyTap,
    required this.onFiltersTap,
    required this.onTimerTap,
    required this.onFlashTap,
  });

  final bool flashEnabled;
  final VoidCallback onFlipTap;
  final VoidCallback onSpeedTap;
  final VoidCallback onBeautyTap;
  final VoidCallback onFiltersTap;
  final VoidCallback onTimerTap;
  final VoidCallback onFlashTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CameraToolButton(
          icon: Icons.cameraswitch_rounded,
          label: 'Flip',
          onTap: onFlipTap,
        ),
        _CameraToolButton(
          icon: Icons.speed_rounded,
          label: 'Speed',
          onTap: onSpeedTap,
        ),
        _CameraToolButton(
          icon: Icons.auto_fix_high_rounded,
          label: 'Beauty',
          onTap: onBeautyTap,
        ),
        _CameraToolButton(
          icon: Icons.filter_vintage_outlined,
          label: 'Filters',
          onTap: onFiltersTap,
        ),
        _CameraToolButton(
          icon: Icons.timer_3_outlined,
          label: 'Timer',
          onTap: onTimerTap,
        ),
        _CameraToolButton(
          icon: flashEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          label: 'Flash',
          onTap: onFlashTap,
        ),
      ],
    );
  }
}

class _CameraToolButton extends StatelessWidget {
  const _CameraToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 19),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraBottomControls extends StatelessWidget {
  const _CameraBottomControls({
    required this.duration,
    required this.isRecording,
    required this.onDurationChanged,
    required this.onEffectsTap,
    required this.onRecordTap,
    required this.onUploadTap,
  });

  final String duration;
  final bool isRecording;
  final ValueChanged<String> onDurationChanged;
  final VoidCallback onEffectsTap;
  final VoidCallback onRecordTap;
  final VoidCallback onUploadTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _BottomCameraAction(
                icon: Icons.face_retouching_natural_rounded,
                label: 'Effects',
                onTap: onEffectsTap,
              ),
              Tooltip(
                message: 'Record reel',
                child: Semantics(
                  button: true,
                  label: 'Record reel',
                  child: GestureDetector(
                    onTap: onRecordTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF03F5C),
                          width: 4,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isRecording
                              ? const Color(0xFFCB233A)
                              : const Color(0xFFFF405D),
                          shape: BoxShape.circle,
                        ),
                        child: isRecording
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              _BottomCameraAction(
                icon: Icons.image_outlined,
                label: 'Upload',
                onTap: onUploadTap,
                iconBackground: const Color(0xFFFFF3C8),
                iconColor: const Color(0xFF7FA6CC),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DurationButton(
              label: '60s',
              isSelected: duration == '60s',
              onTap: () => onDurationChanged('60s'),
            ),
            const SizedBox(width: 24),
            _DurationButton(
              label: '15s',
              isSelected: duration == '15s',
              onTap: () => onDurationChanged('15s'),
            ),
            const SizedBox(width: 24),
            _DurationButton(
              label: 'Templates',
              isSelected: duration == 'Templates',
              onTap: () => onDurationChanged('Templates'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: 132,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _BottomCameraAction extends StatelessWidget {
  const _BottomCameraAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconBackground = const Color(0xFFF4DAD6),
    this.iconColor = const Color(0xFFE45B67),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationButton extends StatelessWidget {
  const _DurationButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _CameraFocusFrame extends StatelessWidget {
  const _CameraFocusFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.28),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.45),
            ],
          ),
        ),
      ),
    );
  }
}
