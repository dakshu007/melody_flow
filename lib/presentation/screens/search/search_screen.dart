import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/song.dart';
import '../../providers/app_providers.dart';
import '../../widgets/song_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  List<Song> _filter(List<Song> all) {
    if (_q.isEmpty) return [];
    final q = _q.toLowerCase();
    return all.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).take(200).toList();
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(songsProvider).valueOrNull ?? [];
    final results = _filter(songs);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search songs, artists, albums',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
        actions: [
          if (_q.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _ctl.clear();
                setState(() => _q = '');
              },
            ),
        ],
      ),
      body: _q.isEmpty
          ? Center(
              child: Text('Search your library',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).textTheme.bodySmall?.color,
                      )))
          : results.isEmpty
              ? const Center(child: Text('No matches'))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) => SongTile(
                    song: results[i],
                    onTap: () => ref
                        .read(audioHandlerProvider)
                        .loadQueue(results, initialIndex: i),
                  ),
                ),
    );
  }
}
