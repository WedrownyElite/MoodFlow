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

  // Cache all segment data
  final Map<int, double> _cachedMoodValues = {};
  final Map<int, TextEditingController> _cachedNoteControllers = {};
  
  late PageController _pageController;
  late AnimationController _gradientAnimationController;
  late BlurTransitionService _blurService;
  late SliderAnimationService _sliderService;
  
  LinearGradient? _currentGradient;
  LinearGradient? _targetGradient;
  Animation<LinearGradient>? _gradientAnimation;

  bool _isInitialLoading = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    currentSegment = _getCurrentSegmentIndex();
    _pageController = PageController(initialPage: currentSegment);

    // Initialize controllers for all segments
    for (int i = 0; i < timeSegments.length; i++) {
      _cachedNoteControllers[i] = TextEditingController();
      _cachedMoodValues[i] = 5.0; // Default value
    }

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
    
    // Preload all data
    _preloadAllData();
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

  Future<void> _preloadAllData() async {
    // Load all accessible segments' data
    final loadFutures = <Future<void>>[];

    for (int i = 0; i < timeSegments.length; i++) {
      if (await _canAccessSegmentAsync(i)) {
        loadFutures.add(_loadDataForSegment(i));
      }
    }
    
    await Future.wait(loadFutures);
    
    setState(() {
      _isInitialLoading = false;
    });

    // Update gradient with current segment's mood after loading
    if (widget.useCustomGradient) {
      _updateGradientForMood(_cachedMoodValues[currentSegment] ?? 5.0);
    }
    
    // Initialize slider with current mood value
    _sliderService.setValueImmediate(_cachedMoodValues[currentSegment] ?? 5.0);
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

  int _getCurrentSegmentIndex() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 0;
    if (hour < 18) return 1;
    return 2;
  }

  bool _canAccessSegment(int index) {
    return true; // We'll implement async version
  }

  Future<bool> _canAccessSegmentAsync(int index) async {
    final settings = await EnhancedNotificationService.loadSettings();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    switch (index) {
      case 0: // Morning - always accessible
        return true;
      case 1: // Midday - accessible after midday time
        final middayMinutes = settings.middayTime.hour * 60 + settings.middayTime.minute;
        return currentMinutes >= middayMinutes;
      case 2: // Evening - accessible after evening time
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
  }

  void _initGradient() async {
    if (widget.useCustomGradient) {
      final moodValue = _cachedMoodValues[currentSegment] ?? 5.0;
      final gradient = await MoodGradientService.computeGradientForMood(moodValue, currentSegment);
      setState(() {
        _currentGradient = gradient;
        _targetGradient = gradient;
        _gradientAnimation = Tween<LinearGradient>(begin: gradient, end: gradient).animate(_gradientAnimationController);
      });
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
    if (!_canAccessSegment(newIndex) || _blurService.isTransitioning) return;
    
    await _blurService.executeTransition(() async {
      // Load data and switch page while blurred
      await _loadDataForSegment(newIndex);
      
      setState(() {
        currentSegment = newIndex;
      });
      
      _pageController.jumpToPage(newIndex);
      
      // Animate slider to new value after page switch
      final newMoodValue = _cachedMoodValues[newIndex] ?? 5.0;
      await _sliderService.animateToValue(newMoodValue);
      
      if (widget.useCustomGradient) {
        _updateGradientForMood(newMoodValue);
      }
    });
    
    // Ensure UI is properly updated after transition
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildMoodPage(int index) {
    final canEdit = index == currentSegment && _canAccessSegment(index);

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
                          if (widget.useCustomGradient) {
                            _updateGradientForMood(_cachedMoodValues[newIndex] ?? 5.0);
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
                          if (currentSegment > 0 && _canAccessSegment(currentSegment - 1))
                            IconButton(
                              icon: const Icon(Icons.arrow_left, color: Colors.white, size: 32),
                              onPressed: _blurService.isTransitioning ? null : () => _navigateToSegment(currentSegment - 1),
                            )
                          else
                            const SizedBox(width: 48),
                          Text(
                            timeSegments[currentSegment],
                            style: const TextStyle(fontSize: 20, color: Colors.white),
                          ),
                          if (currentSegment < timeSegments.length - 1 && _canAccessSegment(currentSegment + 1))
                            IconButton(
                              icon: const Icon(Icons.arrow_right, color: Colors.white, size: 32),
                              onPressed: _blurService.isTransitioning ? null : () => _navigateToSegment(currentSegment + 1),
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