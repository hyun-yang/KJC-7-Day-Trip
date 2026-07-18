import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/generation_selection.dart';
import '../../domain/providers/online_text_gen_exception.dart';
import '../../providers.dart';
import 'conversation_viewer_screen.dart';
import '../settings/settings_screen.dart';

class GenerationScreen extends ConsumerStatefulWidget {
  const GenerationScreen({required this.selection, super.key});

  final GenerationSelection selection;

  @override
  ConsumerState<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends ConsumerState<GenerationScreen> {
  bool _isGenerating = false;
  String? _errorMessage;
  bool _needsApiKey = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create conversation')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.selection.subtopic.labelEn,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.selection.city.nameEn} · '
                    '${widget.selection.category.labelEn}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage case final message?) ...[
                    Text(
                      message,
                      key: const ValueKey('generation-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isGenerating ? null : _generate,
                      child: const Text('Retry'),
                    ),
                    if (_needsApiKey) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _isGenerating
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Open Settings'),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isGenerating ? null : _generate,
                      icon: _isGenerating
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _isGenerating
                            ? 'Generating conversation…'
                            : 'Generate Conversation',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _needsApiKey = false;
    });

    try {
      final id = await ref.read(generationActionProvider)(widget.selection);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ConversationViewerScreen(conversationId: id),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _needsApiKey = error is ApiKeyMissingException;
        _errorMessage = switch (error) {
          ApiKeyMissingException() =>
            'Configure your OpenAI API key in Settings, then try again.',
          OnlineTextGenException() => error.userMessage,
          FormatException() =>
            'The provider returned an invalid response. Please try again.',
          _ => 'Could not generate the conversation. Please try again.',
        };
      });
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
