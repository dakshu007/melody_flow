import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/song.dart';

class SongInfoSheet extends StatelessWidget {
  final Song song;
  const SongInfoSheet({super.key, required this.song});

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => SongInfoSheet(song: song),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int ms) {
    final m = (ms ~/ 60000);
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDate(int epoch) {
    if (epoch == 0) return 'Unknown';
    final d = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    return DateFormat('MMM d, yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text('Song info',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),
            _row('Title', song.title),
            _row('Artist', song.artist),
            _row('Album', song.album),
            if (song.genre != null && song.genre!.isNotEmpty) _row('Genre', song.genre!),
            if (song.composer != null && song.composer!.isNotEmpty) _row('Composer', song.composer!),
            if (song.track != null) _row('Track', '#${song.track}'),
            _row('Duration', _formatDuration(song.duration)),
            _row('Size', _formatBytes(song.size)),
            _row('Added', _formatDate(song.dateAdded)),
            if (song.data != null)
              _row('Location', song.data!, monospace: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
