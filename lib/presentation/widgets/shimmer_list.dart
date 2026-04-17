import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmering skeleton rows that mimic the SongTile layout.
/// Use anywhere a list is loading.
class ShimmerList extends StatelessWidget {
  final int itemCount;
  const ShimmerList({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final highlight = theme.brightness == Brightness.dark
        ? Colors.grey.shade700
        : Colors.grey.shade100;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: itemCount,
      itemBuilder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 160,
                        height: 11,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer grid for albums/playlists while loading.
class ShimmerGrid extends StatelessWidget {
  final int itemCount;
  const ShimmerGrid({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final highlight = theme.brightness == Brightness.dark
        ? Colors.grey.shade700
        : Colors.grey.shade100;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(width: double.infinity, height: 12, color: Colors.white),
              const SizedBox(height: 6),
              Container(width: 80, height: 10, color: Colors.white),
            ],
          ),
        );
      },
    );
  }
}
