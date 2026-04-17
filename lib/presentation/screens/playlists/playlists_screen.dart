import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/playlist.dart';
import '../../../data/models/song.dart';
import '../../providers/app_providers.dart';
import '../../widgets/collection_quick_actions.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final smart = playlists.where((p) => p.isSmart).toList();
    final user = playlists.where((p) => !p.isSmart).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          if (smart.isNotEmpty) ...[
            const _SectionHeader('Smart playlists'),
            ...smart.map((p) => _PlaylistTile(playlist: p, smart: true)),
          ],
          const _SectionHeader('Your playlists'),
          if (user.isEmpty)
            EmptyState.noPlaylists(
              onCreate: () => _showCreateDialog(context, ref),
            )
          else
            ...user.map((p) => _PlaylistTile(playlist: p, smart: false)),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (ctl.text.trim().isNotEmpty) {
                ref.read(playlistsProvider.notifier).create(ctl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.bodySmall?.color,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  final Playlist playlist;
  final bool smart;
  const _PlaylistTile({required this.playlist, required this.smart});

  IconData _iconForSmart(String name) {
    switch (name) {
      case 'Favorites':
        return Icons.favorite_rounded;
      case 'Most Played':
        return Icons.local_fire_department_rounded;
      case 'Recently Played':
        return Icons.history_rounded;
      case 'Recently Added':
        return Icons.new_releases_rounded;
      default:
        return Icons.queue_music_rounded;
    }
  }

  Future<List<Song>> _resolveSongs(WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    final allSongs = ref.read(songsProvider).valueOrNull ?? [];
    final map = {for (final s in allSongs) s.id: s};

    if (smart) {
      switch (playlist.id) {
        case 'smart_favorites':
          return storage.favoriteIds()
              .map((id) => map[id])
              .whereType<Song>()
              .toList();
        case 'smart_most_played':
          return ref.read(mostPlayedProvider);
        case 'smart_recently_played':
          return ref.read(recentlyPlayedProvider);
        case 'smart_recently_added':
          return ref.read(recentlyAddedProvider);
      }
    }
    return playlist.songIds
        .map((id) => map[id])
        .whereType<Song>()
        .toList();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete playlist?',
      message:
          '"${playlist.name}" will be permanently removed. The songs in it will stay in your library.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
    );
    if (ok == true) {
      ref.read(playlistsProvider.notifier).delete(playlist.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Deleted "${playlist.name}"'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final ctl = TextEditingController(text: playlist.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename playlist'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      ref.read(playlistsProvider.notifier).rename(playlist.id, newName.trim());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Song>>(
      future: _resolveSongs(ref),
      builder: (context, snap) {
        final songs = snap.data ?? const <Song>[];
        final subtitle = songs.isEmpty
            ? '${playlist.songCount} songs'
            : Format.listSummary(songs);

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              smart ? _iconForSmart(playlist.name) : Icons.queue_music_rounded,
              size: 26,
            ),
          ),
          title: Text(playlist.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          trailing: smart
              ? null
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (v) {
                    if (v == 'rename') _showRenameDialog(context, ref);
                    if (v == 'delete') _confirmDelete(context, ref);
                  },
                ),
          onTap: () {
            Haptics.light();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
              ),
            );
          },
          onLongPress: () {
            CollectionQuickActions.show(
              context,
              title: playlist.name,
              subtitle: subtitle,
              leadingIcon: smart
                  ? _iconForSmart(playlist.name)
                  : Icons.queue_music_rounded,
              loadSongs: () => _resolveSongs(ref),
              onDelete: smart ? null : () => _confirmDelete(context, ref),
            );
          },
        );
      },
    );
  }
}
