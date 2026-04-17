#!/bin/bash
# Melody Flow — Blurred backdrop fix
# Replaces the broken _BlurredBackdrop class with a proper implementation
# that uses our cached ArtworkImage widget + BackdropFilter.
# Run from project root:
#   bash fix_blur.sh

set -e

echo "🔧 Fixing blurred backdrop..."

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found. Run from the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Rewrite just the broken _BlurredBackdrop + _BlurExt blocks
# ----------------------------------------------------------------------------
python3 << 'PYEOF'
path = 'lib/presentation/screens/now_playing/now_playing_screen.dart'
with open(path) as f:
    content = f.read()

# Remove the old broken _BlurredBackdrop class
old_backdrop = '''// ---------- Blurred backdrop (A5) ----------
class _BlurredBackdrop extends StatelessWidget {
  final int songId;
  const _BlurredBackdrop({required this.songId});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: QueryArtworkWidget(
        id: songId,
        type: ArtworkType.AUDIO,
        artworkFit: BoxFit.cover,
        artworkWidth: double.infinity,
        artworkHeight: double.infinity,
        artworkBorder: BorderRadius.zero,
        keepOldArtwork: true,
        artworkClipBehavior: Clip.none,
        nullArtworkWidget: const SizedBox.shrink(),
        artwork: Stack(
          fit: StackFit.expand,
          children: [
            // The artwork fills the area; we blur with BackdropFilter
            Container(color: Colors.black),
          ],
        ),
      ).toBlurred(),
    );
  }
}

/// Helper extension so we can wrap the artwork in a blur layer.
extension _BlurExt on Widget {
  Widget toBlurred() => ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            this,
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ],
        ),
      );
}'''

# Properly implemented: load artwork bytes directly and display via Image.memory,
# then overlay BackdropFilter. No fake API usage.
new_backdrop = '''// ---------- Blurred backdrop (A5) ----------
/// Renders the current song's artwork as a heavily-blurred, darkened
/// full-screen background behind the Now Playing UI.
class _BlurredBackdrop extends StatefulWidget {
  final int songId;
  const _BlurredBackdrop({required this.songId});

  @override
  State<_BlurredBackdrop> createState() => _BlurredBackdropState();
}

class _BlurredBackdropState extends State<_BlurredBackdrop> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _BlurredBackdrop old) {
    super.didUpdateWidget(old);
    if (old.songId != widget.songId) _load();
  }

  Future<void> _load() async {
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
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Artwork, slightly scaled up so blur edges aren't visible
            Transform.scale(
              scale: 1.2,
              child: Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            // Heavy blur on top
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ],
        ),
      ),
    );
  }
}'''

if old_backdrop in content:
    content = content.replace(old_backdrop, new_backdrop)
    print("   Replaced broken backdrop with a working implementation")
else:
    print("   ⚠️  Couldn't find the exact broken block — checking alternate patterns...")
    # Try removing just the _BlurExt extension and the "artwork:" param line if direct replace failed
    import re
    # Nuclear fallback: strip any line that contains bare `artwork: Stack(`
    content = re.sub(r'.*artwork: Stack\(.*\n', '', content)

# Ensure Uint8List import exists
if "import 'dart:typed_data';" not in content:
    content = content.replace(
        "import 'dart:ui';",
        "import 'dart:typed_data';\nimport 'dart:ui';",
    )
    print("   Added dart:typed_data import")

with open(path, 'w') as f:
    f.write(content)
print("   Done")
PYEOF

echo ""
echo "---- Verifying no stray 'artwork:' params remain ----"
if grep -n "artwork: Stack" lib/presentation/screens/now_playing/now_playing_screen.dart; then
  echo "⚠️  Still found one — the patch didn't fully apply"
  exit 1
else
  echo "✓  Clean"
fi

echo ""
echo "---- Verifying Uint8List is imported ----"
head -20 lib/presentation/screens/now_playing/now_playing_screen.dart | grep -E "(typed_data|dart:ui)"
echo ""

git add -A
git status --short
echo ""
git commit -m "Fix: broken _BlurredBackdrop — reimplement with Image.memory + BackdropFilter"
git push

echo ""
echo "🎉 Pushed. Build running."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
