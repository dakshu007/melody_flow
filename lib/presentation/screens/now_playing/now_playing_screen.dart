import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../providers/app_providers.dart';
import '../equalizer/equalizer_screen.dart';
import 'lyrics_panel.dart';
import 'queue_sheet.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  Color? _bgColor;
  int? _lastArtSongId;
  bool _showLyrics = false;

  Future<void> _extractColor(int songId) async {
    if (_lastArtSongId == songId) return;
    _lastArtSongId = songId;
    try {
      final art = await OnAudioQuery()
          .queryArtwork(songId, ArtworkType.AUDIO, size: 200);
      if (art == null || !mounted) return;
      final palette = await PaletteGenerator.fromImageProvider(MemoryImage(art));
      if (!mounted) return;
      setState(() {
        _bgColor = palette.darkMutedColor?.color ??
            palette.dominantColor?.color ??
            Theme.of(context).scaffoldBackgroundColor;
      });
    } catch (_) {/* ignore */}
  }

  @override
  Widget build(BuildContext context) {
    final mediaItem = ref.watch(mediaItemStreamProvider).valueOrNull;
    final playback = ref.watch(playbackStateStreamProvider).valueOrNull;
    final position = ref.watch(positionStreamProvider).valueOrNull ?? Duration.zero;
    final handler = ref.read(audioHandlerProvider);

    if (mediaItem == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing')));
    }

    final songId = mediaItem.extras?['songId'] as int?;
    if (songId != null) _extractColor(songId);

    final duration = mediaItem.duration ?? Duration.zero;
    final isFav = songId != null &&
        ref.watch(storageServiceProvider).isFavorite(songId);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _bgColor ?? Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Now Playing',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showMoreSheet(context, mediaItem),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (_bgColor ?? Colors.black).withValues(alpha: 0.9),
              (_bgColor ?? Colors.black).withValues(alpha: 0.3),
              Colors.black,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Artwork or Lyrics
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showLyrics
                        ? LyricsPanel(
                            key: const ValueKey('lyrics'),
                            mediaItem: mediaItem,
                            position: position,
                          )
                        : _Artwork(
                            key: ValueKey('art_$songId'),
                            songId: songId,
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                // Title + artist + fav
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mediaItem.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mediaItem.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav ? Colors.redAccent : Colors.white,
                        size: 28,
                      ),
                      onPressed: () async {
                        if (songId == null) return;
                        await ref
                            .read(storageServiceProvider)
                            .toggleFavorite(songId);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Seek bar
                _SeekBar(
                  position: position,
                  duration: duration,
                  onSeek: handler.seek,
                ),
                const SizedBox(height: 16),
                // Main controls
                _MainControls(
                  isPlaying: playback?.playing ?? false,
                  onPlayPause: () => (playback?.playing ?? false)
                      ? handler.pause()
                      : handler.play(),
                  onNext: handler.skipToNext,
                  onPrev: handler.skipToPrevious,
                  shuffleMode: playback?.shuffleMode ??
                      AudioServiceShuffleMode.none,
                  repeatMode:
                      playback?.repeatMode ?? AudioServiceRepeatMode.none,
                  onShuffle: () {
                    final next = playback?.shuffleMode ==
                            AudioServiceShuffleMode.all
                        ? AudioServiceShuffleMode.none
                        : AudioServiceShuffleMode.all;
                    handler.setShuffleMode(next);
                  },
                  onRepeat: () {
                    final cur = playback?.repeatMode ??
                        AudioServiceRepeatMode.none;
                    final next = switch (cur) {
                      AudioServiceRepeatMode.none =>
                        AudioServiceRepeatMode.all,
                      AudioServiceRepeatMode.all =>
                        AudioServiceRepeatMode.one,
                      _ => AudioServiceRepeatMode.none,
                    };
                    handler.setRepeatMode(next);
                  },
                ),
                const SizedBox(height: 20),
                // Bottom action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _IconAction(
                      icon: Icons.lyrics_outlined,
                      active: _showLyrics,
                      onTap: () => setState(() => _showLyrics = !_showLyrics),
                    ),
                    _IconAction(
                      icon: Icons.equalizer_rounded,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const EqualizerScreen())),
                    ),
                    _IconAction(
                      icon: Icons.timer_outlined,
                      onTap: () => _showSleepTimerSheet(context, ref),
                    ),
                    _IconAction(
                      icon: Icons.queue_music_rounded,
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const QueueSheet(),
                      ),
                    ),
                    _IconAction(
                      icon: Icons.cast_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Chromecast picker coming soon')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context, MediaItem item) {
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
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.album_outlined),
              title: const Text('Go to album'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Go to artist'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit tags'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: const Text('Playback speed'),
              onTap: () {
                Navigator.pop(context);
                _showSpeedSheet(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Artwork extends StatelessWidget {
  final int? songId;
  const _Artwork({super.key, this.songId});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              spreadRadius: 4,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: songId == null
              ? _fallback(context)
              : QueryArtworkWidget(
                  id: songId!,
                  type: ArtworkType.AUDIO,
                  artworkBorder: BorderRadius.circular(20),
                  artworkQuality: FilterQuality.high,
                  quality: 100,
                  size: 1000,
                  artworkFit: BoxFit.cover,
                  nullArtworkWidget: _fallback(context),
                ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) => Container(
        color: Colors.white.withValues(alpha: 0.05),
        child: const Icon(Icons.music_note_rounded,
            size: 96, color: Colors.white54),
      );
}

// ---------------------------------------------------------------------------

class _SeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (d.inHours > 0) return '${d.inHours}:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    final cur = _dragValue ??
        widget.position.inMilliseconds.clamp(0, max.toInt()).toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.1),
          ),
          child: Slider(
            min: 0,
            max: max <= 0 ? 1 : max,
            value: cur.clamp(0, max <= 0 ? 1 : max),
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              widget.onSeek(Duration(milliseconds: v.toInt()));
              setState(() => _dragValue = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(Duration(milliseconds: cur.toInt())),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              Text(_format(widget.duration),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _MainControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final AudioServiceShuffleMode shuffleMode;
  final AudioServiceRepeatMode repeatMode;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  const _MainControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.shuffleMode,
    required this.repeatMode,
    required this.onShuffle,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    IconData repeatIcon() => switch (repeatMode) {
          AudioServiceRepeatMode.one => Icons.repeat_one_rounded,
          _ => Icons.repeat_rounded,
        };

    final repeatActive = repeatMode != AudioServiceRepeatMode.none;
    final shuffleActive = shuffleMode == AudioServiceShuffleMode.all;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          iconSize: 26,
          icon: Icon(Icons.shuffle_rounded,
              color: shuffleActive ? accent : Colors.white),
          onPressed: onShuffle,
        ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          onPressed: onPrev,
        ),
        GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 40,
            ),
          ),
        ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: onNext,
        ),
        IconButton(
          iconSize: 26,
          icon: Icon(repeatIcon(),
              color: repeatActive ? accent : Colors.white),
          onPressed: onRepeat,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _IconAction(
      {required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return IconButton(
      icon: Icon(icon,
          color: active ? accent : Colors.white.withValues(alpha: 0.85)),
      onPressed: onTap,
      iconSize: 24,
      splashRadius: 22,
    );
  }
}

// ---------------------------------------------------------------------------
// Sleep timer sheet
// ---------------------------------------------------------------------------

void _showSleepTimerSheet(BuildContext context, WidgetRef ref) {
  const presets = [5, 10, 15, 30, 45, 60, 90];
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return Consumer(
        builder: (context, ref, __) {
          final remaining = ref.watch(sleepTimerProvider).valueOrNull;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sleep timer',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (remaining != null)
                    Text(
                        'Stops in ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: presets
                        .map((m) => ActionChip(
                              label: Text('$m min'),
                              onPressed: () {
                                ref
                                    .read(audioHandlerProvider)
                                    .startSleepTimer(Duration(minutes: m));
                                Navigator.pop(context);
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  if (remaining != null)
                    TextButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel timer'),
                      onPressed: () {
                        ref.read(audioHandlerProvider).cancelSleepTimer();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Playback speed sheet
// ---------------------------------------------------------------------------

void _showSpeedSheet(BuildContext context, WidgetRef ref) {
  const presets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Playback speed',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presets
                  .map((s) => ActionChip(
                        label: Text('${s}x'),
                        onPressed: () {
                          ref.read(audioHandlerProvider).setSpeed(s);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}
