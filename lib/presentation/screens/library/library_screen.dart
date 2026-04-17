import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/song.dart';
import '../../providers/app_providers.dart';
import '../../widgets/artwork_image.dart';
import '../../widgets/collection_quick_actions.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_list.dart';
import '../../widgets/song_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  SongSortType _sortType = SongSortType.TITLE;
  OrderType _order = OrderType.ASC_OR_SMALLER;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(settingsProvider);
      setState(() {
        _sortType = SongSortType.values[
            s.songSort.clamp(0, SongSortType.values.length - 1)];
        _order = s.sortAscending
            ? OrderType.ASC_OR_SMALLER
            : OrderType.DESC_OR_GREATER;
      });
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) {
              setState(() {
                switch (v) {
                  case 'title':
                    _sortType = SongSortType.TITLE;
                  case 'artist':
                    _sortType = SongSortType.ARTIST;
                  case 'album':
                    _sortType = SongSortType.ALBUM;
                  case 'date':
                    _sortType = SongSortType.DATE_ADDED;
                  case 'duration':
                    _sortType = SongSortType.DURATION;
                  case 'order':
                    _order = _order == OrderType.ASC_OR_SMALLER
                        ? OrderType.DESC_OR_GREATER
                        : OrderType.ASC_OR_SMALLER;
                }
              });
              ref.read(settingsProvider.notifier).update((c) {
                c.songSort = _sortType.index;
                c.sortAscending = _order == OrderType.ASC_OR_SMALLER;
                return c;
              });
              ref.read(songsProvider.notifier).refresh();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'title', child: Text('Sort by title')),
              PopupMenuItem(value: 'artist', child: Text('Sort by artist')),
              PopupMenuItem(value: 'album', child: Text('Sort by album')),
              PopupMenuItem(value: 'date', child: Text('Sort by date added')),
              PopupMenuItem(value: 'duration', child: Text('Sort by duration')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'order', child: Text('Toggle asc / desc')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              Haptics.light();
              ref.read(songsProvider.notifier).refresh();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Albums'),
            Tab(text: 'Artists'),
            Tab(text: 'Genres'),
            Tab(text: 'Folders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _SongsTab(),
          _AlbumsTab(),
          _ArtistsTab(),
          _GenresTab(),
          _FoldersTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SongsTab extends ConsumerWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(songsProvider);
    return songs.when(
      loading: () => const ShimmerList(itemCount: 10),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: '$e',
        actionLabel: 'Retry',
        onAction: () => ref.read(songsProvider.notifier).refresh(),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState.noMusic(
            onRefresh: () => ref.read(songsProvider.notifier).refresh(),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: list.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) return _PlayAllHeader(songs: list);
            final s = list[i - 1];
            return SongTile(
              song: s,
              onTap: () {
                Haptics.light();
                ref
                    .read(audioHandlerProvider)
                    .loadQueue(list, initialIndex: i - 1);
              },
            );
          },
        );
      },
    );
  }
}

