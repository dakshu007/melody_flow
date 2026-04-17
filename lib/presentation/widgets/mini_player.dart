import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../providers/app_providers.dart';
import '../screens/now_playing/now_playing_screen.dart';
import 'artwork_image.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaItem = ref.watch(mediaItemStreamProvider).valueOrNull;
    final playback = ref.watch(playbackStateStreamProvider).valueOrNull;
    final position = ref.watch(positionStreamProvider).valueOrNull ?? Duration.zero;

    if (mediaItem == null) return const SizedBox.shrink();

    final duration = mediaItem.duration ?? Duration.zero;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, a, __) =>
                FadeTransition(opacity: a, child: const NowPlayingScreen()),
            transitionDuration: const Duration(milliseconds: 320),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _artwork(mediaItem),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 18,
                          child: _scrollOrTruncate(
                            mediaItem.title,
                            theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600) ??
                                const TextStyle(),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mediaItem.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      (playback?.playing ?? false)
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 30,
                    ),
                    onPressed: () {
                      final handler = ref.read(audioHandlerProvider);
                      (playback?.playing ?? false)
                          ? handler.pause()
                          : handler.play();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 28),
                    onPressed: () =>
                        ref.read(audioHandlerProvider).skipToNext(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scrollOrTruncate(String text, TextStyle style) {
    // Marquee only if title is long (>28 chars)
    if (text.length <= 28) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return Marquee(
      text: text,
      style: style,
      velocity: 28,
      blankSpace: 40,
      pauseAfterRound: const Duration(seconds: 2),
      startPadding: 0,
    );
  }

  Widget _artwork(MediaItem item) {
    final songId = item.extras?['songId'] as int?;
    if (songId == null) return const _ArtFallback();
    return ArtworkImage(
      id: songId,
      type: ArtworkType.AUDIO,
      size: 44,
      borderRadius: 8,
    );
  }
}

class _ArtFallback extends StatelessWidget {
  const _ArtFallback();
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note_rounded, size: 22),
      );
}
