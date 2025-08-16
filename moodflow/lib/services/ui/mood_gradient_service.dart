import 'package:flutter/material.dart';
import '../data/mood_data_service.dart';

class MoodGradientService {
  static const List<String> timeSegments = MoodDataService.timeSegments;

  /// Determine if a segment is accessible based on hour
  static bool canAccessSegment(int index, DateTime now) {
    if (index == 0) return true;
    if (index == 1) return now.hour >= 12;
    if (index == 2) return now.hour >= 18;
    return false;
  }

  /// Compute average mood from accessible segments and generate gradient
  static Future<LinearGradient> computeGradientForMood(double currentMood, int currentSegment) async {
    final now = DateTime.now();
    final List<double> moods = [];

    for (int i = 0; i < timeSegments.length; i++) {
      if (canAccessSegment(i, now)) {
        final moodData = await MoodDataService.loadMood(now, i);
        if (moodData != null && moodData['rating'] is num) {
          moods.add(moodData['rating'].toDouble());
        } else {
          moods.add(5.0); // default neutral mood if no data yet
        }
      }
    }

    // Find the index of currentSegment within accessible segments
    final accessibleIndices = List<int>.generate(timeSegments.length, (i) => i).where((i) => canAccessSegment(i, now)).toList();
    final segmentPos = accessibleIndices.indexOf(currentSegment);
    if (segmentPos != -1) {
      moods[segmentPos] = currentMood;
    }

    final avg = moods.reduce((a, b) => a + b) / moods.length;
    return _gradientFromNormalizedT((avg - 1) / 9);
  }

  /// Gradient helper
  static LinearGradient _gradientFromNormalizedT(double t) {
    Color lerpColor(Color a, Color b, double t) {
      return Color.fromARGB(
        (a.alpha + (b.alpha - a.alpha) * t).round(),
        (a.red + (b.red - a.red) * t).round(),
        (a.green + (b.green - a.green) * t).round(),
        (a.blue + (b.blue - a.blue) * t).round(),
      );
    }

    final black = const Color(0xFF000000);
    final orange = Colors.orange.shade700;
    final yellow = Colors.yellow.shade600;
    final green = Colors.green.shade600;

    if (t <= 0.5) {
      final localT = t / 0.5;
      return LinearGradient(
        colors: [lerpColor(black, orange, localT), orange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      final localT = (t - 0.5) / 0.5;
      final start = lerpColor(orange, yellow, localT);
      final end = lerpColor(yellow, green, localT);
      return LinearGradient(
        colors: [start, end],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  /// Fallback gradient for no moods available
  static LinearGradient fallbackGradient(bool isDarkMode) {
    return isDarkMode
        ? const LinearGradient(colors: [Color(0xFF121212), Color(0xFF1E1E1E)])
        : const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF90CAF9)]);
  }
}

class LinearGradientTween extends Tween<LinearGradient> {
  LinearGradientTween({required LinearGradient begin, required LinearGradient end}) : super(begin: begin, end: end);

  @override
  LinearGradient lerp(double t) {
    final begin = this.begin!;
    final end = this.end!;

    List<Color> lerpColors() {
      final beginColors = begin.colors;
      final endColors = end.colors;
      final length = beginColors.length;

      // Assume both gradients have the same number of colors
      return List.generate(length, (i) => Color.lerp(beginColors[i], endColors[i], t) ?? beginColors[i]);
    }

    List<double>? lerpStops() {
      if (begin.stops == null || end.stops == null) return null;
      final length = begin.stops!.length;
      return List.generate(length, (i) => lerpDouble(begin.stops![i], end.stops![i], t) ?? begin.stops![i]);
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