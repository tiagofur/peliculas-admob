// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/entities.dart';
import '../../providers/custom_lists_provider.dart';

class MovieListsWidget extends ConsumerStatefulWidget {
  const MovieListsWidget({super.key, required this.movie});

  final Movie movie;

  @override
  ConsumerState<MovieListsWidget> createState() => _MovieListsWidgetState();
}

class _MovieListsWidgetState extends ConsumerState<MovieListsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allLists = ref.watch(listsProvider);
    final listsContainingMovie = allLists
        .where((list) => list.movieIds.contains(widget.movie.id))
        .toList();
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    // Separar listas predeterminadas y personalizadas
    final defaultLists = allLists.where((list) => list.isDefault).toList();
    final customLists = allLists.where((list) => !list.isDefault).toList();

    // Calcular altura fija basada en las listas predeterminadas (máximo 8 listas en 4 filas)
    final defaultListsCount = defaultLists.length;
    final rowsNeeded = (defaultListsCount / 2).ceil().clamp(1, 4);
    final fixedHeight = (rowsNeeded * 80.0) +
        ((rowsNeeded - 1) * 8.0); // altura de card + spacing

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Mis Listas',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showCreateListDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nueva lista'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Reducido de 12 a 8
          if (allLists.isEmpty)
            _buildEmptyState(colors, textStyles)
          else
            Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.onSurface.withValues(alpha: 0.6),
                  indicatorColor: colors.primary,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_outline, size: 16),
                          const SizedBox(width: 4),
                          Text('Predeterminadas (${defaultLists.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text('Personalizadas (${customLists.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: fixedHeight,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Pestaña de listas predeterminadas
                      _buildListsGrid(defaultLists, listsContainingMovie,
                          colors, textStyles, false // sin scroll
                          ),
                      // Pestaña de listas personalizadas
                      _buildListsGrid(
                          customLists,
                          listsContainingMovie,
                          colors,
                          textStyles,
                          customLists.length > 8 // con scroll si hay más de 8
                          ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors, TextTheme textStyles) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.playlist_add,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'No tienes listas aún',
            style: textStyles.titleSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Crea tu primera lista para organizar tus películas',
            style: textStyles.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListsGrid(
      List<CustomList> lists,
      List<CustomList> listsContainingMovie,
      ColorScheme colors,
      TextTheme textStyles,
      bool enableScroll) {
    if (lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay listas en esta categoría',
              style: textStyles.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    final gridView = GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: enableScroll
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        final list = lists[index];
        final isInList = listsContainingMovie.any((l) => l.id == list.id);
        return _buildListCard(list, isInList, colors, textStyles);
      },
    );

    return gridView;
  }

  Widget _buildListCard(CustomList list, bool isInList, ColorScheme colors,
      TextTheme textStyles) {
    final listColor = _getColorFromString(list.color);

    return GestureDetector(
      onTap: () => _toggleMovieInList(list, isInList),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isInList ? listColor.withValues(alpha: 0.15) : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInList ? listColor : colors.outline.withValues(alpha: 0.2),
            width: isInList ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  list.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    list.name,
                    style: textStyles.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isInList ? listColor : colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isInList ? Icons.check_circle : Icons.add_circle_outline,
                    key: ValueKey(isInList),
                    color: isInList
                        ? listColor
                        : colors.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${list.movieIds.length} películas',
                  style: textStyles.bodySmall?.copyWith(
                    color: isInList
                        ? listColor.withValues(alpha: 0.8)
                        : colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (list.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Por defecto',
                      style: textStyles.labelSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMovieInList(CustomList list, bool isInList) {
    if (isInList) {
      ref
          .read(allListsNotifierProvider.notifier)
          .removeMovieFromList(list.id, widget.movie.id);

      // Mostrar confirmación de eliminación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Película eliminada de "${list.name}"'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ref
          .read(allListsNotifierProvider.notifier)
          .addMovieToList(list.id, widget.movie.id);

      // Mostrar confirmación de adición
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Película añadida a "${list.name}"'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Ver',
            textColor: Colors.white,
            onPressed: () {
              // Navegar a la lista
              context.go('/my-library/lists/${list.id}');
            },
          ),
        ),
      );
    }
  }

  void _showCreateListDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _CreateListDialog(movieId: widget.movie.id),
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

class _CreateListDialog extends ConsumerStatefulWidget {
  const _CreateListDialog({required this.movieId});

  final int movieId;

  @override
  ConsumerState<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<_CreateListDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String _selectedEmoji = '🎬';
  String _selectedColor = 'blue';
  bool _addCurrentMovie = true;
  bool _isButtonEnabled = false;

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
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();

    // Listener para habilitar/deshabilitar el botón dinámicamente
    _nameController.addListener(() {
      setState(() {
        _isButtonEnabled = _nameController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Crear nueva lista',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la lista',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
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
                    CheckboxListTile(
                      title: const Text('Agregar esta película a la lista'),
                      value: _addCurrentMovie,
                      onChanged: (value) =>
                          setState(() => _addCurrentMovie = value ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    const Text('Emoji:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          childAspectRatio: 1,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: _emojis.length,
                        itemBuilder: (context, index) {
                          final emoji = _emojis[index];
                          final isSelected = emoji == _selectedEmoji;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedEmoji = emoji),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : null,
                                borderRadius: BorderRadius.circular(6),
                                border: isSelected
                                    ? Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 18)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Color:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        scrollDirection: Axis.horizontal,
                        itemCount: _colors.length,
                        itemBuilder: (context, index) {
                          final colorName = _colors[index];
                          final color = _getColorFromString(colorName);
                          final isSelected = colorName == _selectedColor;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedColor = colorName),
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : Border.all(
                                        color:
                                            Colors.grey.withValues(alpha: 0.3),
                                        width: 1),
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
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isButtonEnabled
                        ? () async {
                            try {
                              // Crear la lista usando el nuevo provider
                              await ref
                                  .read(allListsNotifierProvider.notifier)
                                  .createList(
                                    name: _nameController.text.trim(),
                                    description:
                                        _descriptionController.text.trim(),
                                    emoji: _selectedEmoji,
                                    color: _selectedColor,
                                  );

                              // Esperar un frame para que se actualice el provider
                              await Future.delayed(
                                  const Duration(milliseconds: 100));

                              if (_addCurrentMovie) {
                                // Obtener el ID de la lista recién creada y agregar la película
                                final newList = ref.read(listsProvider).last;
                                await ref
                                    .read(allListsNotifierProvider.notifier)
                                    .addMovieToList(newList.id, widget.movieId);
                              }

                              if (mounted) {
                                Navigator.of(context).pop();

                                // Usar el contexto del scaffold padre para mostrar el snackbar
                                final scaffoldContext =
                                    Navigator.of(context).context;
                                if (scaffoldContext.mounted) {
                                  ScaffoldMessenger.of(scaffoldContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Lista "${_nameController.text.trim()}" creada'),
                                      action: SnackBarAction(
                                        label: 'Ver',
                                        onPressed: () {
                                          final newList =
                                              ref.read(listsProvider).last;
                                          GoRouter.of(scaffoldContext).push(
                                              '/my-library/lists/${newList.id}');
                                        },
                                      ),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Error al crear la lista: $e'),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                );
                              }
                            }
                          }
                        : null,
                    child: const Text('Crear'),
                  ),
                ],
              ),
            ),
          ],
        ),
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
