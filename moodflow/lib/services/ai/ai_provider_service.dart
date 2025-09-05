import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

enum AIProvider {
  openai,
  anthropic,
  google,
  mistral,
  perplexity,
  groq,
}

class AIProviderService {
  static const String _lastUsedProviderKey = 'last_used_ai_provider';
  static const String _lastUsedModelKey = 'last_used_ai_model';
  static const String _apiKeyPrefix = 'api_key_';

  // Model configurations for each provider
  static const Map<AIProvider, List<String>> availableModels = {
    AIProvider.openai: ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo'],
    AIProvider.anthropic: ['claude-3-5-sonnet-20241022', 'claude-3-haiku-20240307'],
    AIProvider.google: ['gemini-1.5-pro', 'gemini-1.5-flash'],
    AIProvider.mistral: ['mistral-large-latest', 'mistral-medium-latest', 'mistral-small-latest'],
    AIProvider.perplexity: ['llama-3.1-sonar-large-128k-online', 'llama-3.1-sonar-small-128k-online'],
    AIProvider.groq: ['llama-3.1-70b-versatile', 'mixtral-8x7b-32768'],
  };

  static const Map<AIProvider, String> baseUrls = {
    AIProvider.openai: 'https://api.openai.com/v1/chat/completions',
    AIProvider.anthropic: 'https://api.anthropic.com/v1/messages',
    AIProvider.google: 'https://generativelanguage.googleapis.com/v1beta/models',
    AIProvider.mistral: 'https://api.mistral.ai/v1/chat/completions',
    AIProvider.perplexity: 'https://api.perplexity.ai/chat/completions',
    AIProvider.groq: 'https://api.groq.com/openai/v1/chat/completions',
  };

  /// Get or set last used provider
  static Future<AIProvider> getLastUsedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_lastUsedProviderKey);
    if (providerName != null) {
      try {
        return AIProvider.values.firstWhere((p) => p.name == providerName);
      } catch (e) {
        return AIProvider.openai; // Default fallback
      }
    }
    return AIProvider.openai;
  }

  static Future<void> setLastUsedProvider(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUsedProviderKey, provider.name);
  }

  /// Get or set last used model
  static Future<String> getLastUsedModel(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    final modelKey = '${_lastUsedModelKey}_${provider.name}';
    final model = prefs.getString(modelKey);
    return model ?? availableModels[provider]!.first;
  }

  static Future<void> setLastUsedModel(AIProvider provider, String model) async {
    final prefs = await SharedPreferences.getInstance();
    final modelKey = '${_lastUsedModelKey}_${provider.name}';
    await prefs.setString(modelKey, model);
  }

  /// API Key management
  static Future<String?> getApiKey(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_apiKeyPrefix${provider.name}');
  }

  static Future<void> saveApiKey(AIProvider provider, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_apiKeyPrefix${provider.name}', apiKey);
  }

  static Future<bool> hasValidApiKey(AIProvider provider) async {
    final apiKey = await getApiKey(provider);
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Validate API key for specific provider
  static Future<bool> validateApiKey(AIProvider provider, String apiKey) async {
    try {
      final testMessage = await sendMessage(
        provider: provider,
        model: availableModels[provider]!.first,
        messages: [{'role': 'user', 'content': 'Test'}],
        apiKey: apiKey,
        maxTokens: 5,
      );
      return testMessage != null;
    } catch (e) {
      Logger.aiService('API key validation failed for ${provider.name}: $e');
      return false;
    }
  }

  /// Universal message sending
  static Future<String?> sendMessage({
    required AIProvider provider,
    required String model,
    required List<Map<String, String>> messages,
    String? apiKey,
    int maxTokens = 1500,
    double temperature = 0.7,
  }) async {
    apiKey ??= await getApiKey(provider);
    if (apiKey == null) return null;

    switch (provider) {
      case AIProvider.openai:
        return await _sendOpenAIMessage(model, messages, apiKey, maxTokens, temperature);
      case AIProvider.anthropic:
        return await _sendAnthropicMessage(model, messages, apiKey, maxTokens, temperature);
      case AIProvider.google:
        return await _sendGoogleMessage(model, messages, apiKey, maxTokens, temperature);
      case AIProvider.mistral:
        return await _sendMistralMessage(model, messages, apiKey, maxTokens, temperature);
      case AIProvider.perplexity:
        return await _sendPerplexityMessage(model, messages, apiKey, maxTokens, temperature);
      case AIProvider.groq:
        return await _sendGroqMessage(model, messages, apiKey, maxTokens, temperature);
    }
  }

  // Provider-specific implementation methods
  static Future<String?> _sendOpenAIMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    final response = await http.post(
      Uri.parse(baseUrls[AIProvider.openai]!),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('OpenAI API error: ${response.statusCode}');
  }

  static Future<String?> _sendAnthropicMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    // Convert OpenAI format to Anthropic format
    final systemMessage = messages.firstWhere((m) => m['role'] == 'system', orElse: () => {})['content'];
    final conversationMessages = messages.where((m) => m['role'] != 'system').toList();

    final response = await http.post(
      Uri.parse(baseUrls[AIProvider.anthropic]!),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'temperature': temperature,
        if (systemMessage != null) 'system': systemMessage,
        'messages': conversationMessages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] as String;
    }
    throw Exception('Anthropic API error: ${response.statusCode}');
  }

  // Add similar methods for other providers...
  static Future<String?> _sendGoogleMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    // Implementation for Google Gemini API
    throw UnimplementedError('Google Gemini implementation needed');
  }

  static Future<String?> _sendMistralMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    // Similar to OpenAI format
    final response = await http.post(
      Uri.parse(baseUrls[AIProvider.mistral]!),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Mistral API error: ${response.statusCode}');
  }

  static Future<String?> _sendPerplexityMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    // Similar to OpenAI format
    final response = await http.post(
      Uri.parse(baseUrls[AIProvider.perplexity]!),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Perplexity API error: ${response.statusCode}');
  }

  static Future<String?> _sendGroqMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    // Similar to OpenAI format
    final response = await http.post(
      Uri.parse(baseUrls[AIProvider.groq]!),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Groq API error: ${response.statusCode}');
  }

  /// Get display names for providers
  static String getProviderDisplayName(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai: return 'OpenAI';
      case AIProvider.anthropic: return 'Anthropic';
      case AIProvider.google: return 'Google';
      case AIProvider.mistral: return 'Mistral';
      case AIProvider.perplexity: return 'Perplexity';
      case AIProvider.groq: return 'Groq';
    }
  }

  /// Get model display names
  static String getModelDisplayName(String model) {
    final modelNames = {
      'gpt-4o': 'GPT-4o',
      'gpt-4o-mini': 'GPT-4o Mini',
      'gpt-3.5-turbo': 'GPT-3.5 Turbo',
      'claude-3-5-sonnet-20241022': 'Claude 3.5 Sonnet',
      'claude-3-haiku-20240307': 'Claude 3 Haiku',
      'gemini-1.5-pro': 'Gemini 1.5 Pro',
      'gemini-1.5-flash': 'Gemini 1.5 Flash',
      'mistral-large-latest': 'Mistral Large',
      'mistral-medium-latest': 'Mistral Medium',
      'mistral-small-latest': 'Mistral Small',
      'llama-3.1-sonar-large-128k-online': 'Llama 3.1 Sonar Large',
      'llama-3.1-sonar-small-128k-online': 'Llama 3.1 Sonar Small',
      'llama-3.1-70b-versatile': 'Llama 3.1 70B',
      'mixtral-8x7b-32768': 'Mixtral 8x7B',
    };
    return modelNames[model] ?? model;
  }
}