import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loader for the actor details screen.
///
/// Mirrors the [MovieDetailsSkeleton] language: shimmer placeholders that
/// follow the ActorScreen layout (hero photo, header, biography, filmography).
class ActorDetailsSkeleton extends StatelessWidget {
  const ActorDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    Color base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    Color highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    Widget shimmerBox({
      required double width,
      required double height,
      double radius = 8,
    }) {
      return Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(
              width: double.infinity,
              height: size.height * 0.55,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBox(width: 220, height: 28, radius: 6),
                const SizedBox(height: 12),
                Row(
                  children: [
                    shimmerBox(width: 110, height: 28, radius: 14),
                    const SizedBox(width: 8),
                    shimmerBox(width: 130, height: 28, radius: 14),
                  ],
                ),
                const SizedBox(height: 24),
                shimmerBox(width: double.infinity, height: 120, radius: 12),
                const SizedBox(height: 24),
                shimmerBox(width: 160, height: 24, radius: 6),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, _) => shimmerBox(
                    width: double.infinity,
                    height: 180,
                    radius: 12,
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
