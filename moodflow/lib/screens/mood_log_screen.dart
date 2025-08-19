import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data/mood_data_service.dart';
import '../services/ui/mood_gradient_service.dart';
import '../services/animation/blur_transition_service.dart';
import '../services/animation/slider_animation_service.dart';
import '../widgets/animated_mood_slider.dart';
import '../services/data/enhanced_notification_service.dart';

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

  // Cache all segment data
  final Map<int, double> _cachedMoodValues = {};
  final Map<int, TextEditingController> _cachedNoteControllers = {};
  final Map<int, bool> _accessibilityCache = {};

  LinearGradient? _currentGradient;
  LinearGradient? _targetGradient;
  Animation<LinearGradient>? _gradientAnimation;

  bool _isInitialLoading = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    // Initialize controllers for all segments first
    for (int i = 0; i < timeSegments.length; i++) {
      _cachedNoteControllers[i] = TextEditingController();
      _cachedMoodValues[i] = 5.0; // Default value
    }

    // FIXED: Initialize all services immediately (synchronously)
    _initializeServicesSync();

    // Then do async initialization
    _initializeCurrentSegment();
  }

  void _initializeServicesSync() {
    // Initialize current segment with a default value (will be updated async)
    currentSegment = 0;

    // Initialize page controller with default segment
    _pageController = PageController(initialPage: currentSegment);

    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? currentSegment;
      if (!_canAccessSegment(page)) {
        _pageController.jumpToPage(currentSegment);
      }
    });

    // Initialize blur transition service
    _blurService = BlurTransitionService(vsync: this);

    // Initialize slider animation service
    _sliderService = SliderAnimationService(
      vsync: this,
      initialValue: _cachedMoodValues[currentSegment] ?? 5.0,
    );

    // Gradient animation controller
    _gradientAnimationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500)
    );
    _gradientAnimationController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize gradient synchronously first
    _initGradientSync();
  }

  Future<void> _initializeCurrentSegment() async {
    // FIXED: Get the correct current segment based on time and accessibility
    final detectedSegment = await _getCurrentSegmentIndex();

    // FIXED: If initialSegment is provided (from notification), use that if accessible
    if (widget.initialSegment != null) {
      final requestedSegment = widget.initialSegment!;
      final canAccess = await _canAccessSegmentAsync(requestedSegment);
      if (canAccess) {
        currentSegment = requestedSegment;
      } else {
        currentSegment = detectedSegment;
      }
    } else {
      currentSegment = detectedSegment;
    }

    // Update page controller with the correct segment
    if (mounted) {
      _pageController.animateToPage(
        currentSegment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Preload all data
    _preloadAllData();
  }

  Future<void> _preloadAllData() async {
    // Load all segments' accessibility and data
    final loadFutures = <Future<void>>[];

    for (int i = 0; i < timeSegments.length; i++) {
      loadFutures.add(_loadAccessibilityAndDataForSegment(i));
    }

    await Future.wait(loadFutures);

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });

      // Update gradient with current segment's mood after loading
      if (widget.useCustomGradient) {
        _updateGradientForMood(_cachedMoodValues[currentSegment] ?? 5.0);
      }

      // FIXED: Animate slider to the saved mood value instead of jumping
      final savedMoodValue = _cachedMoodValues[currentSegment] ?? 5.0;
      await _sliderService.animateToValue(savedMoodValue);
    }
  }

  Future<void> _loadAccessibilityAndDataForSegment(int segment) async {
    // Check accessibility
    final canAccess = await _canAccessSegmentAsync(segment);
    _accessibilityCache[segment] = canAccess;

    // Load data only if accessible
    if (canAccess) {
      await _loadDataForSegment(segment);
    } else {
      // Set default values for inaccessible segments
      _cachedMoodValues[segment] = 5.0;
      _cachedNoteControllers[segment]?.text = '';
    }
  }

  Future<void> _loadDataForSegment(int segment) async {
    final moodData = await MoodDataService.loadMood(DateTime.now(), segment);

    _cachedMoodValues[segment] = (moodData?['rating'] ?? 5).toDouble();
    _cachedNoteControllers[segment]?.text = (moodData?['note'] ?? '');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pageController.dispose();

    // Dispose all controllers
    for (final controller in _cachedNoteControllers.values) {
      controller.dispose();
    }

    _gradientAnimationController.dispose();
    _blurService.dispose();
    _sliderService.dispose();
    super.dispose();
  }

  Future<int> _getCurrentSegmentIndex() async {
    final settings = await EnhancedNotificationService.loadSettings();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final middayMinutes = settings.middayTime.hour * 60 + settings.middayTime.minute;
    final eveningMinutes = settings.eveningTime.hour * 60 + settings.eveningTime.minute;

    // FIXED: Return the highest accessible segment
    if (currentMinutes >= eveningMinutes) return 2; // Evening
    if (currentMinutes >= middayMinutes) return 1;  // Midday
    return 0; // Morning
  }

  bool _canAccessSegment(int index) {
    // Use cached results from _accessibilityCache
    return _accessibilityCache[index] ?? false;
  }

  Future<bool> _canAccessSegmentAsync(int index) async {
    final settings = await EnhancedNotificationService.loadSettings();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    switch (index) {
      case 0: // Morning - always accessible from midnight
        return true;
      case 1: // Midday - accessible after user's midday time
        final middayMinutes = settings.middayTime.hour * 60 + settings.middayTime.minute;
        return currentMinutes >= middayMinutes;
      case 2: // Evening - accessible after user's evening time
        final eveningMinutes = settings.eveningTime.hour * 60 + settings.eveningTime.minute;
        return currentMinutes >= eveningMinutes;
      default:
        return false;
    }
  }

  Future<void> _saveMoodData(int segment) async {
    final moodValue = _cachedMoodValues[segment] ?? 5.0;
    final noteText = _cachedNoteControllers[segment]?.text ?? '';

    await MoodDataService.saveMood(DateTime.now(), segment, moodValue, noteText);

    if (widget.useCustomGradient && segment == currentSegment) {
      _updateGradientForMood(moodValue);
    }

    // FIXED: Trigger streak recalculation when mood is saved
    // This will update the statistics cards on other screens
    // We don't need to do anything here specifically, but the statistics
    // will be recalculated when the trends screen is next visited
  }

  void _initGradientSync() {
    // Initialize with fallback gradient immediately
    final gradient = MoodGradientService.fallbackGradient(widget.isDarkMode);
    _currentGradient = gradient;
    _targetGradient = gradient;
    _gradientAnimation = Tween<LinearGradient>(begin: gradient, end: gradient).animate(_gradientAnimationController);

    // Then asynchronously update if using custom gradient
    if (widget.useCustomGradient) {
      _initGradient();
    }
  }

  void _initGradient() async {
    if (widget.useCustomGradient) {
      final moodValue = _cachedMoodValues[currentSegment] ?? 5.0;
      final gradient = await MoodGradientService.computeGradientForMood(moodValue, currentSegment);
      if (mounted) {
        setState(() {
          _currentGradient = gradient;
          _targetGradient = gradient;
          _gradientAnimation = Tween<LinearGradient>(begin: gradient, end: gradient).animate(_gradientAnimationController);
        });
      }
    }
  }

  void _updateGradientForMood(double mood) async {
    if (!widget.useCustomGradient) return;
    final newGradient = await MoodGradientService.computeGradientForMood(mood, currentSegment);
    _targetGradient = newGradient;
    _gradientAnimation = LinearGradientTween(
      begin: _currentGradient ?? newGradient,
      end: newGradient,
    ).animate(_gradientAnimationController);
    _gradientAnimationController.reset();
    _gradientAnimationController.forward();
    _currentGradient = newGradient;
  }

  Future<void> _navigateToSegment(int newIndex) async {
    // Check accessibility first
    final canAccess = await _canAccessSegmentAsync(newIndex);
    if (!canAccess || _blurService.isTransitioning) return;

    // FIXED: Simplified blur transition to prevent getting stuck
    await _blurService.executeTransition(() async {
      // Do minimal work during blur - just switch the page
      setState(() {
        currentSegment = newIndex;
      });
      _pageController.jumpToPage(newIndex);

      // Small delay to let the page switch visually complete
      await Future.delayed(const Duration(milliseconds: 50));
    });

    // FIXED: Do heavy lifting AFTER blur transition completes
    // Load data for the new segment
    await _loadAccessibilityAndDataForSegment(newIndex);

    // Animate slider to new segment's mood value
    final newMoodValue = _cachedMoodValues[newIndex] ?? 5.0;
    await _sliderService.animateToValue(newMoodValue);

    // Update gradient
    if (widget.useCustomGradient) {
      _updateGradientForMood(newMoodValue);
    }

    // Ensure UI is properly updated after transition
    if (mounted) {
      setState(() {});
    }
  }

  // FIXED: Add method to get navigation bounds
  int _getFirstAccessibleSegment() {
    for (int i = 0; i < timeSegments.length; i++) {
      if (_accessibilityCache[i] == true) {
        return i;
      }
    }
    return 0; // Fallback to morning
  }

  int _getLastAccessibleSegment() {
    for (int i = timeSegments.length - 1; i >= 0; i--) {
      if (_accessibilityCache[i] == true) {
        return i;
      }
    }
    return 0; // Fallback to morning
  }

  Widget _buildMoodPage(int index) {
    final canEdit = index == currentSegment && (_accessibilityCache[index] ?? false);

    if (!_cachedMoodValues.containsKey(index) || !_cachedNoteControllers.containsKey(index)) {
      return const Center(child: CircularProgressIndicator());
    }

    final noteController = _cachedNoteControllers[index]!;

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
                _cachedMoodValues[index] = value;
                if (widget.useCustomGradient && index == currentSegment) {
                  _updateGradientForMood(value);
                }
              },
              onChangeEnd: canEdit ? (_) => _saveMoodData(index) : null,
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
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 800), () {
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
                          await _loadDataForSegment(newIndex);
                          setState(() {
                            currentSegment = newIndex;
                            _isInitialLoading = false;
                          });

                          // FIXED: Animate slider to the new segment's mood value
                          final newMoodValue = _cachedMoodValues[newIndex] ?? 5.0;
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
                          // FIXED: Use proper navigation bounds
                          if (currentSegment > _getFirstAccessibleSegment())
                            IconButton(
                              icon: const Icon(Icons.arrow_left, color: Colors.white, size: 32),
                              onPressed: _blurService.isTransitioning ? null : () {
                                // Find the previous accessible segment
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
                          // FIXED: Use proper navigation bounds
                          if (currentSegment < _getLastAccessibleSegment())
                            IconButton(
                              icon: const Icon(Icons.arrow_right, color: Colors.white, size: 32),
                              onPressed: _blurService.isTransitioning ? null : () {
                                // Find the next accessible segment
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

          // Initial loading overlay (only shown on app start)
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