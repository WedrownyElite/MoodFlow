import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data/mood_data_service.dart';
import '../services/ui/mood_gradient_service.dart';
import '../services/animation/blur_transition_service.dart';
import '../services/animation/slider_animation_service.dart';
import '../widgets/animated_mood_slider.dart';
import '../services/notifications/enhanced_notification_service.dart';
import '../services/utils/logger.dart';

class MoodLogScreen extends StatefulWidget {
  final bool useCustomGradient;
  final bool isDarkMode;
  final int? initialSegment;
  final String? timeSegment;

  const MoodLogScreen({
    super.key,
    required this.useCustomGradient,
    required this.isDarkMode,
    this.initialSegment,
    this.timeSegment,
  });

  @override
  State<MoodLogScreen> createState() => _MoodLogScreenState();
}

class _MoodLogScreenState extends State<MoodLogScreen> with TickerProviderStateMixin {
  final List<String> timeSegments = MoodDataService.timeSegments;
  int currentSegment = 0;

  late PageController _pageController;
  late AnimationController _gradientAnimationController;
  late BlurTransitionService _blurService;
  late SliderAnimationService _sliderService;

  // Store values in memory only during the session
  final Map<int, double> _sessionMoodValues = {};
  final Map<int, TextEditingController> _noteControllers = {};
  final Map<int, bool> _accessibilityCache = {};

  LinearGradient? _currentGradient;
  Animation<LinearGradient>? _gradientAnimation;

  bool _isInitialLoading = true;
  Timer? _debounceTimer;
  Timer? _saveDebounceTimer;

  @override
  void initState() {
    super.initState();

    // Initialize controllers for all segments first
    for (int i = 0; i < timeSegments.length; i++) {
      _noteControllers[i] = TextEditingController();
      _sessionMoodValues[i] = 5.0; // Default value
    }

    // Determine the correct starting segment synchronously
    _initializeCorrectSegment();
  }

  void _initializeCorrectSegment() {
    if (widget.initialSegment != null) {
      currentSegment = widget.initialSegment!;
    } else {
      currentSegment = _getHighestAccessibleSegmentSync();
    }

    _initializeServicesSync();
    _initializeAsync();
  }

  int _getHighestAccessibleSegmentSync() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    const defaultMiddayMinutes = 13 * 60; // 1 PM
    const defaultEveningMinutes = 19 * 60; // 7 PM

