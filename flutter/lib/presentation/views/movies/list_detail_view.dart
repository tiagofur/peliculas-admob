import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/utils/tmdb_image_utils.dart';
import '../../../domain/entities/entities.dart';
import '../../../services/share_service.dart';
import '../../providers/custom_lists_provider.dart';
import '../../providers/list_items_provider.dart'; // MIGRACIÓN: Nuevo provider basado en streams
import '../../providers/movies/movie_info_provider.dart';
import '../../providers/search/search_movies_provider.dart';
import '../../providers/storage/direct_custom_lists_provider.dart';
import '../../widgets/movies/movie_masonry_with_ads.dart';

class ListDetailView extends ConsumerStatefulWidget {
  const ListDetailView({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ListDetailView> createState() => _ListDetailViewState();
}

class _ListDetailViewState extends ConsumerState<ListDetailView> {
  @override
  Widget build(BuildContext context) {
    final directListsState = ref.watch(directCustomListsProvider);
    final directCustomList = directListsState.getListWithMovies(widget.listId);
    final repositoryCustomList = ref.watch(listByIdProvider(widget.listId));
    final customList = directCustomList ?? repositoryCustomList;

    // Debug: Mostrar qué ID estamos buscando
    LoggerFactory.info(
        'ListDetailView: Buscando lista con ID: ${widget.listId}');
    LoggerFactory.info(
        'ListDetailView: Lista encontrada (direct): ${directCustomList?.name ?? 'null'}');
    LoggerFactory.info(
        'ListDetailView: Lista encontrada (repository): ${repositoryCustomList?.name ?? 'null'}');
    LoggerFactory.info(
        'ListDetailView: Lista final usada: ${customList?.name ?? 'null'}');
    LoggerFactory.info(
        'ListDetailView: Tipo de customList: ${customList.runtimeType}');

    // Por ahora, asumiendo que siempre hay una lista válida para debuggear
    return _buildListContent(customList, context);
  }

  Widget _buildListContent(CustomList? customList, BuildContext context) {
    if (customList == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lista no encontrada'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('La lista solicitada no existe'),
              const SizedBox(height: 8),
              Text('ID buscado: ${widget.listId}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;
    final moviesCacheAsync = ref.watch(movieInfoProvider);

    // MIGRADO: Usar listMovieCountProvider en lugar de movieIds.isEmpty
    final movieCount = ref.watch(listMovieCountProvider(customList.id));
    if (movieCount == 0) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(customList, colors, textStyles),
            SliverFillRemaining(
              child: _buildEmptyState(colors, textStyles),
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(customList, colors),
      );
    }

    // MIGRADO: Primero obtener items de la lista usando listItemsProvider
    final listItemsAsync = ref.watch(listItemsProvider(customList.id));

    return listItemsAsync.when(
      loading: () => Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(customList, colors, textStyles),
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(customList, colors),
      ),
      error: (err, stack) => Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(customList, colors, textStyles),
            SliverFillRemaining(
              child: Center(child: Text('Error al cargar items: $err')),
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(customList, colors),
      ),
      data: (listItems) {
        // Ahora usar .when para el caché de películas
        return moviesCacheAsync.when(
          loading: () => Scaffold(
            body: CustomScrollView(
              slivers: [
                _buildSliverAppBar(customList, colors, textStyles),
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
          error: (err, stack) => Scaffold(
            body: CustomScrollView(
              slivers: [
                _buildSliverAppBar(customList, colors, textStyles),
                SliverFillRemaining(
                  child: Center(child: Text('Error al cargar películas: $err')),
                ),
              ],
            ),
          ),
          data: (moviesMap) {
            final failedMovieIds = ref.watch(movieLoadFailuresProvider);
            final loadingMovieIds = ref.watch(movieLoadInProgressProvider);

            // MIGRADO: Extraer IDs de los ListItems
            final requestedMovieIds =
                listItems.map((item) => item.movieId.toString()).toList();

            for (final movieId in requestedMovieIds) {
              if (moviesMap[movieId] != null) continue;
              if (failedMovieIds.contains(movieId)) continue;
              if (loadingMovieIds.contains(movieId)) continue;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ref.read(movieInfoProvider.notifier).loadMovie(movieId);
              });
            }

            final movies = requestedMovieIds
                .map((id) => moviesMap[id])
                .whereType<Movie>()
                .toList();

            final missingMovieIds = requestedMovieIds
                .where(failedMovieIds.contains)
                .map((id) => int.tryParse(id))
                .whereType<int>()
                .toList();

            final loadingIdsForList =
                requestedMovieIds.where(loadingMovieIds.contains).toList();

            final slivers = <Widget>[
              _buildSliverAppBar(customList, colors, textStyles),
            ];

            if (missingMovieIds.isNotEmpty) {
              slivers.add(
                SliverToBoxAdapter(
                  child: _buildMissingMoviesBanner(
                    colors: colors,
                    textStyles: textStyles,
                    missingCount: missingMovieIds.length,
                    onRemove: () =>
                        _removeMissingMovies(customList, missingMovieIds),
                    onRetry: () {
                      for (final id in missingMovieIds) {
                        ref
                            .read(movieInfoProvider.notifier)
                            .loadMovie(id.toString(), force: true);
                      }
                    },
                  ),
                ),
              );
            }

            if (movies.isNotEmpty) {
              slivers.add(
                SliverFillRemaining(
                  child: MasonryWithAds(movies: movies),
                ),
              );
            } else if (loadingIdsForList.isNotEmpty) {
              slivers.add(
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            } else if (listItems.isNotEmpty &&
                missingMovieIds.length == listItems.length) {
              // MIGRADO: Comparar con listItems.length en lugar de movieIds.length
              slivers.add(
                SliverFillRemaining(
                  child: _buildMissingMoviesEmptyState(
                    colors,
                    textStyles,
                    missingMovieIds.length,
                  ),
                ),
              );
            } else {
              slivers.add(
                SliverFillRemaining(
                  child: _buildEmptyState(colors, textStyles),
                ),
              );
            }

            return Scaffold(
              body: CustomScrollView(
                slivers: slivers,
              ),
              floatingActionButton:
                  _buildFloatingActionButton(customList, colors),
            );
          },
        );
      },
    );
  }

  Widget _buildSliverAppBar(
      CustomList customList, ColorScheme colors, TextTheme textStyles) {
    final listColor = _getColorFromString(customList.color);
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: listColor,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          customList.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                listColor,
                listColor.withValues(alpha: 170), // 0.7 * 255 ≈ 170
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: listColor.withValues(alpha: 77), // 0.3 * 255 ≈ 77
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            customList.emoji,
                            style: const TextStyle(fontSize: 48),
                          ),
                          if (customList.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              customList.description,
                              style: textStyles.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 10),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black
                                  .withValues(alpha: 51), // 0.2 * 255 ≈ 51
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Consumer(
                              builder: (context, ref, _) {
                                // MIGRADO: Usar listMovieCountProvider
                                final count = ref.watch(
                                    listMovieCountProvider(customList.id));
                                return Text(
                                  '$count películas',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, customList),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Editar lista'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'duplicate',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Duplicar lista'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share),
                title: Text('Compartir lista'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: ListTile(
                leading: Icon(Icons.clear_all),
                title: Text('Vaciar lista'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (!customList.isDefault)
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Eliminar lista',
                      style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colors, TextTheme textStyles) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 48,
            color: colors.onSurface.withValues(alpha: 77), // 0.3 * 255 ≈ 77
          ),
          const SizedBox(height: 12),
          Text(
            'Lista vacía',
            style: textStyles.titleMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 153), // 0.6 * 255 ≈ 153
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Agrega películas a esta lista desde\nlos detalles de cualquier película',
            style: textStyles.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 128), // 0.5 * 255 ≈ 128
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Explorar películas'),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingMoviesBanner({
    required ColorScheme colors,
    required TextTheme textStyles,
    required int missingCount,
    required VoidCallback onRemove,
    required VoidCallback onRetry,
  }) {
    final title = missingCount == 1
        ? 'Una película ya no está disponible'
        : '$missingCount películas ya no están disponibles';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.movie_outlined, color: colors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textStyles.titleSmall?.copyWith(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Es posible que hayan sido eliminadas o no estén disponibles en la API. Puedes reintentar la carga o quitarlas de la lista.',
                      style: textStyles.bodySmall?.copyWith(
                        color: colors.onErrorContainer.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar carga'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar de la lista'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMissingMoviesEmptyState(
    ColorScheme colors,
    TextTheme textStyles,
    int missingCount,
  ) {
    final title = missingCount == 1
        ? 'La película guardada ya no está disponible'
        : 'Las películas guardadas ya no están disponibles';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 56,
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Puedes eliminar estas referencias o agregar nuevas películas desde la sección de búsqueda.',
            style: textStyles.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.search),
            label: const Text('Buscar nuevas películas'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMissingMovies(
    CustomList customList,
    List<int> missingMovieIds,
  ) async {
    if (missingMovieIds.isEmpty) return;

    final notifier = ref.read(directCustomListsProvider.notifier);
    final failuresNotifier = ref.read(movieLoadFailuresProvider.notifier);
    final uniqueIds = missingMovieIds.toSet();

    try {
      for (final movieId in uniqueIds) {
        await notifier.removeMovieFromList(customList.id, movieId);
        failuresNotifier.remove(movieId.toString());
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uniqueIds.length == 1
                ? 'Se eliminó la película no disponible de la lista.'
                : 'Se eliminaron ${uniqueIds.length} películas no disponibles.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      LoggerFactory.error(
          '❌ ListDetailView: Error eliminando películas no disponibles: $error');
      LoggerFactory.error('📍 StackTrace: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron eliminar algunas películas: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildFloatingActionButton(CustomList customList, ColorScheme colors) {
    final listColor = _getColorFromString(customList.color);
    return FloatingActionButton.extended(
      onPressed: () => _showAddMovieDialog(customList),
      backgroundColor: listColor,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Agregar película'),
    );
  }

  void _handleMenuAction(String action, CustomList customList) {
    switch (action) {
      case 'edit':
        _showEditListDialog(customList);
        break;
      case 'duplicate':
        _duplicateList(customList);
        break;
      case 'share':
        _shareList(customList);
        break;
      case 'clear':
        _clearList(customList);
        break;
      case 'delete':
        _deleteList(customList);
        break;
    }
  }

  void _showEditListDialog(CustomList customList) {
    showDialog(
      context: context,
      builder: (context) => _EditListDialog(customList: customList),
    );
  }

  void _showAddMovieDialog(CustomList customList) {
    showDialog(
      context: context,
      builder: (context) => _AddMovieDialog(listId: widget.listId),
    );
  }

  void _duplicateList(CustomList customList) async {
    try {
      final notifier = ref.read(directCustomListsProvider.notifier);

      final newListId = await notifier.createList(
        name: '${customList.name} (Copia)',
        description: customList.description.isNotEmpty
            ? '${customList.description} (Copia)'
            : 'Copia de ${customList.name}',
        emoji: customList.emoji,
        color: customList.color,
      );

      if (newListId == null) {
        throw Exception('No se pudo crear la lista duplicada');
      }

      // Get current list items from provider
      final listItems = await ref.read(listItemsProvider(customList.id).future);
      for (final item in listItems) {
        await notifier.addMovieToList(newListId, item.movieId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lista "${customList.name}" duplicada'),
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () {
                context.push('/lists/$newListId');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al duplicar lista: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _shareList(CustomList customList) async {
    try {
      // Get movie count from provider
      final movieCount = ref.read(listMovieCountProvider(customList.id));
      await ShareService.shareMovieList(
        context: context,
        listId: customList.id.toString(),
        listName: customList.name,
        listDescription: customList.description.isNotEmpty
            ? customList.description
            : 'Una colección de $movieCount películas seleccionadas',
        movieCount: movieCount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _clearList(CustomList customList) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar lista'),
        content: Text(
            '¿Estás seguro de que quieres eliminar todas las películas de "${customList.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                // Get current list items from provider
                final listItems =
                    await ref.read(listItemsProvider(customList.id).future);
                // Remover todas las películas de la lista
                for (final item in listItems) {
                  await ref
                      .read(directCustomListsProvider.notifier)
                      .removeMovieFromList(
                        customList.id,
                        item.movieId,
                      );
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lista "${customList.name}" vaciada')),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al vaciar lista: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
  }

  void _deleteList(CustomList customList) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text(
            '¿Estás seguro de que quieres eliminar "${customList.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              try {
                await ref
                    .read(directCustomListsProvider.notifier)
                    .deleteList(customList.id);
                Navigator.of(context).pop();
                context.pop(); // Volver a la vista anterior
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Lista "${customList.name}" eliminada')),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar lista: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'pink':
        return Colors.pink;
      case 'purple':
        return Colors.purple;
      case 'deep_purple':
        return Colors.deepPurple;
      case 'indigo':
        return Colors.indigo;
      case 'blue':
        return Colors.blue;
      case 'light_blue':
        return Colors.lightBlue;
      case 'cyan':
        return Colors.cyan;
      case 'teal':
        return Colors.teal;
      case 'green':
        return Colors.green;
      case 'light_green':
        return Colors.lightGreen;
      case 'lime':
        return Colors.lime;
      case 'yellow':
        return Colors.yellow;
      case 'amber':
        return Colors.amber;
      case 'orange':
        return Colors.orange;
      case 'deep_orange':
        return Colors.deepOrange;
      case 'brown':
        return Colors.brown;
      case 'grey':
        return Colors.grey;
      case 'blue_grey':
        return Colors.blueGrey;
      default:
        return Colors.blue;
    }
  }
}

class _EditListDialog extends ConsumerStatefulWidget {
  const _EditListDialog({required this.customList});

  final CustomList customList;

  @override
  ConsumerState<_EditListDialog> createState() => _EditListDialogState();
}

class _EditListDialogState extends ConsumerState<_EditListDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _selectedEmoji;
  late String _selectedColor;

  final List<String> _emojis = [
    '🎬',
    '🍿',
    '🎭',
    '🎪',
    '🎨',
    '🎵',
    '🎸',
    '🎤',
    '🎧',
    '🎮',
    '📚',
    '📖',
    '📝',
    '📊',
    '📈',
    '📉',
    '📋',
    '📌',
    '📍',
    '📎',
    '💡',
    '💭',
    '💫',
    '⭐',
    '🌟',
    '✨',
    '🔥',
    '❤️',
    '💙',
    '💚',
    '💛',
    '💜',
    '🧡',
    '🖤',
    '🤍',
    '🤎',
    '💖',
    '💕',
    '💗',
    '💓',
  ];

  final List<String> _colors = [
    'red',
    'pink',
    'purple',
    'deep_purple',
    'indigo',
    'blue',
    'light_blue',
    'cyan',
    'teal',
    'green',
    'light_green',
    'lime',
    'yellow',
    'amber',
    'orange',
    'deep_orange',
    'brown',
    'grey',
    'blue_grey'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customList.name);
    _descriptionController =
        TextEditingController(text: widget.customList.description);
    _selectedEmoji = widget.customList.emoji;
    _selectedColor = widget.customList.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar lista'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la lista',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text('Emoji:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _emojis.length,
                itemBuilder: (context, index) {
                  final emoji = _emojis[index];
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                      ),
                      child: Center(
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('Color:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  final colorName = _colors[index];
                  final color = _getColorFromString(colorName);
                  final isSelected = colorName == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorName),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () async {
                  try {
                    await ref
                        .read(directCustomListsProvider.notifier)
                        .updateList(
                          widget.customList.id,
                          name: _nameController.text.trim(),
                          description: _descriptionController.text.trim(),
                          emoji: _selectedEmoji,
                          color: _selectedColor,
                        );
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al actualizar lista: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'pink':
        return Colors.pink;
      case 'purple':
        return Colors.purple;
      case 'deep_purple':
        return Colors.deepPurple;
      case 'indigo':
        return Colors.indigo;
      case 'blue':
        return Colors.blue;
      case 'light_blue':
        return Colors.lightBlue;
      case 'cyan':
        return Colors.cyan;
      case 'teal':
        return Colors.teal;
      case 'green':
        return Colors.green;
      case 'light_green':
        return Colors.lightGreen;
      case 'lime':
        return Colors.lime;
      case 'yellow':
        return Colors.yellow;
      case 'amber':
        return Colors.amber;
      case 'orange':
        return Colors.orange;
      case 'deep_orange':
        return Colors.deepOrange;
      case 'brown':
        return Colors.brown;
      case 'grey':
        return Colors.grey;
      case 'blue_grey':
        return Colors.blueGrey;
      default:
        return Colors.blue;
    }
  }
}

class _AddMovieDialog extends ConsumerStatefulWidget {
  const _AddMovieDialog({required this.listId});

  final String listId;

  @override
  ConsumerState<_AddMovieDialog> createState() => _AddMovieDialogState();
}

class _AddMovieDialogState extends ConsumerState<_AddMovieDialog> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(searchedMoviesProvider);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Agregar película',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar película',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).update((state) => value);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: searchResultsAsync.when(
                data: (movies) {
                  if (movies.isEmpty) {
                    return const Center(
                      child:
                          Text('Escribe el nombre de una película para buscar'),
                    );
                  }

                  return ListView.builder(
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      return ListTile(
                        leading: movie.posterPath.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  resolvePosterUrl(
                                    movie.posterPath,
                                    size: 'w92',
                                  ),
                                  width: 40,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 40,
                                      height: 60,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.movie),
                                    );
                                  },
                                ),
                              )
                            : Container(
                                width: 40,
                                height: 60,
                                color: Colors.grey[300],
                                child: const Icon(Icons.movie),
                              ),
                        title: Text(movie.title),
                        subtitle: Text(
                          movie.releaseDate.year.toString(),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            try {
                              // Agregar película a la lista usando el provider
                              await ref
                                  .read(directCustomListsProvider.notifier)
                                  .addMovieToList(
                                    widget.listId,
                                    movie.id,
                                  );

                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${movie.title} agregada a la lista'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Error al agregar película: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(searchedMoviesProvider);
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
