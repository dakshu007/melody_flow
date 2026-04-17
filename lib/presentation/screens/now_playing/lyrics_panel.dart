import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

/// Shows lyrics for the current song.
/// TODO v1.1: scan for .lrc file in the song's folder and parse it.
/// TODO v1.1: fallback to fetching from api.lyrics.ovh.
/// For v1.0 we show an honest empty state.
class LyricsPanel extends StatelessWidget {
  final MediaItem mediaItem;
  final Duration position;
  const LyricsPanel({
    super.key,
    required this.mediaItem,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined,
                size: 56, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No lyrics available',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Place a .lrc file next to this song, or wait for the\nautomatic lyrics downloader in the next update.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
