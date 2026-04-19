#!/bin/bash
# Melody Flow — Release Setup
# Generates a keystore, wires signing, builds release APK + AAB for Play Store.
# Run once per machine:
#   bash release_setup.sh

set -e

echo "🔐 Melody Flow Release Setup"
echo "============================="
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Run from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Step 1: Create keystore (if not already present)
# ----------------------------------------------------------------------------
KEYSTORE_PATH="$HOME/melody-flow-release.jks"

if [ -f "$KEYSTORE_PATH" ]; then
  echo "✅ [1/4] Keystore already exists at $KEYSTORE_PATH"
  echo "   Skipping creation."
else
  echo "✅ [1/4] Creating new keystore..."
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  IMPORTANT: You will be prompted for a password."
  echo "    REMEMBER THIS PASSWORD — you will need it:"
  echo "      • Every time you build a release"
  echo "      • For the lifetime of the app on Play Store"
  echo ""
  echo "    LOSING THIS PASSWORD = cannot update your app ever again."
  echo "    Save it in your password manager NOW."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  read -rp "Press Enter to continue..."

  keytool -genkey -v \
    -keystore "$KEYSTORE_PATH" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias melody_upload \
    -storepass "" \
    -keypass "" || {
      # If no password was typed, fail clearly
      echo ""
      echo "❌ Keystore creation failed. Re-run and enter password when prompted."
      exit 1
    }

  echo ""
  echo "✅ Keystore created at: $KEYSTORE_PATH"
fi

# ----------------------------------------------------------------------------
# Step 2: Write android/key.properties
# ----------------------------------------------------------------------------
echo ""
echo "✅ [2/4] Creating android/key.properties"
echo ""
echo "Enter the keystore password you just used:"
read -rs KEYSTORE_PASS
echo ""

cat > android/key.properties << EOF
storePassword=$KEYSTORE_PASS
keyPassword=$KEYSTORE_PASS
keyAlias=melody_upload
storeFile=$KEYSTORE_PATH
EOF

# Make sure this file isn't committed
if ! grep -q "android/key.properties" .gitignore 2>/dev/null; then
  echo "android/key.properties" >> .gitignore
fi
if ! grep -q "\*.jks" .gitignore 2>/dev/null; then
  echo "*.jks" >> .gitignore
fi

echo "   ✓ android/key.properties written (gitignored — never commits)"

# ----------------------------------------------------------------------------
# Step 3: Wire signing config into android/app/build.gradle
# ----------------------------------------------------------------------------
echo "✅ [3/4] Wiring signing into build.gradle..."

python3 << 'PYEOF'
with open('android/app/build.gradle', 'r') as f:
    content = f.read()

# Check if already wired
if 'keystoreProperties' in content:
    print("   Already wired, skipping")
else:
    # Add key loading at the top (after plugin declarations)
    top_block = '''
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('app/key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
'''
    # Find position after last "id ..." in the plugins {} block
    import re
    m = re.search(r'^plugins \{[\s\S]*?\}\s*$', content, re.MULTILINE)
    if m:
        insert_at = m.end()
        content = content[:insert_at] + '\n' + top_block + content[insert_at:]

    # Replace the existing signingConfigs block (which was commented out) with a real one
    sign_block = '''
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
'''
    # Strip any existing signingConfigs block
    content = re.sub(
        r'signingConfigs\s*\{[^}]*(?:\{[^}]*\}[^}]*)*\}',
        sign_block.strip(),
        content,
        count=1,
    )

    # Replace the release buildType's signingConfig
    content = re.sub(
        r'release\s*\{[^}]*signingConfig\s+signingConfigs\.\w+',
        'release {\n            signingConfig signingConfigs.release',
        content,
    )

    with open('android/app/build.gradle', 'w') as f:
        f.write(content)
    print("   Signing wired into build.gradle")
PYEOF

# The python patch above places key.properties at app/key.properties
# Move it there if we wrote it to android/
if [ -f "android/key.properties" ] && [ ! -f "android/app/key.properties" ]; then
  mv android/key.properties android/app/key.properties
fi

# ----------------------------------------------------------------------------
# Step 4: Build release AAB + APK
# ----------------------------------------------------------------------------
echo ""
echo "✅ [4/4] Building signed release..."
echo "   (This takes 3–5 minutes first time)"
echo ""

flutter clean > /dev/null
flutter pub get > /dev/null

echo "   Building APK..."
flutter build apk --release || echo "   ⚠️  APK build had issues"

echo ""
echo "   Building AAB for Play Store..."
flutter build appbundle --release || echo "   ⚠️  AAB build had issues"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Done! Your release artifacts:"
echo ""
echo "   APK (for sideloading):"
echo "     build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "   AAB (for Play Store upload):"
echo "     build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NEXT STEPS:"
echo "  1. Go to https://play.google.com/console"
echo "  2. Sign up as a developer (\$25 one-time fee)"
echo "  3. Create app → Name: Melody Flow"
echo "  4. Set up internal testing → upload the .aab file"
echo "  5. Add testers by email, share the test link"
echo ""
echo "The AAB is signed with your upload key. Google will re-sign with"
echo "their own key when distributing to users (standard Play Store flow)."
echo ""
echo "⚠️  REMEMBER:"
echo "   BACKUP your keystore: $KEYSTORE_PATH"
echo "   BACKUP your password"
echo "   LOSE either = can't update your app ever again"
