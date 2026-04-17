import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Shows a bottom sheet listing all user playlists. Tap one to add [songId].
/// Also has a "Create new" row that prompts for a name and then adds.
class PlaylistPickerSheet extends ConsumerWidget {
  final int songId;
  const PlaylistPickerSheet({super.key, required this.songId});

  static void show(BuildContext context, int songId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PlaylistPickerSheet(songId: songId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).where((p) => !p.isSmart).toList();

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('Add to playlist',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline_rounded),
            title: const Text('Create new playlist'),
            onTap: () async {
              Navigator.pop(context);
              final name = await _promptForName(context);
              if (name != null && name.trim().isNotEmpty) {
                ref.read(playlistsProvider.notifier).create(name.trim());
                // Find the newly-created playlist and add this song
                final fresh = ref.read(playlistsProvider);
                final newOne = fresh.firstWhere((p) => p.name == name.trim(),
                    orElse: () => fresh.last);
                ref.read(playlistsProvider.notifier).addSong(newOne.id, songId);
                _toast(context, 'Added to "${newOne.name}"');
              }
            },
          ),
          const Divider(height: 1),
          Flexible(
            child: playlists.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No playlists yet.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (_, i) {
                      final p = playlists[i];
                      final alreadyIn = p.songIds.contains(songId);
                      return ListTile(
                        leading: Icon(alreadyIn
                            ? Icons.check_circle_rounded
                            : Icons.queue_music_rounded),
                        title: Text(p.name),
                        subtitle: Text('${p.songCount} songs'),
                        enabled: !alreadyIn,
                        onTap: () {
                          ref
                              .read(playlistsProvider.notifier)
                              .addSong(p.id, songId);
                          Navigator.pop(context);
                          _toast(context, 'Added to "${p.name}"');
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<String?> _promptForName(BuildContext context) {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}
