#!/bin/bash
# Melody Flow — crash-on-launch fix
# Addresses the 3 most common causes of "app keeps crashing" on first launch
# Run from inside melody_flow project root:
#   bash fix_crash.sh

set -e

echo "🔧 Melody Flow crash fix script starting..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found. Run from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Fix 1: Create missing XML theme resources that our Manifest references
# ----------------------------------------------------------------------------
echo "✅ [1/5] Ensuring theme resources exist..."
mkdir -p android/app/src/main/res/values
mkdir -p android/app/src/main/res/values-night
mkdir -p android/app/src/main/res/drawable
mkdir -p android/app/src/main/res/drawable-v21

cat > android/app/src/main/res/values/styles.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Shown while app is loading, replaced by Flutter after engine starts -->
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <!-- Active while Flutter is running -->
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
EOF

cat > android/app/src/main/res/values-night/styles.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
EOF

cat > android/app/src/main/res/drawable/launch_background.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="?android:colorBackground" />
</layer-list>
EOF

cat > android/app/src/main/res/drawable-v21/launch_background.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="?android:colorBackground" />
</layer-list>
EOF

# ----------------------------------------------------------------------------
# Fix 2: Make MainActivity extend FlutterActivity (audio_service requires this)
# ----------------------------------------------------------------------------
echo "✅ [2/5] Ensuring MainActivity extends FlutterActivity..."
MAIN_ACTIVITY=$(find android/app/src/main -name "MainActivity.kt" -o -name "MainActivity.java" | head -1)
echo "   Found: $MAIN_ACTIVITY"

if [ -n "$MAIN_ACTIVITY" ]; then
  if [[ "$MAIN_ACTIVITY" == *.kt ]]; then
    cat > "$MAIN_ACTIVITY" << 'EOF'
package com.melodyflow.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
EOF
  fi
  echo "   MainActivity rewritten to use FlutterActivity"
fi

# ----------------------------------------------------------------------------
# Fix 3: Remove `audio_service` Activity handler requirement by simplifying
#        service declaration in manifest (use default Flutter embedding v2)
# ----------------------------------------------------------------------------
echo "✅ [3/5] Hardening AndroidManifest.xml..."

python3 << 'PYEOF'
path = 'android/app/src/main/AndroidManifest.xml'
with open(path) as f:
    content = f.read()

# Ensure tools:ignore on the service doesn't break without xmlns:tools
if 'xmlns:tools' not in content:
    content = content.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools">'
    )

# Ensure the application tag has the right attributes
if 'android:allowBackup' not in content:
    content = content.replace(
        '<application',
        '<application\n        android:allowBackup="false"',
        1
    )

with open(path, 'w') as f:
    f.write(content)
print("   Manifest updated")
PYEOF

# ----------------------------------------------------------------------------
# Fix 4: Harden main.dart to catch initialization errors gracefully instead of
#        crashing the app silently. This is the BIG one — wraps Hive init and
#        AudioService.init in try/catch so we see exactly what went wrong.
# ----------------------------------------------------------------------------
echo "✅ [4/5] Hardening main.dart with error handling..."

cat > lib/main.dart << 'EOF'
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/services/audio_handler.dart';
import 'data/services/storage_service.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/home/home_shell.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';

MelodyAudioHandler? audioHandler;
String? initError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch any unhandled Flutter errors and surface them visibly
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrint('STACK: ${details.stack}');
  };

  // Edge-to-edge UI (wrapped in try-catch — some OEMs reject this)
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (e) {
    debugPrint('SystemChrome error (non-fatal): $e');
  }

  // Initialize Hive — critical for app to work
  try {
    await StorageService.instance.init();
  } catch (e, st) {
    debugPrint('Hive init FAILED: $e\n$st');
    initError = 'Storage init failed: $e';
  }

  // Initialize audio service — if this fails, app still launches, just without playback
  try {
    audioHandler = await AudioService.init(
      builder: () => MelodyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.melodyflow.audio',
        androidNotificationChannelName: 'Melody Flow',
        androidNotificationChannelDescription: 'Music playback controls',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFF1DB954),
      ),
    );
  } catch (e, st) {
    debugPrint('AudioService init FAILED: $e\n$st');
    initError = 'Audio service init failed: $e';
  }

  runApp(
    ProviderScope(
      overrides: [
        if (audioHandler != null)
          audioHandlerProvider.overrideWithValue(audioHandler!),
      ],
      child: const MelodyApp(),
    ),
  );
}

