import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 3)
class AppSettings {
  @HiveField(0) int themeMode;            // 0 light, 1 dark, 2 amoled, 3 system
  @HiveField(1) int accentColorValue;     // ARGB int
  @HiveField(2) bool useMaterialYou;
  @HiveField(3) bool dynamicColorFromArtwork;
  @HiveField(4) int songSort;             // 0 title, 1 artist, 2 album, 3 dateAdded, 4 duration
  @HiveField(5) bool sortAscending;
  @HiveField(6) int crossfadeMs;          // 0 = disabled
  @HiveField(7) bool gaplessPlayback;
  @HiveField(8) bool fadeInOut;
  @HiveField(9) bool replayGainEnabled;
  @HiveField(10) int sleepTimerDefaultMin;
  @HiveField(11) int minTrackLengthSec;   // filter short clips (ringtones)
  @HiveField(12) List<String> excludedFolders;
  @HiveField(13) String artistSeparator;
  @HiveField(14) String genreSeparator;
  @HiveField(15) int nowPlayingTheme;     // 0 classic, 1 glow, 2 materialYou, 3 minimal, 4 immersive
  @HiveField(16) bool showLyricsButton;
  @HiveField(17) bool shuffleOnStart;

  AppSettings({
    this.themeMode = 3,
    this.accentColorValue = 0xFF1DB954,
    this.useMaterialYou = false,
    this.dynamicColorFromArtwork = true,
    this.songSort = 0,
    this.sortAscending = true,
    this.crossfadeMs = 0,
    this.gaplessPlayback = true,
    this.fadeInOut = true,
    this.replayGainEnabled = false,
    this.sleepTimerDefaultMin = 30,
    this.minTrackLengthSec = 30,
    List<String>? excludedFolders,
    this.artistSeparator = ';',
    this.genreSeparator = ';',
    this.nowPlayingTheme = 3,
    this.showLyricsButton = true,
    this.shuffleOnStart = false,
  }) : excludedFolders = excludedFolders ?? const [];
}
