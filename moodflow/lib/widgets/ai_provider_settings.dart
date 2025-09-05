import 'package:flutter/material.dart';
import '../services/ai/ai_provider_service.dart';

class AIProviderSettings extends StatefulWidget {
  final String title;
  final AIProvider currentProvider;
  final String currentModel;
  final Function(AIProvider, String) onProviderChanged;

  const AIProviderSettings({
    super.key,
    required this.title,
    required this.currentProvider,
    required this.currentModel,
    required this.onProviderChanged,
  });

  @override
  State<AIProviderSettings> createState() => _AIProviderSettingsState();
}

class _AIProviderSettingsState extends State<AIProviderSettings> {
  late AIProvider _selectedProvider;
  late String _selectedModel;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.currentProvider;
    _selectedModel = widget.currentModel;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Provider selection
            DropdownButtonFormField<AIProvider>(
              initialValue: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'AI Provider',
                border: OutlineInputBorder(),
              ),
              items: AIProvider.values.map((provider) {
                return DropdownMenuItem(
                  value: provider,
                  child: Row(
                    children: [
                      Icon(_getProviderIcon(provider)),
                      const SizedBox(width: 8),
                      Text(AIProviderService.getProviderDisplayName(provider)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (provider) {
                if (provider != null) {
                  setState(() {
                    _selectedProvider = provider;
                    _selectedModel = AIProviderService.availableModels[provider]!.first;
                  });
                  widget.onProviderChanged(provider, _selectedModel);
                }
              },
            ),
            const SizedBox(height: 16),

            // Model selection
            DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
              ),
              items: AIProviderService.availableModels[_selectedProvider]!.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(AIProviderService.getModelDisplayName(model)),
                );
              }).toList(),
              onChanged: (model) {
                if (model != null) {
                  setState(() {
                    _selectedModel = model;
                  });
                  widget.onProviderChanged(_selectedProvider, model);
                }
              },
            ),
            const SizedBox(height: 16),

            // API Key status and management
            FutureBuilder<bool>(
              future: AIProviderService.hasValidApiKey(_selectedProvider),
              builder: (context, snapshot) {
                final hasKey = snapshot.data ?? false;
                return Row(
                  children: [
                    Icon(
                      hasKey ? Icons.check_circle : Icons.error,
                      color: hasKey ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasKey ? 'API key configured' : 'API key required',
                        style: TextStyle(
                          color: hasKey ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showApiKeyDialog(_selectedProvider),
                      child: Text(hasKey ? 'Change Key' : 'Add Key'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai: return Icons.psychology;
      case AIProvider.anthropic: return Icons.auto_awesome;
      case AIProvider.google: return Icons.apps;
      case AIProvider.mistral: return Icons.memory;
      case AIProvider.perplexity: return Icons.search;
      case AIProvider.groq: return Icons.speed;
    }
  }

  Future<void> _showApiKeyDialog(AIProvider provider) async {
    final controller = TextEditingController();
    final existingKey = await AIProviderService.getApiKey(provider);
    if (existingKey != null) {
      controller.text = existingKey;
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${AIProviderService.getProviderDisplayName(provider)} API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API Key',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final isValid = await AIProviderService.validateApiKey(
                  provider,
                  controller.text,
                );

                if (!dialogContext.mounted) return;

                if (isValid) {
                  await AIProviderService.saveApiKey(provider, controller.text);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } else {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid API key'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() {}); // Refresh the UI
    }
  }
}