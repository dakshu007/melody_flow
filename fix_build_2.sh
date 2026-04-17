#!/bin/bash
# Melody Flow — round 2 build fix
# Run from inside melody_flow project root:
#   bash fix_build_2.sh

set -e

echo "🔧 Melody Flow build fix round 2..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found. Run this from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Fix 1: Add xmlns:tools namespace to AndroidManifest.xml
# ----------------------------------------------------------------------------
echo "✅ [1/3] Fixing AndroidManifest.xml namespace..."
MANIFEST="android/app/src/main/AndroidManifest.xml"

# Only add if not already present
if ! grep -q 'xmlns:tools' "$MANIFEST"; then
  # Replace the opening <manifest> tag with one that includes xmlns:tools
  python3 << 'PYEOF'
path = 'android/app/src/main/AndroidManifest.xml'
with open(path, 'r') as f:
    content = f.read()

content = content.replace(
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools">'
)

with open(path, 'w') as f:
    f.write(content)

print("   AndroidManifest.xml patched")
PYEOF
else
  echo "   xmlns:tools already present, skipping"
fi

# ----------------------------------------------------------------------------
# Fix 2: Make assets/images/ and assets/icons/ trackable by git
# ----------------------------------------------------------------------------
echo "✅ [2/3] Creating .gitkeep files so asset folders get tracked..."
mkdir -p assets/images assets/icons
touch assets/images/.gitkeep assets/icons/.gitkeep

# ----------------------------------------------------------------------------
# Fix 3: Verify changes
# ----------------------------------------------------------------------------
echo "✅ [3/3] Verifying..."
echo ""
echo "---- AndroidManifest.xml first 3 lines ----"
head -3 android/app/src/main/AndroidManifest.xml
echo ""
echo "---- assets folder contents ----"
ls -la assets/images/ assets/icons/
echo ""

# ----------------------------------------------------------------------------
# Commit and push
# ----------------------------------------------------------------------------
echo "📝 Committing and pushing..."
git add -A
git status --short
echo ""
git commit -m "Fix: add xmlns:tools to manifest and commit empty asset dirs"
git push

echo ""
echo "🎉 Done! Build is re-running."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
