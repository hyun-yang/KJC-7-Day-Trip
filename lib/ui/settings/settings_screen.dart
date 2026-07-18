import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/native_language.dart';
import '../../domain/settings/kjc_settings.dart';
import '../../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late NativeLanguage _language;
  late String _model;
  final _apiKeyController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _language = settings.nativeLanguage;
    _model = settings.openaiModel;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref.watch(apiKeyProvider);
    final busy = _isSaving || apiKey.isLoading;
    final hasApiKey = apiKey.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Conversation preferences',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<NativeLanguage>(
                  key: const ValueKey('language-field'),
                  initialValue: _language,
                  decoration: const InputDecoration(
                    labelText: 'Native language',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final language in NativeLanguage.values)
                      DropdownMenuItem(
                        value: language,
                        child: Text(language.promptName),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) setState(() => _language = value);
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('model-field'),
                  initialValue: _model,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI model',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final model in kOpenAiModels)
                      DropdownMenuItem(value: model, child: Text(model)),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) setState(() => _model = value);
                        },
                ),
                const SizedBox(height: 28),
                Text(
                  'OpenAI API key',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  apiKey.when(
                    loading: () => 'Checking API key status…',
                    error: (_, _) => 'Could not check API key status.',
                    data: (key) => key == null || key.isEmpty
                        ? 'No API key configured'
                        : 'API key configured',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('api-key-field'),
                  controller: _apiKeyController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: hasApiKey ? 'Replacement API key' : 'API key',
                    helperText: hasApiKey
                        ? 'Leave blank to keep the configured key.'
                        : 'Stored securely on this device.',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (hasApiKey) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: busy ? null : _clearApiKey,
                      icon: const Icon(Icons.key_off_rounded),
                      label: const Text('Clear API Key'),
                    ),
                  ),
                ],
                if (_errorMessage case final message?) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    key: const ValueKey('settings-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: busy ? null : _save,
                    child: _isSaving
                        ? Semantics(
                            label: 'Saving settings',
                            child: const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final nextSettings = KjcSettings(
      nativeLanguage: _language,
      openaiModel: _model,
    );
    final replacement = _apiKeyController.text.trim();
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final apiKeyNotifier = ref.read(apiKeyProvider.notifier);
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await settingsNotifier.update(nextSettings);
      if (replacement.isNotEmpty) {
        try {
          await apiKeyNotifier.write(replacement);
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _errorMessage =
                'Preferences saved, but the API key could not be updated. '
                'Please try again.';
          });
          return;
        }
      }
      if (!mounted) return;
      if (replacement.isNotEmpty) {
        _apiKeyController.clear();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved.')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not save settings. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearApiKey() async {
    if (_isSaving) return;
    final apiKeyNotifier = ref.read(apiKeyProvider.notifier);
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await apiKeyNotifier.clear();
      if (!mounted) return;
      _apiKeyController.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not clear the API key. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
