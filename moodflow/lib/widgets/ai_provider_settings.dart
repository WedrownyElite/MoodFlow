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
  void didUpdateWidget(AIProviderSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update state when widget properties change
    if (oldWidget.currentProvider != widget.currentProvider ||
        oldWidget.currentModel != widget.currentModel) {
      setState(() {
        _selectedProvider = widget.currentProvider;
        _selectedModel = widget.currentModel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the selected model is valid for the current provider
    final availableModels = AIProviderService.availableModels[_selectedProvider]!;
    if (!availableModels.contains(_selectedModel)) {
      _selectedModel = availableModels.first;
    }

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
                  final newModel = AIProviderService.availableModels[provider]!.first;
                  setState(() {
                    _selectedProvider = provider;
                    _selectedModel = newModel;
                  });
                  widget.onProviderChanged(provider, newModel);
                }
              },
            ),
            const SizedBox(height: 16),

            // Model selection with cost indicators
            DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
                helperText: '🆓 = Free tier, 💰 = Paid model',
              ),
              items: availableModels.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(AIProviderService.getModelDisplayNameWithCost(_selectedProvider, model)),
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

    bool isValidating = false;

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
                'Enter your ${AIProviderService.getProviderDisplayName(provider)} API key.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'One key works for all ${AIProviderService.getProviderDisplayName(provider)} models (subject to your plan limits).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  border: const OutlineInputBorder(),
                  hintText: provider == AIProvider.openai ? 'sk-...' : 'Enter your API key',
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
              onPressed: isValidating ? null : () => Navigator.pop(builderContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isValidating
                  ? null
                  : () async {
                final keyText = controller.text.trim();
                if (keyText.isEmpty) return;

                setDialogState(() => isValidating = true);

                try {
                  final isValid = await AIProviderService.validateApiKey(provider, keyText);

                  if (!builderContext.mounted) return;

                  if (isValid) {
                    await AIProviderService.saveApiKey(provider, keyText);
                    if (builderContext.mounted) {
                      Navigator.pop(builderContext, true);
                    }
                  } else {
                    if (builderContext.mounted) {
                      setDialogState(() => isValidating = false);
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Invalid API key for ${AIProviderService.getProviderDisplayName(provider)}. Please check and try again.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (builderContext.mounted) {
                    setDialogState(() => isValidating = false);
                    ScaffoldMessenger.of(builderContext).showSnackBar(
                      SnackBar(
                        content: Text('Error validating API key: ${e.toString()}'),
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
      setState(() {}); // Refresh the UI to show updated API key status
    }
  }
}