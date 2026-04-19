import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Tiny in-memory LRU cache for MediaStore artwork bytes.
/// Avoids re-querying the same album art dozens of times while scrolling.
class _ArtCache {
  _ArtCache._();
  static final _ArtCache instance = _ArtCache._();

  static const int _maxEntries = 300;
  final _map = <String, Uint8List?>{};
  final _order = <String>[];

  Uint8List? get(String key) {
    if (!_map.containsKey(key)) return null;
    // Touch → move to end
    _order.remove(key);
    _order.add(key);
    return _map[key];
  }

  void put(String key, Uint8List? bytes) {
    if (_map.containsKey(key)) {
      _order.remove(key);
    } else if (_order.length >= _maxEntries) {
      final oldest = _order.removeAt(0);
      _map.remove(oldest);
    }
    _map[key] = bytes;
    _order.add(key);
  }

  bool contains(String key) => _map.containsKey(key);
}

/// Drop-in replacement for QueryArtworkWidget that caches the result.
/// Use anywhere a song / album thumbnail is shown.
class ArtworkImage extends StatefulWidget {
  final int id;
  final ArtworkType type;
  final double size;
  final double borderRadius;
  final BoxFit fit;
  final Widget? placeholder;

  const ArtworkImage({
    super.key,
    required this.id,
    this.type = ArtworkType.AUDIO,
    this.size = 48,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends State<ArtworkImage> {
  Uint8List? _bytes;
  bool _loading = false;
  bool _tried = false;

  String get _key => '${widget.type.name}_${widget.id}_${widget.size.toInt()}';

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ArtworkImage old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.type != widget.type) {
      _tried = false;
      _bytes = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (_ArtCache.instance.contains(_key)) {
      setState(() => _bytes = _ArtCache.instance.get(_key));
      return;
    }
    if (_loading) return;
    _loading = true;
    try {
      final bytes = await OnAudioQuery().queryArtwork(
        widget.id,
        widget.type,
        size: widget.size.toInt() * 2, // request 2x for retina
      );
      _ArtCache.instance.put(_key, bytes);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _bytes = bytes;
            _tried = true;
          });
        }
      });
    } catch (_) {
      _ArtCache.instance.put(_key, null);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tried = true);
      });
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder ??
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Icon(
            Icons.music_note_rounded,
            size: widget.size * 0.4,
            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
          ),
        );

    if (_bytes == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: placeholder,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
