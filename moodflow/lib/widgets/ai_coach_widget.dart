import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../services/ai/mood_coach_service.dart';
import '../services/ai/ai_provider_service.dart';
import '../widgets/ai_provider_settings.dart';

class AiCoachWidget extends StatefulWidget {
  const AiCoachWidget({super.key});

  @override
  State<AiCoachWidget> createState() => _AiCoachWidgetState();
}

class _AiCoachWidgetState extends State<AiCoachWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<CoachMessage> _messages = [];
  bool _isTyping = false;
  bool _isEnabled = false;
  bool _disclaimerAccepted = false;
  bool _hasApiKey = false;
  bool _showDataSettings = false;
  int _maxWordCount = 150; // Default word count limit
  final _wordCountController = TextEditingController(text: '150');

  // Data selection options
  bool _includeMoodData = true;
  bool _includeWeatherData = false;
  bool _includeSleepData = false;
  bool _includeActivityData = false;
  bool _includeWorkStressData = false;

  AIProvider _selectedProvider = AIProvider.openai;
  String _selectedModel = '';

  @override
  void initState() {
    super.initState();
    _wordCountController.text = _maxWordCount.toString();
    _initializeCoach();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _wordCountController.dispose();
    super.dispose();
  }

  Future<void> _initializeCoach() async {
    final isEnabled = await MoodCoachService.isCoachEnabled();
    final disclaimerAccepted = await MoodCoachService.isDisclaimerAccepted();
    final hasApiKey = await MoodCoachService.hasValidApiKey();
    final provider = await MoodCoachService.getSelectedProvider();
    final model = await MoodCoachService.getSelectedModel();
    setState(() {
      _selectedProvider = provider;
      _selectedModel = model;
    });
    
    setState(() {
      _isEnabled = isEnabled;
      _disclaimerAccepted = disclaimerAccepted;
      _hasApiKey = hasApiKey;
    });

    if (isEnabled && hasApiKey) {
      await _loadConversationHistory();

      // Only add welcome message if no history exists
      if (_messages.isEmpty) {
        final welcomeMessage = await MoodCoachService.getWelcomeMessage();
        if (welcomeMessage != null && mounted) {
          setState(() {
            _messages.add(welcomeMessage);
          });
        }
      }
    }
  }

  void _onProviderChanged(AIProvider provider, String model) async {
    await MoodCoachService.setSelectedProvider(provider);
    await MoodCoachService.setSelectedModel(model);
    setState(() {
      _selectedProvider = provider;
      _selectedModel = model;
    });
    await _checkApiKey();
  }

  Future<void> _checkApiKey() async {
    final hasKey = await MoodCoachService.hasValidApiKey();
    setState(() {
      _hasApiKey = hasKey;
    });
  }

  Future<void> _loadConversationHistory() async {
    try {
      final history = await MoodCoachService.getConversationHistory();
      if (mounted && history.isNotEmpty) {
        setState(() {
          _messages.addAll(history);
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Failed to load history, continue with empty state
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

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
      final response = await MoodCoachService.processUserMessage(
        text,
        maxWordCount: _maxWordCount,
        includeMoodData: _includeMoodData,
        includeWeatherData: _includeWeatherData,
        includeSleepData: _includeSleepData,
        includeActivityData: _includeActivityData,
        includeWorkStressData: _includeWorkStressData,
      );

      if (mounted) {
        setState(() {
          _messages.add(response);
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(CoachMessage(
            id: 'error_${DateTime.now().millisecondsSinceEpoch}',
            text: 'I\'m having trouble connecting right now. ${e.toString().contains('API key') ? 'Please check your API key in settings.' : 'Please try again in a moment.'}',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
        _scrollToBottom();
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
    if (!_hasApiKey) {
      return _buildApiKeySetupCard();
    }

    if (!_isEnabled || !_disclaimerAccepted) {
      return _buildSetupCard();
    }

    return Container(
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [Colors.grey.shade800, Colors.grey.shade900]
              : [Colors.blue.shade50, Colors.purple.shade50],
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (_showDataSettings) _buildDataSelectionPanel(),
          Expanded(child: _buildMessageList()),
          // Wrap input area with bottom padding based on keyboard
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: _buildInputArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickWordButton(int wordCount) {
    final isSelected = _maxWordCount == wordCount;
    return GestureDetector(
      onTap: () {
        setState(() {
          _maxWordCount = wordCount;
          _wordCountController.text = wordCount.toString();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          '$wordCount',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeySetupCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.key,
              size: 48,
              color: Colors.orange.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'API Key Required for ${AIProviderService.getProviderDisplayName(_selectedProvider)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'To use the AI Mood Coach, you need to provide your own API key. This ensures your conversations remain private and under your control.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),

            // AI Provider Settings
            AIProviderSettings(
              title: 'AI Provider Configuration',
              currentProvider: _selectedProvider,
              currentModel: _selectedModel,
              onProviderChanged: _onProviderChanged,
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Maybe Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showProviderApiKeyDialog(_selectedProvider),
                    icon: const Icon(Icons.add_circle),
                    label: const Text('Add API Key'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(50),
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
              'Get personalized insights and have authentic conversations about your mood patterns. Choose from multiple AI providers for the best experience.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _setupAiCoach,
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

  Future<void> _showProviderApiKeyDialog(AIProvider provider) async {
    final controller = TextEditingController();
    final existingKey = await AIProviderService.getApiKey(provider);
    if (existingKey != null) {
      controller.text = existingKey;
    }

    bool isValidating = false;

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: Text('${AIProviderService.getProviderDisplayName(provider)} API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your ${AIProviderService.getProviderDisplayName(provider)} API key:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !isValidating,
              ),
              if (isValidating) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Validating API key...'),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isValidating ? null : () => Navigator.of(builderContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isValidating
                  ? null
                  : () async {
                if (controller.text.trim().isEmpty) return;

                setDialogState(() => isValidating = true);

                try {
                  final isValid = await AIProviderService.validateApiKey(
                      provider, controller.text.trim());

                  if (!builderContext.mounted) return;

                  if (isValid) {
                    await AIProviderService.saveApiKey(provider, controller.text.trim());
                    if (builderContext.mounted) {
                      Navigator.of(builderContext).pop(true);
                    }
                  } else {
                    if (builderContext.mounted) {
                      setDialogState(() => isValidating = false);
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid API key. Please check and try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (builderContext.mounted) {
                    setDialogState(() => isValidating = false);
                    ScaffoldMessenger.of(builderContext).showSnackBar(
                      const SnackBar(
                        content: Text('Error validating API key. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      await _checkApiKey();
      await _initializeCoach();
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.psychology,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Mood Coach',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Powered by ${AIProviderService.getProviderDisplayName(_selectedProvider)} • Not professional advice',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.amber.shade300
                        : Colors.orange.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),

              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _showDataSettings = !_showDataSettings),
            icon: Icon(
              _showDataSettings ? Icons.expand_less : Icons.tune,
              size: 20,
              color: Colors.grey.shade600,
            ),
            tooltip: 'Data Settings',
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearConversation();
              } else if (value == 'disable') {
                _disableCoach();
              } else if (value == 'api_key') {
                _showProviderApiKeyDialog(_selectedProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 16),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'disable',
                child: Row(
                  children: [
                    Icon(Icons.close, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Disable Coach'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataSelectionPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Icon(Icons.tune, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              const Text(
                'AI Coach Settings:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Response length setting
          Row(
            children: [
              Icon(Icons.short_text, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              const Text(
                'Max words:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _wordCountController,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          isDense: true,
                          hintText: '50-800',
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        onChanged: (value) {
                          final wordCount = int.tryParse(value);
                          if (wordCount != null && wordCount >= 50 && wordCount <= 800) {
                            setState(() {
                              _maxWordCount = wordCount;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQuickWordButton(75),
                        _buildQuickWordButton(150),
                        _buildQuickWordButton(300),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
 
          Row(
            children: [
              Icon(Icons.storage, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              const Text(
                'Data shared with AI:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Compact checkboxes
          _buildCompactCheckbox(
            'Mood Data',
            'Daily mood ratings and notes',
            Icons.sentiment_satisfied,
            _includeMoodData,
                (value) => setState(() => _includeMoodData = value ?? true),
            enabled: true, // Mood data should always be included
          ),

          _buildCompactCheckbox(
            'Weather Data',
            'Weather conditions and temperature',
            Icons.wb_sunny,
            _includeWeatherData,
                (value) => setState(() => _includeWeatherData = value ?? false),
          ),

          _buildCompactCheckbox(
            'Sleep Data',
            'Sleep quality, duration, and schedule',
            Icons.bedtime,
            _includeSleepData,
                (value) => setState(() => _includeSleepData = value ?? false),
          ),

          _buildCompactCheckbox(
            'Activity Data',
            'Exercise levels and social activities',
            Icons.fitness_center,
            _includeActivityData,
                (value) => setState(() => _includeActivityData = value ?? false),
          ),

          _buildCompactCheckbox(
            'Work Stress Data',
            'Work stress levels and patterns',
            Icons.work,
            _includeWorkStressData,
                (value) => setState(() => _includeWorkStressData = value ?? false),
          ),

            const SizedBox(height: 16),
            AIProviderSettings(
              title: 'AI Provider Settings',
              currentProvider: _selectedProvider,
              currentModel: _selectedModel,
              onProviderChanged: _onProviderChanged,
            ),
          ],
      ),
    ),
    );
  }

  Widget _buildCompactCheckbox(
      String title,
      String subtitle,
      IconData icon,
      bool value,
      ValueChanged<bool?> onChanged, {
        bool enabled = true,
      }) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
                icon,
                size: 16,
                color: enabled
                    ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade300
                    : Colors.grey.shade600)
                    : Colors.grey.shade500
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: enabled ? null : Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade300
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Checkbox(
                value: value,
                onChanged: enabled ? onChanged : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty && !_isTyping) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Start a conversation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask me anything about your mood patterns, get personalized insights, or just chat about how you\'re feeling.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 12, top: 4),
              decoration: BoxDecoration(
                color: isError
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isError ? Colors.red.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.psychology,
                size: 20,
                color: isError ? Colors.red : Colors.blue,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.blue.shade600
                    : isError
                    ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.red.shade900.withValues(alpha: 0.3)
                    : Colors.red.shade50)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isError
                    ? Border.all(color: Colors.red.shade200)
                    : !isUser
                    ? Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Split message into main content and disclaimer
                      () {
                    if (!isUser && message.text.contains('IMPORTANT SAFETY NOTICE')) {
                      // Split on the first occurrence of the safety notice
                      final parts = message.text.split(RegExp(r'\n\s*⚠️\s*IMPORTANT SAFETY NOTICE\s*⚠️'));

                      if (parts.length >= 2) {
                        final mainText = parts[0].trim();
                        final disclaimerText = '⚠️ IMPORTANT SAFETY NOTICE ⚠️\n${parts.sublist(1).join('\n⚠️ IMPORTANT SAFETY NOTICE ⚠️')}'.trim();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (mainText.isNotEmpty)
                              Text(
                                mainText,
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  height: 1.5,
                                  fontSize: 14,
                                ),
                              ),
                            if (disclaimerText.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade300, width: 1.5),
                                ),
                                child: Text(
                                  disclaimerText,
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }
                    }

                    // Default case - display the full message as-is
                    return Text(
                      message.text,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : isError
                            ? Colors.red.shade700
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    );
                  }(),
                  if (message.suggestions != null && message.suggestions!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.suggestions!.map((suggestion) => InkWell(
                        onTap: () => _sendMessage(suggestion),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            suggestion,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
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
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 12, top: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.person,
                size: 18,
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Icon(
              Icons.psychology,
              size: 18,
              color: Colors.blue,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
                const SizedBox(width: 8),
                Text(
                  'AI is thinking...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        final phase = (value + (index * 0.33)) % 1.0;
        final scale = 0.4 + (0.6 * (math.sin(phase * 2 * math.pi) + 1) / 2);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.blue.shade400,
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
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Quick suggestions (only show if conversation is new or last message was from user)
          if (_messages.isEmpty || (_messages.isNotEmpty && _messages.last.isUser)) ...[
            _buildQuickSuggestions(),
            const SizedBox(height: 12),
          ],
          // Input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask about your mood patterns, get insights, or just chat...',
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.grey.shade50,
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
                  enabled: !_isTyping,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _isTyping ? Colors.grey.shade400 : Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  onPressed: _isTyping ? null : () => _sendMessage(_messageController.text),
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

  Widget _buildQuickSuggestions() {
    List<String> suggestions;

    if (_messages.isEmpty) {
      suggestions = [
        'What patterns do you see in my data?',
        'How can I improve my mood today?',
        'What factors affect my mood most?',
        'Help me understand my trends',
      ];
    } else {
      // Contextual suggestions based on conversation
      suggestions = [
        'Tell me more about that',
        'What should I focus on this week?',
        'Give me a specific action plan',
        'How does this compare to others?',
      ];
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: suggestions.map((suggestion) => Container(
          margin: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: _isTyping ? null : () => _sendMessage(suggestion),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isTyping ? Colors.grey.shade200 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _isTyping ? Colors.grey.shade300 : Colors.blue.shade200
                ),
              ),
              child: Text(
                suggestion,
                style: TextStyle(
                  color: _isTyping ? Colors.grey.shade500 : Colors.blue.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _setupAiCoach() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('AI Coach Disclaimer'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ IMPORTANT DISCLAIMER',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This AI Coach uses ChatGPT to provide conversational support. It is NOT a licensed therapist, psychologist, or medical professional.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'What the AI Coach CAN do:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('• Have authentic conversations about your mood journey'),
              const Text('• Analyze your personal mood patterns and trends'),
              const Text('• Provide personalized wellness suggestions'),
              const Text('• Help you reflect on what affects your wellbeing'),
              const Text('• Offer evidence-based coping strategies'),
              const SizedBox(height: 16),
              const Text(
                'What it CANNOT do:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('• Diagnose mental health conditions'),
              const Text('• Replace professional mental health treatment'),
              const Text('• Provide crisis intervention or emergency support'),
              const Text('• Offer medical or clinical advice'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚨 IF YOU ARE IN CRISIS:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please contact emergency services (911), Crisis Text Line (text HOME to 741741), or National Suicide Prevention Lifeline (988).',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'By enabling the AI Coach, you acknowledge that:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('• You understand this is AI-generated content, not professional advice'),
              const Text('• You will seek professional help for serious mental health concerns'),
              const Text('• You use this tool as a supplement to, not replacement for, proper care'),
              const Text('• Your data is sent to the selected AI provider for processing (see their privacy policy)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('I Understand & Enable'),
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
            content: Text('AI Mood Coach enabled! Remember: AI insights, not professional advice.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text('This will delete all chat history with your AI Coach. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MoodCoachService.clearConversationHistory();
      setState(() {
        _messages.clear();
      });

      // Add welcome message back
      final welcomeMessage = await MoodCoachService.getWelcomeMessage();
      if (welcomeMessage != null && mounted) {
        setState(() {
          _messages.add(welcomeMessage);
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _disableCoach() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable AI Coach'),
        content: const Text(
            'This will disable the AI Coach and clear all conversation history. '
                'Your API key will remain saved. You can re-enable it later.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MoodCoachService.disableCoach();
      setState(() {
        _isEnabled = false;
        _disclaimerAccepted = false;
        _messages.clear();
      });
    }
  }
}