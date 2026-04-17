import 'package:hive/hive.dart';

part 'playlist.g.dart';

@HiveType(typeId: 1)
class Playlist {
  @HiveField(0) final String id;          // uuid
  @HiveField(1) String name;
  @HiveField(2) List<int> songIds;        // ordered
  @HiveField(3) final int createdAt;      // epoch ms
  @HiveField(4) int updatedAt;            // epoch ms
  @HiveField(5) String? description;
  @HiveField(6) String? coverPath;        // optional custom cover
  @HiveField(7) bool isSmart;             // smart/auto playlist flag

  Playlist({
    required this.id,
    required this.name,
    List<int>? songIds,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.coverPath,
    this.isSmart = false,
  }) : songIds = songIds ?? [];

  int get songCount => songIds.length;
}
