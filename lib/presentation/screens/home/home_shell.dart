import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../search/search_screen.dart';
import '../library/library_screen.dart';
import '../playlists/playlists_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/mini_player.dart';
import 'home_screen.dart';

/// Root scaffold with 4-tab bottom nav and persistent MiniPlayer.
///
/// Design decisions:
///   - Search lives in a persistent top AppBar, always visible from any tab
///   - No FAB (it collided with the MiniPlayer and only worked on Home tab)
///   - Each tab's title updates the AppBar title dynamically
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  // The four tab pages. Keeping them const means Flutter preserves their
  // state across tab switches (e.g. Library's scroll position survives
  // switching to Settings and back).
  final _pages = const [
    HomeScreen(),
    LibraryScreen(),
    PlaylistsScreen(),
    SettingsScreen(),
  ];

  // Tab titles shown in the AppBar — match the bottom nav labels exactly.
  static const _titles = ['Melody Flow', 'Library', 'Playlists', 'Settings'];

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _index == 0;

    return Scaffold(
      // ----- TOP APPBAR WITH SEARCH (always visible) -----
      appBar: AppBar(
        // No back button — this is the root, not a pushed screen
        automaticallyImplyLeading: false,
        title: Text(
          _titles[_index],
          style: TextStyle(
            // Use a slightly bolder weight on Home so the brand feels stronger,
            // lighter weight for utility tabs so they don't shout.
            fontWeight: isHome ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: isHome ? -0.5 : -0.3,
          ),
        ),
        // A subtle, flat AppBar that doesn't fight with the content below.
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          // THE SEARCH BUTTON — always visible, any tab
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search your music',
            onPressed: _openSearch,
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ----- MAIN CONTENT — one of 4 tabs -----
      body: IndexedStack(index: _index, children: _pages),

      // ----- BOTTOM: MINI-PLAYER + BOTTOM NAV -----
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
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
    );
  }
}
