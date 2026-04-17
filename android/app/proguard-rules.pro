# Flutter default
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# just_audio + ExoPlayer
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# audio_service
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# on_audio_query
-keep class com.lucasjosino.** { *; }

# Hive
-keep class hive.** { *; }
-keep class **$HiveFieldAdapter { *; }

# ===== Play Core (deferred components) — we don't use them, tell R8 it's OK =====
# Flutter embedding references these classes but they're optional — we ship
# a single APK, not dynamic feature modules. Tell R8 not to panic.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
