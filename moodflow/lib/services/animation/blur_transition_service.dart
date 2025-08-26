import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/logger.dart';

class BlurTransitionService {
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  bool _isTransitioning = false;
  bool _disposed = false;

  BlurTransitionService({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 400),
    double maxBlur = 10.0,
  }) {
    _controller = AnimationController(vsync: vsync, duration: duration);

    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: maxBlur,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  /// Get the current blur value for ImageFilter
  double get blurValue => _blurAnimation.value;

  /// Check if a transition is currently in progress
  bool get isTransitioning => _isTransitioning;

  /// Get the animation controller for listening to changes
  Animation<double> get animation => _blurAnimation;

  /// Execute a blur transition with a callback for the content change
  Future<void> executeTransition(
      Future<void> Function() onContentChange) async {
    if (_isTransitioning || _disposed) {
      Logger.moodService(
          '⚠️ Blur transition blocked - already transitioning: $_isTransitioning, disposed: $_disposed');
      return;
    }

    Logger.moodService('🌀 Starting blur transition');
    _isTransitioning = true;

    try {
      // 1. Blur in (0 -> maxBlur)
      Logger.moodService('🌀 Phase 1: Blurring IN (0 -> max blur)');
      await _controller.forward();
      Logger.moodService('🌀 Blur IN complete - content is now hidden');

      // 2. Execute content change at peak blur (content is hidden by blur)
      Logger.moodService('🔄 Phase 2: Executing content change while blurred');
      await onContentChange();
      Logger.moodService('✅ Content change complete');

      // 3. Add a small delay to ensure new content is rendered
      Logger.moodService('⏱️ Phase 3: Waiting for content to be ready');
      await Future.delayed(const Duration(milliseconds: 50));
      Logger.moodService('✅ Content should be ready');

      // 4. Blur out (maxBlur -> 0)
      if (!_disposed) {
        Logger.moodService('🌀 Phase 4: Blurring OUT ($blurValue -> 0)');
        await _controller.reverse();
        Logger.moodService('🌀 Blur OUT complete - content is now visible');
      }
    } finally {
      _isTransitioning = false;
      Logger.moodService('🎯 Blur transition fully complete');
    }
  }

  void dispose() {
    _disposed = true;
    if (!_disposed) {
      _controller.dispose();
    }
  }

  /// Create an ImageFilter with the current blur value
  ImageFilter get imageFilter => ImageFilter.blur(
        sigmaX: blurValue,
        sigmaY: blurValue,
      );
}

/// Widget wrapper that applies blur transition to its child
/// FIXED: Better handling of content changes
class BlurTransitionWidget extends StatefulWidget {
  final Widget child;
  final BlurTransitionService blurService;

  const BlurTransitionWidget({
    super.key,
    required this.child,
    required this.blurService,
  });

  @override
  State<BlurTransitionWidget> createState() => _BlurTransitionWidgetState();
}

class _BlurTransitionWidgetState extends State<BlurTransitionWidget> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.blurService.animation,
      builder: (context, _) {
        final blurValue = widget.blurService.blurValue;

        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blurValue,
            sigmaY: blurValue,
          ),
          child: widget.child,
        );
      },
    );
  }
}
