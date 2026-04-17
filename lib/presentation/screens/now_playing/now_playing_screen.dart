import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../core/utils/haptics.dart';
import '../../providers/app_providers.dart';
import '../../widgets/playlist_picker_sheet.dart';
import '../equalizer/equalizer_screen.dart';
import 'lyrics_panel.dart';
import 'queue_sheet.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});
  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  Color _bgColor = const Color(0xFF1E1E1E);
  int? _lastArtSongId;
  bool _showLyrics = false;

  // Drag-to-dismiss state
  double _dragY = 0;
  static const _dismissThreshold = 120.0;

  Future<void> _extractColor(int songId) async {
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
  }

  @override
  Widget build(BuildContext context) {
    final mediaItem = ref.watch(mediaItemStreamProvider).valueOrNull;
    final playback = ref.watch(playbackStateStreamProvider).valueOrNull;
    final position =
        ref.watch(positionStreamProvider).valueOrNull ?? Duration.zero;
    final handler = ref.read(audioHandlerProvider);

    if (mediaItem == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing')));
    }

    final songId = mediaItem.extras?['songId'] as int?;
    if (songId != null) _extractColor(songId);

    final duration = mediaItem.duration ?? Duration.zero;
    final isFav =
        songId != null && ref.watch(storageServiceProvider).isFavorite(songId);

    // Opacity that fades out as user drags down
    final dragOpacity = (1 - (_dragY / 400)).clamp(0.0, 1.0);

    return GestureDetector(
      // Vertical drag to dismiss
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 0 || _dragY > 0) {
          setState(() => _dragY = (_dragY + d.delta.dy).clamp(0, 400));
        }
      },
      onVerticalDragEnd: (d) {
        if (_dragY > _dismissThreshold ||
            (d.primaryVelocity != null && d.primaryVelocity! > 800)) {
          Haptics.light();
          Navigator.pop(context);
        } else {
          setState(() => _dragY = 0);
        }
      },
      onVerticalDragCancel: () => setState(() => _dragY = 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        color: _bgColor,
        child: Transform.translate(
          offset: Offset(0, _dragY),
          child: Opacity(
            opacity: dragOpacity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred artwork background (A5)
                if (songId != null) _BlurredBackdrop(songId: songId),

                // Gradient overlay for readability
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _bgColor.withValues(alpha: 0.75),
                        _bgColor.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                Scaffold(
                  extendBodyBehindAppBar: true,
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 32, color: Colors.white),
                      onPressed: () {
                        Haptics.light();
                        Navigator.pop(context);
                      },
                    ),
                    title: const Text('Now Playing',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white),
                        onPressed: () =>
                            _showMoreSheet(context, ref, mediaItem),
                      ),
                    ],
                  ),
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Column(
                        children: [
                          // Drag indicator at top
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(top: 4, bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _showLyrics
                                  ? LyricsPanel(
                                      key: const ValueKey('lyrics'),
                                      mediaItem: mediaItem,
                                      position: position,
                                    )
                                  : GestureDetector(
                                      // A14: tap artwork to toggle lyrics
                                      onTap: () {
                                        Haptics.light();
                                        setState(() =>
                                            _showLyrics = !_showLyrics);
                                      },
                                      child: _Artwork(
                                        key: ValueKey('art_$songId'),
                                        songId: songId,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 28,
                                      child: _scrollingTitle(mediaItem.title),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      mediaItem.artist ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
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
                                  color:
                                      isFav ? Colors.redAccent : Colors.white,
                                  size: 28,
                                ),
                                onPressed: () async {
                                  if (songId == null) return;
                                  Haptics.medium();
                                  await ref
                                      .read(storageServiceProvider)
                                      .toggleFavorite(songId);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SeekBar(
                            position: position,
                            duration: duration,
                            onSeek: handler.seek,
                          ),
                          const SizedBox(height: 16),
                          _MainControls(
                            isPlaying: playback?.playing ?? false,
                            onPlayPause: () {
                              Haptics.medium();
                              (playback?.playing ?? false)
                                  ? handler.pause()
                                  : handler.play();
                            },
                            onNext: () {
                              Haptics.selection();
                              handler.skipToNext();
                            },
                            onPrev: () {
                              Haptics.selection();
                              handler.skipToPrevious();
                            },
                            shuffleMode: playback?.shuffleMode ??
                                AudioServiceShuffleMode.none,
                            repeatMode: playback?.repeatMode ??
                                AudioServiceRepeatMode.none,
                            onShuffle: () {
                              Haptics.light();
                              final next = playback?.shuffleMode ==
                                      AudioServiceShuffleMode.all
                                  ? AudioServiceShuffleMode.none
                                  : AudioServiceShuffleMode.all;
                              handler.setShuffleMode(next);
                            },
                            onRepeat: () {
                              Haptics.light();
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _IconAction(
                                icon: Icons.lyrics_outlined,
                                active: _showLyrics,
                                onTap: () {
                                  Haptics.light();
                                  setState(
                                      () => _showLyrics = !_showLyrics);
                                },
                              ),
                              _IconAction(
                                icon: Icons.equalizer_rounded,
                                onTap: () {
                                  Haptics.light();
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>
                                          const EqualizerScreen()));
                                },
                              ),
                              _IconAction(
                                icon: Icons.timer_outlined,
                                onTap: () {
                                  Haptics.light();
                                  _showSleepTimerSheet(context, ref);
                                },
                              ),
                              _IconAction(
                                icon: Icons.queue_music_rounded,
                                onTap: () {
                                  Haptics.light();
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => const QueueSheet(),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scrollingTitle(String text) {
    const style = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: -0.3,
    );
    if (text.length <= 26) {
      return Text(text,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return Marquee(
      text: text,
      style: style,
      velocity: 30,
      blankSpace: 50,
      pauseAfterRound: const Duration(seconds: 2),
    );
  }

  void _showMoreSheet(BuildContext context, WidgetRef ref, MediaItem item) {
    final songId = item.extras?['songId'] as int?;
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
            if (songId != null)
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to playlist'),
                onTap: () {
                  Navigator.pop(context);
                  PlaylistPickerSheet.show(context, songId);
                },
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
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Pitch'),
              onTap: () {
                Navigator.pop(context);
                _showPitchSheet(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Blurred backdrop (A5) ----------
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
}

// ---------- Artwork ----------
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
              ? _fallback()
              : QueryArtworkWidget(
                  id: songId!,
                  type: ArtworkType.AUDIO,
                  artworkBorder: BorderRadius.circular(20),
                  artworkQuality: FilterQuality.high,
                  quality: 100,
                  size: 1000,
                  artworkFit: BoxFit.cover,
                  keepOldArtwork: true,
                  nullArtworkWidget: _fallback(),
                ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: Colors.white.withValues(alpha: 0.05),
        child: const Icon(Icons.music_note_rounded,
            size: 96, color: Colors.white54),
      );
}

// ---------- SeekBar ----------
class _SeekBar extends StatefulWidget {
  final Duration position, duration;
  final ValueChanged<Duration> onSeek;
  const _SeekBar(
      {required this.position, required this.duration, required this.onSeek});
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;
  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    final cur = _dragValue ??
        widget.position.inMilliseconds.clamp(0, max.toInt()).toDouble();
    return Column(children: [
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
              Text(_fmt(Duration(milliseconds: cur.toInt())),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12)),
              Text(_fmt(widget.duration),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12)),
            ]),
      ),
    ]);
  }
}

// ---------- Controls ----------
class _MainControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause, onNext, onPrev, onShuffle, onRepeat;
  final AudioServiceShuffleMode shuffleMode;
  final AudioServiceRepeatMode repeatMode;
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
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
          iconSize: 26,
          icon: Icon(Icons.shuffle_rounded,
              color: shuffleActive ? accent : Colors.white),
          onPressed: onShuffle),
      IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          onPressed: onPrev),
      GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 72,
            height: 72,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 40),
          )),
      IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: onNext),
      IconButton(
          iconSize: 26,
          icon: Icon(repeatIcon(),
              color: repeatActive ? accent : Colors.white),
          onPressed: onRepeat),
    ]);
  }
}

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
        splashRadius: 22);
  }
}

