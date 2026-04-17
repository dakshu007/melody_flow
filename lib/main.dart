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

    // FIX #9+#10: Defer queue restore until library scan completes.
    // We can't resolve song ids to Song objects before songs are loaded.
    // The provider layer handles this via _tryRestoreQueue in app_providers.dart.
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
