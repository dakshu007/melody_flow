#!/bin/bash
# Melody Flow — round 3 build fix
# Fixes Kotlin/Java JVM target mismatch in on_audio_query_android plugin
# Run from inside melody_flow project root:
#   bash fix_build_3.sh

set -e

echo "🔧 Melody Flow build fix round 3 (JVM target)..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found. Run from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Update the GitHub Actions workflow to patch JVM target in plugin gradles
# ----------------------------------------------------------------------------
echo "✅ [1/2] Extending workflow with JVM target patch step..."

cat > .github/workflows/build-apk.yml << 'EOF'
name: Build APK

on:
  push:
    branches: [main]
  workflow_dispatch:
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - run: flutter --version
      - run: flutter pub get

      # ----- Patch on_audio_query_android namespace (abandoned package) -----
      - name: Patch on_audio_query namespace
        run: |
          GRADLE_FILE=$(find ~/.pub-cache -path '*on_audio_query_android*/android/build.gradle' | head -n 1)
          echo "Patching namespace in: $GRADLE_FILE"
          if ! grep -q 'namespace' "$GRADLE_FILE"; then
            sed -i '/^android {/a\    namespace "com.lucasjosino.on_audio_query"' "$GRADLE_FILE"
          fi

      # ----- Patch JVM target to 17 for consistency across plugins -----
      - name: Force JVM target 17 on on_audio_query_android
        run: |
          GRADLE_FILE=$(find ~/.pub-cache -path '*on_audio_query_android*/android/build.gradle' | head -n 1)
          echo "Patching JVM target in: $GRADLE_FILE"
          # Replace Java source/target compatibility
          sed -i 's/sourceCompatibility JavaVersion.VERSION_1_8/sourceCompatibility JavaVersion.VERSION_17/g' "$GRADLE_FILE"
          sed -i 's/targetCompatibility JavaVersion.VERSION_1_8/targetCompatibility JavaVersion.VERSION_17/g' "$GRADLE_FILE"
          # Replace Kotlin jvmTarget
          sed -i "s/jvmTarget = '1.8'/jvmTarget = '17'/g" "$GRADLE_FILE"
          sed -i 's/jvmTarget = "1.8"/jvmTarget = "17"/g' "$GRADLE_FILE"
          # If no compileOptions block exists, inject one
          if ! grep -q 'sourceCompatibility' "$GRADLE_FILE"; then
            sed -i '/^android {/a\    compileOptions {\n        sourceCompatibility JavaVersion.VERSION_17\n        targetCompatibility JavaVersion.VERSION_17\n    }\n    kotlinOptions {\n        jvmTarget = "17"\n    }' "$GRADLE_FILE"
          fi
          echo "---- Patched file ----"
          cat "$GRADLE_FILE"

      - run: flutter analyze || true
      - run: flutter build apk --debug
      - run: flutter build apk --release

      - uses: actions/upload-artifact@v4
        with:
          name: melody-flow-debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk

      - uses: actions/upload-artifact@v4
        with:
          name: melody-flow-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
EOF

# ----------------------------------------------------------------------------
# Verify
# ----------------------------------------------------------------------------
echo "✅ [2/2] Verifying workflow file..."
echo ""
echo "---- Workflow now has these patch steps ----"
grep -E 'name: (Patch|Force)' .github/workflows/build-apk.yml
echo ""

# ----------------------------------------------------------------------------
# Commit and push
# ----------------------------------------------------------------------------
echo "📝 Committing and pushing..."
git add -A
git status --short
echo ""
git commit -m "Fix: patch JVM target 17 in on_audio_query_android"
git push

echo ""
echo "🎉 Pushed. Build running."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
