import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';

import '../../../data/services/lyrics_service.dart';

/// Displays lyrics for the currently playing song.
///
/// Tries: local .lrc file → on-disk cache → api.lyrics.ovh
/// Gracefully shows an empty state if nothing is found.
class LyricsPanel extends StatefulWidget {
  final MediaItem mediaItem;
  final Duration position;
  const LyricsPanel({
    super.key,
    required this.mediaItem,
    required this.position,
  });

  @override
  State<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<LyricsPanel> {
  LyricsResult? _result;
  bool _loading = true;
  String? _lastFetchedId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant LyricsPanel old) {
    super.didUpdateWidget(old);
    if (old.mediaItem.id != widget.mediaItem.id) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (_lastFetchedId == widget.mediaItem.id) return;
    _lastFetchedId = widget.mediaItem.id;

    if (!mounted) return;
    setState(() {
      _loading = true;
      _result = null;
    });

    final filePath = widget.mediaItem.extras?['data'] as String?;
    final res = await LyricsService.instance.fetchLyrics(
      title: widget.mediaItem.title,
      artist: widget.mediaItem.artist ?? '',
      filePath: filePath,
    );

    if (!mounted) return;
    setState(() {
      _result = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text('Looking for lyrics…',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          ],
        ),
      );
    }

    final r = _result;
    if (r == null || !r.hasLyrics) {
      return _emptyState();
    }

    if (r.isSynced) {
      // Use flutter_lyric for synced .lrc rendering
      final model = LyricsModelBuilder.create().bindLyricToMain(r.text!).getModel();
      return LyricsReader(
        model: model,
        position: widget.position.inMilliseconds,
        lyricUi: UINetease(
          defaultSize: 16,
          defaultExtSize: 14,
          otherMainSize: 14,
          lyricAlign: LyricAlign.CENTER,
          lyricBaseLine: LyricBaseLine.CENTER,
        ),
        emptyBuilder: () => _emptyState(),
      );
    }

    // Plain text lyrics — auto-scrolling centered display
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        r.text!,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: 16,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lyrics_outlined,
              size: 48, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No lyrics found',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Not available in our lyrics database.\nPlace a .lrc file next to the song for offline lyrics.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
