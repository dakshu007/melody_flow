import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../models/song.dart';
import 'storage_service.dart';

/// [MelodyAudioHandler] is the singleton between UI and native audio engine.
class MelodyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _equalizer = AndroidEqualizer();
  final _loudnessEnhancer = AndroidLoudnessEnhancer();

  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [_equalizer, _loudnessEnhancer],
    ),
  );

  ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: []);

  List<Song> _queue = [];
  Timer? _sleepTimer;
  Timer? _queueSaveDebouncer;
  final BehaviorSubject<Duration?> _sleepTimerRemaining =
      BehaviorSubject.seeded(null);

  // Play-count tracking (FIX #17)
  int? _lastCountedIndex;

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

    // Handle audio interruptions (calls, alarms, other apps taking focus)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.duck) {
          _player.setVolume(0.3);
        } else {
          _player.pause();
        }
      } else {
        if (event.type == AudioInterruptionType.duck) {
          _player.setVolume(1.0);
        }
      }
    });

    // Noise (e.g. headphone unplug) -> pause
    session.becomingNoisyEventStream.listen((_) => _player.pause());

    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        // ignore: avoid_print
        print('AudioPlayer error: $e');
      },
    );

    // FIX #17: increment play count when a track starts playing.
    // We fire on index change, not on every position tick, and dedupe by
    // remembering the last-counted index.
    _player.currentIndexStream.listen((index) {
      if (index == null || index >= _queue.length) return;
      mediaItem.add(_queue[index].toMediaItem());
      if (_lastCountedIndex != index) {
        _lastCountedIndex = index;
        final song = _queue[index];
        // Fire and forget
        StorageService.instance.incrementPlay(song.id);
      }
      _scheduleQueueSave();
    });

    // FIX #9: persist shuffle/repeat changes
    _player.shuffleModeEnabledStream.listen((enabled) {
      StorageService.instance.saveShuffleMode(enabled);
    });
    _player.loopModeStream.listen((mode) {
      StorageService.instance.saveRepeatMode(mode.index);
    });

    try {
      await _player.setAudioSource(_playlist);
    } catch (_) {}
  }

  /// FIX #9 + #10: Call this once from main() after the handler is ready.
  /// Restores shuffle/repeat and optionally re-seeds the queue from disk.
  Future<void> restorePersistedState(List<Song> Function(List<int>) resolveSongs) async {
    // Shuffle / repeat
    final shuffle = StorageService.instance.loadShuffleMode();
    final repeatIdx = StorageService.instance.loadRepeatMode();
    if (shuffle) await _player.setShuffleModeEnabled(true);
    if (repeatIdx >= 0 && repeatIdx < LoopMode.values.length) {
      await _player.setLoopMode(LoopMode.values[repeatIdx]);
    }

    // Queue
    final ids = StorageService.instance.restoreQueueIds();
    if (ids != null && ids.isNotEmpty) {
      final songs = resolveSongs(ids);
      if (songs.isNotEmpty) {
        final savedIndex = StorageService.instance.restoreQueueIndex()
            .clamp(0, songs.length - 1);
        await _loadQueueInternal(songs, initialIndex: savedIndex, autoPlay: false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Queue management
  // ---------------------------------------------------------------------------

  Future<void> loadQueue(List<Song> songs, {int initialIndex = 0}) async {
    await _loadQueueInternal(songs, initialIndex: initialIndex, autoPlay: true);
  }

  Future<void> _loadQueueInternal(
    List<Song> songs, {
    int initialIndex = 0,
    bool autoPlay = true,
  }) async {
    if (songs.isEmpty) return;
    _queue = List.of(songs);
    _lastCountedIndex = null; // reset so the new first track is counted

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
    _scheduleQueueSave();
    if (autoPlay) await play();
  }

  Future<void> addToQueue(Song song) async {
    _queue.add(song);
    await _playlist.add(_toAudioSource(song));
    queue.add(_queue.map((s) => s.toMediaItem()).toList());
    _scheduleQueueSave();
  }

  Future<void> playNext(Song song) async {
    final idx = (_player.currentIndex ?? 0) + 1;
    _queue.insert(idx, song);
    await _playlist.insert(idx, _toAudioSource(song));
    queue.add(_queue.map((s) => s.toMediaItem()).toList());
    _scheduleQueueSave();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    await _playlist.removeAt(index);
    queue.add(_queue.map((s) => s.toMediaItem()).toList());
    _scheduleQueueSave();
  }

  Future<void> moveInQueue(int from, int to) async {
    if (from == to) return;
    final item = _queue.removeAt(from);
    _queue.insert(to, item);
    await _playlist.move(from, to);
    queue.add(_queue.map((s) => s.toMediaItem()).toList());
    _scheduleQueueSave();
  }

  AudioSource _toAudioSource(Song s) {
    final uri = s.data != null && s.data!.startsWith('content://')
        ? Uri.parse(s.data!)
        : Uri.file(s.data ?? '');
    return AudioSource.uri(uri, tag: s.toMediaItem());
  }

  /// FIX #10: Debounced queue persistence. Don't hammer Hive on every change.
  void _scheduleQueueSave() {
    _queueSaveDebouncer?.cancel();
    _queueSaveDebouncer = Timer(const Duration(seconds: 2), () {
      final ids = _queue.map((s) => s.id).toList();
      final idx = _player.currentIndex ?? 0;
      StorageService.instance.saveQueue(ids, idx);
    });
  }

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() async {
    await _player.setVolume(0.0);
    await _player.play();
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      await _player.setVolume(i / 10.0);
    }
  }

  @override
  Future<void> pause() async {
    for (int i = 9; i >= 0; i--) {
      await Future.delayed(const Duration(milliseconds: 30));
      await _player.setVolume(i / 10.0);
    }
    await _player.pause();
    await _player.setVolume(1.0);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  /// FIX #13: Make skip-previous edge-case-safe.
  /// If we're within 3s of the track start, go to the real previous track.
  /// If we're past 3s, restart the current one.
  /// Also guard against the player reporting "hasPrevious = true" while we're
  /// already on index 0 (which happens on some OEMs with audio_service queue).
  @override
  Future<void> skipToPrevious() async {
    final pos = _player.position;
    final currentIdx = _player.currentIndex ?? 0;

    // Past 3 seconds in: restart current track, don't navigate.
    if (pos.inSeconds >= 3) {
      await _player.seek(Duration.zero);
      return;
    }

    // At the start of the first track: just restart it.
    if (currentIdx <= 0) {
      await _player.seek(Duration.zero);
      return;
    }

    // Normal case: jump back one.
    await _player.seek(Duration.zero, index: currentIdx - 1);
  }

  @override
  Future<void> skipToQueueItem(int index) =>
      _player.seek(Duration.zero, index: index);

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
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      AudioServiceRepeatMode.group => LoopMode.all,
    });
  }

  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));
  Future<void> setSpeed(double s) => _player.setSpeed(s.clamp(0.25, 2.5));
  Future<void> setPitch(double p) => _player.setPitch(p.clamp(0.5, 2.0));

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
  Stream<bool> get playingStream => _player.playingStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  Stream<bool> get shuffleModeStream => _player.shuffleModeEnabledStream;
}

extension SongToMediaItem on Song {
  MediaItem toMediaItem() => MediaItem(
        id: mediaId,
        title: title,
        album: album,
        artist: artist,
        duration: durationAsDuration,
        extras: {
          'songId': id,
          'albumId': albumId,
          'data': data,
        },
      );
}

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
