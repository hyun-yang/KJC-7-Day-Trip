import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/providers/line_speaker.dart';
import '../../providers.dart';

class ConversationViewerScreen extends ConsumerStatefulWidget {
  const ConversationViewerScreen({required this.conversationId, super.key});

  final int conversationId;

  @override
  ConsumerState<ConversationViewerScreen> createState() =>
      _ConversationViewerScreenState();
}

class _ConversationViewerScreenState
    extends ConsumerState<ConversationViewerScreen> {
  late final LineSpeaker _lineSpeaker;

  @override
  void initState() {
    super.initState();
    _lineSpeaker = ref.read(lineSpeakerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(conversationDetailProvider(widget.conversationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load this conversation.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(
                      conversationDetailProvider(widget.conversationId),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (value) => _ConversationContent(detail: value),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_lineSpeaker.stop());
    super.dispose();
  }
}

class _ConversationContent extends ConsumerWidget {
  const _ConversationContent({required this.detail});

  final ConversationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = detail.conversation;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.subtopicLabel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${conversation.country.flag} ${conversation.cityName} · '
                        '${conversation.country.labelEn}',
                      ),
                      Text('Model: ${conversation.model}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final line in detail.lines) ...[
                _LineCard(
                  line: line,
                  onListen: () async {
                    try {
                      await ref
                          .read(lineSpeakerProvider)
                          .speak(
                            text: line.targetText,
                            country: conversation.country,
                            speaker: line.speaker,
                          );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Audio is unavailable right now.'),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.onListen});

  final ConvLine line;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final speakerLabel = line.speaker == 1 ? 'Traveler' : 'Local';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    speakerLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    key: ValueKey('listen-${line.lineOrder}'),
                    tooltip:
                        'Listen to line ${line.lineOrder + 1}, $speakerLabel',
                    onPressed: onListen,
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                ),
              ],
            ),
            Text(
              line.targetText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(line.romanization),
            Text(line.transliteration),
            Text(line.translation),
          ],
        ),
      ),
    );
  }
}
