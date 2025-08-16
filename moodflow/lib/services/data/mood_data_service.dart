import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MoodDataService {
  static const List<String> timeSegments = ['Morning', 'Midday', 'Evening'];

  /// Returns key for storing mood data
  static String getKeyForDateSegment(DateTime date, int segmentIndex) {
    final dateString = date.toIso8601String().substring(0, 10);
    return '${dateString}_${timeSegments[segmentIndex].toLowerCase()}';
  }

  /// Loads saved mood (rating + note) for given date and segment
  static Future<Map<String, dynamic>?> loadMood(DateTime date, int segmentIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final key = getKeyForDateSegment(date, segmentIndex);
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Saves mood (rating + note) for given date and segment
  static Future<void> saveMood(DateTime date, int segmentIndex, double rating, String note) async {
    final prefs = await SharedPreferences.getInstance();
    final key = getKeyForDateSegment(date, segmentIndex);
    final jsonData = jsonEncode({'rating': rating, 'note': note});
    await prefs.setString(key, jsonData);
  }
}