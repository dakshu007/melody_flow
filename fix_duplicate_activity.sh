#!/bin/bash
# Melody Flow — Fix duplicate MainActivity
# The project has TWO MainActivity.kt files:
#   1. android/app/src/main/kotlin/com/melodyflow/melody_flow/MainActivity.kt  (OLD — stale, wrong package)
#   2. android/app/src/main/kotlin/com/melodyflow/app/MainActivity.kt          (NEW — matches namespace, handles widget intents)
#
# The second is the one we want. Delete the first, clean up empty dirs.
#
# Run from project root:
#   bash fix_duplicate_activity.sh

set -e

echo "🔧 Fixing duplicate MainActivity..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Run from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# 1. Confirm what we have
# ----------------------------------------------------------------------------
echo "✅ [1/4] Checking which MainActivity files exist..."
OLD_PATH="android/app/src/main/kotlin/com/melodyflow/melody_flow/MainActivity.kt"
NEW_PATH="android/app/src/main/kotlin/com/melodyflow/app/MainActivity.kt"

if [ -f "$OLD_PATH" ]; then
  echo "   ✓ Found stale old MainActivity at: $OLD_PATH"
else
  echo "   (no old MainActivity — maybe already cleaned)"
fi

if [ -f "$NEW_PATH" ]; then
  echo "   ✓ Found current MainActivity at: $NEW_PATH"
else
  echo "   ⚠️  Current MainActivity missing! Will re-create it..."
fi

# ----------------------------------------------------------------------------
# 2. Make sure our new MainActivity is present and correct
# ----------------------------------------------------------------------------
echo ""
echo "✅ [2/4] Ensuring com/melodyflow/app/MainActivity.kt is correct..."
mkdir -p android/app/src/main/kotlin/com/melodyflow/app

cat > "$NEW_PATH" << 'EOF'
package com.melodyflow.app

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity extends AudioServiceActivity so just_audio/audio_service
 * can find and bind the media session when the app comes up.
 *
 * Also handles incoming widget_action intents from MelodyWidgetProvider.
 * These come in as Intent extras; we pass them to Flutter via a
 * MethodChannel so the Dart audio handler can react.
 */
class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "com.melodyflow.app/widget"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handled post-resume
    }

    override fun onPostResume() {
        super.onPostResume()
        if (intent.getBooleanExtra("widget_silent", false)) {
            window.decorView.postDelayed({
                if (!isFinishing) finish()
            }, 200)
        }
    }

    private fun handleWidgetIntent(intent: Intent?) {
        val action = intent?.getStringExtra("widget_action") ?: return
        intent.removeExtra("widget_action")
        methodChannel?.invokeMethod("widgetAction", action)
    }
}
EOF
echo "   ✓ Correct MainActivity written"

# ----------------------------------------------------------------------------
# 3. Delete the stale old MainActivity and its now-empty package folder
# ----------------------------------------------------------------------------
echo ""
echo "✅ [3/4] Removing stale old MainActivity..."

if [ -f "$OLD_PATH" ]; then
  rm -f "$OLD_PATH"
  echo "   ✓ Deleted $OLD_PATH"

  # Clean up the now-empty melody_flow/ package dir if it's empty
  OLD_DIR="android/app/src/main/kotlin/com/melodyflow/melody_flow"
  if [ -d "$OLD_DIR" ] && [ -z "$(ls -A "$OLD_DIR")" ]; then
    rmdir "$OLD_DIR"
    echo "   ✓ Removed empty directory $OLD_DIR"
  fi
fi

# ----------------------------------------------------------------------------
# 4. Double-check nothing else references the old package
# ----------------------------------------------------------------------------
echo ""
echo "✅ [4/4] Verifying no stale references remain..."

# Check AndroidManifest for any references to the old path
if grep -q "com.melodyflow.melody_flow" android/app/src/main/AndroidManifest.xml 2>/dev/null; then
  echo "   ⚠️  Found stale reference in AndroidManifest.xml — fixing..."
  sed -i '' 's/com\.melodyflow\.melody_flow/com.melodyflow.app/g' android/app/src/main/AndroidManifest.xml 2>/dev/null || \
    sed -i 's/com\.melodyflow\.melody_flow/com.melodyflow.app/g' android/app/src/main/AndroidManifest.xml
  echo "   ✓ AndroidManifest cleaned"
else
  echo "   ✓ AndroidManifest is clean"
fi

# Show what remains
echo ""
echo "---- Kotlin files remaining ----"
find android/app/src/main/kotlin -name "*.kt" | sort

echo ""
echo "---- Committing ----"
git add -A
git status --short
echo ""

git commit -m "Fix: delete duplicate MainActivity in stale com/melodyflow/melody_flow package"
git push

echo ""
echo "🎉 Pushed! CI rebuilding."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "   Both jobs should now pass:"
echo "     ✓ build-debug"
echo "     ✓ build-release (with signed AAB artifact)"
