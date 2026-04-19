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
/// Responsibilities:
///   1. Listen to audio state changes and push them to SharedPreferences
///      (via the home_widget plugin) so the native widget can redraw.
///   2. Save artwork as a PNG to app documents so the widget can load it.
///   3. Receive button-tap events from the widget (via MethodChannel) and
///      forward them to the audio handler.
class WidgetBridge {
  WidgetBridge._();
  static final WidgetBridge instance = WidgetBridge._();

  static const _channel = MethodChannel('com.melodyflow.app/widget');
  static const _widgetName = 'MelodyWidgetProvider';

  MelodyAudioHandler? _handler;
  int? _lastArtSongId;
  bool _initialized = false;

  /// Wire everything up. Call once from main() after the handler is built.
  Future<void> init(MelodyAudioHandler handler) async {
    if (_initialized) return;
    _initialized = true;
    _handler = handler;

    // 1. Listen for widget button taps
    _channel.setMethodCallHandler(_onMethodCall);

    // 2. Listen for media state changes and update the widget
    handler.mediaItem.listen((item) => _pushState(item, handler.playing));
    handler.playingStream.listen((playing) {
      _pushState(handler.mediaItem.value, playing);
    });

    // 3. Push initial state
    await _pushState(handler.mediaItem.value, handler.playing);
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (_handler == null) return;
    if (call.method != 'widgetAction') return;
    final action = call.arguments as String?;
    if (action == null) return;

    switch (action) {
      case 'com.melodyflow.app.PLAY_PAUSE':
        if (_handler!.playing) {
          await _handler!.pause();
        } else {
          await _handler!.play();
        }
        break;
      case 'com.melodyflow.app.SKIP_NEXT':
        await _handler!.skipToNext();
        break;
      case 'com.melodyflow.app.SKIP_PREV':
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

        // Save artwork to disk only when the song changes
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