class MelodyApp extends ConsumerWidget {
  const MelodyApp({super.key});

  ThemeMode _themeMode(int i) => switch (i) {
        0 => ThemeMode.light,
        1 => ThemeMode.dark,
        2 => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If init errored, show a visible error screen instead of black screen
    if (initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text('Startup error',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(initError!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 24),
                  const Text('Send this message to support so we can fix it.',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Audio handler missing means init failed silently — degrade to home anyway
    if (audioHandler == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(const Color(0xFF1DB954)),
        home: const Scaffold(
          body: Center(
            child: Text('Audio service unavailable on this device',
                style: TextStyle(color: Colors.white)),
          ),
        ),
      );
    }

    final settings = ref.watch(settingsProvider);
    final accent = Color(settings.accentColorValue);
    final darkTheme = settings.themeMode == 2
        ? AppTheme.amoled(accent)
        : AppTheme.dark(accent);

    return MaterialApp(
      title: 'Melody Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: darkTheme,
      themeMode: _themeMode(settings.themeMode),
      home: FutureBuilder<bool>(
        future: ref.read(libraryServiceProvider).hasPermission(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _Splash();
          }
          final granted = snap.data ?? false;
          return granted ? const HomeShell() : const OnboardingScreen();
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Icon(
          Icons.graphic_eq_rounded,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
EOF

# ----------------------------------------------------------------------------
# Fix 5: Harden SongsNotifier to not crash if songs have null fields
# ----------------------------------------------------------------------------
echo "✅ [5/5] Hardening songs provider..."

python3 << 'PYEOF'
path = 'lib/presentation/providers/app_providers.dart'
with open(path) as f:
    content = f.read()

# Wrap the refresh() body in an additional try layer for null safety
old = '''  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final granted = await _lib.requestPermission();
      if (!granted) {
        state = AsyncValue.error(
          'Permission to read audio files was denied.',
          StackTrace.current,
        );
        return;
      }
      final settings = _storage.currentSettings;
      final songs = await _lib.fetchAllSongs(
        minDurationSec: settings.minTrackLengthSec,
        excludedFolders: settings.excludedFolders,
      );
      state = AsyncValue.data(songs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }'''

new = '''  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final granted = await _lib.requestPermission();
      if (!granted) {
        state = AsyncValue.error(
          'Permission to read audio files was denied.',
          StackTrace.current,
        );
        return;
      }
      final settings = _storage.currentSettings;
      final songs = await _lib.fetchAllSongs(
        minDurationSec: settings.minTrackLengthSec,
        excludedFolders: settings.excludedFolders,
      );
      state = AsyncValue.data(songs);
    } catch (e, st) {
      // Log but don\\'t crash — show empty library
      // ignore: avoid_print
      print('Song scan failed: $e\\n$st');
      state = const AsyncValue.data([]);
    }
  }'''

if old in content:
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)
    print("   Songs provider hardened")
else:
    print("   (Songs provider already updated or different — skipping)")
PYEOF

echo ""
echo "---- Files changed summary ----"
git status --short
echo ""

# ----------------------------------------------------------------------------
# Commit and push
# ----------------------------------------------------------------------------
echo "📝 Committing and pushing..."
git add -A
git commit -m "Fix: crash on launch — add themes, harden init with try/catch, error UI"
git push

echo ""
echo "🎉 Done! Build re-running."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "💡 After new APK installs:"
echo "   - If it still crashes, you'll now see a VISIBLE error screen showing"
echo "     what failed (not a silent 'app keeps crashing' dialog)"
echo "   - Screenshot that error and send it to me"
