import 'package:flutter/material.dart';

class SliderAnimationService {
  late AnimationController _controller;
  late Animation<double> _sliderAnimation;
  double _currentValue = 5.0;
  double _targetValue = 5.0;
  bool _isAnimating = false;

  SliderAnimationService({
    required TickerProvider vsync,
    Duration duration =
        const Duration(milliseconds: 300), // FIXED: Reduced from 600ms to 300ms
    double initialValue = 5.0,
  }) {
    _currentValue = initialValue;
    _targetValue = initialValue;

    _controller = AnimationController(vsync: vsync, duration: duration);

    _sliderAnimation = Tween<double>(
      begin: _currentValue,
      end: _targetValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    // FIXED: Clear animation flag as soon as animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _isAnimating = false;
      }
    });
  }

  /// Get the current animated slider value
  double get value => _sliderAnimation.value;

  /// Check if slider is currently animating
  bool get isAnimating => _isAnimating;

  /// Get the animation for listening to changes
  Animation<double> get animation => _sliderAnimation;

  /// Animate slider to a new value
  Future<void> animateToValue(double newValue, {bool immediate = false}) async {
    if (immediate ||
        newValue == _currentValue ||
        (newValue - _currentValue).abs() < 0.1) {
      // FIXED: If the difference is tiny, don't animate
      _currentValue = newValue;
      _targetValue = newValue;
      _sliderAnimation = Tween<double>(
        begin: newValue,
        end: newValue,
      ).animate(_controller);
      _controller.reset();
      _isAnimating = false;
      return;
    }

    if (_isAnimating) {
      // If already animating, update the target and restart
      _controller.stop();
    }

    _isAnimating = true;
    _currentValue =
        _sliderAnimation.value; // Start from current animated position
    _targetValue = newValue;

    _sliderAnimation = Tween<double>(
      begin: _currentValue,
      end: _targetValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _controller.reset();

    // FIXED: Don't await the animation - let it run in background
    // This allows immediate user interaction
    _controller.forward().then((_) {
      _isAnimating = false;
      _currentValue = _targetValue;
    });

    // FIXED: Allow user interaction after just a tiny delay to avoid conflicts
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Update value immediately without animation (for user interactions)
  void setValueImmediate(double value) {
    // FIXED: Stop any ongoing animation immediately
    if (_isAnimating) {
      _controller.stop();
      _isAnimating = false;
    }

    _currentValue = value;
    _targetValue = value;
    _sliderAnimation = Tween<double>(
      begin: value,
      end: value,
    ).animate(_controller);
    _controller.reset();
  }

  /// Dispose of the animation controller
  void dispose() {
    _controller.dispose();
  }
}
