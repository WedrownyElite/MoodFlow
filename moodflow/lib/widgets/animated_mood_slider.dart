import 'package:flutter/material.dart';
import '../services/animation/slider_animation_service.dart';

/// Animated slider widget that uses SliderAnimationService
class AnimatedMoodSlider extends StatelessWidget {
  final SliderAnimationService sliderService;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const AnimatedMoodSlider({
    super.key,
    required this.sliderService,
    this.min = 1.0,
    this.max = 10.0,
    this.divisions = 9,
    this.enabled = true,
    this.onChanged,
    this.onChangeEnd,
  });

  /// Get emoji based on mood value (1-10)
  String _getMoodEmoji(double value) {
    final roundedValue = value.round();
    switch (roundedValue) {
      case 1:
        return '😭'; // Crying
      case 2:
        return '😢'; // Sad
      case 3:
        return '😔'; // Disappointed
      case 4:
        return '😕'; // Slightly sad
      case 5:
        return '😐'; // Neutral
      case 6:
        return '🙂'; // Slightly happy
      case 7:
        return '😊'; // Happy
      case 8:
        return '😄'; // Very happy
      case 9:
        return '😁'; // Excited
      case 10:
        return '🤩'; // Ecstatic
      default:
        return '😐'; // Default neutral
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sliderService.animation,
      builder: (context, child) {
        final currentValue = sliderService.value.clamp(min, max);
        final emoji = _getMoodEmoji(currentValue);
        final number = currentValue.round();
        
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            // Make the popup bigger
            valueIndicatorTextStyle: const TextStyle(
              fontSize: 18, // Larger text
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            // Make the popup bubble bigger
            valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
            // This is the key - enable the popup to show always when dragging
            showValueIndicator: ShowValueIndicator.onlyForDiscrete,
            // Customize colors
            valueIndicatorColor: Colors.black87,
          ),
          child: Slider(
            value: currentValue,
            min: min,
            max: max,
            divisions: divisions,
            label: '$emoji $number',
            onChanged: enabled && !sliderService.isAnimating
                ? (value) {
                    sliderService.setValueImmediate(value);
                    onChanged?.call(value);
                  }
                : null,
            onChangeEnd: enabled && !sliderService.isAnimating
                ? (value) {
                    onChangeEnd?.call(value);
                  }
                : null,
          ),
        );
      },
    );
  }
}