import '../../data/models/song.dart';

/// Formats durations, counts, and list stats used across the app.
class Format {
  Format._();

  /// Short: "3:42"  /  Long: "1:03:42"
  static String duration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (d.inHours > 0) return '${d.inHours}:${two(m)}:${two(s)}';
    return '$m:${two(s)}';
  }

  /// Summary for album/playlist/artist headers.
  /// e.g. "42 songs · 2 hr 18 min"
  ///      "3 songs · 11 min"
  ///      "1 song · 3:42"
  static String listSummary(List<Song> songs) {
    if (songs.isEmpty) return 'No songs';
    final total = songs.fold<Duration>(
      Duration.zero,
      (acc, s) => acc + Duration(milliseconds: s.duration),
    );
    final countLabel = songs.length == 1 ? '1 song' : '${songs.length} songs';
    return '$countLabel · ${prettyDuration(total)}';
  }

  /// Human-friendly duration:
  /// "42 sec" / "3 min" / "1 hr 24 min" / "12 hr"
  static String prettyDuration(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      if (m == 0) return '$h hr';
      return '$h hr $m min';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes} min';
    }
    return '${d.inSeconds} sec';
  }

  /// File-size formatter
  static String bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
