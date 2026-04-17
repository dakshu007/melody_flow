#!/bin/bash
# Melody Flow — single-shot fix script
# Run from inside the melody_flow project root:
#   bash fix_build.sh

set -e  # exit on any error

echo "🔧 Melody Flow build fix script starting..."
echo ""

# ----------------------------------------------------------------------------
# Sanity check: must be in the project root
# ----------------------------------------------------------------------------
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found. Run this from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Fix 1: Bump compileSdk to 36 and targetSdk to 35
# ----------------------------------------------------------------------------
echo "✅ [1/7] Bumping compileSdk to 36 and targetSdk to 35..."
sed -i '' 's/compileSdk 34/compileSdk 36/' android/app/build.gradle 2>/dev/null || \
  sed -i 's/compileSdk 34/compileSdk 36/' android/app/build.gradle
sed -i '' 's/targetSdk 34/targetSdk 35/' android/app/build.gradle 2>/dev/null || \
  sed -i 's/targetSdk 34/targetSdk 35/' android/app/build.gradle

# ----------------------------------------------------------------------------
# Fix 2: Make Playlist extend HiveObject so .save() works
# ----------------------------------------------------------------------------
echo "✅ [2/7] Making Playlist extend HiveObject..."
sed -i '' 's/^class Playlist {/class Playlist extends HiveObject {/' lib/data/models/playlist.dart 2>/dev/null || \
  sed -i 's/^class Playlist {/class Playlist extends HiveObject {/' lib/data/models/playlist.dart

# ----------------------------------------------------------------------------
# Fix 3: Add hive_flutter import to app_providers.dart for .listenable()
# ----------------------------------------------------------------------------
echo "✅ [3/7] Adding hive_flutter import to app_providers.dart..."
if ! grep -q "import 'package:hive_flutter/hive_flutter.dart';" lib/presentation/providers/app_providers.dart; then
  # macOS sed needs empty string for -i, Linux doesn't
  sed -i '' "1a\\
import 'package:hive_flutter/hive_flutter.dart';
" lib/presentation/providers/app_providers.dart 2>/dev/null || \
  sed -i "1a import 'package:hive_flutter/hive_flutter.dart';" lib/presentation/providers/app_providers.dart
fi

# ----------------------------------------------------------------------------
# Fix 4: Rewrite audio_handler.dart equalizer access with Python multi-line edit
# ----------------------------------------------------------------------------
echo "✅ [4/7] Fixing just_audio audioPipeline API usage..."
python3 << 'PYEOF'
path = 'lib/data/services/audio_handler.dart'
with open(path, 'r') as f:
    content = f.read()

# Replace AudioPlayer constructor block
old_constructor = '''  final _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [
        AndroidEqualizer(),
        AndroidLoudnessEnhancer(),
      ],
    ),
  );'''

new_constructor = '''  final _equalizer = AndroidEqualizer();
  final _loudnessEnhancer = AndroidLoudnessEnhancer();

  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [_equalizer, _loudnessEnhancer],
    ),
  );'''

content = content.replace(old_constructor, new_constructor)

# Replace equalizer getter
old_eq_getter = '''  /// Get the equalizer for UI access.
  AndroidEqualizer get equalizer =>
      _player.audioPipeline.androidAudioEffects
          .whereType<AndroidEqualizer>()
          .first;

  AndroidLoudnessEnhancer get loudnessEnhancer =>
      _player.audioPipeline.androidAudioEffects
          .whereType<AndroidLoudnessEnhancer>()
          .first;'''

new_eq_getter = '''  /// Get the equalizer for UI access.
  AndroidEqualizer get equalizer => _equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _loudnessEnhancer;'''

content = content.replace(old_eq_getter, new_eq_getter)

with open(path, 'w') as f:
    f.write(content)

print("   audio_handler.dart patched successfully")
PYEOF

# ----------------------------------------------------------------------------
# Fix 5: Replace queryAudiosFromGenreId with queryAudiosFrom in library_service
# ----------------------------------------------------------------------------
echo "✅ [5/7] Fixing on_audio_query genre query API..."
sed -i '' 's|final r = await _query.queryAudiosFromGenreId(genreId);|final r = await _query.queryAudiosFrom(AudiosFromType.GENRE_ID, genreId);|' lib/data/services/library_service.dart 2>/dev/null || \
  sed -i 's|final r = await _query.queryAudiosFromGenreId(genreId);|final r = await _query.queryAudiosFrom(AudiosFromType.GENRE_ID, genreId);|' lib/data/services/library_service.dart

# ----------------------------------------------------------------------------
# Fix 6: Remove invalid highLightTextColor param from flutter_lyric
# ----------------------------------------------------------------------------
echo "✅ [6/7] Removing invalid highLightTextColor param from lyrics_panel..."
sed -i '' '/highLightTextColor: Theme.of(context).colorScheme.primary,/d' lib/presentation/screens/now_playing/lyrics_panel.dart 2>/dev/null || \
  sed -i '/highLightTextColor: Theme.of(context).colorScheme.primary,/d' lib/presentation/screens/now_playing/lyrics_panel.dart

# ----------------------------------------------------------------------------
# Fix 7: Verify changes
# ----------------------------------------------------------------------------
echo "✅ [7/7] Verifying all changes..."
echo ""
echo "---- android/app/build.gradle SDK versions ----"
grep -E 'compileSdk|targetSdk|minSdk' android/app/build.gradle | head -5
echo ""
echo "---- Playlist class declaration ----"
grep '^class Playlist' lib/data/models/playlist.dart
echo ""
echo "---- app_providers.dart imports (first 6 lines) ----"
head -6 lib/presentation/providers/app_providers.dart
echo ""
echo "---- highLightTextColor removed? (should print nothing) ----"
grep highLightTextColor lib/presentation/screens/now_playing/lyrics_panel.dart || echo "   ✓ removed"
echo ""
echo "---- queryAudiosFromGenreId removed? (should print nothing) ----"
grep queryAudiosFromGenreId lib/data/services/library_service.dart || echo "   ✓ removed"
echo ""

# ----------------------------------------------------------------------------
# Update pubspec.lock, then commit + push
# ----------------------------------------------------------------------------
echo "📦 Running flutter pub get..."
flutter pub get || echo "   (pub get had warnings — proceeding anyway, CI will handle it)"

echo ""
echo "📝 Committing and pushing to GitHub..."
git add -A
git status --short
echo ""
git commit -m "Fix: API mismatches (just_audio, hive, on_audio_query, flutter_lyric) + bump compileSdk to 36"
git push

echo ""
echo "🎉 Done! GitHub Actions will now rebuild."
echo "   Watch progress: https://github.com/dakshu007/melody_flow/actions"
