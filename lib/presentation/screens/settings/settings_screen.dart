import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/services/lyrics_service.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
            body: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          const _Section('Appearance'),
          _themeTile(context, settings, notifier),
          _accentTile(context, ref, settings, notifier),
          SwitchListTile(
            title: const Text('Material You colors'),
            subtitle: const Text('Android 12+ system-wide theming'),
            value: settings.useMaterialYou,
            onChanged: (v) {
              Haptics.light();
              notifier.update((c) => c..useMaterialYou = v);
            },
          ),
          SwitchListTile(
            title: const Text('Color from artwork'),
            subtitle: const Text(
                'Now Playing background adapts to current album art'),
            value: settings.dynamicColorFromArtwork,
            onChanged: (v) {
              Haptics.light();
              notifier.update((c) => c..dynamicColorFromArtwork = v);
            },
          ),

          const _Section('Audio'),
          SwitchListTile(
            title: const Text('Fade in / fade out'),
            subtitle: Text(settings.fadeInOut
                ? 'Smooth fade when pausing/resuming (enabled)'
                : 'Smooth fade when pausing/resuming (disabled)'),
            value: settings.fadeInOut,
            onChanged: (v) {
              Haptics.light();
              notifier.update((c) => c..fadeInOut = v);
            },
          ),

          const _Section('Library'),
          ListTile(
            title: const Text('Minimum track length'),
            subtitle: Text(
                '${settings.minTrackLengthSec} seconds — hides ringtones and short clips'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                _showMinLengthDialog(context, settings, notifier, ref),
          ),
          ListTile(
            title: const Text('Excluded folders'),
            subtitle: Text(settings.excludedFolders.isEmpty
                ? '0 excluded'
                : '${settings.excludedFolders.length} excluded'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                _showExcludedFoldersSheet(context, settings, notifier, ref),
          ),
          ListTile(
            title: const Text('Artist separator'),
            subtitle: Text(
                '"${settings.artistSeparator}" — how to split multi-artist tags'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                _showSeparatorDialog(context, settings, notifier, ref),
          ),

          const _Section('Lyrics'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear lyrics cache'),
            subtitle: const Text('Deletes previously downloaded lyrics'),
            onTap: () async {
              Haptics.medium();
              await LyricsService.instance.clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Lyrics cache cleared'),
                    behavior: SnackBarBehavior.floating));
              }
            },
          ),

          const _Section('About'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) {
              final v = snap.data?.version ?? '1.0.0';
              final b = snap.data?.buildNumber ?? '1';
              return ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Melody Flow'),
                subtitle: Text('Version $v (build $b) — ad-free forever'),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('Open source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Melody Flow',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('Contact support'),
            onTap: () async {
              final uri = Uri.parse('mailto:support@melodyflow.app');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
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
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  4,
                  (i) => RadioListTile<int>(
                    title: Text(labels[i]),
                    subtitle: Text(_themeDescription(i)),
                    value: i,
                    groupValue: s.themeMode,
                    onChanged: (v) {
                      Haptics.light();
                      n.update((c) => c..themeMode = v!);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _themeDescription(int i) => switch (i) {
        0 => 'Bright and clean',
        1 => 'Easy on the eyes',
        2 => 'Pure black for OLED screens — saves battery',
        _ => 'Follow your phone\'s theme',
      };

  // Working accent color picker — taps apply immediately with haptic feedback
  Widget _accentTile(
      BuildContext context, WidgetRef ref, AppSettings s, SettingsNotifier n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: Text('Accent color',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: AppColors.accentPresets.map((c) {
              final selected = s.accentColorValue == c.toARGB32();
              return GestureDetector(
                onTap: () {
                  Haptics.light();
                  n.update((cs) => cs..accentColorValue = c.toARGB32());
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: selected ? 36 : 30,
                  height: selected ? 36 : 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: c.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showMinLengthDialog(BuildContext context, AppSettings s,
      SettingsNotifier n, WidgetRef ref) {
    int v = s.minTrackLengthSec;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Minimum track length'),
        content: StatefulBuilder(
          builder: (_, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$v seconds',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Slider(
                min: 0,
                max: 120,
                divisions: 24,
                value: v.toDouble(),
                onChanged: (x) => setS(() => v = x.toInt()),
              ),
              Text(v == 0
                  ? 'Show all audio files'
                  : 'Songs shorter than $v seconds are hidden'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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

  void _showSeparatorDialog(BuildContext context, AppSettings s,
      SettingsNotifier n, WidgetRef ref) {
    final ctl = TextEditingController(text: s.artistSeparator);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Artist separator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'When a song has multiple artists in one tag, this character is used to split them.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              maxLength: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. ; or ,',
                border: OutlineInputBorder(),
              ),
            ),
            const Text('Common separators: ;  ,  /  &',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final sep = ctl.text.trim();
              if (sep.isNotEmpty) {
                n.update((c) => c..artistSeparator = sep);
                ref.read(songsProvider.notifier).refresh();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showExcludedFoldersSheet(BuildContext context, AppSettings s,
      SettingsNotifier n, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExcludedFoldersSheet(
        settings: s,
        notifier: n,
        refreshLibrary: () => ref.read(songsProvider.notifier).refresh(),
      ),
    );
  }
}

class _ExcludedFoldersSheet extends StatefulWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  final VoidCallback refreshLibrary;

  const _ExcludedFoldersSheet({
    required this.settings,
    required this.notifier,
    required this.refreshLibrary,
  });

  @override
  State<_ExcludedFoldersSheet> createState() => _ExcludedFoldersSheetState();
}

class _ExcludedFoldersSheetState extends State<_ExcludedFoldersSheet> {
  late List<String> _folders;

  @override
  void initState() {
    super.initState();
    _folders = List.of(widget.settings.excludedFolders);
  }

  Future<void> _addFolder() async {
    final picked = await FilePicker.platform.getDirectoryPath();
    if (picked != null && !_folders.contains(picked)) {
      setState(() => _folders.add(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('Excluded folders',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                  onPressed: _addFolder,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _folders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_off_outlined,
                              size: 48,
                              color: Theme.of(context).dividerColor),
                          const SizedBox(height: 12),
                          const Text(
                              'No folders excluded.\nTap "Add" to hide a folder from your library.',
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: ctl,
                    itemCount: _folders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => ListTile(
                      leading: const Icon(Icons.folder_rounded),
                      title: Text(_folders[i].split('/').last),
                      subtitle: Text(_folders[i],
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          setState(() => _folders.removeAt(i));
                        },
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.notifier
                      .update((c) => c..excludedFolders = _folders);
                  widget.refreshLibrary();
                  Navigator.pop(context);
                },
                child: const Text('Save changes'),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
