import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/services/audio_handler.dart';
import 'data/services/storage_service.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/home/home_shell.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';

late MelodyAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge UI
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // 1. Open Hive boxes
  await StorageService.instance.init();

  // 2. Boot the background audio service
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

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
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
        2 => ThemeMode.dark, // AMOLED uses dark mode with black scaffold
        _ => ThemeMode.system,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final accent = Color(settings.accentColorValue);

    final darkTheme =
        settings.themeMode == 2 ? AppTheme.amoled(accent) : AppTheme.dark(accent);

    // Decide first screen: onboarding if permission not yet granted,
    // otherwise straight into the home shell.
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
