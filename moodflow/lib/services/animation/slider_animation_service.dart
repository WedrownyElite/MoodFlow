import 'package:flutter/material.dart';

class SliderAnimationService {
  late AnimationController _controller;
  late Animation<double> _sliderAnimation;
  double _currentValue = 5.0;
  double _targetValue = 5.0;
  bool _isAnimating = false;

  SliderAnimationService({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 600),
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
  }

  /// Get the current animated slider value
  double get value => _sliderAnimation.value;

  /// Check if slider is currently animating
  bool get isAnimating => _isAnimating;

  /// Get the animation for listening to changes
  Animation<double> get animation => _sliderAnimation;

  /// Animate slider to a new value
  Future<void> animateToValue(double newValue, {bool immediate = false}) async {
    if (immediate || newValue == _currentValue) {
      _currentValue = newValue;
      _targetValue = newValue;
      _sliderAnimation = Tween<double>(
        begin: newValue,
        end: newValue,
      ).animate(_controller);
      _controller.reset();
      return;
    }

    if (_isAnimating) {
      // If already animating, update the target and restart
      _controller.stop();
    }

    _isAnimating = true;
    _currentValue = _sliderAnimation.value; // Start from current animated position
    _targetValue = newValue;

    _sliderAnimation = Tween<double>(
      begin: _currentValue,
      end: _targetValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _controller.reset();
    await _controller.forward();
    
    _isAnimating = false;
    _currentValue = _targetValue;
  }

  /// Update value immediately without animation (for user interactions)
  void setValueImmediate(double value) {
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