import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/custom_list.dart';
import '../../../generated/app_localizations.dart';
import '../../providers/storage/direct_custom_lists_provider.dart';
import '../../widgets/admob/full_width_ad_widget.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/sync/minimal_sync_indicator.dart';

class CustomListsView extends ConsumerStatefulWidget {
  const CustomListsView({super.key});

  @override
  ConsumerState<CustomListsView> createState() => _CustomListsViewState();
}

class _CustomListsViewState extends ConsumerState<CustomListsView> {
  static const List<_ListSuggestion> _suggestions = [
    _ListSuggestion(
      name: 'Noche de Lluvia',
      description: 'Películas acogedoras para una noche tranquila',
      emoji: '🌧️',
      color: Colors.indigo,
      colorName: 'indigo',
    ),
    _ListSuggestion(
      name: 'En Familia',
      description: 'Historias para todas las edades',
      emoji: '👨‍👩‍👧‍👦',
      color: Colors.orange,
      colorName: 'orange',
    ),
    _ListSuggestion(
      name: 'Maratón de Fin de Semana',
      description: 'Sagas y trilogías para ver sin parar',
      emoji: '🎬',
      color: Colors.purple,
      colorName: 'purple',
    ),
    _ListSuggestion(
      name: 'Noche Romántica',
      description: 'Películas ideales para compartir en pareja',
      emoji: '💕',
      color: Colors.pink,
      colorName: 'pink',
    ),
    _ListSuggestion(
      name: 'Acción Pura',
      description: 'Adrenalina y explosiones garantizadas',
      emoji: '🔥',
      color: Colors.red,
      colorName: 'red',
    ),
    _ListSuggestion(
      name: 'Joyas Ocultas',
      description: 'Películas poco conocidas que vale la pena descubrir',
      emoji: '💎',
      color: Colors.teal,
      colorName: 'teal',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final listsState = ref.watch(directCustomListsProvider);
    final notifier = ref.read(directCustomListsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    final customLists = [
      ...listsState.getAllListsWithMovies().where((list) => !list.isDefault),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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
            child: RefreshIndicator(
              onRefresh: () async => notifier.refresh(),
              child: _buildListsBody(
                context: context,
                listsState: listsState,
                customLists: customLists,
                l10n: l10n,
                notifier: notifier,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListsBody({
    required BuildContext context,
    required CustomListsState listsState,
    required List<CustomList> customLists,
    required AppLocalizations l10n,
    required DirectCustomListsNotifier notifier,
  }) {
    if (listsState.isLoading && customLists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 120),
        children: const [
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (listsState.errorMessage != null && customLists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _buildErrorState(
            context,
            listsState.errorMessage!,
            notifier.refresh,
          ),
        ],
      );
    }

    final sections = _buildContentSections(
      context,
      customLists,
      l10n,
    );

    final children = <Widget>[];

    if (listsState.errorMessage != null) {
      children.add(
        _buildInlineErrorBanner(
          context,
          listsState.errorMessage!,
          notifier.refresh,
        ),
      );
    }

    if (listsState.isLoading && customLists.isNotEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      );
    }

    children.addAll(sections);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: children,
    );
  }

  Widget _buildStatsHeader({
    required int totalLists,
    required int activeLists,
    required int totalMovies,
    required ColorScheme colors,
    required TextTheme textStyles,
  }) {
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
            value: totalLists.toString(),
            color: colors.primary,
          ),
          _buildStatItem(
            icon: Icons.movie,
            label: 'Películas',
            value: totalMovies.toString(),
            color: colors.secondary,
          ),
          _buildStatItem(
            icon: Icons.person,
            label: 'Activas',
            value: activeLists.toString(),
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

  Widget _buildErrorState(
    BuildContext context,
    String message,
    Future<void> Function() onRetry,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 12),
            Text(
              'No pudimos cargar tus listas',
              style: textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textStyles.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineErrorBanner(
    BuildContext context,
    String message,
    Future<void> Function() onRetry,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: textStyles.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w600,
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

  List<Widget> _buildContentSections(
    BuildContext context,
    List<CustomList> lists,
    AppLocalizations l10n,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;
    final totalMovies =
        lists.fold<int>(0, (sum, list) => sum + list.movieIds.length);
    final activeLists = lists.where((list) => list.movieIds.isNotEmpty).length;

    final sections = <Widget>[
      _buildStatsHeader(
        totalLists: lists.length,
        activeLists: activeLists,
        totalMovies: totalMovies,
        colors: colors,
        textStyles: textStyles,
      ),
      const SizedBox(height: 24),
      _buildSuggestionsSection(context),
      const SizedBox(height: 24),
    ];

    if (lists.isEmpty) {
      sections.add(_buildEmptyState(context, l10n));
    } else {
      sections.addAll(_buildCustomListsSection(context, lists));
    }

    return sections;
  }

  Widget _buildSuggestionsSection(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ideas rápidas',
          style: textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((suggestion) {
            return ActionChip(
              avatar:
                  Text(suggestion.emoji, style: const TextStyle(fontSize: 18)),
              label: Text(suggestion.name),
              backgroundColor: suggestion.color.withValues(alpha: 0.15),
              onPressed: () => _createListFromSuggestion(context, suggestion),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _createListFromSuggestion(
    BuildContext context,
    _ListSuggestion suggestion,
  ) {
    return _showCreateListDialog(
      context,
      suggestion: suggestion,
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 32),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add_outlined, size: 56, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              l10n.noCustomLists,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noCustomListsMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _showCreateListDialog(context),
              child: Text(l10n.startCreating),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCustomListsSection(
      BuildContext context, List<CustomList> lists) {
    final widgets = <Widget>[];
    final totalItems = _calculateItemsWithAds(lists.length);

    for (var index = 0; index < totalItems; index++) {
      if (_shouldShowAdAtIndex(index, lists.length)) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: NativeAdWidget(
              height: 120,
              showLabel: true,
            ),
          ),
        );
        continue;
      }

      if (_isFinalBanner(index, lists.length)) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: FullWidthAdWidget(
              height: 100,
              showLabel: true,
              borderRadius: 12,
            ),
          ),
        );
        continue;
      }

      final listIndex = _getRealListIndex(index, lists.length);
      final list = lists[listIndex];
      widgets.add(_buildListCard(list));
    }

    return widgets;
  }

  // Legacy tab methods removed in Option A implementation.

  Widget _buildListCard(CustomList list) {
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
              // Botón de opciones (todas las listas son personalizadas)
              PopupMenuButton<String>(
                onSelected: (value) => _handleListAction(value, list),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 16),
                        SizedBox(width: 8),
                        Text('Duplicar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, size: 16),
                        SizedBox(width: 8),
                        Text('Vaciar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
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

  Future<void> _showCreateListDialog(
    BuildContext context, {
    _ListSuggestion? suggestion,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => _CreateListDialog(suggestion: suggestion),
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
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final colorScheme = Theme.of(context).colorScheme;

              try {
                await ref
                    .read(directCustomListsProvider.notifier)
                    .clearList(list.id);

                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Lista "${list.name}" vaciada')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al vaciar la lista: $e'),
                    backgroundColor: colorScheme.error,
                  ),
                );
              }
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
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final colorScheme = Theme.of(context).colorScheme;

              try {
                await ref
                    .read(directCustomListsProvider.notifier)
                    .deleteList(list.id);

                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Lista "${list.name}" eliminada')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar la lista: $e'),
                    backgroundColor: colorScheme.error,
                  ),
                );
              }
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
  const _CreateListDialog({this.suggestion});

  final _ListSuggestion? suggestion;

  @override
  ConsumerState<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends ConsumerState<_CreateListDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
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
    final suggestion = widget.suggestion;
    _nameController = TextEditingController(text: suggestion?.name ?? '');
    _descriptionController =
        TextEditingController(text: suggestion?.description ?? '');
    _selectedEmoji = suggestion?.emoji ?? '📝';
    _selectedColor = suggestion?.colorName ?? 'blue';
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
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Describe el propósito de esta lista',
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
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
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final colorScheme = Theme.of(context).colorScheme;
                  final name = _nameController.text.trim();
                  final description = _descriptionController.text.trim();

                  try {
                    await ref
                        .read(directCustomListsProvider.notifier)
                        .createList(
                          name: name,
                          description: description,
                          emoji: _selectedEmoji,
                          color: _selectedColor,
                        );

                    if (!mounted) return;
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Lista "$name" creada')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error al crear la lista: $e'),
                        backgroundColor: colorScheme.error,
                      ),
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
              : () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final colorScheme = Theme.of(context).colorScheme;
                  final name = _nameController.text.trim();
                  final description = _descriptionController.text.trim();

                  try {
                    await ref
                        .read(directCustomListsProvider.notifier)
                        .updateList(
                          widget.list.id,
                          name: name,
                          description: description,
                          emoji: _selectedEmoji,
                          color: _selectedColor,
                        );

                    if (!mounted) return;
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Lista "$name" actualizada'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error al actualizar la lista: $e'),
                        backgroundColor: colorScheme.error,
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
              : () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final colorScheme = Theme.of(context).colorScheme;
                  final newName = _nameController.text.trim();
                  final notifier = ref.read(directCustomListsProvider.notifier);
                  final sourceList = notifier.getListWithMovies(widget.list.id);

                  if (sourceList == null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content:
                            const Text('No pudimos obtener la lista original'),
                        backgroundColor: colorScheme.error,
                      ),
                    );
                    return;
                  }

                  try {
                    final newListId = await notifier.createList(
                      name: newName,
                      description: sourceList.description,
                      emoji: sourceList.emoji,
                      color: sourceList.color,
                    );

                    if (newListId == null) {
                      throw Exception('No se pudo crear la lista duplicada');
                    }

                    for (final movieId in sourceList.movieIds) {
                      await notifier.addMovieToList(newListId, movieId);
                    }

                    if (!mounted) return;
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Lista "$newName" creada'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error al duplicar la lista: $e'),
                        backgroundColor: colorScheme.error,
                      ),
                    );
                  }
                },
          child: const Text('Duplicar'),
        ),
      ],
    );
  }
}

class _ListSuggestion {
  const _ListSuggestion({
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.colorName,
  });

  final String name;
  final String description;
  final String emoji;
  final Color color;
  final String colorName;
}
