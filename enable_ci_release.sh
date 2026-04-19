#!/bin/bash
# Melody Flow — Enable CI-signed release builds
# After you've added the 4 GitHub secrets, run this to update the workflow.
#   bash enable_ci_release.sh

set -e

echo "🔐 Enabling CI-signed release builds..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Run from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Overwrite the workflow to add a signed-release job
# ----------------------------------------------------------------------------
mkdir -p .github/workflows

cat > .github/workflows/build-apk.yml << 'EOF'
name: Build APK

on:
  push:
    branches: [main]
  workflow_dispatch:
  pull_request:
    branches: [main]

jobs:
  # -------- Debug build (unsigned, for testing) --------
  build-debug:
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

      # Patch on_audio_query_android namespace (abandoned package)
      - name: Patch on_audio_query namespace
        run: |
          GRADLE_FILE=$(find ~/.pub-cache -path '*on_audio_query_android*/android/build.gradle' | head -n 1)
          echo "Patching namespace in: $GRADLE_FILE"
          if ! grep -q 'namespace' "$GRADLE_FILE"; then
            sed -i '/^android {/a\    namespace "com.lucasjosino.on_audio_query"' "$GRADLE_FILE"
          fi

      # Patch JVM target to 17
      - name: Force JVM target 17
        run: |
          GRADLE_FILE=$(find ~/.pub-cache -path '*on_audio_query_android*/android/build.gradle' | head -n 1)
          sed -i 's/sourceCompatibility JavaVersion.VERSION_1_8/sourceCompatibility JavaVersion.VERSION_17/g' "$GRADLE_FILE"
          sed -i 's/targetCompatibility JavaVersion.VERSION_1_8/targetCompatibility JavaVersion.VERSION_17/g' "$GRADLE_FILE"
          sed -i "s/jvmTarget = '1.8'/jvmTarget = '17'/g" "$GRADLE_FILE"
          sed -i 's/jvmTarget = "1.8"/jvmTarget = "17"/g' "$GRADLE_FILE"

      - run: flutter analyze || true
      - run: flutter build apk --debug

      - uses: actions/upload-artifact@v4
        with:
          name: melody-flow-debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk

  # -------- Signed release build (APK + AAB for Play Store) --------
  build-release:
    runs-on: ubuntu-latest
    # Only run release build on main branch pushes (not PRs) to avoid
    # exposing secrets to untrusted contributors.
    if: github.event_name != 'pull_request'
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

      - run: flutter pub get

      # Same plugin patches as debug build
      - name: Patch on_audio_query namespace
        run: |
          GRADLE_FILE=$(find ~/.pub-cache -path '*on_audio_query_android*/android/build.gradle' | head -n 1)
          if ! grep -q 'namespace' "$GRADLE_FILE"; then
            sed -i '/^android {/a\    namespace "com.lucasjosino.on_audio_query"' "$GRADLE_FILE"
          fi

      - name: Force JVM target 17
        run: |
          GRADLE_FILE=$(find ~/.pub-cache -path '*on_audio_query_android*/android/build.gradle' | head -n 1)
          sed -i 's/sourceCompatibility JavaVersion.VERSION_1_8/sourceCompatibility JavaVersion.VERSION_17/g' "$GRADLE_FILE"
          sed -i 's/targetCompatibility JavaVersion.VERSION_1_8/targetCompatibility JavaVersion.VERSION_17/g' "$GRADLE_FILE"
          sed -i "s/jvmTarget = '1.8'/jvmTarget = '17'/g" "$GRADLE_FILE"
          sed -i 's/jvmTarget = "1.8"/jvmTarget = "17"/g' "$GRADLE_FILE"

      # Restore the keystore from the base64-encoded secret
      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/melody-release.jks
          ls -la android/app/melody-release.jks

      # Write key.properties with the runner's filepath to the keystore
      - name: Create key.properties
        run: |
          cat > android/app/key.properties << PROPS
          storePassword=${{ secrets.KEYSTORE_PASSWORD }}
          keyPassword=${{ secrets.KEY_PASSWORD }}
          keyAlias=${{ secrets.KEY_ALIAS }}
          storeFile=melody-release.jks
          PROPS

      - run: flutter build apk --release
      - run: flutter build appbundle --release

      - uses: actions/upload-artifact@v4
        with:
          name: melody-flow-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk

      - uses: actions/upload-artifact@v4
        with:
          name: melody-flow-release-aab
          path: build/app/outputs/bundle/release/app-release.aab

      # Make sure we don't leave secrets in the workspace between runs
      - name: Cleanup
        if: always()
        run: |
          rm -f android/app/melody-release.jks
          rm -f android/app/key.properties
EOF

echo "✅ Workflow written to .github/workflows/build-apk.yml"

# ----------------------------------------------------------------------------
# Also update the local build.gradle so CI's key.properties is found.
# CI stores the keystore file next to the properties file, so we need to
# support both: absolute path (local) and relative filename (CI).
# ----------------------------------------------------------------------------
python3 << 'PYEOF'
import re

path = 'android/app/build.gradle'
with open(path) as f:
    content = f.read()

# Change signingConfigs.release to resolve storeFile relative to the
# build.gradle's folder when it's a bare filename (no slashes).
old = '''    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }'''

new = '''    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                // storeFile can be an absolute path (local dev) or a filename
                // next to key.properties (CI). Support both.
                def storePath = keystoreProperties['storeFile']
                if (storePath.startsWith('/') || storePath.contains(':')) {
                    storeFile file(storePath)
                } else {
                    storeFile file("${projectDir}/${storePath}")
                }
                storePassword keystoreProperties['storePassword']
            }
        }
    }'''

if old in content:
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)
    print("   ✓ build.gradle now supports both local and CI keystore paths")
else:
    print("   (signingConfigs already updated or different — skipping)")
PYEOF

echo ""
echo "---- Committing and pushing ----"
git add -A
git status --short
echo ""

git commit -m "CI: build signed release APK + AAB using GitHub secrets"
git push

echo ""
echo "🎉 Done! CI will now build your signed AAB automatically."
echo ""
echo "   Watch the build: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "   In ~5 minutes you'll see two jobs run:"
echo "     • build-debug (unsigned APK for testing)"
echo "     • build-release (signed APK + AAB for Play Store)"
echo ""
echo "   When build-release finishes (green check), scroll to the bottom"
echo "   of the run page and look for the 'Artifacts' section:"
echo ""
echo "     📦 melody-flow-release-apk   ← sideload this one"
echo "     📦 melody-flow-release-aab   ← UPLOAD THIS TO PLAY STORE"
echo ""
echo "⚠️  If the build-release job shows a red X, it usually means one of"
echo "   the 4 secrets is missing or wrong. Double-check at:"
echo "   https://github.com/dakshu007/melody_flow/settings/secrets/actions"
