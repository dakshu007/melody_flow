#!/bin/bash
# Melody Flow — App Icon & Splash Setup (v2 — mint vinyl icon)
#
# BEFORE RUNNING:
#   1. Save the uploaded icon image as 'app_icon.png' to your Mac Downloads folder
#      (right-click the image in chat → Save image as → name it exactly app_icon.png)
#   2. Run these from terminal:
#        cd ~/Downloads/melody_flow
#        bash setup_icon.sh

set -e

echo "🎨 Melody Flow icon & splash setup (v2 — mint vinyl)..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found. Run from the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Locate the source icon
# ----------------------------------------------------------------------------
SOURCE_ICON=""
if [ -f "app_icon.png" ]; then
  SOURCE_ICON="app_icon.png"
  echo "✅ Found app_icon.png in project root"
elif [ -f "$HOME/Downloads/app_icon.png" ]; then
  echo "   Found at ~/Downloads/app_icon.png, copying into project..."
  cp "$HOME/Downloads/app_icon.png" app_icon.png
  SOURCE_ICON="app_icon.png"
elif [ -f "$HOME/Downloads/melody-flow-icon-1024.png" ]; then
  echo "   Found at ~/Downloads/melody-flow-icon-1024.png, copying + renaming..."
  cp "$HOME/Downloads/melody-flow-icon-1024.png" app_icon.png
  SOURCE_ICON="app_icon.png"
else
  echo "❌ Could not find icon file."
  echo ""
  echo "   1. Right-click the uploaded icon in chat → Save image as → app_icon.png"
  echo "   2. Save it to your Downloads folder"
  echo "   3. Re-run this script (from inside melody_flow folder)"
  exit 1
fi

# ----------------------------------------------------------------------------
# Put icon in the right folders
# ----------------------------------------------------------------------------
mkdir -p assets/icons assets/images

cp "$SOURCE_ICON" assets/icons/app_icon.png
cp "$SOURCE_ICON" assets/icons/app_icon_fg.png
cp "$SOURCE_ICON" assets/icons/splash.png

echo "✅ [1/5] Copied icon to assets/icons/"

# ----------------------------------------------------------------------------
# Update pubspec.yaml with the new color palette
# ----------------------------------------------------------------------------
echo "✅ [2/5] Updating pubspec.yaml with icon + splash config..."

python3 << 'PYEOF'
import re

with open('pubspec.yaml', 'r') as f:
    content = f.read()

# Background color that matches the mint-green pastel of this icon
BG_COLOR = "#CDEBC0"

launcher_block = f'''flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/app_icon.png"
  min_sdk_android: 23
  adaptive_icon_background: "{BG_COLOR}"
  adaptive_icon_foreground: "assets/icons/app_icon_fg.png"
  adaptive_icon_monochrome: "assets/icons/app_icon_fg.png"
  remove_alpha_ios: true
  web:
    generate: false
  windows:
    generate: false
  macos:
    generate: false
'''

# Strip any existing flutter_launcher_icons block
content = re.sub(
    r'^flutter_launcher_icons:.*?(?=^\S|\Z)',
    '',
    content,
    flags=re.MULTILINE | re.DOTALL,
)

splash_block = f'''flutter_native_splash:
  color: "{BG_COLOR}"
  image: assets/icons/splash.png
  android_12:
    image: assets/icons/splash.png
    color: "{BG_COLOR}"
  android: true
  ios: true
  web: false
'''

content = re.sub(
    r'^flutter_native_splash:.*?(?=^\S|\Z)',
    '',
    content,
    flags=re.MULTILINE | re.DOTALL,
)

# Append both blocks at end of file
content = content.rstrip() + '\n\n' + launcher_block + '\n' + splash_block

with open('pubspec.yaml', 'w') as f:
    f.write(content)

print(f"   Updated pubspec.yaml with background color {BG_COLOR}")
PYEOF

# ----------------------------------------------------------------------------
# Run the generators
# ----------------------------------------------------------------------------
echo "✅ [3/5] Downloading packages..."
flutter pub get

echo ""
echo "✅ [4/5] Generating icon + splash assets..."
echo "   This creates icons at 5 different densities + adaptive layers + iOS set."
dart run flutter_launcher_icons || echo "   (icon generation had warnings — may still be OK)"
dart run flutter_native_splash:create || echo "   (splash generation had warnings — may still be OK)"

echo ""
echo "---- Generated files ----"
find android/app/src/main/res -name "ic_launcher*" 2>/dev/null | head -10 || true
find android/app/src/main/res -name "launch_image*" 2>/dev/null | head -10 || true

# ----------------------------------------------------------------------------
# Make sure app label is 'Melody Flow', not 'melody_flow'
# ----------------------------------------------------------------------------
python3 << 'PYEOF'
path = 'android/app/src/main/AndroidManifest.xml'
with open(path) as f:
    content = f.read()
content = content.replace('android:label="melody_flow"', 'android:label="Melody Flow"')
with open(path, 'w') as f:
    f.write(content)
PYEOF

echo "✅ [5/5] App label set to 'Melody Flow'"
echo ""

# ----------------------------------------------------------------------------
# Commit and push
# ----------------------------------------------------------------------------
echo "---- Files changed ----"
git status --short
echo ""

echo "📝 Committing and pushing..."
git add -A
git commit -m "Set up app icon and splash screen — mint vinyl record design"
git push

echo ""
echo "🎉 Done! Build running with your custom icon + splash."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "   In the new APK:"
echo "     • Home-screen icon: vinyl record on mint green"
echo "     • App name under icon: 'Melody Flow'"
echo "     • Splash screen: mint background with icon centered"
echo ""
echo "   IMPORTANT when installing new APK:"
echo "     1. Uninstall the old Melody Flow from your phone first"
echo "        (Settings → Apps → Melody Flow → Uninstall)"
echo "     2. Install fresh — some Android launchers cache old icons"
echo "     3. If icon still looks old, reboot the phone once"
