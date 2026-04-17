import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/song.dart';
import '../providers/app_providers.dart';
import 'artwork_image.dart';
import 'playlist_picker_sheet.dart';
import 'song_info_sheet.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool isPlaying;
  final bool selected;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.isPlaying = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final storage = ref.watch(storageServiceProvider);
    final isFav = storage.isFavorite(song.id);

    return Material(
      color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ArtworkImage(
                id: song.id,
                type: ArtworkType.AUDIO,
                size: 48,
                borderRadius: 8,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPlaying
                            ? accent
                            : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist}  •  ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              if (isFav)
                Icon(Icons.favorite_rounded,
                    size: 16, color: Colors.redAccent),
              trailing ??
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () => _showMenu(context, ref, song),
                    splashRadius: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final storage = ref.read(storageServiceProvider);
        final isFav = storage.isFavorite(song.id);
        final handler = ref.read(audioHandlerProvider);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              // Song header in the sheet
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkBorder: BorderRadius.circular(4),
                    artworkWidth: 40,
                    artworkHeight: 40,
                    nullArtworkWidget: Container(
                      width: 40,
                      height: 40,
                      color: Theme.of(context).dividerColor,
                      child: const Icon(Icons.music_note_rounded, size: 20),
                    ),
                  ),
                ),
                title: Text(song.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(song.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Play now'),
                onTap: () {
                  Navigator.pop(context);
                  handler.loadQueue([song]);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_play_next_rounded),
                title: const Text('Play next'),
                onTap: () {
                  Navigator.pop(context);
                  handler.playNext(song);
                  _toast(context, 'Added to play next');
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Add to queue'),
                onTap: () {
                  Navigator.pop(context);
                  handler.addToQueue(song);
                  _toast(context, 'Added to queue');
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to playlist'),
                onTap: () {
                  Navigator.pop(context);
                  PlaylistPickerSheet.show(context, song.id);
                },
              ),
              ListTile(
                leading: Icon(isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                    color: isFav ? Colors.redAccent : null),
                title: Text(isFav ? 'Remove from favorites' : 'Add to favorites'),
                onTap: () async {
                  await storage.toggleFavorite(song.id);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Song info'),
                onTap: () {
                  Navigator.pop(context);
                  SongInfoSheet.show(context, song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share song'),
                onTap: () async {
                  Navigator.pop(context);
                  if (song.data != null) {
                    try {
                      await Share.shareXFiles([XFile(song.data!)],
                          text: '${song.title} — ${song.artist}');
                    } catch (e) {
                      _toast(context, 'Could not share: $e');
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}
