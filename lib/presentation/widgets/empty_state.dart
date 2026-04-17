import 'package:flutter/material.dart';

/// Friendly empty state with an icon, a title, a subtitle, and optional action.
/// Used instead of bare "No songs" text.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  // Common presets
  factory EmptyState.noMusic({VoidCallback? onRefresh}) => EmptyState(
        icon: Icons.music_off_rounded,
        title: 'No music found',
        subtitle:
            'Add songs to your phone and pull down to rescan your library.',
        actionLabel: onRefresh != null ? 'Rescan' : null,
        onAction: onRefresh,
      );

  factory EmptyState.noPlaylists({VoidCallback? onCreate}) => EmptyState(
        icon: Icons.queue_music_rounded,
        title: 'No playlists yet',
        subtitle: 'Create your first playlist to organize your favorite songs.',
        actionLabel: onCreate != null ? 'Create playlist' : null,
        onAction: onCreate,
      );

  factory EmptyState.noSearchResults(String query) => EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        subtitle: 'We couldn\'t find "$query" in your library.',
      );

  factory EmptyState.noFavorites() => const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No favorites yet',
        subtitle: 'Tap the heart on any song to save it here.',
      );

  factory EmptyState.noHistory() => const EmptyState(
        icon: Icons.history_rounded,
        title: 'No history yet',
        subtitle: 'Songs you play will appear here.',
      );

  factory EmptyState.emptyPlaylist() => const EmptyState(
        icon: Icons.playlist_play_rounded,
        title: 'This playlist is empty',
        subtitle: 'Add songs from the library by tapping the 3-dot menu.',
      );

  factory EmptyState.noLyrics() => const EmptyState(
        icon: Icons.lyrics_outlined,
        title: 'No lyrics available',
        subtitle:
            'Place a .lrc file next to this song, or wait for automatic lyrics in the next update.',
      );

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Layered icon: soft circle + icon on top
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 44, color: color.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
