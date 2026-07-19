import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/conversation.dart';
import '../../providers.dart';
import '../generation/conversation_viewer_screen.dart';
import '../settings/settings_screen.dart';
import '../theme/atlas_theme.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final Set<int> _pendingDeleteIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    return Scaffold(
      backgroundColor: AtlasTheme.background,
      appBar: AppBar(
        title: const Text(
          'Saved Conversations',
          style: TextStyle(
            color: AtlasTheme.heading,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: conversations.when(
          loading: () => Center(
            child: Semantics(
              label: 'Loading saved conversations',
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load saved conversations.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(conversationsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (items) => items.isEmpty
              ? const Center(child: Text('No saved conversations yet.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Material(
                        key: const ValueKey('saved-list-surface'),
                        color: AtlasTheme.paper,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AtlasTheme.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AtlasTheme.line),
                          itemBuilder: (context, index) {
                            final conversation = items[index];
                            return _ConversationRow(
                              conversation: conversation,
                              onOpen: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ConversationViewerScreen(
                                    conversationId: conversation.id!,
                                  ),
                                ),
                              ),
                              onDelete: () =>
                                  _confirmDelete(context, ref, conversation),
                              isDeleting: _pendingDeleteIds.contains(
                                conversation.id,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Conversation conversation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
          'Delete “${conversation.subtopicLabel}” from saved conversations?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _delete(context, ref, conversation.id!);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int id) async {
    if (_pendingDeleteIds.contains(id)) return;
    setState(() => _pendingDeleteIds.add(id));
    try {
      await ref.read(deleteConversationProvider)(id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete this conversation.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _delete(context, ref, id),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pendingDeleteIds.remove(id));
    }
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.onOpen,
    required this.onDelete,
    required this.isDeleting,
  });

  final Conversation conversation;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final date = conversation.createdAt;
    final dateLabel =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final trimmedPlace = conversation.placeName?.trim();
    final placeName = trimmedPlace == null || trimmedPlace.isEmpty
        ? null
        : trimmedPlace;
    final locationLabel = placeName == null
        ? conversation.cityName
        : '$placeName, ${conversation.cityName}';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 96),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              enabled: !isDeleting,
              label: 'Open ${conversation.subtopicLabel} at $locationLabel',
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('saved-conversation-${conversation.id}'),
                onTap: isDeleting ? null : onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.subtopicLabel,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AtlasTheme.heading,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 7),
                      if (placeName != null) ...[
                        Text(
                          placeName,
                          key: ValueKey('saved-place-${conversation.id}'),
                          style: const TextStyle(
                            color: AtlasTheme.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        conversation.cityName,
                        style: const TextStyle(color: AtlasTheme.heading),
                      ),
                      Text(
                        '${conversation.country.flag} '
                        '${conversation.country.labelEn}',
                        style: const TextStyle(color: AtlasTheme.muted),
                      ),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: AtlasTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              enabled: !isDeleting,
              label: 'Delete ${conversation.subtopicLabel}',
              excludeSemantics: true,
              child: SizedBox.square(
                dimension: 48,
                child: IconButton(
                  key: ValueKey('delete-conversation-${conversation.id}'),
                  tooltip: 'Delete ${conversation.subtopicLabel}',
                  color: AtlasTheme.muted,
                  onPressed: isDeleting ? null : onDelete,
                  icon: isDeleting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
