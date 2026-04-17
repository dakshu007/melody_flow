import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/playlist.dart';
import '../../providers/app_providers.dart';
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
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.queue_music_rounded,
                        size: 48, color: Theme.of(context).dividerColor),
                    const SizedBox(height: 8),
                    const Text('No playlists yet — tap + to create one'),
                  ],
                ),
              ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
      subtitle: Text('${playlist.songCount} songs'),
      trailing: smart
          ? null
          : PopupMenuButton(
              icon: const Icon(Icons.more_vert_rounded),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                const PopupMenuItem(value: 'export', child: Text('Export .m3u')),
              ],
              onSelected: (v) {
                if (v == 'delete') {
                  ref.read(playlistsProvider.notifier).delete(playlist.id);
                }
                // rename + export: wire in v1.1
              },
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
        ),
      ),
    );
  }
}
