import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data/mood_trends_service.dart';
import '../services/data/mood_data_service.dart';

enum StreakCalculationMode {
  strict,   // Must log on actual day
  lenient,  // Allows backfilling
  both,     // Show both types
}

class MoodStatisticsCards extends StatefulWidget {
  final MoodStatistics statistics;

  const MoodStatisticsCards({super.key, required this.statistics});

  @override
  State<MoodStatisticsCards> createState() => _MoodStatisticsCardsState();
}

class _MoodStatisticsCardsState extends State<MoodStatisticsCards> {
  StreakCalculationMode _streakMode = StreakCalculationMode.both;
  int _liveStreak = 0;
  int _completionStreak = 0;
  bool _isLoadingStreaks = true;

  @override
  void initState() {
    super.initState();
    _loadStreakPreference();
    _calculateDetailedStreaks();
  }

  Future<void> _loadStreakPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('streak_calculation_mode') ?? StreakCalculationMode.both.index;
    setState(() {
      _streakMode = StreakCalculationMode.values[modeIndex];
    });
  }

  Future<void> _saveStreakPreference(StreakCalculationMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streak_calculation_mode', mode.index);
    setState(() {
      _streakMode = mode;
    });
  }

  Future<void> _calculateDetailedStreaks() async {
    setState(() => _isLoadingStreaks = true);

    int liveStreak = 0;
    int completionStreak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate streaks by going backwards from today
    DateTime currentDate = today;
    bool liveBroken = false;
    bool completionBroken = false;

    // Check up to 365 days back
    for (int i = 0; i < 365; i++) {
      bool hasAnyMood = false;
      bool wasLoggedOnTime = false;

      // Check all segments for this day
      for (int segment = 0; segment < 3; segment++) {
        final moodData = await MoodDataService.loadMood(currentDate, segment);
        if (moodData != null && moodData['rating'] != null) {
          hasAnyMood = true;

          // Check if this was logged on time
          if (await MoodDataService.wasMoodLoggedOnTime(currentDate, segment)) {
            wasLoggedOnTime = true;
          }
        }
      }

      if (hasAnyMood) {
        // Update completion streak (allows backfilling)
        if (!completionBroken) {
          completionStreak++;
        }

        // Update live streak (must be logged on time)
        if (!liveBroken && wasLoggedOnTime) {
          liveStreak++;
        } else if (!liveBroken) {
          liveBroken = true;
        }
      } else {
        // No mood data for this day - break both streaks
        liveBroken = true;
        completionBroken = true;
      }

      // If both streaks are broken, we can stop
      if (liveBroken && completionBroken) {
        break;
      }

      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    setState(() {
      _liveStreak = liveStreak;
      _completionStreak = completionStreak;
      _isLoadingStreaks = false;
    });
  }

  void _showStreakSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildStreakSettingsSheet(),
    );
  }

  Widget _buildStreakSettingsSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Streak Calculation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Choose how you want streaks to be calculated:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 24),

          // Streak options
          RadioListTile<StreakCalculationMode>(
            title: const Text('Strict Mode'),
            subtitle: const Text('Must log moods on the actual day (within 6 hours)'),
            value: StreakCalculationMode.strict,
            groupValue: _streakMode,
            onChanged: (value) {
              if (value != null) {
                _saveStreakPreference(value);
                Navigator.of(context).pop();
              }
            },
          ),

          RadioListTile<StreakCalculationMode>(
            title: const Text('Lenient Mode'),
            subtitle: const Text('Allows backfilling missed days'),
            value: StreakCalculationMode.lenient,
            groupValue: _streakMode,
            onChanged: (value) {
              if (value != null) {
                _saveStreakPreference(value);
                Navigator.of(context).pop();
              }
            },
          ),

          RadioListTile<StreakCalculationMode>(
            title: const Text('Show Both'),
            subtitle: const Text('Display both strict and lenient streaks'),
            value: StreakCalculationMode.both,
            groupValue: _streakMode,
            onChanged: (value) {
              if (value != null) {
                _saveStreakPreference(value);
                Navigator.of(context).pop();
              }
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    if (_isLoadingStreaks) {
      return _buildStatCard(
        title: 'Current Streak',
        value: '...',
        subtitle: 'calculating',
        icon: Icons.local_fire_department,
        color: Colors.orange.shade600,
        onTap: _showStreakSettings,
      );
    }

    switch (_streakMode) {
      case StreakCalculationMode.strict:
        return _buildStatCard(
          title: 'Live Streak',
          value: '$_liveStreak',
          subtitle: _liveStreak == 1 ? 'day (strict)' : 'days (strict)',
          icon: Icons.local_fire_department,
          color: Colors.orange.shade600,
          onTap: _showStreakSettings,
        );

      case StreakCalculationMode.lenient:
        return _buildStatCard(
          title: 'Current Streak',
          value: '$_completionStreak',
          subtitle: _completionStreak == 1 ? 'day (lenient)' : 'days (lenient)',
          icon: Icons.local_fire_department,
          color: Colors.orange.shade600,
          onTap: _showStreakSettings,
        );

      case StreakCalculationMode.both:
        return _buildDualStreakCard();
    }
  }

  Widget _buildDualStreakCard() {
    return GestureDetector(
      onTap: _showStreakSettings,
      child: Card(
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.orange.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Current Streaks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Icon(Icons.settings, size: 16, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 12),

              // Live streak
              Row(
                children: [
                  Text(
                    '🔥 $_liveStreak',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _liveStreak == 1 ? 'day (live)' : 'days (live)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Completion streak
              Row(
                children: [
                  Text(
                    '✅ $_completionStreak',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _completionStreak == 1 ? 'day (total)' : 'days (total)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Tap to change calculation mode',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Top row - Streaks and Days Logged
          Row(
            children: [
              Expanded(child: _buildStreakCard()),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Days Logged',
                  value: '${widget.statistics.daysLogged}',
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
            value: widget.statistics.overallAverage > 0
                ? widget.statistics.overallAverage.toStringAsFixed(1)
                : '-',
            subtitle: _getMoodDescription(widget.statistics.overallAverage),
            icon: Icons.sentiment_satisfied,
            color: _getMoodColor(widget.statistics.overallAverage),
            isWide: true,
          ),
          const SizedBox(height: 12),

          // Bottom row - Best/Worst days
          if (widget.statistics.bestDay != null && widget.statistics.worstDay != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Best Day',
                    value: DateFormat('MMM d').format(widget.statistics.bestDay!),
                    subtitle: '${widget.statistics.bestDayMood!.toStringAsFixed(1)} 😊',
                    icon: Icons.trending_up,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Toughest Day',
                    value: DateFormat('MMM d').format(widget.statistics.worstDay!),
                    subtitle: '${widget.statistics.worstDayMood!.toStringAsFixed(1)} 💪',
                    icon: Icons.trending_down,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Time of day insights
          if (widget.statistics.timeSegmentAverages.isNotEmpty)
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
    VoidCallback? onTap,
  }) {
    Widget cardContent = Container(
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
              if (onTap != null)
                Icon(Icons.settings, size: 16, color: Colors.grey.shade500),
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
    );

    if (onTap != null) {
      return Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: cardContent,
        ),
      );
    } else {
      return Card(
        elevation: 2,
        child: cardContent,
      );
    }
  }

  Widget _buildTimeOfDayInsight() {
    final bestSegment = widget.statistics.bestTimeSegment;
    final segments = MoodDataService.timeSegments;
    final bestAverage = widget.statistics.timeSegmentAverages[bestSegment] ?? 0;

    String insightText;
    IconData insightIcon;
    Color insightColor;
    Color textColor;

    switch (bestSegment) {
      case 0: // Morning
        insightText = "You're brightest in the morning! ☀️";
        insightIcon = Icons.wb_sunny;
        insightColor = Colors.orange.shade600;
        textColor = const Color.fromARGB(255, 160, 73, 1);
        break;
      case 1: // Midday
        insightText = "Midday energy is your strength! ⚡";
        insightIcon = Icons.flash_on;
        insightColor = Colors.blue.shade600;
        textColor = Colors.blue.shade700;
        break;
      case 2: // Evening
        insightText = "Evenings bring out your best! 🌙";
        insightIcon = Icons.nights_stay;
        insightColor = Colors.purple.shade600;
        textColor = Colors.purple.shade700;
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
    final intensity = (mood - 1) / 9;

    if (intensity < 0.3) {
      return Colors.red.shade600;
    } else if (intensity < 0.7) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }
}