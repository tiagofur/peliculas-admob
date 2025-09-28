// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/entities.dart';
import '../../providers/storage/direct_custom_lists_provider.dart';

class MovieListsWidget extends ConsumerWidget {
  const MovieListsWidget({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsState = ref.watch(directCustomListsProvider);
    final notifier = ref.read(directCustomListsProvider.notifier);

    final customLists = [
      ...listsState.getAllListsWithMovies().where((list) => !list.isDefault),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final movieListIds = customLists
        .where((list) => list.movieIds.contains(movie.id))
        .map((list) => list.id)
        .toSet();

    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Mis listas',
              style: textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showCreateListDialog(context),
              icon: const Icon(Icons.add),
              tooltip: 'Crear lista',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (listsState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ErrorBanner(
              message: listsState.errorMessage!,
              onRetry: notifier.refresh,
            ),
          ),
        if (listsState.isLoading && customLists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (customLists.isEmpty)
          _buildEmptyState(context, colors, textStyles)
        else
          _buildListsGrid(
            context: context,
            ref: ref,
            lists: customLists,
            movieListIds: movieListIds,
            colors: colors,
            textStyles: textStyles,
          ),
      ],
    );
  }

  Widget _buildListsGrid({
    required BuildContext context,
    required WidgetRef ref,
    required List<CustomList> lists,
    required Set<String> movieListIds,
    required ColorScheme colors,
    required TextTheme textStyles,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        final list = lists[index];
        final isInList = movieListIds.contains(list.id);
        return _buildListCard(
          context: context,
          ref: ref,
          list: list,
          isInList: isInList,
          colors: colors,
          textStyles: textStyles,
        );
      },
    );
  }

  Widget _buildEmptyState(
      BuildContext context, ColorScheme colors, TextTheme textStyles) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            'Crea tu primera lista para organizar tus películas favoritas',
            style: textStyles.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _showCreateListDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Crear mi primera lista'),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard({
    required BuildContext context,
    required WidgetRef ref,
    required CustomList list,
    required bool isInList,
    required ColorScheme colors,
    required TextTheme textStyles,
  }) {
    final listColor = _getColorFromString(list.color);

    return GestureDetector(
      onTap: () => _toggleMovieInList(context, ref, list, isInList),
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
            Text(
              '${list.movieIds.length} películas',
              style: textStyles.bodySmall?.copyWith(
                color: isInList
                    ? listColor.withValues(alpha: 0.8)
                    : colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMovieInList(
    BuildContext context,
    WidgetRef ref,
    CustomList list,
    bool isInList,
  ) {
    if (isInList) {
      ref
          .read(directCustomListsProvider.notifier)
          .removeMovieFromList(list.id, movie.id);

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
          .read(directCustomListsProvider.notifier)
          .addMovieToList(list.id, movie.id);

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
              Navigator.of(context).pushNamed(
                '/list-detail',
                arguments: list.id,
              );
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
      builder: (dialogContext) => _CreateListDialog(movieId: movie.id),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colors.onErrorContainer.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: textStyles.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onRetry(),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
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
    'blue_grey',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();

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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
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
                            final navigator = Navigator.of(context);
                            final scaffoldContext = navigator.context;
                            final messenger =
                                ScaffoldMessenger.of(scaffoldContext);
                            final colorScheme = Theme.of(context).colorScheme;
                            final name = _nameController.text.trim();
                            final description =
                                _descriptionController.text.trim();

                            try {
                              final notifier =
                                  ref.read(directCustomListsProvider.notifier);

                              final newListId = await notifier.createList(
                                name: name,
                                description: description,
                                emoji: _selectedEmoji,
                                color: _selectedColor,
                              );

                              if (newListId == null) {
                                throw Exception('No se pudo crear la lista');
                              }

                              if (_addCurrentMovie) {
                                await notifier.addMovieToList(
                                  newListId,
                                  widget.movieId,
                                );
                              }

                              if (!mounted || !scaffoldContext.mounted) {
                                return;
                              }

                              navigator.pop();

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Lista "$name" creada'),
                                  action: SnackBarAction(
                                    label: 'Ver',
                                    onPressed: () {
                                      GoRouter.of(scaffoldContext)
                                          .push('/lists/$newListId');
                                    },
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted || !scaffoldContext.mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error al crear la lista: $e'),
                                  backgroundColor: colorScheme.error,
                                ),
                              );
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
