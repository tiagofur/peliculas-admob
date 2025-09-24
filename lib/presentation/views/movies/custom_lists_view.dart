import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/entities.dart';
import '../../../generated/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/admob/full_width_ad_widget.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/sync/minimal_sync_indicator.dart';

class CustomListsView extends ConsumerStatefulWidget {
  const CustomListsView({super.key});

  @override
  ConsumerState<CustomListsView> createState() => _CustomListsViewState();
}

class _CustomListsViewState extends ConsumerState<CustomListsView>
    with TickerProviderStateMixin {
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
    final customLists = ref.watch(customListsProvider);
    final defaultLists = ref.watch(defaultListsProvider);
    final listStats = ref.watch(listStatsProvider);
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showCreateListDialog(context),
            icon: const Icon(Icons.add),
            tooltip: 'Crear nueva lista',
          ),
        ],
      ),
      body: Column(
        children: [
          const MinimalSyncIndicator(),
          Expanded(
            child: Column(
              children: [
                // Estadísticas
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildStatsHeader(listStats, colors, textStyles),
                ),
                // Tabs
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
                          const Icon(Icons.star, size: 16),
                          const SizedBox(width: 8),
                          Text('Predefinidas (${defaultLists.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 16),
                          const SizedBox(width: 8),
                          Text('Personalizadas (${customLists.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
                // TabBarView
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDefaultListsTab(defaultLists),
                      _buildCustomListsTab(customLists, l10n),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(
      Map<String, int> stats, ColorScheme colors, TextTheme textStyles) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.list_alt,
            label: 'Listas',
            value: stats['totalLists'].toString(),
            color: colors.primary,
          ),
          _buildStatItem(
            icon: Icons.movie,
            label: 'Películas',
            value: stats['totalMovies'].toString(),
            color: colors.secondary,
          ),
          _buildStatItem(
            icon: Icons.person,
            label: 'Personalizadas',
            value: stats['customLists'].toString(),
            color: colors.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultListsTab(List<CustomList> lists) {
    if (lists.isEmpty) {
      return const Center(
        child: Text('No hay listas predefinidas disponibles'),
      );
    }

    // Calcular items totales incluyendo anuncios
    final totalItems = _calculateItemsWithAds(lists.length);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Verificar si debe mostrar anuncio
        if (_shouldShowAdAtIndex(index, lists.length)) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: NativeAdWidget(
              height: 120,
              showLabel: true,
            ),
          );
        }

        // Verificar si es el banner final
        if (_isFinalBanner(index, lists.length)) {
          return const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: FullWidthAdWidget(
              height: 100,
              showLabel: true,
              borderRadius: 12,
            ),
          );
        }

        // Calcular índice real de la lista
        final listIndex = _getRealListIndex(index, lists.length);
        final list = lists[listIndex];
        return _buildListCard(list, isDefault: true);
      },
    );
  }

  Widget _buildCustomListsTab(List<CustomList> lists, AppLocalizations l10n) {
    if (lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.playlist_add_outlined,
                size: 60, color: Theme.of(context).colorScheme.primary),
            Text(l10n.noCustomLists,
                style: TextStyle(
                    fontSize: 30,
                    color: Theme.of(context).colorScheme.primary)),
            Text(l10n.noCustomListsMessage,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: () => _showCreateListDialog(context),
                child: Text(l10n.startCreating))
          ],
        ),
      );
    }

    // Calcular items totales incluyendo anuncios
    final totalItems = _calculateItemsWithAds(lists.length);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Verificar si debe mostrar anuncio
        if (_shouldShowAdAtIndex(index, lists.length)) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: NativeAdWidget(
              height: 120,
              showLabel: true,
            ),
          );
        }

        // Verificar si es el banner final
        if (_isFinalBanner(index, lists.length)) {
          return const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: FullWidthAdWidget(
              height: 100,
              showLabel: true,
              borderRadius: 12,
            ),
          );
        }

        // Calcular índice real de la lista
        final listIndex = _getRealListIndex(index, lists.length);
        final list = lists[listIndex];
        return _buildListCard(list, isDefault: false);
      },
    );
  }

  Widget _buildListCard(CustomList list, {required bool isDefault}) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;
    final cardColor = _getColorFromString(list.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToListDetail(list),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Emoji y color
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    list.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Información de la lista
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            list.name,
                            style: textStyles.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Predefinida',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      list.description,
                      style: textStyles.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.movie,
                          size: 16,
                          color: cardColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${list.movieIds.length} películas',
                          style: TextStyle(
                            fontSize: 12,
                            color: cardColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Actualizada ${_formatDate(list.lastModifiedAt)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Botón de opciones
              if (!isDefault)
                PopupMenuButton<String>(
                  onSelected: (value) => _handleListAction(value, list),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 16),
                          SizedBox(width: 8),
                          Text('Duplicar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, size: 16),
                          SizedBox(width: 8),
                          Text('Vaciar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
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
      case 'indigo':
        return Colors.indigo;
      case 'blue':
        return Colors.blue;
      case 'teal':
        return Colors.teal;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'hoy';
    } else if (difference.inDays == 1) {
      return 'ayer';
    } else if (difference.inDays < 7) {
      return 'hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToListDetail(CustomList list) {
    if (kIsWeb) {
      context.go('/my-library/lists/${list.id}');
    } else {
      context.push('/my-library/lists/${list.id}');
    }
  }

  void _showCreateListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateListDialog(),
    );
  }

  void _handleListAction(String action, CustomList list) {
    switch (action) {
      case 'edit':
        _showEditListDialog(list);
        break;
      case 'duplicate':
        _showDuplicateListDialog(list);
        break;
      case 'clear':
        _showClearListDialog(list);
        break;
      case 'delete':
        _showDeleteListDialog(list);
        break;
    }
  }

  void _showEditListDialog(CustomList list) {
    showDialog(
      context: context,
      builder: (context) => _EditListDialog(list: list),
    );
  }

  void _showDuplicateListDialog(CustomList list) {
    showDialog(
      context: context,
      builder: (context) => _DuplicateListDialog(list: list),
    );
  }

  void _showClearListDialog(CustomList list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar Lista'),
        content: Text(
            '¿Estás seguro de que quieres eliminar todas las películas de "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // ref.read(allListsNotifierProvider.notifier).clearList(list.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lista "${list.name}" vaciada')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteListDialog(CustomList list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Lista'),
        content: Text(
            '¿Estás seguro de que quieres eliminar la lista "${list.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // ref.read(allListsNotifierProvider.notifier).deleteList(list.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lista "${list.name}" eliminada')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  /// Calcula el número total de items incluyendo anuncios
  int _calculateItemsWithAds(int listCount) {
    if (listCount <= 2) {
      return listCount; // No mostrar anuncios si hay pocas listas
    }
    int adsCount = 0;
    if (listCount >= 4) adsCount += 1; // Anuncio nativo cada 4 listas
    adsCount += 1; // Banner final
    return listCount + adsCount;
  }

  /// Determina si en esta posición se debe mostrar un anuncio nativo
  bool _shouldShowAdAtIndex(int index, int listCount) {
    if (listCount <= 2) return false;
    return listCount >= 4 && index == 4; // Mostrar anuncio después de 4 listas
  }

  /// Determina si en esta posición se debe mostrar el banner final
  bool _isFinalBanner(int index, int listCount) {
    if (listCount <= 2) return false;
    final expectedFinalIndex =
        listCount + (listCount >= 4 ? 1 : 0); // +1 si hay anuncio nativo
    return index == expectedFinalIndex;
  }

  /// Calcula el índice real de la lista considerando los anuncios insertados
  int _getRealListIndex(int displayIndex, int listCount) {
    if (listCount <= 2) return displayIndex;
    if (listCount >= 4 && displayIndex > 4) {
      return displayIndex - 1; // Restar 1 por el anuncio nativo
    }
    return displayIndex;
  }
}

class _CreateListDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<_CreateListDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedEmoji = '📝';
  String _selectedColor = 'blue';

  final List<String> _emojis = [
    '📝',
    '🍿',
    '🎬',
    '🎭',
    '🎪',
    '🎨',
    '🎵',
    '🎮',
    '💕',
    '👥',
    '🌟',
    '🔥',
    '⚡',
    '🌈',
    '🎯',
    '🚀',
  ];

  final List<String> _colors = [
    'blue',
    'red',
    'green',
    'orange',
    'purple',
    'pink',
    'teal',
    'indigo',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Nueva Lista'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la lista',
                hintText: 'Ej: Películas de terror',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Describe el propósito de esta lista',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Selector de emoji
            const Align(
              alignment: Alignment.centerLeft,
              child:
                  Text('Emoji:', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _emojis.map((emoji) {
                final isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Selector de color
            const Align(
              alignment: Alignment.centerLeft,
              child:
                  Text('Color:', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((colorName) {
                final color = _getColorFromString(colorName);
                final isSelected = colorName == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorName),
                  child: Container(
                    width: 30,
                    height: 30,
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
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () async {
                  try {
                    // Usar el provider correcto para la creación de listas
                    final repository =
                        await ref.read(customListsRepositoryProvider.future);

                    final now = DateTime.now();
                    const uuid = Uuid();
                    final newId = uuid.v4();

                    final newList = CustomList(
                      id: newId,
                      name: _nameController.text.trim(),
                      description: _descriptionController.text.trim(),
                      emoji: _selectedEmoji,
                      movieIds: [],
                      createdAt: now,
                      lastModifiedAt: now,
                      isDefault: false,
                      color: _selectedColor,
                    );

                    // Crear la lista usando el repositorio directamente
                    await repository.createList(newList);

                    // Invalidar el provider para que se recargue
                    ref.invalidate(allListsProvider);

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Lista "${_nameController.text.trim()}" creada')),
                    );
                  } catch (e) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error al crear la lista: $e'),
                          backgroundColor: Theme.of(context).colorScheme.error),
                    );
                  }
                },
          child: const Text('Crear'),
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
      case 'indigo':
        return Colors.indigo;
      case 'blue':
        return Colors.blue;
      case 'teal':
        return Colors.teal;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

class _EditListDialog extends ConsumerStatefulWidget {
  const _EditListDialog({required this.list});

  final CustomList list;

  @override
  ConsumerState<_EditListDialog> createState() => _EditListDialogState();
}

class _EditListDialogState extends ConsumerState<_EditListDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _selectedEmoji;
  late String _selectedColor;

  final List<String> _emojis = [
    '📝',
    '🍿',
    '🎬',
    '🎭',
    '🎪',
    '🎨',
    '🎵',
    '🎮',
    '💕',
    '👥',
    '🌟',
    '🔥',
    '⚡',
    '🌈',
    '🎯',
    '🚀',
  ];

  final List<String> _colors = [
    'blue',
    'red',
    'green',
    'orange',
    'purple',
    'pink',
    'teal',
    'indigo',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list.name);
    _descriptionController =
        TextEditingController(text: widget.list.description);
    _selectedEmoji = widget.list.emoji;
    _selectedColor = widget.list.color;
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
      title: const Text('Editar Lista'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la lista',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Selector de emoji
            const Align(
              alignment: Alignment.centerLeft,
              child:
                  Text('Emoji:', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _emojis.map((emoji) {
                final isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Selector de color
            const Align(
              alignment: Alignment.centerLeft,
              child:
                  Text('Color:', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((colorName) {
                final color = _getColorFromString(colorName);
                final isSelected = colorName == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorName),
                  child: Container(
                    width: 30,
                    height: 30,
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
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  // ref.read(allListsNotifierProvider.notifier).updateList(
                  //      widget.list.id,
                  //      name: _nameController.text.trim(),
                  //      description: _descriptionController.text.trim(),
                  //      emoji: _selectedEmoji,
                  //      color: _selectedColor,
                  //    );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Lista "${_nameController.text.trim()}" actualizada')),
                  );
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
      case 'indigo':
        return Colors.indigo;
      case 'blue':
        return Colors.blue;
      case 'teal':
        return Colors.teal;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

class _DuplicateListDialog extends ConsumerStatefulWidget {
  const _DuplicateListDialog({required this.list});

  final CustomList list;

  @override
  ConsumerState<_DuplicateListDialog> createState() =>
      _DuplicateListDialogState();
}

class _DuplicateListDialogState extends ConsumerState<_DuplicateListDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: '${widget.list.name} (Copia)');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Duplicar Lista'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              'Se creará una copia de "${widget.list.name}" con todas sus películas.'),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la nueva lista',
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  // ref.read(allListsNotifierProvider.notifier).duplicateList(
                  //      widget.list.id,
                  //      _nameController.text.trim(),
                  //    );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Lista "${_nameController.text.trim()}" creada')),
                  );
                },
          child: const Text('Duplicar'),
        ),
      ],
    );
  }
}
