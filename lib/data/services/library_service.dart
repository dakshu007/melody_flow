import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/song.dart';

/// Wraps on_audio_query to give the rest of the app a clean interface
/// over MediaStore: request permission, scan, and fetch album/artist/genre lists.
class LibraryService {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  final OnAudioQuery _query = OnAudioQuery();

  /// Request the right permission for the running Android version.
  Future<bool> requestPermission() async {
    // Android 13+ uses READ_MEDIA_AUDIO
    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;
    // Fallback for older Android versions
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<bool> hasPermission() async {
    return await _query.permissionsStatus();
  }

  /// Query all songs with optional filtering.
  ///
  /// [minDurationSec] removes short ringtones / notification sounds.
  Future<List<Song>> fetchAllSongs({
    int minDurationSec = 30,
    List<String> excludedFolders = const [],
    SongSortType sortType = SongSortType.TITLE,
    OrderType order = OrderType.ASC_OR_SMALLER,
  }) async {
    final rawSongs = await _query.querySongs(
      sortType: sortType,
      orderType: order,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return rawSongs
        .where((s) => (s.duration ?? 0) >= minDurationSec * 1000)
        .where((s) {
          if (excludedFolders.isEmpty || s.data == null) return true;
          return !excludedFolders.any((f) => s.data!.startsWith(f));
        })
        .map(Song.fromSongModel)
        .toList();
  }

  Future<List<AlbumModel>> fetchAlbums() => _query.queryAlbums(
        sortType: AlbumSortType.ALBUM,
        orderType: OrderType.ASC_OR_SMALLER,
      );

  Future<List<ArtistModel>> fetchArtists() => _query.queryArtists(
        sortType: ArtistSortType.ARTIST,
        orderType: OrderType.ASC_OR_SMALLER,
      );

  Future<List<GenreModel>> fetchGenres() => _query.queryGenres(
        sortType: GenreSortType.GENRE,
        orderType: OrderType.ASC_OR_SMALLER,
      );

  Future<List<String>> fetchFolders() async {
    final songs = await _query.querySongs();
    final folders = <String>{};
    for (final s in songs) {
      if (s.data == null) continue;
      final idx = s.data!.lastIndexOf('/');
      if (idx > 0) folders.add(s.data!.substring(0, idx));
    }
    return folders.toList()..sort();
  }

  Future<List<Song>> songsFromAlbum(int albumId) async {
    final r = await _query.queryAudiosFrom(AudiosFromType.ALBUM_ID, albumId);
    return r.map(Song.fromSongModel).toList();
  }

  Future<List<Song>> songsFromArtist(int artistId) async {
    final r = await _query.queryAudiosFrom(AudiosFromType.ARTIST_ID, artistId);
    return r.map(Song.fromSongModel).toList();
  }

  Future<List<Song>> songsFromGenre(int genreId) async {
    final r = await _query.queryAudiosFromGenreId(genreId);
    return r.map(Song.fromSongModel).toList();
  }

  OnAudioQuery get raw => _query;
}
