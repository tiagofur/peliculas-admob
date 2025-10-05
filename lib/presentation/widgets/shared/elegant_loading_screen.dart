import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Pantalla de carga elegante para transiciones suaves
/// Reemplaza las pantallas de error rojas durante estados de carga
class ElegantLoadingScreen extends StatelessWidget {
  const ElegantLoadingScreen({
    super.key,
    this.message,
    this.showShimmer = true,
  });

  final String? message;
  final bool showShimmer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated loading indicator
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  // Inner ring (faster)
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                  // Center icon
                  Icon(
                    Icons.movie_outlined,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),

            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder para contenido de pantalla (sin Scaffold)
class ContentLoadingPlaceholder extends StatelessWidget {
  const ContentLoadingPlaceholder({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.movie_outlined,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder con shimmer para listas
class ShimmerLoadingPlaceholder extends StatelessWidget {
  const ShimmerLoadingPlaceholder({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            highlightColor: colorScheme.surface,
            child: Container(
              height: itemHeight,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Profile loading placeholder específico
class ProfileLoadingPlaceholder extends StatelessWidget {
  const ProfileLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar shimmer
          Shimmer.fromColors(
            baseColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            highlightColor: colorScheme.surface,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name shimmer
          Shimmer.fromColors(
            baseColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            highlightColor: colorScheme.surface,
            child: Container(
              width: 200,
              height: 24,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Username shimmer
          Shimmer.fromColors(
            baseColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            highlightColor: colorScheme.surface,
            child: Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stats cards shimmer
          Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == 2 ? 0 : 4,
                  ),
                  child: Shimmer.fromColors(
                    baseColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    highlightColor: colorScheme.surface,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Content cards shimmer
          ...List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Shimmer.fromColors(
                baseColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                highlightColor: colorScheme.surface,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Movie detail loading placeholder específico
class MovieDetailLoadingPlaceholder extends StatelessWidget {
  const MovieDetailLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Backdrop shimmer
          Shimmer.fromColors(
            baseColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            highlightColor: colorScheme.surface,
            child: Container(
              width: double.infinity,
              height: 250,
              color: colorScheme.surfaceContainerHighest,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title shimmer
                Shimmer.fromColors(
                  baseColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  highlightColor: colorScheme.surface,
                  child: Container(
                    width: double.infinity,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Genre chips shimmer
                Row(
                  children: List.generate(3, (index) {
                    return Padding(
                      padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      child: Shimmer.fromColors(
                        baseColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        highlightColor: colorScheme.surface,
                        child: Container(
                          width: 80,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Overview shimmer
                ...List.generate(4, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Shimmer.fromColors(
                      baseColor: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      highlightColor: colorScheme.surface,
                      child: Container(
                        width: index == 3
                            ? MediaQuery.of(context).size.width * 0.6
                            : double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
