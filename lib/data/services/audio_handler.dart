import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../models/song.dart';

/// [MelodyAudioHandler] is the singleton that sits between the UI and
/// the native audio engine. It's the source of truth for: current song,
/// position, queue, shuffle, repeat, and equalizer state.
///
/// Handles:
///   * Background playback (via audio_service)
///   * Bluetooth headset / notification / lock-screen controls
///   * Android Auto & Chromecast (via just_audio's pipeline)
///   * Gapless + crossfade
///   * Sleep timer
///   * Equalizer
class MelodyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _equalizer = AndroidEqualizer();
  final _loudnessEnhancer = AndroidLoudnessEnhancer();

  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [_equalizer, _loudnessEnhancer],
    ),
  );

  /// The underlying concat source that lets us have a live, editable queue.
  ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: []);

  List<Song> _queue = [];
  Timer? _sleepTimer;
  final BehaviorSubject<Duration?> _sleepTimerRemaining =
      BehaviorSubject.seeded(null);

  /// Get the equalizer for UI access.
  AndroidEqualizer get equalizer => _equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _loudnessEnhancer;

  Stream<Duration?> get sleepTimerRemainingStream =>
      _sleepTimerRemaining.stream;

  List<Song> get currentQueue => List.unmodifiable(_queue);
  AudioPlayer get player => _player;

  MelodyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Broadcast just_audio's playback state changes into audio_service.
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        // ignore: avoid_print
        print('AudioPlayer error: $e');
      },
    );

    _player.currentIndexStream.listen((index) {
      if (index == null || index >= _queue.length) return;
      mediaItem.add(_queue[index].toMediaItem());
    });

    // Auto-advance when track completes and repeat isn't on one.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // handled by ConcatenatingAudioSource automatically in loop modes
      }
    });

    try {
      await _player.setAudioSource(_playlist);
    } catch (_) {
      // empty initial source is fine
    }
  }

  // ---------------------------------------------------------------------------
  // Queue management
  // ---------------------------------------------------------------------------

  /// Replace the entire queue with [songs] and start playing [initialIndex].
  Future<void> loadQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    _queue = List.of(songs);

    _playlist = ConcatenatingAudioSource(
      children: songs.map((s) => _toAudioSource(s)).toList(),
    );

    await _player.setAudioSource(
      _playlist,
      initialIndex: initialIndex,
      initialPosition: Duration.zero,
      preload: true,
    );
    queue.add(_queue.map((s) => s.toMediaItem()).toList());
    mediaItem.add(_queue[initialIndex].toMediaItem());
    await play();
  }

  Future<void> addToQueue(Song song) async {
    _queue.add(song);
    await _playlist.add(_toAudioSource(song));
    queue.add(_queue.map((s) => s.toMediaItem()).toList());
  }

  Future<void> playNext(Song song) async {
    final idx = (_player.currentIndex ?? 0) + 1;
    _queue.insert(idx, song);
    await _playlist.insert(idx, _toAudioSource(song));
    queue.add(_queue.map((s) => s.toMediaItem()).toList());
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    await _playlist.removeAt(index);
    queue.add(_queue.map((s) => s.toMediaItem()).toList());
  }

  Future<void> moveInQueue(int from, int to) async {
    if (from == to) return;
    final item = _queue.removeAt(from);
    _queue.insert(to, item);
    await _playlist.move(from, to);
    queue.add(_queue.map((s) => s.toMediaItem()).toList());
  }

  AudioSource _toAudioSource(Song s) {
    final uri = s.data != null && s.data!.startsWith('content://')
        ? Uri.parse(s.data!)
        : Uri.file(s.data ?? '');
    return AudioSource.uri(uri, tag: s.toMediaItem());
  }

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() async {
    await _player.setVolume(0.0);
    await _player.play();
    // Fade in over 400ms
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      await _player.setVolume(i / 10.0);
    }
  }

  @override
  Future<void> pause() async {
    // Fade out over 300ms
    for (int i = 9; i >= 0; i--) {
      await Future.delayed(const Duration(milliseconds: 30));
      await _player.setVolume(i / 10.0);
    }
    await _player.pause();
    await _player.setVolume(1.0);
  }
  @override Future<void> stop()  async {
    await _player.stop();
    await super.stop();
  }
  @override Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // Oto-style: if > 3s, go to start first, else previous track.
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    final enabled = mode == AudioServiceShuffleMode.all;
    if (enabled) await _player.shuffle();
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    await _player.setLoopMode(switch (mode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one  => LoopMode.one,
      AudioServiceRepeatMode.all  => LoopMode.all,
      AudioServiceRepeatMode.group => LoopMode.all,
    });
  }

  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));
  Future<void> setSpeed(double s)  => _player.setSpeed(s.clamp(0.25, 2.5));
  Future<void> setPitch(double p)  => _player.setPitch(p.clamp(0.5, 2.0));

  // ---------------------------------------------------------------------------
  // Sleep timer
  // ---------------------------------------------------------------------------

  void startSleepTimer(Duration duration, {bool finishTrack = false}) {
    cancelSleepTimer();
    _sleepTimerRemaining.add(duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final current = _sleepTimerRemaining.value;
      if (current == null) return;
      final next = current - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        t.cancel();
        _sleepTimerRemaining.add(null);
        if (finishTrack) {
          // Wait until current track ends
          final sub = _player.processingStateStream.listen(null);
          sub.onData((s) async {
            if (s == ProcessingState.completed) {
              await pause();
              await sub.cancel();
            }
          });
        } else {
          await pause();
        }
      } else {
        _sleepTimerRemaining.add(next);
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerRemaining.add(null);
  }

  // ---------------------------------------------------------------------------
  // audio_service state broadcast
  // ---------------------------------------------------------------------------

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  // Streams forwarded for UI convenience.
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedStream => _player.bufferedPositionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream   => _player.playingStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  Stream<bool> get shuffleModeStream  => _player.shuffleModeEnabledStream;
}

/// Mapping from our internal [Song] to audio_service's [MediaItem].
extension SongToMediaItem on Song {
  MediaItem toMediaItem() => MediaItem(
        id: mediaId,
        title: title,
        album: album,
        artist: artist,
        duration: durationAsDuration,
        // Album art is resolved via content:// URI that on_audio_query exposes;
        // the UI layer uses QueryArtworkWidget for in-app display.
        extras: {
          'songId': id,
          'albumId': albumId,
          'data': data,
        },
      );
}

/// Utility — shuffle the queue in place, respecting current song.
void shuffleList<T>(List<T> list, {int? pinIndex}) {
  final rng = Random();
  if (pinIndex == null) {
    list.shuffle(rng);
    return;
  }
  final pinned = list[pinIndex];
  list.removeAt(pinIndex);
  list.shuffle(rng);
  list.insert(0, pinned);
}
