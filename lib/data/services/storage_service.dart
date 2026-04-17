import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/play_stats.dart';
import '../models/playlist.dart';
import '../models/song.dart';

/// Single Hive-backed datastore for everything the user creates or configures.
///
/// Boxes:
///   * playlists    (key = playlist.id)
///   * play_stats   (key = songId)
///   * settings     (key = 'main')
///   * queue_backup (key = 'current' -> List<int> song ids)
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _playlistsBox = 'playlists';
  static const _statsBox     = 'play_stats';
  static const _settingsBox  = 'settings';
  static const _queueBox     = 'queue_backup';

  late Box<Playlist>   playlists;
  late Box<PlayStats>  stats;
  late Box<AppSettings> settings;
  late Box             queueBackup;

  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters (generated via build_runner).
    Hive.registerAdapter(SongAdapter());
    Hive.registerAdapter(PlaylistAdapter());
    Hive.registerAdapter(PlayStatsAdapter());
    Hive.registerAdapter(AppSettingsAdapter());

    playlists = await Hive.openBox<Playlist>(_playlistsBox);
    stats     = await Hive.openBox<PlayStats>(_statsBox);
    settings  = await Hive.openBox<AppSettings>(_settingsBox);
    queueBackup = await Hive.openBox(_queueBox);

    // Seed defaults
    if (settings.get('main') == null) {
      await settings.put('main', AppSettings());
    }
    _ensureSmartPlaylists();
  }

  // -------- Settings --------
  AppSettings get currentSettings => settings.get('main') ?? AppSettings();
  Future<void> saveSettings(AppSettings s) => settings.put('main', s);

  // -------- Playlists --------
  final _uuid = const Uuid();

  Playlist createPlaylist(String name, {String? description}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = Playlist(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
      description: description,
    );
    playlists.put(p.id, p);
    return p;
  }

  Future<void> deletePlaylist(String id) => playlists.delete(id);

  Future<void> renamePlaylist(String id, String newName) async {
    final p = playlists.get(id);
    if (p == null) return;
    p.name = newName;
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await p.save();
  }

  Future<void> addSongToPlaylist(String playlistId, int songId) async {
    final p = playlists.get(playlistId);
    if (p == null || p.songIds.contains(songId)) return;
    p.songIds.add(songId);
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await p.save();
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    final p = playlists.get(playlistId);
    if (p == null) return;
    p.songIds.remove(songId);
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await p.save();
  }

  Future<void> reorderSongInPlaylist(String playlistId, int from, int to) async {
    final p = playlists.get(playlistId);
    if (p == null) return;
    final item = p.songIds.removeAt(from);
    p.songIds.insert(to, item);
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await p.save();
  }

  List<Playlist> allPlaylists() =>
      playlists.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Ensure "Favorites", "Recently Added", "Most Played", "Recently Played"
  /// smart playlists exist.
  void _ensureSmartPlaylists() {
    const smartNames = ['Favorites', 'Most Played', 'Recently Played', 'Recently Added'];
    for (final name in smartNames) {
      final exists = playlists.values.any((p) => p.isSmart && p.name == name);
      if (!exists) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final p = Playlist(
          id: 'smart_${name.toLowerCase().replaceAll(' ', '_')}',
          name: name,
          createdAt: now,
          updatedAt: now,
          isSmart: true,
        );
        playlists.put(p.id, p);
      }
    }
  }

  // -------- Play stats --------
  PlayStats statsFor(int songId) =>
      stats.get(songId) ??
      PlayStats(songId: songId);

  Future<void> incrementPlay(int songId) async {
    final s = statsFor(songId);
    s.playCount += 1;
    s.lastPlayed = DateTime.now().millisecondsSinceEpoch;
    await stats.put(songId, s);
  }

  Future<void> toggleFavorite(int songId) async {
    final s = statsFor(songId);
    s.isFavorite = !s.isFavorite;
    await stats.put(songId, s);
  }

  bool isFavorite(int songId) => statsFor(songId).isFavorite;

  List<int> mostPlayedIds({int limit = 50}) {
    final all = stats.values.where((s) => s.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return all.take(limit).map((s) => s.songId).toList();
  }

  List<int> recentlyPlayedIds({int limit = 50}) {
    final all = stats.values.where((s) => s.lastPlayed > 0).toList()
      ..sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    return all.take(limit).map((s) => s.songId).toList();
  }

  List<int> favoriteIds() =>
      stats.values.where((s) => s.isFavorite).map((s) => s.songId).toList();


  // -------- Playback state persistence (shuffle / repeat) --------
  Future<void> saveShuffleMode(bool enabled) =>
      queueBackup.put('shuffle', enabled);
  bool loadShuffleMode() => queueBackup.get('shuffle', defaultValue: false) as bool;

  Future<void> saveRepeatMode(int index) =>
      queueBackup.put('repeat', index);
  int loadRepeatMode() => queueBackup.get('repeat', defaultValue: 0) as int;

  // -------- Queue backup --------
  Future<void> saveQueue(List<int> songIds, int currentIndex) async {
    await queueBackup.put('current', songIds);
    await queueBackup.put('index', currentIndex);
  }

  List<int>? restoreQueueIds() {
    final ids = queueBackup.get('current');
    if (ids is List) return ids.cast<int>();
    return null;
  }

  int restoreQueueIndex() => queueBackup.get('index') as int? ?? 0;
}
