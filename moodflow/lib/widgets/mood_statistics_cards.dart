import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data/mood_trends_service.dart';
import '../services/data/mood_data_service.dart';

class MoodStatisticsCards extends StatelessWidget {
  final MoodStatistics statistics;

  const MoodStatisticsCards({super.key, required this.statistics});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Top row - Main stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Current Streak',
                  value: '${statistics.currentStreak}',
                  subtitle: statistics.currentStreak == 1 ? 'day' : 'days',
                  icon: Icons.local_fire_department,
                  color: Colors.orange.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Days Logged',
                  value: '${statistics.daysLogged}',
                  subtitle: 'total',
                  icon: Icons.calendar_today,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Middle row - Average mood
          _buildStatCard(
            title: 'Average Mood',
            value: statistics.overallAverage > 0 ? statistics.overallAverage.toStringAsFixed(1) : '-',
            subtitle: _getMoodDescription(statistics.overallAverage),
            icon: Icons.sentiment_satisfied,
            color: _getMoodColor(statistics.overallAverage),
            isWide: true,
          ),
          const SizedBox(height: 12),
          
          // Bottom row - Best/Worst days
          if (statistics.bestDay != null && statistics.worstDay != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Best Day',
                    value: DateFormat('MMM d').format(statistics.bestDay!),
                    subtitle: '${statistics.bestDayMood!.toStringAsFixed(1)} 😊',
                    icon: Icons.trending_up,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Toughest Day',
                    value: DateFormat('MMM d').format(statistics.worstDay!),
                    subtitle: '${statistics.worstDayMood!.toStringAsFixed(1)} 💪',
                    icon: Icons.trending_down,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // Time of day insights
          if (statistics.timeSegmentAverages.isNotEmpty)
            _buildTimeOfDayInsight(),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isWide = false,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: isWide ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOfDayInsight() {
    final bestSegment = statistics.bestTimeSegment;
    final segments = MoodDataService.timeSegments;
    final bestAverage = statistics.timeSegmentAverages[bestSegment] ?? 0;

    String insightText;
    IconData insightIcon;
    Color insightColor;
    Color textColor; // Add text color variable

    switch (bestSegment) {
      case 0: // Morning
        insightText = "You're brightest in the morning! ☀️";
        insightIcon = Icons.wb_sunny;
        insightColor = Colors.orange.shade600;
        textColor = const Color.fromARGB(255, 160, 73, 1); // Darker orange for better contrast
        break;
      case 1: // Midday
        insightText = "Midday energy is your strength! ⚡";
        insightIcon = Icons.flash_on;
        insightColor = Colors.blue.shade600;
        textColor = Colors.blue.shade700; // Slightly darker blue
        break;
      case 2: // Evening
        insightText = "Evenings bring out your best! 🌙";
        insightIcon = Icons.nights_stay;
        insightColor = Colors.purple.shade600;
        textColor = Colors.purple.shade700; // Slightly darker purple
        break;
      default:
        insightText = "Keep tracking to find your patterns!";
        insightIcon = Icons.insights;
        insightColor = Colors.grey.shade600;
        textColor = Colors.grey.shade700;
    }

    return Card(
      elevation: 2,
      color: insightColor.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(insightIcon, color: insightColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Peak Time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insightText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${segments[bestSegment]} average: ${bestAverage.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMoodDescription(double mood) {
    if (mood == 0) return 'No data yet';
    if (mood < 3) return 'Tough times';
    if (mood < 5) return 'Getting by';
    if (mood < 7) return 'Pretty good';
    if (mood < 9) return 'Great vibes';
    return 'Amazing!';
  }

  Color _getMoodColor(double mood) {
    if (mood == 0) return Colors.grey;
    final intensity = (mood - 1) / 9; // Normalize to 0-1
    
    if (intensity < 0.3) {
      return Colors.red.shade600;
    } else if (intensity < 0.7) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }
}