import 'package:flutter/material.dart';
import '../data/mood_data_service.dart';
import '../notifications/enhanced_notification_service.dart';

class MoodGradientService {
  static const List<String> timeSegments = MoodDataService.timeSegments;

  /// Determine if a segment is accessible based on hour
  static Future<bool> canAccessSegment(int index, DateTime now) async {
    final settings = await EnhancedNotificationService.loadSettings();
    final currentMinutes = now.hour * 60 + now.minute;

    switch (index) {
      case 0: // Morning - always accessible from midnight
        return true;
      case 1: // Midday - accessible after user's midday time
        final middayMinutes =
            settings.middayTime.hour * 60 + settings.middayTime.minute;
        return currentMinutes >= middayMinutes;
      case 2: // Evening - accessible after user's evening time
        final eveningMinutes =
            settings.eveningTime.hour * 60 + settings.eveningTime.minute;
        return currentMinutes >= eveningMinutes;
      default:
        return false;
    }
  }

  /// Compute average mood from accessible segments and generate gradient
  static Future<LinearGradient> computeGradientForMood(
      double currentMood, int currentSegment) async {
    final now = DateTime.now();
    final List<double> moods = [];

    for (int i = 0; i < timeSegments.length; i++) {
      if (await canAccessSegment(i, now)) {
        final moodData = await MoodDataService.loadMood(now, i);
        if (moodData != null && moodData['rating'] is num) {
          moods.add(moodData['rating'].toDouble());
        } else {
          moods.add(5.0); // default neutral mood if no data yet
        }
      }
    }

    // Find the index of currentSegment within accessible segments
    final accessibleIndices = <int>[];
    for (int i = 0; i < timeSegments.length; i++) {
      if (await canAccessSegment(i, now)) {
        accessibleIndices.add(i);
      }
    }

    final segmentPos = accessibleIndices.indexOf(currentSegment);
    if (segmentPos != -1 && segmentPos < moods.length) {
      moods[segmentPos] = currentMood;
    }

    final avg = moods.reduce((a, b) => a + b) / moods.length;
    return _gradientFromNormalizedT((avg - 1) / 9);
  }

  /// Improved gradient helper with smooth color transitions
  static LinearGradient _gradientFromNormalizedT(double t) {
    // Clamp t to ensure it's between 0 and 1
    t = t.clamp(0.0, 1.0);

    // Define the color progression points (more muted colors)
    final veryDark =
        const Color(0xFF2C1810); // Very dark brown for lowest moods
    final darkRed = const Color(0xFF8B4513); // Dark reddish-brown
    final orange = Colors.orange.shade700; // Orange
    final yellow = Colors.yellow.shade600; // Yellow
    final lightGreen = Colors.green.shade400; // Light green
    final green = Colors.green.shade600; // Regular green
    final darkGreen = Colors.green.shade800; // Dark green

    // Always create a gradient with two distinct colors
    Color startColor;
    Color endColor;

    if (t <= 0.2) {
      // Very low mood (0-2): dark to dark red
      startColor = Color.lerp(veryDark, darkRed, t / 0.2)!;
      endColor = darkRed;
    } else if (t <= 0.4) {
      // Low mood (2-4): dark red to orange
      startColor = Color.lerp(darkRed, orange, (t - 0.2) / 0.2)!;
      endColor = orange;
    } else if (t <= 0.6) {
      // Neutral mood (4-6): orange to yellow
      startColor = Color.lerp(orange, yellow, (t - 0.4) / 0.2)!;
      endColor = yellow;
    } else if (t <= 0.8) {
      // Good mood (6-8): yellow to light green
      startColor = Color.lerp(yellow, lightGreen, (t - 0.6) / 0.2)!;
      endColor = lightGreen;
    } else {
      // Great mood (8-10): light green to green, with dark green accent
      final progress = (t - 0.8) / 0.2;
      startColor = Color.lerp(lightGreen, green, progress)!;
      // For the end color, blend green with a hint of dark green/yellow
      final hintColor =
          Color.lerp(darkGreen, yellow, 0.3)!; // 30% yellow, 70% dark green
      endColor = Color.lerp(green, hintColor, progress * 0.4)!; // Subtle hint
    }

    return LinearGradient(
      colors: [startColor, endColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Fallback gradient for no moods available
  static LinearGradient fallbackGradient(bool isDarkMode) {
    return isDarkMode
        ? const LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF1E1E1E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF90CAF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
  }
}

class LinearGradientTween extends Tween<LinearGradient> {
  LinearGradientTween(
      {required LinearGradient begin, required LinearGradient end})
      : super(begin: begin, end: end);

  @override
  LinearGradient lerp(double t) {
    final begin = this.begin!;
    final end = this.end!;

    List<Color> lerpColors() {
      final beginColors = begin.colors;
      final endColors = end.colors;
      final maxLength = beginColors.length > endColors.length
          ? beginColors.length
          : endColors.length;

      return List.generate(maxLength, (i) {
        final beginColor =
            i < beginColors.length ? beginColors[i] : beginColors.last;
        final endColor = i < endColors.length ? endColors[i] : endColors.last;
        return Color.lerp(beginColor, endColor, t) ?? beginColor;
      });
    }

    List<double>? lerpStops() {
      if (begin.stops == null || end.stops == null) return null;
      final beginStops = begin.stops!;
      final endStops = end.stops!;
      final maxLength = beginStops.length > endStops.length
          ? beginStops.length
          : endStops.length;

      return List.generate(maxLength, (i) {
        final beginStop =
            i < beginStops.length ? beginStops[i] : beginStops.last;
        final endStop = i < endStops.length ? endStops[i] : endStops.last;
        return lerpDouble(beginStop, endStop, t) ?? beginStop;
      });
    }

    AlignmentGeometry lerpAlignment(AlignmentGeometry a, AlignmentGeometry b) {
      if (a is Alignment && b is Alignment) {
        return Alignment.lerp(a, b, t) ?? a;
      }
      return a;
    }

    return LinearGradient(
      colors: lerpColors(),
      stops: lerpStops(),
      begin: lerpAlignment(begin.begin, end.begin),
      end: lerpAlignment(begin.end, end.end),
      tileMode: end.tileMode,
      transform: end.transform,
    );
  }

  double? lerpDouble(double? a, double? b, double t) {
    if (a == null || b == null) return a ?? b;
    return a + (b - a) * t;
  }
}