    if (currentMinutes >= defaultEveningMinutes) return 2; // Evening
    if (currentMinutes >= defaultMiddayMinutes) return 1;  // Midday
    return 0; // Morning
  }

  void _initializeServicesSync() {
    _pageController = PageController(initialPage: currentSegment);

    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? currentSegment;
      if (!_canAccessSegment(page)) {
        _pageController.jumpToPage(currentSegment);
      }
    });

    _blurService = BlurTransitionService(vsync: this);

    _sliderService = SliderAnimationService(
      vsync: this,
      initialValue: _sessionMoodValues[currentSegment] ?? 5.0,
    );

    _gradientAnimationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500)
    );
    _gradientAnimationController.addListener(() {
      if (mounted) setState(() {});
    });

    _initGradientSync();
  }

  Future<void> _initializeAsync() async {
    await _loadAllAccessibility();

    int highestAccessible = 0;
    for (int i = 2; i >= 0; i--) {
      if (_accessibilityCache[i] == true) {
        highestAccessible = i;
        break;
      }
    }

    if (highestAccessible > currentSegment && (_accessibilityCache[highestAccessible] ?? false)) {
      currentSegment = highestAccessible;
      if (mounted) {
        _pageController.jumpToPage(currentSegment);
      }
    }

    // Load all data fresh from storage
    await _loadAllDataFresh();

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });

      if (widget.useCustomGradient) {
        _updateGradientForMood(_sessionMoodValues[currentSegment] ?? 5.0);
      }

      final savedMoodValue = _sessionMoodValues[currentSegment] ?? 5.0;
      _sliderService.setValueImmediate(savedMoodValue);
    }
  }

  /// Load all data fresh from storage to ensure accuracy
  Future<void> _loadAllDataFresh() async {
    Logger.moodService('🔄 Loading all mood data fresh from storage...');

    for (int i = 0; i < timeSegments.length; i++) {
      if (_accessibilityCache[i] == true) {
        await _loadDataForSegmentFresh(i);
      }
    }

    Logger.moodService('✅ Fresh data loading complete');
  }

  /// Always load fresh data from storage
  Future<void> _loadDataForSegmentFresh(int segment) async {
    try {
      Logger.moodService('📖 Loading fresh data for segment $segment...');

      // Always load fresh from storage, no cache
      final moodData = await MoodDataService.loadMood(DateTime.now(), segment);

      final rating = (moodData?['rating'] ?? 5).toDouble();
      final note = (moodData?['note'] ?? '');

      // Update session values
      _sessionMoodValues[segment] = rating;
      _noteControllers[segment]?.text = note;

      Logger.moodService('✅ Loaded segment $segment: rating=$rating, note="$note"');
    } catch (e) {
      Logger.moodService('❌ Error loading segment $segment: $e');
      // Set defaults on error
      _sessionMoodValues[segment] = 5.0;
      _noteControllers[segment]?.text = '';
    }
  }

  Future<void> _loadAllAccessibility() async {
    for (int i = 0; i < timeSegments.length; i++) {
      final canAccess = await _canAccessSegmentAsync(i);
      _accessibilityCache[i] = canAccess;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _saveDebounceTimer?.cancel();
    _pageController.dispose();

    for (final controller in _noteControllers.values) {
      controller.dispose();
    }

    _gradientAnimationController.dispose();
    _blurService.dispose();
    _sliderService.dispose();
    super.dispose();
  }

  bool _canAccessSegment(int index) {
    return _accessibilityCache[index] ?? false;
  }

  Future<bool> _canAccessSegmentAsync(int index) async {
    final settings = await EnhancedNotificationService.loadSettings();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    switch (index) {
      case 0:
        return true;
      case 1:
        final middayMinutes = settings.middayTime.hour * 60 + settings.middayTime.minute;
        return currentMinutes >= middayMinutes;
      case 2:
        final eveningMinutes = settings.eveningTime.hour * 60 + settings.eveningTime.minute;
        return currentMinutes >= eveningMinutes;
      default:
        return false;
    }
  }

  /// FIXED: Improved save process with immediate verification
  Future<void> _saveMoodData(int segment) async {
    final moodValue = _sessionMoodValues[segment] ?? 5.0;
    final noteText = _noteControllers[segment]?.text ?? '';

    Logger.moodService('💾 Saving mood data for segment $segment: rating=$moodValue, note="$noteText"');

    try {
      final success = await MoodDataService.saveMood(DateTime.now(), segment, moodValue, noteText);

      if (success) {
        Logger.moodService('✅ Mood saved successfully for segment $segment');

        if (widget.useCustomGradient && segment == currentSegment) {
          _updateGradientForMood(moodValue);
        }
      } else {
        Logger.moodService('❌ Failed to save mood for segment $segment');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save mood. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Logger.moodService('❌ Error saving mood for segment $segment: $e');
    }
  }

  void _initGradientSync() {
    final gradient = MoodGradientService.fallbackGradient(widget.isDarkMode);
    _currentGradient = gradient;
    _gradientAnimation = Tween<LinearGradient>(begin: gradient, end: gradient).animate(_gradientAnimationController);

    if (widget.useCustomGradient) {
      _initGradient();
    }
  }

  void _initGradient() async {
    if (widget.useCustomGradient) {
      final moodValue = _sessionMoodValues[currentSegment] ?? 5.0;
      final gradient = await MoodGradientService.computeGradientForMood(moodValue, currentSegment);
      if (mounted) {
        setState(() {
          _currentGradient = gradient;
          _gradientAnimation = Tween<LinearGradient>(begin: gradient, end: gradient).animate(_gradientAnimationController);
        });
      }
    }
  }

  void _updateGradientForMood(double mood) async {
    if (!widget.useCustomGradient) return;
    final newGradient = await MoodGradientService.computeGradientForMood(mood, currentSegment);
    _gradientAnimation = LinearGradientTween(
      begin: _currentGradient ?? newGradient,
      end: newGradient,
    ).animate(_gradientAnimationController);
    _gradientAnimationController.reset();
    _gradientAnimationController.forward();
    _currentGradient = newGradient;
  }

  /// FIXED: Improved navigation with fresh data loading
  Future<void> _navigateToSegment(int newIndex) async {
    final canAccess = await _canAccessSegmentAsync(newIndex);
    if (!canAccess || _blurService.isTransitioning) return;

    Logger.moodService('🔄 Navigating to segment $newIndex');

    await _blurService.executeTransition(() async {
      setState(() {
        currentSegment = newIndex;
      });
      _pageController.jumpToPage(newIndex);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    // Always load fresh data when navigating
    await _loadDataForSegmentFresh(newIndex);

    final newMoodValue = _sessionMoodValues[newIndex] ?? 5.0;
    await _sliderService.animateToValue(newMoodValue);

    if (widget.useCustomGradient) {
      _updateGradientForMood(newMoodValue);
    }

    if (mounted) {
      setState(() {});
    }
  }

  int _getFirstAccessibleSegment() {
    for (int i = 0; i < timeSegments.length; i++) {
      if (_accessibilityCache[i] == true) {
        return i;
      }
    }
    return 0;
  }

  int _getLastAccessibleSegment() {
    for (int i = timeSegments.length - 1; i >= 0; i--) {
      if (_accessibilityCache[i] == true) {
        return i;
      }
    }
    return 0;
  }

  Widget _buildMoodPage(int index) {
    final canEdit = index == currentSegment && (_accessibilityCache[index] ?? false);

    final noteController = _noteControllers[index]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${timeSegments[index]} Mood',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Text(
            'How are you feeling?',
            style: TextStyle(fontSize: 18, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('😢', style: TextStyle(fontSize: 22)),
              Text('😐', style: TextStyle(fontSize: 22)),
              Text('😊', style: TextStyle(fontSize: 22)),
            ],
          ),
          IgnorePointer(
            ignoring: _blurService.isTransitioning,
            child: AnimatedMoodSlider(
              sliderService: _sliderService,
              enabled: canEdit,
              onChanged: (value) {
                // FIXED: Update session value immediately
                _sessionMoodValues[index] = value;

                if (widget.useCustomGradient && index == currentSegment) {
                  _updateGradientForMood(value);
                }
              },
              onChangeEnd: canEdit ? (value) {
                // FIXED: Save with debouncing to avoid excessive saves
                _saveDebounceTimer?.cancel();
                _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                  _saveMoodData(index);
                });
              } : null,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Notes',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(minHeight: 150),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: canEdit
                ? IgnorePointer(
              ignoring: _blurService.isTransitioning,
              child: TextField(
                controller: noteController,
                maxLines: null,
                minLines: 8,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Write your thoughts here...'),
                onChanged: (text) {
                  // FIXED: Save notes with debouncing
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
                    _saveMoodData(index);
                  });
                },
              ),
            )
                : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: noteController.text.isEmpty
                  ? const SizedBox.shrink()
                  : Text(noteController.text, style: const TextStyle(color: Colors.black87)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientAnimation?.value ??
        _currentGradient ??
        MoodGradientService.fallbackGradient(widget.isDarkMode);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Log Mood'),
        leading: BackButton(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: gradient),
            child: Padding(
              padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top),
              child: Column(
                children: [
                  Expanded(
                    child: BlurTransitionWidget(
                      blurService: _blurService,
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: timeSegments.length,
                        onPageChanged: (newIndex) async {
                          if (!_canAccessSegment(newIndex)) {
                            _pageController.jumpToPage(currentSegment);
                            return;
                          }

                          setState(() => _isInitialLoading = true);

                          // FIXED: Load fresh data when page changes
                          await _loadDataForSegmentFresh(newIndex);

                          setState(() {
                            currentSegment = newIndex;
                            _isInitialLoading = false;
                          });

                          final newMoodValue = _sessionMoodValues[newIndex] ?? 5.0;
                          await _sliderService.animateToValue(newMoodValue);

                          if (widget.useCustomGradient) {
                            _updateGradientForMood(newMoodValue);
                          }
                        },
                        itemBuilder: (context, index) {
                          return _buildMoodPage(index);
                        },
                      ),
                    ),
                  ),
                  BlurTransitionWidget(
                    blurService: _blurService,
                    child: Container(
                      color: Colors.black.withAlpha(50),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (currentSegment > _getFirstAccessibleSegment())
                            IconButton(
                              icon: const Icon(Icons.arrow_left, color: Colors.white, size: 32),
                              onPressed: _blurService.isTransitioning ? null : () {
                                for (int i = currentSegment - 1; i >= 0; i--) {
                                  if (_accessibilityCache[i] == true) {
                                    _navigateToSegment(i);
                                    break;
                                  }
                                }
                              },
                            )
                          else
                            const SizedBox(width: 48),
                          Text(
                            timeSegments[currentSegment],
                            style: const TextStyle(fontSize: 20, color: Colors.white),
                          ),
                          if (currentSegment < _getLastAccessibleSegment())
                            IconButton(
                              icon: const Icon(Icons.arrow_right, color: Colors.white, size: 32),
                              onPressed: _blurService.isTransitioning ? null : () {
                                for (int i = currentSegment + 1; i < timeSegments.length; i++) {
                                  if (_accessibilityCache[i] == true) {
                                    _navigateToSegment(i);
                                    break;
                                  }
                                }
                              },
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isInitialLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}