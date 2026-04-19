import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../search/search_screen.dart';
import '../library/library_screen.dart';
import '../playlists/playlists_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/mini_player.dart';
import '../../providers/app_providers.dart';
import 'home_screen.dart';

/// Root scaffold with bottom nav, mini player, and back-to-now-playing FAB.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    LibraryScreen(),
    PlaylistsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final hasMedia = ref.watch(mediaItemStreamProvider).valueOrNull != null;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.library_music_outlined),
                activeIcon: Icon(Icons.library_music_rounded),
                label: 'Library',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.queue_music_outlined),
                activeIcon: Icon(Icons.queue_music_rounded),
                label: 'Playlists',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
      // Search FAB on Home tab only; otherwise no FAB (mini player fills the role)
      floatingActionButton: _index == 0 && !hasMedia
          ? FloatingActionButton(
              heroTag: 'search_fab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              elevation: 0,
              child: const Icon(Icons.search_rounded),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
