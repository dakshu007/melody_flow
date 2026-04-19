#!/bin/bash
# Melody Flow — Fix theme-switch crash
# Fixes "Looking up a deactivated widget's ancestor is unsafe" error that
# appears when switching between Dark/Light/AMOLED themes.
#
# Root cause: async palette extraction + artwork loading were firing on every
# rebuild, and setState() could be called on a deactivated widget during the
# rebuild window.
#
# Run from project root:
#   bash fix_theme_switch.sh

set -e

echo "🔧 Fixing theme-switch crash in Now Playing screen..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Run from inside the melody_flow folder."
  exit 1
fi

python3 << 'PYEOF'
path = 'lib/presentation/screens/now_playing/now_playing_screen.dart'
with open(path) as f:
    content = f.read()

# --------------------------------------------------------------------------
# Fix 1: _extractColor() — guard against running during rebuild, and use
# post-frame callback so we never call setState() mid-build.
# --------------------------------------------------------------------------
old_extract = '''  Color _bgColor = const Color(0xFF1E1E1E);
  int? _lastArtSongId;
  bool _showLyrics = false;
  double _dragY = 0;
  static const _dismissThreshold = 120.0;

  Future<void> _extractColor(int songId, {required bool enabled}) async {
    if (!enabled) {
      setState(() => _bgColor = const Color(0xFF1E1E1E));
      return;
    }
    if (_lastArtSongId == songId) return;
    _lastArtSongId = songId;
    try {
      final art = await OnAudioQuery()
          .queryArtwork(songId, ArtworkType.AUDIO, size: 200);
      if (art == null || !mounted) return;
      final palette =
          await PaletteGenerator.fromImageProvider(MemoryImage(art));
      if (!mounted) return;
      setState(() {
        _bgColor = palette.darkMutedColor?.color ??
            palette.darkVibrantColor?.color ??
            palette.dominantColor?.color ??
            const Color(0xFF1E1E1E);
      });
    } catch (_) {}
  }'''

new_extract = '''  Color _bgColor = const Color(0xFF1E1E1E);
  int? _lastArtSongId;
  bool _extractionRunning = false;
  bool _showLyrics = false;
  double _dragY = 0;
  static const _dismissThreshold = 120.0;

  /// Extract a dominant color from the current song's artwork.
  ///
  /// Safe against:
  ///  - Theme rebuilds (widget deactivation while async in-flight)
  ///  - Concurrent calls for the same song (dedupes via _extractionRunning)
  ///  - Dispose during async (mounted check before setState)
  ///  - Mid-build setState (uses addPostFrameCallback)
  Future<void> _extractColor(int songId, {required bool enabled}) async {
    if (!enabled) {
      // Reset only if we had a non-default color; guard against mid-build setState.
      if (_bgColor != const Color(0xFF1E1E1E)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _bgColor = const Color(0xFF1E1E1E));
        });
      }
      return;
    }
    if (_lastArtSongId == songId) return;
    if (_extractionRunning) return;
    _extractionRunning = true;
    _lastArtSongId = songId;

    try {
      final art = await OnAudioQuery()
          .queryArtwork(songId, ArtworkType.AUDIO, size: 200);
      if (art == null || !mounted) return;
      final palette =
          await PaletteGenerator.fromImageProvider(MemoryImage(art));
      if (!mounted) return;

      final newColor = palette.darkMutedColor?.color ??
          palette.darkVibrantColor?.color ??
          palette.dominantColor?.color ??
          const Color(0xFF1E1E1E);

      // Defer setState to next frame so we're never inside a build() call
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _bgColor = newColor);
      });
    } catch (_) {
      // Ignore — any failure just keeps the default color
    } finally {
      _extractionRunning = false;
    }
  }'''

if old_extract in content:
    content = content.replace(old_extract, new_extract)
    print("   ✓ _extractColor hardened against theme-switch rebuilds")
else:
    print("   ⚠ Could not find _extractColor block — may already be patched")

