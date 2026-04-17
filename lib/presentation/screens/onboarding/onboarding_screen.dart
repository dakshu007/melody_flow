import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/app_providers.dart';
import '../home/home_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _loading = false;
  bool _denied = false;
  bool _permanentlyDenied = false;

  Future<void> _requestPermission() async {
    setState(() {
      _loading = true;
      _denied = false;
      _permanentlyDenied = false;
    });

    final audio = await Permission.audio.request();
    if (audio.isGranted) {
      await ref.read(songsProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
      return;
    }

    // Fallback to storage for older Android
    final storage = await Permission.storage.request();
    if (storage.isGranted) {
      await ref.read(songsProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
      return;
    }

    setState(() {
      _loading = false;
      _denied = true;
      _permanentlyDenied =
          audio.isPermanentlyDenied || storage.isPermanentlyDenied;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.graphic_eq_rounded,
                    size: 64, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text('Melody Flow',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900, letterSpacing: -1)),
              const SizedBox(height: 12),
              Text(
                'A clean, minimal, ad-free music player\nbuilt for people who love music.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
              const Spacer(),
              const _Feature(icon: Icons.block_rounded, text: 'Zero ads, ever'),
              const _Feature(
                  icon: Icons.cloud_off_rounded, text: 'Works 100% offline'),
              const _Feature(
                  icon: Icons.graphic_eq_rounded,
                  text: '10 equalizer presets + loudness'),
              const _Feature(
                  icon: Icons.palette_outlined,
                  text: 'Dynamic colors from album art'),
              const Spacer(),

              if (_denied) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.redAccent),
                      const SizedBox(height: 8),
                      Text(
                        _permanentlyDenied
                            ? 'Permission is permanently denied. Open Settings to enable it manually.'
                            : 'We need permission to read music files. Please try again.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          if (_permanentlyDenied) {
                            await openAppSettings();
                          } else {
                            await _requestPermission();
                          }
                        },
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _permanentlyDenied
                              ? 'Open Settings'
                              : (_denied ? 'Try again' : "Let's go"),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
