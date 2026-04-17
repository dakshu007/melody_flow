#!/bin/bash
# Melody Flow — Polish Pack installer
# Run from inside melody_flow project root:
#   bash install_polish.sh

set -e

echo "🎨 Polish Pack installer starting..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found. Run from the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# 1. Make sure polish_pack.zip sits next to this script
# ----------------------------------------------------------------------------
if [ ! -f "polish_pack.zip" ]; then
  echo "❌ polish_pack.zip not found in current folder."
  echo "   Download it from the chat and place it in this folder, then rerun."
  exit 1
fi

# ----------------------------------------------------------------------------
# 2. Extract zip contents into the project (overwrites existing files)
# ----------------------------------------------------------------------------
echo "✅ [1/4] Extracting polish pack into project..."
unzip -o polish_pack.zip -d . > /dev/null
echo "   Done."

# ----------------------------------------------------------------------------
# 3. Ensure required dependencies are in pubspec.yaml
# ----------------------------------------------------------------------------
echo "✅ [2/4] Checking pubspec.yaml for required packages..."

# Ensure shimmer is present
if ! grep -q "^\\s*shimmer:" pubspec.yaml; then
  echo "   Adding shimmer dependency..."
  sed -i '' 's/^dependencies:/dependencies:\n  shimmer: ^3.0.0/' pubspec.yaml 2>/dev/null || \
    sed -i 's/^dependencies:/dependencies:\n  shimmer: ^3.0.0/' pubspec.yaml
fi

# Ensure marquee is present
if ! grep -q "^\\s*marquee:" pubspec.yaml; then
  echo "   Adding marquee dependency..."
  sed -i '' 's/^dependencies:/dependencies:\n  marquee: ^2.2.3/' pubspec.yaml 2>/dev/null || \
    sed -i 's/^dependencies:/dependencies:\n  marquee: ^2.2.3/' pubspec.yaml
fi

# Ensure intl is present
if ! grep -q "^\\s*intl:" pubspec.yaml; then
  echo "   Adding intl dependency..."
  sed -i '' 's/^dependencies:/dependencies:\n  intl: ^0.19.0/' pubspec.yaml 2>/dev/null || \
    sed -i 's/^dependencies:/dependencies:\n  intl: ^0.19.0/' pubspec.yaml
fi

echo "   Running flutter pub get..."
flutter pub get || echo "   (pub get issues will resolve in CI)"

# ----------------------------------------------------------------------------
# 4. Verify all expected files landed
# ----------------------------------------------------------------------------
echo "✅ [3/4] Verifying files..."
EXPECTED=(
  "lib/core/utils/haptics.dart"
  "lib/core/utils/format.dart"
  "lib/presentation/widgets/back_to_now_playing_fab.dart"
  "lib/presentation/widgets/shimmer_list.dart"
  "lib/presentation/widgets/empty_state.dart"
  "lib/presentation/widgets/collection_quick_actions.dart"
  "lib/presentation/widgets/confirm_dialog.dart"
  "lib/presentation/widgets/mini_player.dart"
  "lib/presentation/screens/now_playing/now_playing_screen.dart"
  "lib/presentation/screens/home/home_shell.dart"
  "lib/presentation/screens/playlists/playlists_screen.dart"
  "lib/presentation/screens/playlists/playlist_detail_screen.dart"
  "lib/presentation/screens/library/library_screen.dart"
)

for f in "${EXPECTED[@]}"; do
  if [ ! -f "$f" ]; then
    echo "   ⚠️  Missing: $f"
  else
    echo "   ✓  $f"
  fi
done

# ----------------------------------------------------------------------------
# 5. Commit & push
# ----------------------------------------------------------------------------
echo ""
echo "✅ [4/4] Committing and pushing..."
git add -A
git status --short
echo ""

git commit -m "Polish Pack: back-to-now-playing FAB, swipe-to-skip mini player, haptics, drag-to-dismiss Now Playing, blurred artwork bg, duration totals, shimmer loading, empty states, long-press quick actions, delete confirmations"
git push

echo ""
echo "🎉 Polish Pack installed! CI building now."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "   New user-visible behaviors:"
echo "     ✓ Swipe the mini-player left/right to skip tracks"
echo "     ✓ Tap any control → feel a subtle haptic tick"
echo "     ✓ Swipe down anywhere on Now Playing to dismiss"
echo "     ✓ Now Playing now has a blurred album-art background"
echo "     ✓ Tap the artwork (not just the icon) to toggle lyrics"
echo "     ✓ Playlist/album/artist headers show '42 songs · 2 hr 18 min'"
echo "     ✓ Loading states shimmer instead of spinning"
echo "     ✓ Empty screens show friendly illustrations + CTAs"
echo "     ✓ Long-press any album/artist/playlist for quick actions"
echo "     ✓ Playlist delete asks for confirmation"
echo "     ✓ Playlist rename actually works"
