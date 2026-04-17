import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../providers/app_providers.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueStreamProvider).valueOrNull ?? [];
    final current = ref.watch(mediaItemStreamProvider).valueOrNull;
    final handler = ref.read(audioHandlerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtl) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text('Playing queue',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Text('${queue.length} songs',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: scrollCtl,
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: queue.length,
                  onReorder: (from, to) {
                    final adjusted = to > from ? to - 1 : to;
                    handler.moveInQueue(from, adjusted);
                  },
                  itemBuilder: (_, i) {
                    final item = queue[i];
                    final songId = item.extras?['songId'] as int?;
                    final isCurrent = current?.id == item.id;
                    return Dismissible(
                      key: ValueKey('q_${item.id}_$i'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => handler.removeQueueItemAt(i),
                      background: Container(
                        color: Colors.redAccent,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        leading: songId != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: QueryArtworkWidget(
                                  id: songId,
                                  type: ArtworkType.AUDIO,
                                  artworkBorder: BorderRadius.circular(6),
                                  artworkWidth: 44,
                                  artworkHeight: 44,
                                  nullArtworkWidget: _fallback(context),
                                ),
                              )
                            : _fallback(context),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          item.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle_rounded),
                        ),
                        onTap: () => handler.skipToQueueItem(i),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fallback(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.music_note_rounded, size: 20),
      );
}
