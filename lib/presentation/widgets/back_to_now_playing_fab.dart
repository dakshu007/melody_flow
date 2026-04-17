import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/haptics.dart';
import '../providers/app_providers.dart';
import '../screens/now_playing/now_playing_screen.dart';

/// A small pill FAB that shows "Now Playing" and bounces in
/// when audio is active but the user isn't on the player screen.
///
/// Tap → opens the full Now Playing screen.
class BackToNowPlayingFab extends ConsumerWidget {
  const BackToNowPlayingFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(mediaItemStreamProvider).valueOrNull;
    final playback = ref.watch(playbackStateStreamProvider).valueOrNull;

    if (mediaItem == null) return const SizedBox.shrink();
    final isPlaying = playback?.playing ?? false;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      offset: Offset.zero,
      child: FloatingActionButton.extended(
        heroTag: 'back_to_now_playing',
        onPressed: () {
          Haptics.light();
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, a, __) =>
                  FadeTransition(opacity: a, child: const NowPlayingScreen()),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: Icon(isPlaying ? Icons.music_note_rounded : Icons.pause_rounded),
        label: const Text('Now playing',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
