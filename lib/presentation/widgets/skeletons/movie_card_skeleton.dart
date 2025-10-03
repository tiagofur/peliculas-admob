import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Task 2.5: Skeleton loader for movie cards
///
/// Provides a shimmer effect placeholder while movie data is loading.
/// Used in horizontal lists, grids, and search results.
///
/// **Features**:
/// - Shimmer animation effect
/// - Matches MovieCard dimensions
/// - Theme-aware colors (light/dark mode)
/// - Reusable across different layouts
class MovieCardSkeleton extends StatelessWidget {
  const MovieCardSkeleton({
    super.key,
    this.width = 150,
    this.height = 280,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster skeleton
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Shimmer.fromColors(
                baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title skeleton
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Container(
              width: width * 0.8,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Rating skeleton
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 30,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal list of movie card skeletons
///
/// Used to show loading state in horizontal scrolling lists.
class MovieHorizontalListSkeleton extends StatelessWidget {
  const MovieHorizontalListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return const MovieCardSkeleton();
        },
      ),
    );
  }
}

/// Grid of movie card skeletons
///
/// Used for search results and category browsing loading states.
class MovieGridSkeleton extends StatelessWidget {
  const MovieGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
  });

  final int itemCount;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return const MovieCardSkeleton(
          width: double.infinity,
        );
      },
    );
  }
}
