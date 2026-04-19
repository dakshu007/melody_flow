import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_handler.dart';

/// Bridges the audio handler and the Android home-screen widget.
///
/// Why this class exists: Android widgets can't call into Dart directly and
/// can't render Flutter UI. They read state from SharedPreferences and fire
/// intents when buttons are tapped. We mediate between those two worlds.
///
/// Responsibilities:
///   1. Listen to audio state changes -> push to SharedPreferences -> tell
///      the native widget to redraw.
///   2. Save current artwork as a PNG on disk so RemoteViews can load it.
///   3. Receive button-tap events from the widget via MethodChannel and
///      forward them to the audio handler.
class WidgetBridge {
  WidgetBridge._();
  static final WidgetBridge instance = WidgetBridge._();

  static const _channel = MethodChannel('com.daksheshbabu.melodyflow/widget');
  static const _widgetName = 'MelodyWidgetProvider';

  MelodyAudioHandler? _handler;
  int? _lastArtSongId;
  bool _initialized = false;

  /// Latest playing state, maintained by listening to the handler's
  /// playingStream. MelodyAudioHandler doesn't expose a sync getter for
  /// the current playing state, so we track it locally.
  bool _isPlaying = false;

  /// Wire everything up. Call once from main() after the handler is built.
  Future<void> init(MelodyAudioHandler handler) async {
    if (_initialized) return;
    _initialized = true;
    _handler = handler;

    // 1. Listen for widget button taps
    _channel.setMethodCallHandler(_onMethodCall);

    // 2. Track playing state locally + push updates to widget
    handler.playingStream.listen((playing) {
      _isPlaying = playing;
      _pushState(handler.mediaItem.value, playing);
    });

    // 3. Push updates when the current song changes
    handler.mediaItem.listen((item) => _pushState(item, _isPlaying));

    // 4. Initial state
    await _pushState(handler.mediaItem.value, _isPlaying);
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (_handler == null) return;
    if (call.method != 'widgetAction') return;
    final action = call.arguments as String?;
    if (action == null) return;

    switch (action) {
      case 'com.daksheshbabu.melodyflow.PLAY_PAUSE':
        if (_isPlaying) {
          await _handler!.pause();
        } else {
          await _handler!.play();
        }
        break;
      case 'com.daksheshbabu.melodyflow.SKIP_NEXT':
        await _handler!.skipToNext();
        break;
      case 'com.daksheshbabu.melodyflow.SKIP_PREV':
        await _handler!.skipToPrevious();
        break;
    }
  }

  /// Write state to native SharedPreferences then tell the widget to redraw.
  Future<void> _pushState(MediaItem? item, bool isPlaying) async {
    if (!Platform.isAndroid) return;
    try {
      if (item == null) {
        await HomeWidget.saveWidgetData<String>(
            'widget_title', 'Melody Flow');
        await HomeWidget.saveWidgetData<String>(
            'widget_artist', 'Tap to start playing');
        await HomeWidget.saveWidgetData<bool>('widget_is_playing', false);
        await HomeWidget.saveWidgetData<String>('widget_artwork_path', '');
      } else {
        await HomeWidget.saveWidgetData<String>('widget_title', item.title);
        await HomeWidget.saveWidgetData<String>(
            'widget_artist', item.artist ?? '');
        await HomeWidget.saveWidgetData<bool>(
            'widget_is_playing', isPlaying);

        // Save artwork only when the song actually changes
        final songId = item.extras?['songId'] as int?;
        if (songId != null && songId != _lastArtSongId) {
          _lastArtSongId = songId;
          final path = await _saveArtwork(songId);
          await HomeWidget.saveWidgetData<String>(
              'widget_artwork_path', path ?? '');
        }
      }
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
      );
    } catch (e) {
      if (kDebugMode) print('WidgetBridge._pushState error: $e');
    }
  }

  Future<String?> _saveArtwork(int songId) async {
    try {
      final Uint8List? bytes = await OnAudioQuery()
          .queryArtwork(songId, ArtworkType.AUDIO, size: 256);
      if (bytes == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'widget_artwork.png'));
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      if (kDebugMode) print('WidgetBridge._saveArtwork failed: $e');
      return null;
    }
  }
}
