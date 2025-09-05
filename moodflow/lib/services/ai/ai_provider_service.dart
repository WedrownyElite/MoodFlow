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

  // Free vs paid models for each provider
  static const Map<AIProvider, Map<String, bool>> modelCosts = {
    AIProvider.openai: {
      'gpt-4o': true,        // Paid
      'gpt-4o-mini': true,   // Paid (but cheaper)
      'gpt-3.5-turbo': false, // Free tier available
    },
    AIProvider.anthropic: {
      'claude-3-5-sonnet-20241022': true, // Paid
      'claude-3-haiku-20240307': false,   // Free tier available
    },
    AIProvider.google: {
      'gemini-1.5-pro': true,   // Paid
      'gemini-1.5-flash': false, // Free tier available
    },
    AIProvider.mistral: {
      'mistral-large-latest': true,  // Paid
      'mistral-medium-latest': true, // Paid
      'mistral-small-latest': false, // Free tier available
    },
    AIProvider.perplexity: {
      'llama-3.1-sonar-large-128k-online': true,  // Paid
      'llama-3.1-sonar-small-128k-online': false, // Free tier available
    },
    AIProvider.groq: {
      'llama-3.1-70b-versatile': false, // Free tier available
      'mixtral-8x7b-32768': false,      // Free tier available
    },
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

  /// Get or set last used model for each provider
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

  /// API Key management - ONE key per provider
  static Future<String?> getApiKey(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_apiKeyPrefix${provider.name}');
  }

  static Future<void> saveApiKey(AIProvider provider, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_apiKeyPrefix${provider.name}', apiKey);
    Logger.aiService('✅ Saved API key for ${provider.name}');
  }

  static Future<bool> hasValidApiKey(AIProvider provider) async {
    final apiKey = await getApiKey(provider);
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Validate API key for specific provider using the cheapest/free model
  static Future<bool> validateApiKey(AIProvider provider, String apiKey) async {
    try {
      Logger.aiService('🔍 Validating API key for ${provider.name}...');

      // Use the cheapest/free model for validation
      final validationModel = _getValidationModel(provider);

      final testMessage = await sendMessage(
        provider: provider,
        model: validationModel,
        messages: [{'role': 'user', 'content': 'Test'}],
        apiKey: apiKey,
        maxTokens: 5,
      );

      final isValid = testMessage != null;
      Logger.aiService(isValid
          ? '✅ API key validation successful for ${provider.name}'
          : '❌ API key validation failed for ${provider.name}');

      return isValid;
    } catch (e) {
      Logger.aiService('❌ API key validation failed for ${provider.name}: $e');
      return false;
    }
  }

  /// Get the cheapest model for validation
  static String _getValidationModel(AIProvider provider) {
    final models = availableModels[provider]!;
    final costs = modelCosts[provider]!;

    // Find first free model, or fall back to first model if none are free
    for (final model in models) {
      if (costs[model] == false) {
        return model;
      }
    }
    return models.first;
  }

  /// Check if a specific model requires paid access
  static bool isModelPaid(AIProvider provider, String model) {
    return modelCosts[provider]?[model] ?? true;
  }

  /// Validate if user has access to a specific model
  static Future<ModelAccessResult> validateModelAccess(
      AIProvider provider, String model, String apiKey) async {
    try {
      Logger.aiService('🔍 Checking access to $model for ${provider.name}...');

      final testMessage = await sendMessage(
        provider: provider,
        model: model,
        messages: [{'role': 'user', 'content': 'Test'}],
        apiKey: apiKey,
        maxTokens: 5,
      );

      if (testMessage != null) {
        Logger.aiService('✅ Access confirmed for $model');
        return ModelAccessResult(hasAccess: true);
      } else {
        Logger.aiService('❌ No access to $model');
        return ModelAccessResult(
          hasAccess: false,
          reason: 'No access to this model. ${isModelPaid(provider, model)
              ? 'This model requires a paid plan.'
              : 'Please check your API key permissions.'}',
        );
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('insufficient_quota') ||
          errorStr.contains('quota') ||
          errorStr.contains('billing')) {
        return ModelAccessResult(
          hasAccess: false,
          reason: 'Insufficient quota or billing issue. This model requires a paid plan.',
        );
      } else if (errorStr.contains('invalid_request_error') ||
          errorStr.contains('model_not_found')) {
        return ModelAccessResult(
          hasAccess: false,
          reason: 'Model not available with your current plan.',
        );
      } else {
        return ModelAccessResult(
          hasAccess: false,
          reason: 'Error checking model access: ${e.toString()}',
        );
      }
    }
  }

  /// Universal message sending with model access validation
  static Future<String?> sendMessage({
    required AIProvider provider,
    required String model,
    required List<Map<String, String>> messages,
    String? apiKey,
    int maxTokens = 1500,
    double temperature = 0.7,
    bool validateAccess = false,
  }) async {
    apiKey ??= await getApiKey(provider);
    if (apiKey == null) {
      throw Exception('No API key found for ${provider.name}');
    }

    // Optional: Validate model access before sending
    if (validateAccess) {
      final accessResult = await validateModelAccess(provider, model, apiKey);
      if (!accessResult.hasAccess) {
        throw Exception(accessResult.reason);
      }
    }

    try {
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
    } catch (e) {
      // Check if it's a model access error and provide helpful message
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('insufficient_quota') ||
          errorStr.contains('quota') ||
          errorStr.contains('billing')) {
        throw Exception('This model requires a paid plan. Please upgrade your ${getProviderDisplayName(provider)} account or try a free model.');
      } else if (errorStr.contains('model_not_found') ||
          errorStr.contains('invalid_request_error')) {
        throw Exception('Model "$model" is not available with your current plan.');
      }
      rethrow;
    }
  }

  // Provider-specific implementation methods
  static Future<String?> _sendOpenAIMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    Logger.aiService('📡 Sending request to OpenAI with model: $model');

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

    Logger.aiService('📡 OpenAI response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      Logger.aiService('✅ OpenAI request successful');
      return content;
    } else {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']['message'] ?? 'Unknown error';
      Logger.aiService('❌ OpenAI API error ${response.statusCode}: $errorMessage');
      throw Exception('OpenAI API error: $errorMessage');
    }
  }

  static Future<String?> _sendAnthropicMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    Logger.aiService('📡 Sending request to Anthropic with model: $model');

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

    Logger.aiService('📡 Anthropic response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['content'][0]['text'] as String;
      Logger.aiService('✅ Anthropic request successful');
      return content;
    } else {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']['message'] ?? 'Unknown error';
      Logger.aiService('❌ Anthropic API error ${response.statusCode}: $errorMessage');
      throw Exception('Anthropic API error: $errorMessage');
    }
  }

  // Add similar methods for other providers...
  static Future<String?> _sendGoogleMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    // Implementation for Google Gemini API
    throw UnimplementedError('Google Gemini implementation needed');
  }

  static Future<String?> _sendMistralMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    Logger.aiService('📡 Sending request to Mistral with model: $model');

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

    Logger.aiService('📡 Mistral response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      Logger.aiService('✅ Mistral request successful');
      return content;
    } else {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']['message'] ?? 'Unknown error';
      Logger.aiService('❌ Mistral API error ${response.statusCode}: $errorMessage');
      throw Exception('Mistral API error: $errorMessage');
    }
  }

  static Future<String?> _sendPerplexityMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    Logger.aiService('📡 Sending request to Perplexity with model: $model');

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

    Logger.aiService('📡 Perplexity response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      Logger.aiService('✅ Perplexity request successful');
      return content;
    } else {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']['message'] ?? 'Unknown error';
      Logger.aiService('❌ Perplexity API error ${response.statusCode}: $errorMessage');
      throw Exception('Perplexity API error: $errorMessage');
    }
  }

  static Future<String?> _sendGroqMessage(String model, List<Map<String, String>> messages, String apiKey, int maxTokens, double temperature) async {
    Logger.aiService('📡 Sending request to Groq with model: $model');

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

    Logger.aiService('📡 Groq response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      Logger.aiService('✅ Groq request successful');
      return content;
    } else {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']['message'] ?? 'Unknown error';
      Logger.aiService('❌ Groq API error ${response.statusCode}: $errorMessage');
      throw Exception('Groq API error: $errorMessage');
    }
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

  /// Get model display name with cost indicator
  static String getModelDisplayNameWithCost(AIProvider provider, String model) {
    final baseName = getModelDisplayName(model);
    final isPaid = isModelPaid(provider, model);
    return isPaid ? '$baseName 💰' : '$baseName 🆓';
  }
}

/// Result class for model access validation
class ModelAccessResult {
  final bool hasAccess;
  final String? reason;

  ModelAccessResult({required this.hasAccess, this.reason});
}