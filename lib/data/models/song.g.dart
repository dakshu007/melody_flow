// GENERATED CODE - DO NOT MODIFY BY HAND
// (This is the hand-written equivalent of what build_runner produces from @HiveType.
//  If you later run `dart run build_runner build`, you can delete this file.)

part of 'song.dart';

class SongAdapter extends TypeAdapter<Song> {
  @override
  final int typeId = 0;

  @override
  Song read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Song(
      id: fields[0] as int,
      title: fields[1] as String,
      artist: fields[2] as String,
      album: fields[3] as String,
      albumId: fields[4] as int,
      data: fields[5] as String?,
      duration: fields[6] as int,
      genre: fields[7] as String?,
      year: fields[8] as int?,
      dateAdded: fields[9] as int,
      size: fields[10] as int,
      composer: fields[11] as String?,
      track: fields[12] as int?,
      displayName: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.album)
      ..writeByte(4)
      ..write(obj.albumId)
      ..writeByte(5)
      ..write(obj.data)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.genre)
      ..writeByte(8)
      ..write(obj.year)
      ..writeByte(9)
      ..write(obj.dateAdded)
      ..writeByte(10)
      ..write(obj.size)
      ..writeByte(11)
      ..write(obj.composer)
      ..writeByte(12)
      ..write(obj.track)
      ..writeByte(13)
      ..write(obj.displayName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
