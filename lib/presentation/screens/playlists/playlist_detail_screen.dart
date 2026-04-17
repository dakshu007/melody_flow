import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/song.dart';
import '../../providers/app_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/song_tile.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  List<Song> _resolveSongs(WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final allSongs = ref.watch(songsProvider).valueOrNull ?? [];
    final map = {for (final s in allSongs) s.id: s};

    if (playlistId.startsWith('smart_')) {
      switch (playlistId) {
        case 'smart_favorites':
          return storage.favoriteIds()
              .map((id) => map[id])
              .whereType<Song>()
              .toList();
        case 'smart_most_played':
          return ref.watch(mostPlayedProvider);
        case 'smart_recently_played':
          return ref.watch(recentlyPlayedProvider);
        case 'smart_recently_added':
          return ref.watch(recentlyAddedProvider);
      }
    }
    final p = storage.playlists.get(playlistId);
    if (p == null) return [];
    return p.songIds.map((id) => map[id]).whereType<Song>().toList();
  }

  String _smartName(String id) => switch (id) {
        'smart_favorites' => 'Favorites',
        'smart_most_played' => 'Most Played',
        'smart_recently_played' => 'Recently Played',
        'smart_recently_added' => 'Recently Added',
        _ => 'Playlist',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final playlist = storage.playlists.get(playlistId);
    final songs = _resolveSongs(ref);
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      body: songs.isEmpty
          ? CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 140,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      playlistId.startsWith('smart_')
                          ? _smartName(playlistId)
                          : (playlist?.name ?? 'Playlist'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  child: EmptyState.emptyPlaylist(),
                ),
              ],
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      playlistId.startsWith('smart_')
                          ? _smartName(playlistId)
                          : (playlist?.name ?? 'Playlist'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    background: Container(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      child: Center(
                        child: Icon(
                          Icons.queue_music_rounded,
                          size: 80,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A6: duration total on header
                        Text(
                          Format.listSummary(songs),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color:
                                    Theme.of(context).textTheme.bodySmall?.color,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play'),
                                onPressed: () {
                                  Haptics.medium();
                                  handler.loadQueue(songs);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.shuffle_rounded),
                                label: const Text('Shuffle'),
                                onPressed: () {
                                  Haptics.medium();
                                  final shuffled = [...songs]..shuffle();
                                  handler.loadQueue(shuffled);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: songs.length,
                  itemBuilder: (_, i) => SongTile(
                    song: songs[i],
                    onTap: () {
                      Haptics.light();
                      handler.loadQueue(songs, initialIndex: i);
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
    );
  }
}
