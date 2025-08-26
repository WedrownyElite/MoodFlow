import 'dart:ui';
import 'package:flutter/material.dart';

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
  Future<void> executeTransition(Future<void> Function() onContentChange) async {
    if (_isTransitioning || _disposed) return; // CHECK DISPOSED

    _isTransitioning = true;

    try {
      await _controller.forward();
      await onContentChange();
      if (!_disposed) {
        await _controller.reverse();
      }
    } finally {
      _isTransitioning = false;
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
class BlurTransitionWidget extends StatelessWidget {
  final Widget child;
  final BlurTransitionService blurService;

  const BlurTransitionWidget({
    super.key,
    required this.child,
    required this.blurService,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: blurService.animation,
      builder: (context, _) {
        return ImageFiltered(
          imageFilter: blurService.imageFilter,
          child: child,
        );
      },
    );
  }
}