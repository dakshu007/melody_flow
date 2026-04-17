part of 'app_settings.dart';

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 3;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      themeMode: fields[0] as int? ?? 3,
      accentColorValue: fields[1] as int? ?? 0xFF1DB954,
      useMaterialYou: fields[2] as bool? ?? false,
      dynamicColorFromArtwork: fields[3] as bool? ?? true,
      songSort: fields[4] as int? ?? 0,
      sortAscending: fields[5] as bool? ?? true,
      crossfadeMs: fields[6] as int? ?? 0,
      gaplessPlayback: fields[7] as bool? ?? true,
      fadeInOut: fields[8] as bool? ?? true,
      replayGainEnabled: fields[9] as bool? ?? false,
      sleepTimerDefaultMin: fields[10] as int? ?? 30,
      minTrackLengthSec: fields[11] as int? ?? 30,
      excludedFolders: (fields[12] as List?)?.cast<String>() ?? const [],
      artistSeparator: fields[13] as String? ?? ';',
      genreSeparator: fields[14] as String? ?? ';',
      nowPlayingTheme: fields[15] as int? ?? 3,
      showLyricsButton: fields[16] as bool? ?? true,
      shuffleOnStart: fields[17] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.themeMode)
      ..writeByte(1)
      ..write(obj.accentColorValue)
      ..writeByte(2)
      ..write(obj.useMaterialYou)
      ..writeByte(3)
      ..write(obj.dynamicColorFromArtwork)
      ..writeByte(4)
      ..write(obj.songSort)
      ..writeByte(5)
      ..write(obj.sortAscending)
      ..writeByte(6)
      ..write(obj.crossfadeMs)
      ..writeByte(7)
      ..write(obj.gaplessPlayback)
      ..writeByte(8)
      ..write(obj.fadeInOut)
      ..writeByte(9)
      ..write(obj.replayGainEnabled)
      ..writeByte(10)
      ..write(obj.sleepTimerDefaultMin)
      ..writeByte(11)
      ..write(obj.minTrackLengthSec)
      ..writeByte(12)
      ..write(obj.excludedFolders)
      ..writeByte(13)
      ..write(obj.artistSeparator)
      ..writeByte(14)
      ..write(obj.genreSeparator)
      ..writeByte(15)
      ..write(obj.nowPlayingTheme)
      ..writeByte(16)
      ..write(obj.showLyricsButton)
      ..writeByte(17)
      ..write(obj.shuffleOnStart);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