void _showSleepTimerSheet(BuildContext context, WidgetRef ref) {
  const presets = [5, 10, 15, 30, 45, 60, 90];
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Consumer(builder: (context, ref, __) {
      final remaining = ref.watch(sleepTimerProvider).valueOrNull;
      return SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sleep timer',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (remaining != null)
                Text(
                    'Stops in ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'),
              const SizedBox(height: 16),
              Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: presets
                      .map((m) => ActionChip(
                            label: Text('$m min'),
                            onPressed: () {
                              Haptics.light();
                              ref
                                  .read(audioHandlerProvider)
                                  .startSleepTimer(Duration(minutes: m));
                              Navigator.pop(context);
                            },
                          ))
                      .toList()),
              const SizedBox(height: 16),
              if (remaining != null)
                TextButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel timer'),
                    onPressed: () {
                      ref.read(audioHandlerProvider).cancelSleepTimer();
                      Navigator.pop(context);
                    }),
            ]),
      ));
    }),
  );
}

void _showSpeedSheet(BuildContext context, WidgetRef ref) {
  const presets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(
        child: Padding(
      padding: const EdgeInsets.all(20),
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
                            Haptics.light();
                            ref.read(audioHandlerProvider).setSpeed(s);
                            Navigator.pop(context);
                          },
                        ))
                    .toList()),
          ]),
    )),
  );
}

void _showPitchSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) {
      double pitch = 1.0;
      return StatefulBuilder(builder: (context, setS) {
        return SafeArea(
            child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pitch: ${pitch.toStringAsFixed(2)}x',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Slider(
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    value: pitch,
                    onChanged: (v) {
                      setS(() => pitch = v);
                      ref.read(audioHandlerProvider).setPitch(v);
                    }),
                TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    onPressed: () {
                      setS(() => pitch = 1.0);
                      ref.read(audioHandlerProvider).setPitch(1.0);
                    }),
              ]),
        ));
      });
    },
  );
}
