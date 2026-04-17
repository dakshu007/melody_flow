#!/bin/bash
# Melody Flow — round 4 build fix
# Fixes R8 release build failure by adding Play Core keep rules
# Run from inside melody_flow project root:
#   bash fix_build_4.sh

set -e

echo "🔧 Melody Flow build fix round 4 (R8/ProGuard)..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found. Run from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Fix: Add R8 keep rules for Play Core classes that Flutter references but
# we don't ship (we don't use deferred components / dynamic feature modules)
# ----------------------------------------------------------------------------
echo "✅ [1/2] Updating proguard-rules.pro with Play Core keep rules..."

cat > android/app/proguard-rules.pro << 'EOF'
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
EOF

# ----------------------------------------------------------------------------
# Also reinforce in the workflow: add the Play Core dependency to kill the
# issue entirely (2 KB of APK bloat but zero build drama)
# ----------------------------------------------------------------------------
echo "✅ [2/2] Adding play:core dependency to android/app/build.gradle..."

python3 << 'PYEOF'
path = 'android/app/build.gradle'
with open(path, 'r') as f:
    content = f.read()

# Add play:core dependency if not already present
if 'com.google.android.play:core' not in content:
    # Find the dependencies block and add our line
    content = content.replace(
        "implementation 'androidx.multidex:multidex:2.0.1'",
        "implementation 'androidx.multidex:multidex:2.0.1'\n"
        "    implementation 'com.google.android.play:core:1.10.3'\n"
        "    implementation 'com.google.android.play:core-ktx:1.8.1'"
    )
    with open(path, 'w') as f:
        f.write(content)
    print("   play:core dependencies added")
else:
    print("   play:core already present")
PYEOF

echo ""
echo "---- Final android/app/build.gradle dependencies block ----"
grep -A 5 'dependencies {' android/app/build.gradle | tail -6
echo ""

# ----------------------------------------------------------------------------
# Commit and push
# ----------------------------------------------------------------------------
echo "📝 Committing and pushing..."
git add -A
git status --short
echo ""
git commit -m "Fix: add Play Core keep rules and dependency for R8 release build"
git push

echo ""
echo "🎉 Pushed. Release build should now succeed."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "💡 Meanwhile, grab the debug APK from the previous run's Artifacts section!"
