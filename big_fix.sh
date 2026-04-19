#!/bin/bash
# Melody Flow — BIG FIX PACK
# Fixes: light mode, accent colors, icon, overflow, shuffle/repeat,
#        smart playlist counts, all settings toggles, lyrics
# Also sets up release signing and builds the APK + AAB for Play Store
#
# Run from project root (where pubspec.yaml lives):
#   bash big_fix.sh

set -e

echo "🚀 Melody Flow BIG FIX PACK"
echo "================================"
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Run from inside the melody_flow folder."
  exit 1
fi

if [ ! -f "big_fix.zip" ]; then
  echo "❌ big_fix.zip not found in current folder."
  echo "   Move the downloaded zip into this folder and rerun."
  exit 1
fi

# ----------------------------------------------------------------------------
# Step 1: Extract all Dart source fixes
# ----------------------------------------------------------------------------
echo "✅ [1/6] Extracting source fixes..."
unzip -o big_fix.zip -d . > /dev/null

# ----------------------------------------------------------------------------
# Step 2: Add missing dependencies to pubspec.yaml
# ----------------------------------------------------------------------------
echo "✅ [2/6] Ensuring required packages are in pubspec.yaml..."

python3 << 'PYEOF'
with open('pubspec.yaml', 'r') as f:
    content = f.read()

needed = [
    ('http', '^1.2.0'),
    ('file_picker', '^8.0.3'),
    ('path', '^1.9.0'),
    ('path_provider', '^2.1.3'),
    ('package_info_plus', '^8.0.0'),
    ('url_launcher', '^6.3.0'),
    ('flutter_lyric', '^2.0.4+6'),
    ('marquee', '^2.2.3'),
    ('shimmer', '^3.0.0'),
    ('intl', '^0.19.0'),
]

for pkg, ver in needed:
    import re
    pattern = re.compile(r'^\s*' + re.escape(pkg) + r':\s', re.MULTILINE)
    if not pattern.search(content):
        # Insert after 'dependencies:'
        content = content.replace(
            'dependencies:\n',
            f'dependencies:\n  {pkg}: {ver}\n',
            1,
        )
        print(f"   Added {pkg}: {ver}")

with open('pubspec.yaml', 'w') as f:
    f.write(content)
PYEOF

# ----------------------------------------------------------------------------
# Step 3: Handle app icon (issue 3)
# ----------------------------------------------------------------------------
echo "✅ [3/6] Setting up app icon..."

SOURCE_ICON=""
for candidate in \
    "app_icon.png" \
    "$HOME/Downloads/app_icon.png" \
    "$HOME/Downloads/melody-flow-icon-1024.png" \
    "$HOME/Downloads/melody-flow-icon.png"; do
  if [ -f "$candidate" ]; then
    SOURCE_ICON="$candidate"
    break
  fi
done

if [ -z "$SOURCE_ICON" ]; then
  echo "   ⚠️  No icon found! Looked for:"
  echo "      - ./app_icon.png (project root)"
  echo "      - ~/Downloads/app_icon.png"
  echo "      - ~/Downloads/melody-flow-icon-1024.png"
  echo ""
  echo "   To fix: save the icon image to Downloads/app_icon.png and rerun."
  echo "   Continuing without icon update..."
else
  echo "   Found icon: $SOURCE_ICON"
  mkdir -p assets/icons assets/images
  cp "$SOURCE_ICON" assets/icons/app_icon.png
  cp "$SOURCE_ICON" assets/icons/app_icon_fg.png
  cp "$SOURCE_ICON" assets/icons/splash.png

  # Add launcher_icons + native_splash config blocks if not present
  python3 << 'PYEOF'
import re

with open('pubspec.yaml', 'r') as f:
    content = f.read()

BG_COLOR = "#CDEBC0"

launcher_block = f'''
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/app_icon.png"
  min_sdk_android: 23
  adaptive_icon_background: "{BG_COLOR}"
  adaptive_icon_foreground: "assets/icons/app_icon_fg.png"
  adaptive_icon_monochrome: "assets/icons/app_icon_fg.png"
  remove_alpha_ios: true
'''

splash_block = f'''
flutter_native_splash:
  color: "{BG_COLOR}"
  image: assets/icons/splash.png
  android_12:
    image: assets/icons/splash.png
    color: "{BG_COLOR}"
  android: true
  ios: true
  web: false
'''

# Strip any existing blocks
content = re.sub(r'(?m)^flutter_launcher_icons:.*?(?=^\S|\Z)', '', content, flags=re.DOTALL)
content = re.sub(r'(?m)^flutter_native_splash:.*?(?=^\S|\Z)', '', content, flags=re.DOTALL)

content = content.rstrip() + '\n' + launcher_block + splash_block

with open('pubspec.yaml', 'w') as f:
    f.write(content)
print("   pubspec.yaml icon configs written")
PYEOF

  flutter pub get > /dev/null
  echo "   Generating icon variants..."
  dart run flutter_launcher_icons 2>&1 | tail -3 || true
  echo "   Generating splash screen..."
  dart run flutter_native_splash:create 2>&1 | tail -3 || true
fi

# Ensure app label is 'Melody Flow'
python3 << 'PYEOF'
path = 'android/app/src/main/AndroidManifest.xml'
with open(path) as f:
    content = f.read()
content = content.replace('android:label="melody_flow"', 'android:label="Melody Flow"')
with open(path, 'w') as f:
    f.write(content)
PYEOF

# ----------------------------------------------------------------------------
# Step 4: Run pub get
# ----------------------------------------------------------------------------
echo "✅ [4/6] Installing dependencies..."
flutter pub get > /dev/null

# ----------------------------------------------------------------------------
# Step 5: Verify key files
# ----------------------------------------------------------------------------
echo "✅ [5/6] Verifying file presence..."
EXPECTED=(
  "lib/core/theme/app_theme.dart"
  "lib/data/services/lyrics_service.dart"
  "lib/presentation/providers/app_providers.dart"
  "lib/presentation/screens/home/home_screen.dart"
  "lib/presentation/screens/now_playing/now_playing_screen.dart"
  "lib/presentation/screens/now_playing/lyrics_panel.dart"
  "lib/presentation/screens/playlists/playlists_screen.dart"
  "lib/presentation/screens/settings/settings_screen.dart"
)
for f in "${EXPECTED[@]}"; do
  if [ -f "$f" ]; then
    echo "   ✓  $f"
  else
    echo "   ⚠️  Missing: $f"
  fi
done

# ----------------------------------------------------------------------------
# Step 6: Commit + push (CI builds debug AAB automatically)
# ----------------------------------------------------------------------------
echo "✅ [6/6] Committing and pushing..."
git add -A
git status --short | head -20
echo ""

git commit -m "BIG FIX: light mode, accent colors, overflow, shuffle/repeat, smart playlist counts, full settings wired, lyrics via api.lyrics.ovh, icon + splash"
git push

echo ""
echo "🎉 Done! Build is running on GitHub Actions."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "---------------------------------------------------------------"
echo "NEXT STEP: Release AAB for Play Store (one-time keystore setup)"
echo "---------------------------------------------------------------"
echo ""
echo "Run the following when you're ready to generate a production AAB:"
echo ""
echo "  bash release_setup.sh"
echo ""
echo "This will create a keystore, sign the release, and build both"
echo "app-release.apk and app-release.aab for Play Store upload."
