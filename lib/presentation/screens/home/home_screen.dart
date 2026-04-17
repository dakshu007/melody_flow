import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../data/models/song.dart';
import '../../providers/app_providers.dart';

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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: '$e',
            onRetry: () => ref.invalidate(songsProvider),
          ),
          data: (songs) {
            if (songs.isEmpty) {
              return const _EmptyState();
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(songsProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 120),
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

class _QuickPicksRow extends ConsumerWidget {
  final List<Song> songs;
  const _QuickPicksRow({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final s = songs[i];
          return GestureDetector(
            onTap: () => ref
                .read(audioHandlerProvider)
                .loadQueue(songs, initialIndex: i),
            child: SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: QueryArtworkWidget(
                      id: s.id,
                      type: ArtworkType.AUDIO,
                      artworkBorder: BorderRadius.circular(12),
                      artworkWidth: 140,
                      artworkHeight: 140,
                      artworkFit: BoxFit.cover,
                      nullArtworkWidget: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.music_note_rounded, size: 36),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    s.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
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
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: QueryArtworkWidget(
                    id: s.id,
                    type: ArtworkType.AUDIO,
                    artworkBorder: BorderRadius.circular(6),
                    artworkWidth: 48,
                    artworkHeight: 48,
                    artworkFit: BoxFit.cover,
                    nullArtworkWidget: Container(
                      width: 48,
                      height: 48,
                      color: Theme.of(context).dividerColor,
                      child: const Icon(Icons.music_note_rounded),
                    ),
                  ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_rounded,
                size: 64, color: Theme.of(context).dividerColor),
            const SizedBox(height: 16),
            Text(
              'No music yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add songs to your device and pull down to refresh.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
