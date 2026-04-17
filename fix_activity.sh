#!/bin/bash
# Melody Flow — fix MainActivity to use AudioServiceActivity
# Run from inside melody_flow project root:
#   bash fix_activity.sh

set -e

echo "🔧 Fixing MainActivity to extend AudioServiceActivity..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found. Run from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Find MainActivity and rewrite it to extend AudioServiceActivity
# ----------------------------------------------------------------------------
echo "✅ [1/2] Locating MainActivity..."
MAIN_ACTIVITY=$(find android/app/src/main -name "MainActivity.kt" -o -name "MainActivity.java" | head -1)
echo "   Found: $MAIN_ACTIVITY"

if [ -z "$MAIN_ACTIVITY" ]; then
  echo "❌ MainActivity not found. Creating one..."
  mkdir -p android/app/src/main/kotlin/com/melodyflow/app
  MAIN_ACTIVITY="android/app/src/main/kotlin/com/melodyflow/app/MainActivity.kt"
fi

echo "✅ [2/2] Writing MainActivity that extends AudioServiceActivity..."

cat > "$MAIN_ACTIVITY" << 'EOF'
package com.melodyflow.app

import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity()
EOF

echo "   Contents:"
cat "$MAIN_ACTIVITY"
echo ""

# ----------------------------------------------------------------------------
# Commit and push
# ----------------------------------------------------------------------------
echo "📝 Committing and pushing..."
git add -A
git status --short
echo ""
git commit -m "Fix: MainActivity must extend AudioServiceActivity for audio_service"
git push

echo ""
echo "🎉 Pushed! Build re-running."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "   After APK arrives:"
echo "   1. Uninstall old version from phone"
echo "   2. Install new APK"
echo "   3. App should launch to onboarding screen"
