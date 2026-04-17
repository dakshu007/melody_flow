import 'package:hive/hive.dart';
import 'package:on_audio_query/on_audio_query.dart';

part 'song.g.dart'; // run build_runner after creating all models

@HiveType(typeId: 0)
class Song {
  @HiveField(0) final int id;              // MediaStore id
  @HiveField(1) final String title;
  @HiveField(2) final String artist;
  @HiveField(3) final String album;
  @HiveField(4) final int albumId;
  @HiveField(5) final String? data;        // file path (content uri too)
  @HiveField(6) final int duration;        // ms
  @HiveField(7) final String? genre;
  @HiveField(8) final int? year;
  @HiveField(9) final int dateAdded;       // epoch
  @HiveField(10) final int size;           // bytes
  @HiveField(11) final String? composer;
  @HiveField(12) final int? track;
  @HiveField(13) final String? displayName;

  // Runtime-only fields (not persisted)
  final int playCount;
  final int? lastPlayed; // epoch ms

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.data,
    required this.duration,
    this.genre,
    this.year,
    required this.dateAdded,
    required this.size,
    this.composer,
    this.track,
    this.displayName,
    this.playCount = 0,
    this.lastPlayed,
  });

  /// Build a Song from on_audio_query's SongModel
  factory Song.fromSongModel(SongModel s) => Song(
        id: s.id,
        title: s.title,
        artist: s.artist ?? 'Unknown Artist',
        album: s.album ?? 'Unknown Album',
        albumId: s.albumId ?? 0,
        data: s.data,
        duration: s.duration ?? 0,
        genre: s.genre,
        dateAdded: s.dateAdded ?? 0,
        size: s.size,
        composer: s.composer,
        track: s.track,
        displayName: s.displayName,
      );

  Song copyWith({int? playCount, int? lastPlayed}) => Song(
        id: id,
        title: title,
        artist: artist,
        album: album,
        albumId: albumId,
        data: data,
        duration: duration,
        genre: genre,
        year: year,
        dateAdded: dateAdded,
        size: size,
        composer: composer,
        track: track,
        displayName: displayName,
        playCount: playCount ?? this.playCount,
        lastPlayed: lastPlayed ?? this.lastPlayed,
      );

  /// Stable id used in audio_service notifications & queues
  String get mediaId => 'song_$id';

  Duration get durationAsDuration => Duration(milliseconds: duration);

  @override
  bool operator ==(Object other) => other is Song && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
