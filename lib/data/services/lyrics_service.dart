import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of a lyrics fetch.
class LyricsResult {
  final String? text;
  final bool isSynced; // true = has timestamps (.lrc format)
  final String source; // 'local', 'ovh', 'cache', 'none'

  const LyricsResult({
    this.text,
    this.isSynced = false,
    this.source = 'none',
  });

  bool get hasLyrics => text != null && text!.trim().isNotEmpty;

  static const empty = LyricsResult();
}

/// Looks up lyrics for a song.
///
/// Priority:
///   1. `.lrc` file next to the audio file (synced)
///   2. On-disk cache (previously downloaded)
///   3. api.lyrics.ovh (free, no key)
///
/// Gracefully returns empty on any failure — users see "No lyrics" instead of a crash.
class LyricsService {
  LyricsService._();
  static final LyricsService instance = LyricsService._();

  Directory? _cacheDir;

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'lyrics_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  String _cacheKey(String title, String artist) {
    final t = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final a = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${a}__$t';
  }

  /// Fetch lyrics for a song. [filePath] is the audio file location (if known),
  /// used to look for a co-located `.lrc` file.
  Future<LyricsResult> fetchLyrics({
    required String title,
    required String artist,
    String? filePath,
  }) async {
    // 1. Check co-located .lrc file
    if (filePath != null && !filePath.startsWith('content://')) {
      try {
        final lrcPath = p.setExtension(filePath, '.lrc');
        final lrcFile = File(lrcPath);
        if (await lrcFile.exists()) {
          final content = await lrcFile.readAsString();
          if (content.trim().isNotEmpty) {
            return LyricsResult(
              text: content,
              isSynced: _looksSynced(content),
              source: 'local',
            );
          }
        }
      } catch (_) {
        // ignore — fall through
      }
    }

    // 2. Check cache
    try {
      final dir = await _getCacheDir();
      final cached = File(p.join(dir.path, '${_cacheKey(title, artist)}.txt'));
      if (await cached.exists()) {
        final content = await cached.readAsString();
        if (content.trim().isNotEmpty) {
          return LyricsResult(
            text: content,
            isSynced: _looksSynced(content),
            source: 'cache',
          );
        }
      }
    } catch (_) {}

    // 3. api.lyrics.ovh — free, no API key required
    try {
      final safeArtist = Uri.encodeComponent(_stripNoise(artist));
      final safeTitle = Uri.encodeComponent(_stripNoise(title));
      final url = Uri.parse(
          'https://api.lyrics.ovh/v1/$safeArtist/$safeTitle');

      final resp = await http
          .get(url)
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final text = (data['lyrics'] as String?)?.trim();
        if (text != null && text.isNotEmpty) {
          // cache it
          try {
            final dir = await _getCacheDir();
            final cached =
                File(p.join(dir.path, '${_cacheKey(title, artist)}.txt'));
            await cached.writeAsString(text);
          } catch (_) {}
          return LyricsResult(text: text, isSynced: false, source: 'ovh');
        }
      }
    } catch (_) {
      // network timeout / no connectivity / not found -> empty
    }

    return LyricsResult.empty;
  }

  /// Heuristic: is this content an .lrc (synced) or plain text?
  bool _looksSynced(String s) =>
      RegExp(r'\[\d{2}:\d{2}[.:]\d{2,3}\]').hasMatch(s);

  /// Strip "(Official Video)", "[Audio]", etc. from titles for better matching.
  String _stripNoise(String input) {
    return input
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Let users manually clear cached lyrics from Settings (optional).
  Future<void> clearCache() async {
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _cacheDir = null;
    } catch (_) {}
  }
}
