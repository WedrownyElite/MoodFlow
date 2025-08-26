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
  /// FIXED: Maintains content visibility during transition
  Future<void> executeTransition(Future<void> Function() onContentChange) async {
    if (_isTransitioning || _disposed) return;

    _isTransitioning = true;

    try {
      // 1. Blur in (0 -> maxBlur)
      await _controller.forward();

      // 2. Execute content change at peak blur (content is hidden by blur)
      await onContentChange();

      // 3. Add a tiny delay to ensure new content is rendered
      await Future.delayed(const Duration(milliseconds: 16)); // One frame at 60fps

      // 4. Blur out (maxBlur -> 0)
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
  Widget? _previousChild;
  Widget? _currentChild;

  @override
  void initState() {
    super.initState();
    _currentChild = widget.child;
    _previousChild = widget.child;
  }

  @override
  void didUpdateWidget(BlurTransitionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the child changed during a transition, keep the previous child
    // visible until the transition completes
    if (widget.child != oldWidget.child) {
      if (widget.blurService.isTransitioning) {
        // During transition, keep previous child visible
        _previousChild = _currentChild;
        _currentChild = widget.child;
      } else {
        // Not transitioning, update normally
        _previousChild = _currentChild;
        _currentChild = widget.child;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.blurService.animation,
      builder: (context, _) {
        final blurValue = widget.blurService.blurValue;

        // Choose which child to show based on transition state
        Widget childToShow;

        if (widget.blurService.isTransitioning) {
          // During the first half of transition (blur increasing), show previous child
          // During the second half (blur decreasing), show current child
          final progress = widget.blurService._controller.value;
          childToShow = progress < 0.5 ? (_previousChild ?? _currentChild!) : _currentChild!;
        } else {
          childToShow = _currentChild!;
        }

        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blurValue,
            sigmaY: blurValue,
          ),
          child: childToShow,
        );
      },
    );
  }
}