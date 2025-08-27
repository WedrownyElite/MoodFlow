// lib/widgets/ai_coach_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ai/mood_coach_service.dart';

class AiCoachWidget extends StatefulWidget {
  const AiCoachWidget({super.key});

  @override
  State<AiCoachWidget> createState() => _AiCoachWidgetState();
}

class _AiCoachWidgetState extends State<AiCoachWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<CoachMessage> _messages = [];
  bool _isTyping = false;
  bool _isEnabled = false;
  bool _disclaimerAccepted = false;

  @override
  void initState() {
    super.initState();
    _initializeCoach();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeCoach() async {
    final isEnabled = await MoodCoachService.isCoachEnabled();
    final disclaimerAccepted = await MoodCoachService.isDisclaimerAccepted();

    setState(() {
      _isEnabled = isEnabled;
      _disclaimerAccepted = disclaimerAccepted;
    });

    if (isEnabled) {
      final welcomeMessage = await MoodCoachService.getWelcomeMessage();
      if (welcomeMessage != null && mounted) {
        setState(() {
          _messages.add(welcomeMessage);
        });
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = CoachMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await MoodCoachService.processUserMessage(text);

      if (mounted) {
        setState(() {
          _messages.add(response);
          _isTyping = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(CoachMessage(
            id: 'error_${DateTime.now().millisecondsSinceEpoch}',
            text: 'I\'m having trouble connecting right now. Please try again in a moment.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEnabled || !_disclaimerAccepted) {
      return _buildSetupCard();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 500, // Increased height for better chat experience
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.psychology,
                size: 48,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI Mood Coach',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get personalized insights and support from your AI mood coach. Analyze patterns, receive recommendations, and have conversations about your mental wellbeing.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _setupAiCoach(),
              icon: const Icon(Icons.smart_toy),
              label: const Text('Setup AI Coach'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
          children: [
      Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.psychology,
        color: Colors.blue,
        size: 20,
      ),
    ),
    const SizedBox(width: 12),
    const Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Your AI Mood Coach',
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    ),
    ),
    Text(
    'AI-powered insights, not professional advice',
    style: TextStyle(
    fontSize: 12,
    color: Colors.grey,
    ),
    ),
    ],
    ),
    ),
    Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
    color: Colors.green.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
    Container(
    width: 6,
    height: 6,
    decoration: const BoxDecoration(
    color: Colors.green,
    shape: BoxShape.circle,
    ),
    ),
    const SizedBox(width: 6),
    const Text(
    'Online',
    style: TextStyle(
    fontSize: 10,
    color: Colors.green,
    fontWeight: FontWeight.w600,
    ),
    ),
    ),
    ),