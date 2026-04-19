#!/bin/bash
# Melody Flow — Release Setup (fixed)
# Generates keystore, wires signing, builds signed release APK + AAB
# Run once:
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
# Step 1: Create keystore (interactive password prompt)
# ----------------------------------------------------------------------------
KEYSTORE_PATH="$HOME/melody-flow-release.jks"

if [ -f "$KEYSTORE_PATH" ]; then
  echo "✅ [1/4] Keystore already exists at $KEYSTORE_PATH"
  echo "   Skipping creation — we'll use the existing one."
else
  echo "✅ [1/4] Creating new keystore..."
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  YOU WILL BE ASKED FOR A PASSWORD:"
  echo ""
  echo "   Type the SAME password BOTH times when asked"
  echo "   (once for 'keystore password', then 'key password')"
  echo ""
  echo "   Requirements:"
  echo "     • Minimum 6 characters"
  echo "     • Can't be recovered if lost"
  echo "     • You'll need this every time you release an update"
  echo ""
  echo "   💾 SAVE IT IN YOUR PASSWORD MANAGER NOW"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  read -rp "Press Enter when ready..."
  echo ""

  # Pre-fill the distinguished-name fields so user only has to answer passwords.
  # keytool will prompt for:
  #   1. Keystore password
  #   2. Re-enter keystore password
  #   3. Key password (press Enter to reuse keystore password — recommended)
  keytool -genkey -v \
    -keystore "$KEYSTORE_PATH" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias melody_upload \
    -dname "CN=Melody Flow, OU=App, O=Melody Flow, L=City, ST=State, C=IN"

  echo ""
  echo "✅ Keystore created at: $KEYSTORE_PATH"
fi

# ----------------------------------------------------------------------------
# Step 2: Get the password again and write android/app/key.properties
# ----------------------------------------------------------------------------
echo ""
echo "✅ [2/4] Storing keystore password for Gradle..."
echo ""
echo "   Enter the SAME password you used above (it won't display):"
read -rs KEYSTORE_PASS
echo ""

if [ -z "$KEYSTORE_PASS" ]; then
  echo "❌ Password was empty. Re-run the script and type a real password."
  exit 1
fi