# --------------------------------------------------------------------------
# Fix 2: _BlurredBackdropState._load() — call via post-frame and mounted check
# before setState. didUpdateWidget should only fire on songId change (already
# does), but _load itself needs to be defensive.
# --------------------------------------------------------------------------
old_load = '''  Future<void> _load() async {
    try {
      final b = await OnAudioQuery().queryArtwork(
        widget.songId,
        ArtworkType.AUDIO,
        size: 400,
      );
      if (!mounted) return;
      setState(() => _bytes = b);
    } catch (_) {
      if (!mounted) return;
      setState(() => _bytes = null);
    }
  }'''

new_load = '''  Future<void> _load() async {
    try {
      final b = await OnAudioQuery().queryArtwork(
        widget.songId,
        ArtworkType.AUDIO,
        size: 400,
      );
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _bytes = b);
      });
    } catch (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _bytes = null);
      });
    }
  }'''

if old_load in content:
    content = content.replace(old_load, new_load)
    print("   ✓ _BlurredBackdrop._load hardened against theme-switch rebuilds")
else:
    print("   ⚠ Could not find _BlurredBackdrop._load — may already be patched")

# --------------------------------------------------------------------------
# Fix 3: The _extractColor() call inside build() should not run on every
# rebuild. Wrap it in post-frame so it only fires AFTER build completes,
# preventing the whole class of "setState during build" issues.
# --------------------------------------------------------------------------
old_call = '''    final songId = mediaItem.extras?['songId'] as int?;
    if (songId != null) {
      _extractColor(songId, enabled: settings.dynamicColorFromArtwork);
    }'''

new_call = '''    final songId = mediaItem.extras?['songId'] as int?;
    if (songId != null) {
      // Defer to post-frame so async work never starts during build()
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _extractColor(songId, enabled: settings.dynamicColorFromArtwork);
        }
      });
    }'''

if old_call in content:
    content = content.replace(old_call, new_call)
    print("   ✓ _extractColor call deferred to post-frame")
else:
    print("   ⚠ Could not find _extractColor call — may already be patched")

with open(path, 'w') as f:
    f.write(content)

print("")
print("   Done patching.")
PYEOF

# ----------------------------------------------------------------------------
# Also fix the same class of issue in ArtworkImage widget - it's the artwork
# cache used across many screens, and its async _resolve() calls setState too.
# ----------------------------------------------------------------------------
python3 << 'PYEOF'
import os
path = 'lib/presentation/widgets/artwork_image.dart'
if not os.path.exists(path):
    print("   (artwork_image.dart not found — skipping)")
else:
    with open(path) as f:
        content = f.read()

    # The resolve method calls setState from an async context. Guard it.
    old = '''      _ArtCache.instance.put(_key, bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _tried = true;
      });
    } catch (_) {
      _ArtCache.instance.put(_key, null);
      if (!mounted) return;
      setState(() => _tried = true);
    } finally {
      _loading = false;
    }'''

    new = '''      _ArtCache.instance.put(_key, bytes);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _bytes = bytes;
            _tried = true;
          });
        }
      });
    } catch (_) {
      _ArtCache.instance.put(_key, null);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tried = true);
      });
    } finally {
      _loading = false;
    }'''

    if old in content:
        content = content.replace(old, new)
        with open(path, 'w') as f:
            f.write(content)
        print("   ✓ artwork_image.dart hardened")
    else:
        print("   (artwork_image.dart already safe or different — skipping)")
PYEOF

echo ""
echo "---- Committing and pushing ----"
git add -A
git status --short
echo ""

git commit -m "Fix: theme-switch crash — use post-frame callbacks for async setState in Now Playing, BlurredBackdrop, and ArtworkImage"
git push

echo ""
echo "🎉 Pushed! CI rebuilding now."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "   After you install the new APK and test:"
echo "     1. Open a song to enter Now Playing"
echo "     2. Go back, open Settings → Theme → switch to Light"
echo "     3. Switch back to Dark or AMOLED"
echo "     4. Repeat 5-6 times rapidly — no red error screen"
echo ""
echo "   If it still crashes with a different error, paste the new screen"
echo "   and I'll patch that too. This class of bug can have multiple"
echo "   spots; we're fixing the 3 I'm confident about now."
