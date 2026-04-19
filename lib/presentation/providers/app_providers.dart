import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../data/services/audio_handler.dart';
import '../../data/services/library_service.dart';
import '../../data/services/storage_service.dart';

/// Singleton audio handler (set once in main()).
final audioHandlerProvider = Provider<MelodyAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main()');
});

final libraryServiceProvider =
    Provider<LibraryService>((_) => LibraryService.instance);

final storageServiceProvider =
    Provider<StorageService>((_) => StorageService.instance);

// ============================================================================
// Songs
// ============================================================================

class SongsNotifier extends StateNotifier<AsyncValue<List<Song>>> {
  SongsNotifier(this._lib, this._storage, this._handler)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final LibraryService _lib;
  final StorageService _storage;
  final MelodyAudioHandler? _handler;
  bool _queueRestored = false;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final granted = await _lib.requestPermission();
      if (!granted) {
        state = AsyncValue.error(
          'Permission to read audio files was denied.',
          StackTrace.current,
        );
        return;
      }
      final settings = _storage.currentSettings;
      final songs = await _lib.fetchAllSongs(
        minDurationSec: settings.minTrackLengthSec,
        excludedFolders: settings.excludedFolders,
      );
      state = AsyncValue.data(songs);

      // Restore persisted queue once after first successful scan
      if (!_queueRestored && _handler != null) {
        _queueRestored = true;
        final byId = {for (final s in songs) s.id: s};
        await _handler!.restorePersistedState(
          (ids) => ids.map((id) => byId[id]).whereType<Song>().toList(),
        );
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('Song scan failed: $e\n$st');
      state = const AsyncValue.data([]);
    }
  }
}

final songsProvider =
    StateNotifierProvider<SongsNotifier, AsyncValue<List<Song>>>((ref) {
  MelodyAudioHandler? handler;
  try {
    handler = ref.watch(audioHandlerProvider);
  } catch (_) {
    handler = null;
  }
  return SongsNotifier(
    ref.watch(libraryServiceProvider),
    ref.watch(storageServiceProvider),
    handler,
  );
});

// ============================================================================
// Playlists
// ============================================================================

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  PlaylistsNotifier(this._storage) : super([]) {
    _load();
    _storage.playlists.listenable().addListener(_load);
    // ALSO reload when play stats change (affects smart playlist counts)
    _storage.stats.listenable().addListener(_load);
  }

  final StorageService _storage;

  void _load() => state = _storage.allPlaylists();

  void create(String name) {
    _storage.createPlaylist(name);
    _load();
  }

  void delete(String id) {
    _storage.deletePlaylist(id);
    _load();
  }

  void rename(String id, String name) {
    _storage.renamePlaylist(id, name);
    _load();
  }

  void addSong(String id, int songId) {
    _storage.addSongToPlaylist(id, songId);
    _load();
  }

  void removeSong(String id, int songId) {
    _storage.removeSongFromPlaylist(id, songId);
    _load();
  }
}

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<Playlist>>(
  (ref) => PlaylistsNotifier(ref.watch(storageServiceProvider)),
);

// ============================================================================
// Smart playlist derivations — used for BOTH count display and detail screens.
// FIX: Previously smart playlists had empty songIds lists so the count shown
// in Playlists screen was always 0 / wrong. Now we derive both contents and
// counts from the actual sources at render time.
// ============================================================================

final favoriteIdsProvider = Provider<List<int>>((ref) {
  // Watch the play_stats box so counts update when favorites change
  ref.watch(playlistsProvider);
  return ref.watch(storageServiceProvider).favoriteIds();
});

final mostPlayedProvider = Provider<List<Song>>((ref) {
  ref.watch(playlistsProvider); // rebuild on stats change
  final ids = ref.watch(storageServiceProvider).mostPlayedIds();
  final songs = ref.watch(songsProvider).valueOrNull ?? [];
  final map = {for (final s in songs) s.id: s};
  return [for (final id in ids) if (map[id] != null) map[id]!];
});

final recentlyPlayedProvider = Provider<List<Song>>((ref) {
  ref.watch(playlistsProvider);
  final ids = ref.watch(storageServiceProvider).recentlyPlayedIds();
  final songs = ref.watch(songsProvider).valueOrNull ?? [];
  final map = {for (final s in songs) s.id: s};
  return [for (final id in ids) if (map[id] != null) map[id]!];
});

final recentlyAddedProvider = Provider<List<Song>>((ref) {
  final songs = ref.watch(songsProvider).valueOrNull ?? [];
  final copy = [...songs]..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
  return copy.take(50).toList();
});

/// Count for a smart playlist given its id. Used by the playlists tile.
int smartPlaylistCount(WidgetRef ref, String smartId) {
  switch (smartId) {
    case 'smart_favorites':
      return ref.watch(favoriteIdsProvider).length;
    case 'smart_most_played':
      return ref.watch(mostPlayedProvider).length;
    case 'smart_recently_played':
      return ref.watch(recentlyPlayedProvider).length;
    case 'smart_recently_added':
      return ref.watch(recentlyAddedProvider).length;
  }
  return 0;
}

/// Resolved songs for a smart playlist.
List<Song> smartPlaylistSongs(WidgetRef ref, String smartId) {
  final songs = ref.watch(songsProvider).valueOrNull ?? [];
  final map = {for (final s in songs) s.id: s};
  switch (smartId) {
    case 'smart_favorites':
      final ids = ref.watch(favoriteIdsProvider);
      return [for (final id in ids) if (map[id] != null) map[id]!];
    case 'smart_most_played':
      return ref.watch(mostPlayedProvider);
    case 'smart_recently_played':
      return ref.watch(recentlyPlayedProvider);
    case 'smart_recently_added':
      return ref.watch(recentlyAddedProvider);
  }
  return const [];
}

// ============================================================================
// Now Playing
// ============================================================================

final playbackStateStreamProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(audioHandlerProvider).playbackState,
);

final mediaItemStreamProvider = StreamProvider<MediaItem?>(
  (ref) => ref.watch(audioHandlerProvider).mediaItem,
);

final queueStreamProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(audioHandlerProvider).queue,
);

final positionStreamProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioHandlerProvider).positionStream,
);

final sleepTimerProvider = StreamProvider<Duration?>(
  (ref) => ref.watch(audioHandlerProvider).sleepTimerRemainingStream,
);

// ============================================================================
// Settings
// ============================================================================

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._storage) : super(_storage.currentSettings);
  final StorageService _storage;

  void update(AppSettings Function(AppSettings current) f) {
    final next = f(state);
    _storage.saveSettings(next);
    // Create a new object reference so ConsumerWidgets rebuild.
    state = AppSettings(
      themeMode: next.themeMode,
      accentColorValue: next.accentColorValue,
      useMaterialYou: next.useMaterialYou,
      dynamicColorFromArtwork: next.dynamicColorFromArtwork,
      songSort: next.songSort,
      sortAscending: next.sortAscending,
      crossfadeMs: next.crossfadeMs,
      gaplessPlayback: next.gaplessPlayback,
      fadeInOut: next.fadeInOut,
      replayGainEnabled: next.replayGainEnabled,
      sleepTimerDefaultMin: next.sleepTimerDefaultMin,
      minTrackLengthSec: next.minTrackLengthSec,
      excludedFolders: List.of(next.excludedFolders),
      artistSeparator: next.artistSeparator,
      genreSeparator: next.genreSeparator,
      nowPlayingTheme: next.nowPlayingTheme,
      showLyricsButton: next.showLyricsButton,
      shuffleOnStart: next.shuffleOnStart,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref.watch(storageServiceProvider)),
);
