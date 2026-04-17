import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../data/services/audio_handler.dart';
import '../../data/services/library_service.dart';
import '../../data/services/storage_service.dart';

/// Holds the singleton audio handler, set once in main().
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
  SongsNotifier(this._lib, this._storage) : super(const AsyncValue.loading()) {
    refresh();
  }

  final LibraryService _lib;
  final StorageService _storage;

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
    } catch (e, st) {
      // Log but don\'t crash — show empty library
      // ignore: avoid_print
      print('Song scan failed: $e\n$st');
      state = const AsyncValue.data([]);
    }
  }
}

final songsProvider =
    StateNotifierProvider<SongsNotifier, AsyncValue<List<Song>>>(
  (ref) => SongsNotifier(
    ref.watch(libraryServiceProvider),
    ref.watch(storageServiceProvider),
  ),
);

// ============================================================================
// Playlists
// ============================================================================

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  PlaylistsNotifier(this._storage) : super([]) {
    _load();
    _storage.playlists.listenable().addListener(_load);
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
// Smart playlists derived from play stats
// ============================================================================

final favoriteIdsProvider = Provider<List<int>>(
  (ref) => ref.watch(storageServiceProvider).favoriteIds(),
);

final mostPlayedProvider = Provider<List<Song>>((ref) {
  final ids = ref.watch(storageServiceProvider).mostPlayedIds();
  final songs = ref.watch(songsProvider).valueOrNull ?? [];
  final map = {for (final s in songs) s.id: s};
  return [for (final id in ids) if (map[id] != null) map[id]!];
});

final recentlyPlayedProvider = Provider<List<Song>>((ref) {
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

// ============================================================================
// Now Playing - exposes audio_service state for UI
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
    state = next;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref.watch(storageServiceProvider)),
);
