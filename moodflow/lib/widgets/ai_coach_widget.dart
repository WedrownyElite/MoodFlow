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
    final welcomeMessage = await MoodCoachService.getWelcomeMessage();

    setState(() {
      _isEnabled = isEnabled;
      if (welcomeMessage != null) {
        _messages.add(welcomeMessage);
      }
    });
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

      setState(() {
        _messages.add(response);
        _isTyping = false;
      });

      _scrollToBottom();
    } catch (e) {
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
    if (!_isEnabled) {
      return _buildSetupCard();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 400,
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
                  'Here to help with insights and support',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator();
        }

        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(CoachMessage message) {
    final isUser = message.isUser;
    final isError = message.isError;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: isError ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.psychology,
                size: 16,
                color: isError ? Colors.red : Colors.blue,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.blue.shade600
                    : isError
                    ? Colors.red.shade50
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 12),
                ),
                border: isError
                    ? Border.all(color: Colors.red.shade200)
                    : !isUser
                    ? Border.all(color: Colors.grey.shade200)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : isError ? Colors.red.shade700 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  if (message.suggestions != null && message.suggestions!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...message.suggestions!.map((suggestion) => Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        onTap: () => _sendMessage(suggestion),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            suggestion,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.psychology,
              size: 16,
              color: Colors.blue,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.5 + (0.5 * (1 - ((value - (index * 0.2)) % 1.0).abs())),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Quick suggestions
          if (_messages.isEmpty || _messages.last.isUser) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickSuggestion('I\'m feeling off but can\'t pinpoint why'),
                  _buildQuickSuggestion('What patterns do you see in my mood?'),
                  _buildQuickSuggestion('How can I improve my mood today?'),
                  _buildQuickSuggestion('I had a great day, what made it special?'),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask about your mood patterns...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _isTyping ? null : _sendMessage,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  onPressed: _isTyping
                      ? null
                      : () => _sendMessage(_messageController.text),
                  icon: Icon(
                    _isTyping ? Icons.hourglass_bottom : Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestion(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _sendMessage(text),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setupAiCoach() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Text('Setup AI Mood Coach'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your AI Mood Coach can help you:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text('• Analyze your mood patterns and correlations'),
            Text('• Provide personalized recommendations'),
            Text('• Answer questions about your mental wellbeing'),
            Text('• Offer support during challenging times'),
            SizedBox(height: 12),
            Text(
              'The coach uses your mood data to provide insights while keeping your information private and secure.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enable Coach'),
          ),
        ],
      ),
    );

    if (result == true) {
      await MoodCoachService.enableCoach();
      await _initializeCoach();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Mood Coach enabled! Start chatting below.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

// Supporting service for the AI Coach
class MoodCoachService {
  static const String _enabledKey = 'ai_coach_enabled';
  static const String _conversationHistoryKey = 'coach_conversation_history';

  static Future<bool> isCoachEnabled() async {
    // In a real implementation, this would check if AI services are configured
    return false; // Disabled by default until properly configured
  }

  static Future<void> enableCoach() async {
    // Enable the coach service
  }

  static Future<CoachMessage?> getWelcomeMessage() async {
    return CoachMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      text: 'Hello! I\'m your AI Mood Coach. I\'ve been analyzing your mood patterns and I\'m here to help you understand what affects your wellbeing. What would you like to explore today?',
      isUser: false,
      timestamp: DateTime.now(),
      suggestions: [
        'What patterns do you see in my mood?',
        'How can I improve my mood today?',
        'What affects my mood the most?',
      ],
    );
  }

  static Future<CoachMessage> processUserMessage(String message) async {
    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));

    // In a real implementation, this would:
    // 1. Analyze the user's mood data
    // 2. Process the message with AI
    // 3. Generate personalized insights
    // 4. Return relevant recommendations

    return CoachMessage(
      id: 'response_${DateTime.now().millisecondsSinceEpoch}',
      text: _generateMockResponse(message),
      isUser: false,
      timestamp: DateTime.now(),
      suggestions: [
        'Tell me more about this',
        'What should I do about it?',
        'Any other insights?',
      ],
    );
  }

  static String _generateMockResponse(String userMessage) {
    final lowercaseMessage = userMessage.toLowerCase();

    if (lowercaseMessage.contains('pattern')) {
      return 'I notice you tend to feel better in the mornings (average 7.2) vs evenings (5.8). Your mood also correlates strongly with sleep quality - when you get 8+ hours, your next day mood averages 7.5 vs 6.1 with less sleep.';
    }

    if (lowercaseMessage.contains('improve') || lowercaseMessage.contains('better')) {
      return 'Based on your data, here are 3 proven mood boosters for you: 1) Light exercise gives you a +1.8 boost, 2) Video calls with friends boost you +2.1, 3) Getting outside on sunny days adds +1.4 points.';
    }

    if (lowercaseMessage.contains('feeling off') || lowercaseMessage.contains('down')) {
      return 'I notice you logged 4.2 today. Looking at your patterns: You missed your usual 2 PM snack, and your energy dips typically happen when you skip protein at lunch. Try a quick protein snack + 10-min walk - this combo worked 8/10 times before.';
    }

    return 'That\'s an interesting question! Based on your mood data from the past 30 days, I can see some patterns that might help. Would you like me to dive deeper into any specific aspect of your mood tracking?';
  }
}

class CoachMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? suggestions;
  final bool isError;

  CoachMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions,
    this.isError = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'suggestions': suggestions,
    'isError': isError,
  };

  factory CoachMessage.fromJson(Map<String, dynamic> json) => CoachMessage(
    id: json['id'],
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
    suggestions: json['suggestions'] != null
        ? List<String>.from(json['suggestions'])
        : null,
    isError: json['isError'] ?? false,
  );
}