import 'package:hive/hive.dart';

part 'play_stats.g.dart';

@HiveType(typeId: 2)
class PlayStats {
  @HiveField(0) final int songId;
  @HiveField(1) int playCount;
  @HiveField(2) int lastPlayed;   // epoch ms
  @HiveField(3) bool isFavorite;

  PlayStats({
    required this.songId,
    this.playCount = 0,
    this.lastPlayed = 0,
    this.isFavorite = false,
  });
}
