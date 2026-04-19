import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../data/models/song.dart';
import '../../providers/app_providers.dart';
import '../../widgets/artwork_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);
    final recentlyAdded = ref.watch(recentlyAddedProvider);
    final recentlyPlayed = ref.watch(recentlyPlayedProvider);
    final mostPlayed = ref.watch(mostPlayedProvider);

    return Scaffold(
      body: SafeArea(
        child: songsAsync.when(
          loading: () => const ShimmerList(itemCount: 8),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            subtitle: '$e',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(songsProvider),
          ),
          data: (songs) {
            if (songs.isEmpty) {
              return EmptyState.noMusic(
                onRefresh: () => ref.read(songsProvider.notifier).refresh(),
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(songsProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 140),
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  _QuickPicksRow(songs: songs.take(6).toList()),
                  const SizedBox(height: 24),
                  if (recentlyPlayed.isNotEmpty)
                    _SongSection(
                      title: 'Recently played',
                      songs: recentlyPlayed,
                    ),
                  if (mostPlayed.isNotEmpty)
                    _SongSection(title: 'Most played', songs: mostPlayed),
                  _SongSection(
                    title: 'Recently added',
                    songs: recentlyAdded,
                  ),
                  _SongSection(
                    title: 'Your library',
                    songs: songs.take(10).toList(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Text(
            'Good vibes',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FIXED: Quick picks row — was overflowing because SizedBox(180) couldn't fit
// 140px artwork + text + subtitle. Solution: use explicit Column heights that
// sum to the container, ellipsize titles, and give the row enough height.
// ---------------------------------------------------------------------------

class _QuickPicksRow extends ConsumerWidget {
  final List<Song> songs;
  const _QuickPicksRow({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) return const SizedBox.shrink();

    // Artwork 130, gap 8, title ~18, artist ~14 = 170, give container 200 for safety
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final s = songs[i];
          return SizedBox(
            width: 130,
            child: GestureDetector(
              onTap: () => ref
                  .read(audioHandlerProvider)
                  .loadQueue(songs, initialIndex: i),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Artwork
                  ArtworkImage(
                    id: s.id,
                    type: ArtworkType.AUDIO,
                    size: 130,
                    borderRadius: 12,
                  ),
                  const SizedBox(height: 8),
                  // Title — fixed single line with ellipsis
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                  ),
                  const SizedBox(height: 2),
                  // Artist
                  Text(
                    s.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SongSection extends ConsumerWidget {
  final String title;
  final List<Song> songs;
  const _SongSection({required this.title, required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ...songs.take(5).map(
              (s) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: ArtworkImage(
                  id: s.id,
                  type: ArtworkType.AUDIO,
                  size: 48,
                  borderRadius: 6,
                ),
                title: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => ref
                    .read(audioHandlerProvider)
                    .loadQueue(songs, initialIndex: songs.indexOf(s)),
              ),
            ),
      ],
    );
  }
}
