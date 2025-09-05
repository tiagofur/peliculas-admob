import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/simple_favorites_provider.dart';

/// Widget temporal para probar la sincronización simple de favoritos
class SimpleFavoritesTestWidget extends ConsumerWidget {
  const SimpleFavoritesTestWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(simpleFavoritesProvider);
    final favoritesCount = ref.watch(favoritesCountProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Test Favoritos Simple',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Favoritos cargados: $favoritesCount',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            if (favorites.isNotEmpty) ...[
              const Text('Últimos favoritos:'),
              const SizedBox(height: 4),
              ...favorites.values.take(3).map((movie) => 
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 2),
                  child: Text(
                    '• ${movie.title}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              if (favorites.length > 3) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 2),
                  child: Text(
                    '... y ${favorites.length - 3} más',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ] else ...[
              const Text('No hay favoritos'),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(simpleFavoritesProvider.notifier).forceSync();
                  },
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Forzar Sync'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Favoritos: $favoritesCount'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info, size: 16),
                  label: const Text('Info'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}