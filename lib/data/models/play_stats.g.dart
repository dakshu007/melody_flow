part of 'play_stats.dart';

class PlayStatsAdapter extends TypeAdapter<PlayStats> {
  @override
  final int typeId = 2;

  @override
  PlayStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlayStats(
      songId: fields[0] as int,
      playCount: fields[1] as int? ?? 0,
      lastPlayed: fields[2] as int? ?? 0,
      isFavorite: fields[3] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, PlayStats obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.songId)
      ..writeByte(1)
      ..write(obj.playCount)
      ..writeByte(2)
      ..write(obj.lastPlayed)
      ..writeByte(3)
      ..write(obj.isFavorite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
