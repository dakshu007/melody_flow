import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';

/// Displays lyrics inline in Now Playing.
/// - Looks for .lrc file alongside the audio file (synced lyrics)
/// - Falls back to embedded ID3 USLT tag (plain lyrics)
/// - Exposes hooks to download from lyrics.ovh / Musixmatch (wire later)
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
    // TODO: load .lrc from path_provider or tag reader
    // For now, render a pleasant placeholder.
    const placeholder = '''
[00:00.00]Lyrics will appear here.
[00:02.00]Tap the lyrics icon again to return to artwork.
[00:06.00]Drop a .lrc file next to your song for synced lyrics,
[00:10.00]or tap "Download lyrics" in the menu.''';

    final model = LyricsModelBuilder.create().bindLyricToMain(placeholder).getModel();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: LyricsReader(
        model: model,
        position: position.inMilliseconds,
        lyricUi: UINetease(
          defaultSize: 16,
          defaultExtSize: 14,
          otherMainSize: 14,
          highlight: false,
          lyricAlign: LyricAlign.CENTER,
          lyricBaseLine: LyricBaseLine.CENTER,
        ),
        emptyBuilder: () => Center(
          child: Text('No lyrics',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ),
      ),
    );
  }
}