class _PlayAllHeader extends ConsumerWidget {
  final List<Song> songs;
  const _PlayAllHeader({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // A6: total duration summary
          Text(Format.listSummary(songs),
              style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.play_circle_fill_rounded),
            label: const Text('Play all'),
            onPressed: () {
              Haptics.medium();
              ref.read(audioHandlerProvider).loadQueue(songs);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text('Shuffle'),
            onPressed: () {
              Haptics.medium();
              final shuffled = [...songs]..shuffle();
              ref.read(audioHandlerProvider).loadQueue(shuffled);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryServiceProvider);
    return FutureBuilder<List<AlbumModel>>(
      future: lib.fetchAlbums(),
      builder: (_, snap) {
        if (!snap.hasData) return const ShimmerGrid(itemCount: 6);
        final albums = snap.data!;
        if (albums.isEmpty) {
          return const EmptyState(
            icon: Icons.album_rounded,
            title: 'No albums',
            subtitle: 'Your songs don\'t have album metadata yet.',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.78,
          ),
          itemCount: albums.length,
          itemBuilder: (_, i) => _AlbumCard(album: albums[i]),
        );
      },
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  final AlbumModel album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        Haptics.light();
        final songs =
            await ref.read(libraryServiceProvider).songsFromAlbum(album.id);
        if (songs.isEmpty) return;
        ref.read(audioHandlerProvider).loadQueue(songs);
      },
      onLongPress: () {
        CollectionQuickActions.show(
          context,
          title: album.album,
          subtitle: album.artist ?? 'Unknown artist',
          leadingIcon: Icons.album_rounded,
          loadSongs: () =>
              ref.read(libraryServiceProvider).songsFromAlbum(album.id),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: ArtworkImage(
                id: album.id,
                type: ArtworkType.ALBUM,
                size: 400,
                borderRadius: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.album,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            album.artist ?? 'Unknown artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryServiceProvider);
    return FutureBuilder<List<ArtistModel>>(
      future: lib.fetchArtists(),
      builder: (_, snap) {
        if (!snap.hasData) return const ShimmerList(itemCount: 10);
        final artists = snap.data!;
        if (artists.isEmpty) {
          return const EmptyState(
            icon: Icons.person_outline_rounded,
            title: 'No artists',
            subtitle: 'Your songs don\'t have artist metadata yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: artists.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 84),
          itemBuilder: (_, i) {
            final a = artists[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).dividerColor,
                child: const Icon(Icons.person_rounded),
              ),
              title: Text(a.artist,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${a.numberOfTracks ?? 0} songs · ${a.numberOfAlbums ?? 0} albums'),
              onTap: () async {
                Haptics.light();
                final songs = await lib.songsFromArtist(a.id);
                if (songs.isEmpty) return;
                ref.read(audioHandlerProvider).loadQueue(songs);
              },
              onLongPress: () {
                CollectionQuickActions.show(
                  context,
                  title: a.artist,
                  subtitle:
                      '${a.numberOfTracks ?? 0} songs · ${a.numberOfAlbums ?? 0} albums',
                  leadingIcon: Icons.person_rounded,
                  loadSongs: () => lib.songsFromArtist(a.id),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _GenresTab extends ConsumerWidget {
  const _GenresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryServiceProvider);
    return FutureBuilder<List<GenreModel>>(
      future: lib.fetchGenres(),
      builder: (_, snap) {
        if (!snap.hasData) return const ShimmerGrid(itemCount: 6);
        final genres = snap.data!;
        if (genres.isEmpty) {
          return const EmptyState(
            icon: Icons.category_outlined,
            title: 'No genres',
            subtitle:
                'Most songs don\'t have genre tags. Try editing their metadata.',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: genres.length,
          itemBuilder: (_, i) {
            final g = genres[i];
            return GestureDetector(
              onTap: () async {
                Haptics.light();
                final songs = await lib.songsFromGenre(g.id);
                if (songs.isEmpty) return;
                ref.read(audioHandlerProvider).loadQueue(songs);
              },
              onLongPress: () {
                CollectionQuickActions.show(
                  context,
                  title: g.genre,
                  leadingIcon: Icons.category_rounded,
                  loadSongs: () => lib.songsFromGenre(g.id),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.bottomLeft,
                child: Text(
                  g.genre,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _FoldersTab extends ConsumerWidget {
  const _FoldersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryServiceProvider);
    return FutureBuilder<List<String>>(
      future: lib.fetchFolders(),
      builder: (_, snap) {
        if (!snap.hasData) return const ShimmerList(itemCount: 8);
        final folders = snap.data!;
        if (folders.isEmpty) {
          return const EmptyState(
            icon: Icons.folder_off_rounded,
            title: 'No folders',
            subtitle: 'Music folders will appear once you have songs.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: folders.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72),
          itemBuilder: (_, i) {
            final f = folders[i];
            final name = f.split('/').last;
            return ListTile(
              leading: const Icon(Icons.folder_rounded, size: 32),
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(f,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Haptics.light();
                final allSongs =
                    ref.read(songsProvider).valueOrNull ?? [];
                final songs = allSongs
                    .where((s) =>
                        s.data != null && s.data!.startsWith(f))
                    .toList();
                if (songs.isEmpty) return;
                ref.read(audioHandlerProvider).loadQueue(songs);
              },
              onLongPress: () {
                CollectionQuickActions.show(
                  context,
                  title: name,
                  subtitle: f,
                  leadingIcon: Icons.folder_rounded,
                  loadSongs: () async {
                    final allSongs =
                        ref.read(songsProvider).valueOrNull ?? [];
                    return allSongs
                        .where((s) =>
                            s.data != null && s.data!.startsWith(f))
                        .toList();
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
