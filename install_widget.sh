#!/bin/bash
# Melody Flow — Icon update + 4x1 widget installer
#
# Run from project root:
#   bash install_widget.sh

set -e

echo "🎛️  Melody Flow — Icon + Widget installer"
echo "=========================================="
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Run from inside the melody_flow folder."
  exit 1
fi

if [ ! -f "widget_pack.zip" ]; then
  echo "❌ widget_pack.zip not found in this folder."
  echo "   Download it from the chat and place it here, then rerun."
  exit 1
fi

# ============================================================================
# PART 1 — Update app icon
# ============================================================================
echo "✅ [1/7] Updating app icon..."

ICON_PATH=""
if [ -f "$HOME/Downloads/app_icon.png" ]; then
  ICON_PATH="$HOME/Downloads/app_icon.png"
elif [ -f "app_icon.png" ]; then
  ICON_PATH="app_icon.png"
fi

if [ -z "$ICON_PATH" ]; then
  echo "   ⚠️  No app_icon.png found in ~/Downloads or project root."
  echo "   Skipping icon update. You can rerun after saving the file."
else
  echo "   Found: $ICON_PATH"
  mkdir -p assets/icons
  cp "$ICON_PATH" assets/icons/app_icon.png
  cp "$ICON_PATH" assets/icons/app_icon_fg.png
  cp "$ICON_PATH" assets/icons/splash.png

  # Regenerate every density
  flutter pub get > /dev/null
  echo "   Regenerating launcher icons..."
  dart run flutter_launcher_icons 2>&1 | tail -2 || true
  echo "   Regenerating splash..."
  dart run flutter_native_splash:create 2>&1 | tail -2 || true
fi

# ============================================================================
# PART 2 — Extract widget files into the project
# ============================================================================
echo ""
echo "✅ [2/7] Extracting widget files..."
unzip -o widget_pack.zip -d . > /dev/null
echo "   Files placed."

# ============================================================================
# PART 3 — Add home_widget dependency
# ============================================================================
echo ""
echo "✅ [3/7] Adding home_widget to pubspec.yaml..."

python3 << 'PYEOF'
import re
with open('pubspec.yaml') as f:
    content = f.read()

if not re.search(r'^\s*home_widget:\s', content, re.MULTILINE):
    content = content.replace(
        'dependencies:\n',
        'dependencies:\n  home_widget: ^0.7.0\n',
        1,
    )
    with open('pubspec.yaml', 'w') as f:
        f.write(content)
    print("   Added home_widget: ^0.7.0")
else:
    print("   home_widget already present")
PYEOF

# ============================================================================
# PART 4 — Register widget provider in AndroidManifest.xml
# ============================================================================
echo ""
echo "✅ [4/7] Registering widget provider in AndroidManifest..."

python3 << 'PYEOF'
path = 'android/app/src/main/AndroidManifest.xml'
with open(path) as f:
    content = f.read()

widget_block = '''
        <!-- Melody Flow 4x1 home-screen widget -->
        <receiver android:name=".MelodyWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
                <action android:name="com.melodyflow.app.PLAY_PAUSE" />
                <action android:name="com.melodyflow.app.SKIP_NEXT" />
                <action android:name="com.melodyflow.app.SKIP_PREV" />
                <action android:name="com.melodyflow.app.WIDGET_REFRESH" />
            </intent-filter>
            <meta-data android:name="android.appwidget.provider"
                android:resource="@xml/melody_widget_info" />
        </receiver>
'''

if 'MelodyWidgetProvider' in content:
    print("   Widget receiver already registered")
else:
    # Insert right before </application>
    content = content.replace('</application>', widget_block + '    </application>')
    with open(path, 'w') as f:
        f.write(content)
    print("   Widget receiver registered")
PYEOF

# ============================================================================
# PART 5 — Wire WidgetBridge into main.dart
# ============================================================================
echo ""
echo "✅ [5/7] Wiring WidgetBridge into main.dart..."

python3 << 'PYEOF'
path = 'lib/main.dart'
with open(path) as f:
    content = f.read()

if 'WidgetBridge' not in content:
    # Add import at top (after other data/services imports)
    if "import 'data/services/widget_bridge.dart';" not in content:
        # Find any existing data/services import and append after it
        import re
        m = re.search(r"(import 'data/services/[^']+\.dart';)", content)
        if m:
            content = content.replace(
                m.group(1),
                m.group(1) + "\nimport 'data/services/widget_bridge.dart';",
                1,
            )
        else:
            # Fallback: add after last top-level import
            m2 = re.search(r"(^import .+;\n)+", content, re.MULTILINE)
            if m2:
                insert = m2.end()
                content = (content[:insert]
                           + "import 'data/services/widget_bridge.dart';\n"
                           + content[insert:])

    # Hook init() after the audio handler is constructed.
    # Look for `await AudioService.init(` or similar.
    import re
    pattern = re.compile(
        r'(final\s+handler\s*=\s*await\s+AudioService\.init[^;]+;)',
        re.DOTALL,
    )
    m = pattern.search(content)
    if m:
        content = content.replace(
            m.group(1),
            m.group(1) + '\n  await WidgetBridge.instance.init(handler);',
            1,
        )
        print("   WidgetBridge.init wired after handler construction")
    else:
        print("   ⚠ Could not auto-wire WidgetBridge.init — you may need to add")
        print("     'await WidgetBridge.instance.init(handler);' after your")
        print("     AudioService.init(...) call in main.dart manually.")

    with open(path, 'w') as f:
        f.write(content)
else:
    print("   WidgetBridge already wired")
PYEOF

# ============================================================================
# PART 6 — Get packages
# ============================================================================
echo ""
echo "✅ [6/7] Installing packages..."
flutter pub get > /dev/null

# ============================================================================
# PART 7 — Commit and push
# ============================================================================
echo ""
echo "✅ [7/7] Committing and pushing..."
git add -A
git status --short | head -25
echo ""

git commit -m "Add 4x1 home-screen widget + app icon update"
git push

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Done! CI building."
echo ""
echo "Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "When the build succeeds and you install the new APK:"
echo ""
echo "  📲 Long-press empty home screen → Widgets"
echo "  📲 Scroll to 'Melody Flow' section"
echo "  📲 Drag the 4x1 widget to your home screen"
echo ""
echo "Widget shows: album art + song title + artist + prev/play/next buttons"
echo "Buttons control playback even when app is closed."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