if [ ${#KEYSTORE_PASS} -lt 6 ]; then
  echo "❌ Password must be at least 6 characters. Re-run."
  exit 1
fi

# Verify the password actually opens the keystore before saving
if ! keytool -list -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASS" > /dev/null 2>&1; then
  echo "❌ That password doesn't unlock the keystore at $KEYSTORE_PATH."
  echo "   Re-run the script and enter the correct password."
  exit 1
fi

mkdir -p android/app
cat > android/app/key.properties << EOF
storePassword=$KEYSTORE_PASS
keyPassword=$KEYSTORE_PASS
keyAlias=melody_upload
storeFile=$KEYSTORE_PATH
EOF

# Remove any old location
rm -f android/key.properties

# Make sure secrets never get committed
touch .gitignore
if ! grep -q "android/app/key.properties" .gitignore; then
  echo "android/app/key.properties" >> .gitignore
fi
if ! grep -q "android/key.properties" .gitignore; then
  echo "android/key.properties" >> .gitignore
fi
if ! grep -q "^\*.jks$" .gitignore; then
  echo "*.jks" >> .gitignore
fi
if ! grep -q "^\*.keystore$" .gitignore; then
  echo "*.keystore" >> .gitignore
fi

echo "   ✓ Saved to android/app/key.properties (gitignored — never committed)"

# ----------------------------------------------------------------------------
# Step 3: Wire signing config into android/app/build.gradle
# ----------------------------------------------------------------------------
echo ""
echo "✅ [3/4] Wiring signing config into build.gradle..."

python3 << 'PYEOF'
import re

path = 'android/app/build.gradle'
with open(path, 'r') as f:
    content = f.read()

# ---- 1. Add keystoreProperties loader at the top (before `android {`) ----
loader_block = '''
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('app/key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

'''

if 'keystoreProperties' not in content:
    # Insert right before `android {`
    content = re.sub(
        r'^(android \{)',
        loader_block + r'\1',
        content,
        count=1,
        flags=re.MULTILINE,
    )
    print("   ✓ Added keystoreProperties loader")

# ---- 2. Replace existing signingConfigs with a working release config ----
working_signing = '''    signingConfigs {
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

# Strip any existing signingConfigs { ... } block, however formatted
def strip_block(text, name):
    pattern = re.compile(rf'\n\s*{name}\s*\{{')
    m = pattern.search(text)
    if not m:
        return text
    start = m.start()
    depth = 0
    i = m.end() - 1  # at opening brace
    while i < len(text):
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return text[:start] + text[i+1:]
        i += 1
    return text

content = strip_block(content, 'signingConfigs')

# Insert a fresh signingConfigs block right before `buildTypes`
if 'buildTypes' in content:
    content = content.replace(
        'buildTypes {',
        working_signing + '\n    buildTypes {',
        1,
    )
    print("   ✓ Added signingConfigs.release")

# ---- 3. Make the release buildType USE signingConfigs.release ----
# Find the release buildType inside buildTypes { release { ... } }
# and set its signingConfig to signingConfigs.release
def set_release_signing(text):
    # Find `release {` inside buildTypes
    # Tolerate whatever is already there (debug keystore, commented out, etc.)
    bt_match = re.search(r'buildTypes\s*\{', text)
    if not bt_match:
        return text
    i = bt_match.end()
    # Find `release {` after it
    rel_match = re.search(r'\brelease\s*\{', text[i:])
    if not rel_match:
        return text
    block_start = i + rel_match.end()
    depth = 1
    j = block_start
    while j < len(text) and depth > 0:
        c = text[j]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
        j += 1
    block_end = j - 1  # points at the closing `}`
    inner = text[block_start:block_end]
    # Remove existing signingConfig line(s)
    inner = re.sub(r'^\s*signingConfig\s+.*$', '', inner, flags=re.MULTILINE)
    # Insert ours at the top
    inner = '\n            signingConfig signingConfigs.release' + inner
    return text[:block_start] + inner + text[block_end:]

content = set_release_signing(content)
print("   ✓ Wired release buildType to use signingConfigs.release")

with open(path, 'w') as f:
    f.write(content)
PYEOF

# ----------------------------------------------------------------------------
# Step 4: Build release APK + AAB locally
# ----------------------------------------------------------------------------
echo ""
echo "✅ [4/4] Building signed release (3–5 min)..."
echo ""

flutter clean > /dev/null 2>&1 || true
flutter pub get > /dev/null

echo "   📦 Building APK..."
if flutter build apk --release; then
  echo "   ✓ APK built"
else
  echo "   ⚠️  APK build failed — check error above"
fi

echo ""
echo "   📦 Building AAB for Play Store..."
if flutter build appbundle --release; then
  echo "   ✓ AAB built"
else
  echo "   ⚠️  AAB build failed — check error above"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Done!"
echo ""
echo "Your release artifacts:"
echo ""

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"

if [ -f "$APK_PATH" ]; then
  APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
  echo "   ✅ APK (sideload / share):"
  echo "        $APK_PATH  ($APK_SIZE)"
fi

if [ -f "$AAB_PATH" ]; then
  AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
  echo "   ✅ AAB (upload to Play Store):"
  echo "        $AAB_PATH  ($AAB_SIZE)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NEXT STEPS FOR PLAY STORE:"
echo "  1. Go to https://play.google.com/console"
echo "  2. Pay the one-time \$25 developer fee"
echo "  3. Create app → name: Melody Flow → category: Music & Audio"
echo "  4. Set up internal testing track → upload the .aab file"
echo "  5. Add your email as a tester → install test version on phone"
echo ""
echo "⚠️  BACKUP THESE TWO THINGS — losing either means you can NEVER"
echo "   update your app on Play Store again:"
echo ""
echo "   1. Keystore file: $KEYSTORE_PATH"
echo "      Copy it to: Google Drive / iCloud / USB drive"
echo ""
echo "   2. Keystore password — in your password manager"
echo ""
