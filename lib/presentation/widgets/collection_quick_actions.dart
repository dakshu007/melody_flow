import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/haptics.dart';
import '../../data/models/song.dart';
import '../providers/app_providers.dart';

/// Quick-action bottom sheet shown when a user long-presses a collection
/// (album, artist, playlist, folder, genre). Offers Play, Shuffle, Play Next,
/// Add to Queue, and Add to Playlist.
class CollectionQuickActions extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final IconData leadingIcon;
  final Future<List<Song>> Function() loadSongs;
  final VoidCallback? onDelete; // for playlists

  const CollectionQuickActions({
    super.key,
    required this.title,
    required this.leadingIcon,
    required this.loadSongs,
    this.subtitle,
    this.onDelete,
  });

  static void show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData leadingIcon,
    required Future<List<Song>> Function() loadSongs,
    VoidCallback? onDelete,
  }) {
    Haptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CollectionQuickActions(
        title: title,
        subtitle: subtitle,
        leadingIcon: leadingIcon,
        loadSongs: loadSongs,
        onDelete: onDelete,
      ),
    );
  }

  Future<void> _play(BuildContext context, WidgetRef ref,
      {bool shuffle = false}) async {
    final songs = await loadSongs();
    if (songs.isEmpty) return;
    final ordered = shuffle ? ([...songs]..shuffle()) : songs;
    ref.read(audioHandlerProvider).loadQueue(ordered);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _enqueue(BuildContext context, WidgetRef ref,
      {bool playNext = false}) async {
    final songs = await loadSongs();
    if (songs.isEmpty) return;
    final handler = ref.read(audioHandlerProvider);
    for (final s in songs) {
      if (playNext) {
        await handler.playNext(s);
      } else {
        await handler.addToQueue(s);
      }
    }
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            playNext ? 'Will play next' : '${songs.length} songs added to queue'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 12),
          // Header
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(leadingIcon,
                  color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: subtitle != null ? Text(subtitle!) : null,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('Play'),
            onTap: () {
              Haptics.light();
              _play(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.shuffle_rounded),
            title: const Text('Shuffle'),
            onTap: () {
              Haptics.light();
              _play(context, ref, shuffle: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_play_next_rounded),
            title: const Text('Play next'),
            onTap: () {
              Haptics.light();
              _enqueue(context, ref, playNext: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: const Text('Add to queue'),
            onTap: () {
              Haptics.light();
              _enqueue(context, ref);
            },
          ),
          if (onDelete != null) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Haptics.heavy();
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
