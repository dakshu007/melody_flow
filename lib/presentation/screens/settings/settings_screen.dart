import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_settings.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          const _Section('Appearance'),
          _themeTile(context, settings, notifier),
          _accentTile(context, settings, notifier),
          SwitchListTile(
            title: const Text('Material You colors'),
            subtitle: const Text('Android 12+ system-wide theming'),
            value: settings.useMaterialYou,
            onChanged: (v) => notifier.update(
              (c) => c..useMaterialYou = v,
            ),
          ),
          SwitchListTile(
            title: const Text('Color from artwork'),
            subtitle: const Text(
                'Now Playing background adapts to current album art'),
            value: settings.dynamicColorFromArtwork,
            onChanged: (v) => notifier.update(
              (c) => c..dynamicColorFromArtwork = v,
            ),
          ),

          const _Section('Audio'),
          SwitchListTile(
            title: const Text('Gapless playback'),
            value: settings.gaplessPlayback,
            onChanged: (v) => notifier.update((c) => c..gaplessPlayback = v),
          ),
          SwitchListTile(
            title: const Text('Fade in / fade out'),
            subtitle: const Text('Smooth transitions when pausing/resuming'),
            value: settings.fadeInOut,
            onChanged: (v) => notifier.update((c) => c..fadeInOut = v),
          ),
          SwitchListTile(
            title: const Text('Replay gain'),
            subtitle: const Text('Normalize volume across tracks'),
            value: settings.replayGainEnabled,
            onChanged: (v) =>
                notifier.update((c) => c..replayGainEnabled = v),
          ),
          ListTile(
            title: const Text('Crossfade'),
            subtitle: Text(settings.crossfadeMs == 0
                ? 'Disabled'
                : '${(settings.crossfadeMs / 1000).toStringAsFixed(1)} seconds'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showCrossfadeDialog(context, settings, notifier),
          ),

          const _Section('Library'),
          ListTile(
            title: const Text('Minimum track length'),
            subtitle: Text('${settings.minTrackLengthSec} seconds — '
                'hides ringtones and short clips'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showMinLengthDialog(context, settings, notifier, ref),
          ),
          ListTile(
            title: const Text('Excluded folders'),
            subtitle: Text('${settings.excludedFolders.length} excluded'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Artist separator'),
            subtitle: Text(
                '"${settings.artistSeparator}" — how to split multi-artist tags'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),

          const _Section('Now Playing'),
          ListTile(
            title: const Text('Player theme'),
            subtitle: Text(_nowPlayingThemeName(settings.nowPlayingTheme)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showNowPlayingThemeSheet(context, settings, notifier),
          ),
          SwitchListTile(
            title: const Text('Show lyrics button'),
            value: settings.showLyricsButton,
            onChanged: (v) =>
                notifier.update((c) => c..showLyricsButton = v),
          ),

          const _Section('About'),
          const ListTile(
            title: Text('Melody Flow'),
            subtitle: Text('Version 1.0.0 — ad-free forever'),
            leading: Icon(Icons.info_outline_rounded),
          ),
          ListTile(
            title: const Text('Rate on Play Store'),
            leading: const Icon(Icons.star_outline_rounded),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Privacy policy'),
            leading: const Icon(Icons.privacy_tip_outlined),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Open source licenses'),
            leading: const Icon(Icons.code_rounded),
            onTap: () => showLicensePage(context: context),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------

  Widget _themeTile(
      BuildContext context, AppSettings s, SettingsNotifier n) {
    final labels = ['Light', 'Dark', 'AMOLED', 'System'];
    return ListTile(
      title: const Text('Theme'),
      subtitle: Text(labels[s.themeMode]),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                4,
                (i) => RadioListTile<int>(
                  title: Text(labels[i]),
                  value: i,
                  groupValue: s.themeMode,
                  onChanged: (v) {
                    n.update((c) => c..themeMode = v!);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _accentTile(
      BuildContext context, AppSettings s, SettingsNotifier n) {
    return ListTile(
      title: const Text('Accent color'),
      trailing: Wrap(
        spacing: 8,
        children: AppColors.accentPresets
            .map((c) => GestureDetector(
                  onTap: () => n.update((cs) => cs..accentColorValue = c.toARGB32()),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: s.accentColorValue == c.toARGB32()
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showCrossfadeDialog(
      BuildContext context, AppSettings s, SettingsNotifier n) {
    double v = (s.crossfadeMs / 1000).toDouble();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crossfade duration'),
        content: StatefulBuilder(
          builder: (_, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(v == 0 ? 'Disabled' : '${v.toStringAsFixed(1)} sec'),
              Slider(
                min: 0,
                max: 12,
                divisions: 24,
                value: v,
                onChanged: (x) => setS(() => v = x),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              n.update((c) => c..crossfadeMs = (v * 1000).toInt());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMinLengthDialog(
      BuildContext context, AppSettings s, SettingsNotifier n, WidgetRef ref) {
    int v = s.minTrackLengthSec;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Minimum track length'),
        content: StatefulBuilder(
          builder: (_, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$v seconds'),
              Slider(
                min: 0,
                max: 120,
                divisions: 24,
                value: v.toDouble(),
                onChanged: (x) => setS(() => v = x.toInt()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              n.update((c) => c..minTrackLengthSec = v);
              ref.read(songsProvider.notifier).refresh();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNowPlayingThemeSheet(
      BuildContext context, AppSettings s, SettingsNotifier n) {
    const themes = ['Classic', 'Glow', 'Material You', 'Minimal', 'Immersive'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            themes.length,
            (i) => RadioListTile<int>(
              title: Text(themes[i]),
              value: i,
              groupValue: s.nowPlayingTheme,
              onChanged: (v) {
                n.update((c) => c..nowPlayingTheme = v!);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  String _nowPlayingThemeName(int i) =>
      ['Classic', 'Glow', 'Material You', 'Minimal', 'Immersive'][i];
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
