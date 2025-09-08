import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/entity_sync_manager.dart';
import '../../../domain/entities/syncable_custom_list.dart';
import '../../../domain/entities/syncable_entity.dart';
import '../../../domain/entities/syncable_watched_movie.dart';
import '../../../domain/entities/syncable_watchlist_item.dart';

/// Widget que muestra el historial de resoluciones de conflictos
class ConflictHistoryList extends ConsumerStatefulWidget {
  const ConflictHistoryList({
    super.key,
    this.maxItems = 50,
    this.showFilters = true,
    this.compact = false,
    this.onConflictTap,
    this.onClearHistory,
  });

  final int maxItems;
  final bool showFilters;
  final bool compact;
  final Function(ConflictInfo)? onConflictTap;
  final VoidCallback? onClearHistory;

  @override
  ConsumerState<ConflictHistoryList> createState() =>
      _ConflictHistoryListState();
}

class _ConflictHistoryListState extends ConsumerState<ConflictHistoryList> {
  List<ConflictInfo> _allConflicts = [];
  List<ConflictInfo> _filteredConflicts = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filtros
  ConflictType? _selectedType;
  ConflictStrategy? _selectedStrategy;
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  bool _showResolvedOnly = false;
  bool _showUnresolvedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadConflictHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (widget.showFilters) ...[
            const Divider(height: 1),
            _buildFiltersSection(context),
          ],
          const Divider(height: 1),
          Expanded(
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      child: Row(
        children: [
          Icon(
            Icons.history,
            size: widget.compact ? 18 : 20,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historial de Conflictos',
                  style: (widget.compact
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                if (!widget.compact && _filteredConflicts.isNotEmpty)
                  Text(
                    '${_filteredConflicts.length} de ${_allConflicts.length} conflictos',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          _buildHeaderActions(context),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _loadConflictHistory,
          icon: Icon(
            Icons.refresh,
            size: widget.compact ? 18 : 20,
          ),
          tooltip: 'Actualizar',
        ),
        if (_allConflicts.isNotEmpty)
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _showClearHistoryDialog(context);
                  break;
                case 'export':
                  _exportHistory();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 16),
                    SizedBox(width: 8),
                    Text('Exportar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 16),
                    SizedBox(width: 8),
                    Text('Limpiar historial'),
                  ],
                ),
              ),
            ],
            child: Icon(
              Icons.more_vert,
              size: widget.compact ? 18 : 20,
            ),
          ),
      ],
    );
  }

  Widget _buildFiltersSection(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      title: Text(
        'Filtros',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: const Icon(Icons.filter_list, size: 20),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSearchField(context),
              const SizedBox(height: 12),
              _buildFilterChips(context),
              const SizedBox(height: 12),
              _buildDateRangeFilter(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Buscar por entidad, tipo o estrategia...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
        _applyFilters();
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        // Filtro por tipo de conflicto
        FilterChip(
          label: Text('Tipo: ${_selectedType?.name ?? "Todos"}'),
          selected: _selectedType != null,
          onSelected: (selected) {
            _showTypeFilterDialog(context);
          },
        ),
        // Filtro por estrategia
        FilterChip(
          label: Text('Estrategia: ${_selectedStrategy?.name ?? "Todas"}'),
          selected: _selectedStrategy != null,
          onSelected: (selected) {
            _showStrategyFilterDialog(context);
          },
        ),
        // Filtro por estado de resolución
        FilterChip(
          label: const Text('Solo resueltos'),
          selected: _showResolvedOnly,
          onSelected: (selected) {
            setState(() {
              _showResolvedOnly = selected;
              if (selected) _showUnresolvedOnly = false;
            });
            _applyFilters();
          },
        ),
        FilterChip(
          label: const Text('Solo sin resolver'),
          selected: _showUnresolvedOnly,
          onSelected: (selected) {
            setState(() {
              _showUnresolvedOnly = selected;
              if (selected) _showResolvedOnly = false;
            });
            _applyFilters();
          },
        ),
        // Botón para limpiar filtros
        if (_hasActiveFilters())
          ActionChip(
            label: const Text('Limpiar filtros'),
            onPressed: _clearFilters,
            avatar: const Icon(Icons.clear, size: 16),
          ),
      ],
    );
  }

  Widget _buildDateRangeFilter(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.date_range,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _dateRange != null
                ? 'Desde ${_formatDate(_dateRange!.start)} hasta ${_formatDate(_dateRange!.end)}'
                : 'Todas las fechas',
            style: theme.textTheme.bodySmall,
          ),
        ),
        TextButton(
          onPressed: () => _showDateRangePicker(context),
          child: Text(_dateRange != null ? 'Cambiar' : 'Seleccionar'),
        ),
        if (_dateRange != null)
          IconButton(
            onPressed: () {
              setState(() {
                _dateRange = null;
              });
              _applyFilters();
            },
            icon: const Icon(Icons.clear, size: 16),
            tooltip: 'Limpiar filtro de fecha',
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingIndicator(context);
    }

    if (_errorMessage != null) {
      return _buildErrorIndicator(context);
    }

    if (_filteredConflicts.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildConflictsList(context);
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar historial',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadConflictHistory,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _hasActiveFilters() ? Icons.filter_list_off : Icons.history,
              size: 48,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _hasActiveFilters()
                  ? 'No hay conflictos que coincidan'
                  : 'No hay conflictos registrados',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters()
                  ? 'Intenta ajustar los filtros para ver más resultados'
                  : 'Los conflictos de sincronización aparecerán aquí cuando ocurran',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters()) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConflictsList(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(widget.compact ? 8 : 12),
      itemCount: _filteredConflicts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final conflict = _filteredConflicts[index];
        return _buildConflictItem(context, conflict);
      },
    );
  }

  Widget _buildConflictItem(BuildContext context, ConflictInfo conflict) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isResolved = conflict.resolution != null;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerHighest,
      child: InkWell(
        onTap: () => widget.onConflictTap?.call(conflict),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConflictHeader(context, conflict, isResolved),
              const SizedBox(height: 8),
              _buildConflictDetails(context, conflict),
              if (isResolved) ...[
                const SizedBox(height: 8),
                _buildResolutionDetails(context, conflict.resolution!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConflictHeader(
      BuildContext context, ConflictInfo conflict, bool isResolved) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        _buildConflictTypeIcon(context, conflict.conflictType),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getEntityDisplayName(conflict.localEntity),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _getConflictTypeDescription(conflict.conflictType),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        _buildStatusChip(context, isResolved, conflict.resolution?.strategy),
      ],
    );
  }

  Widget _buildConflictTypeIcon(BuildContext context, ConflictType type) {
    final colors = Theme.of(context).colorScheme;

    IconData icon;
    Color color;

    switch (type) {
      case ConflictType.concurrentModification:
        icon = Icons.edit;
        color = colors.primary;
        break;
      case ConflictType.deleteVsModify:
        icon = Icons.delete_forever;
        color = colors.error;
        break;
      case ConflictType.duplicateCreation:
        icon = Icons.content_copy;
        color = colors.secondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        icon,
        size: 16,
        color: color,
      ),
    );
  }

  Widget _buildStatusChip(
      BuildContext context, bool isResolved, ConflictStrategy? strategy) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (isResolved) {
      return Chip(
        avatar: Icon(
          Icons.check_circle,
          size: 14,
          color: colors.tertiary,
        ),
        label: Text(
          _getStrategyLabel(strategy!),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.tertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: colors.tertiaryContainer.withValues(alpha: 0.3),
        side: BorderSide(color: colors.tertiary.withValues(alpha: 0.3)),
      );
    } else {
      return Chip(
        avatar: Icon(
          Icons.pending,
          size: 14,
          color: colors.error,
        ),
        label: Text(
          'Pendiente',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.error,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: colors.errorContainer.withValues(alpha: 0.3),
        side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
      );
    }
  }

  Widget _buildConflictDetails(BuildContext context, ConflictInfo conflict) {
    Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Entidad', conflict.localEntity.entityType),
        _buildDetailRow('Detectado', _formatDateTime(conflict.detectedAt)),
        if (conflict.metadata != null && conflict.metadata!.isNotEmpty)
          _buildDetailRow('Versiones',
              '${conflict.metadata!['local_version']} vs ${conflict.metadata!['remote_version']}'),
      ],
    );
  }

  Widget _buildResolutionDetails(
      BuildContext context, ConflictResolution resolution) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: colors.tertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'Resuelto',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildDetailRow('Estrategia', _getStrategyLabel(resolution.strategy)),
          _buildDetailRow(
              'Resuelto el', _formatDateTime(resolution.resolvedAt)),
          if (resolution.reason != null)
            _buildDetailRow('Razón', resolution.reason!),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadConflictHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simular carga de historial - en implementación real usaría un servicio
      await Future.delayed(const Duration(milliseconds: 500));

      // Datos de ejemplo
      final conflicts = _generateSampleConflicts();

      if (mounted) {
        setState(() {
          _allConflicts = conflicts;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredConflicts = _allConflicts
          .where((conflict) {
            // Filtro por tipo
            if (_selectedType != null &&
                conflict.conflictType != _selectedType) {
              return false;
            }

            // Filtro por estrategia
            if (_selectedStrategy != null &&
                conflict.resolution?.strategy != _selectedStrategy) {
              return false;
            }

            // Filtro por estado de resolución
            if (_showResolvedOnly && conflict.resolution == null) {
              return false;
            }
            if (_showUnresolvedOnly && conflict.resolution != null) {
              return false;
            }

            // Filtro por rango de fechas
            if (_dateRange != null) {
              final date = conflict.detectedAt;
              if (date.isBefore(_dateRange!.start) ||
                  date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
                return false;
              }
            }

            // Filtro por búsqueda de texto
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final entityName =
                  _getEntityDisplayName(conflict.localEntity).toLowerCase();
              final entityType = conflict.localEntity.entityType.toLowerCase();
              final conflictType = conflict.conflictType.name.toLowerCase();
              final strategy =
                  conflict.resolution?.strategy.name.toLowerCase() ?? '';

              if (!entityName.contains(query) &&
                  !entityType.contains(query) &&
                  !conflictType.contains(query) &&
                  !strategy.contains(query)) {
                return false;
              }
            }

            return true;
          })
          .take(widget.maxItems)
          .toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedStrategy = null;
      _searchQuery = '';
      _dateRange = null;
      _showResolvedOnly = false;
      _showUnresolvedOnly = false;
    });
    _applyFilters();
  }

  bool _hasActiveFilters() {
    return _selectedType != null ||
        _selectedStrategy != null ||
        _searchQuery.isNotEmpty ||
        _dateRange != null ||
        _showResolvedOnly ||
        _showUnresolvedOnly;
  }

  void _showTypeFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por Tipo de Conflicto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<ConflictType?>(
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() => _selectedType = value);
                Navigator.pop(context);
                _applyFilters();
              },
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Todos'),
                    leading: const Radio<ConflictType?>(
                      value: null,
                    ),
                    onTap: () {
                      setState(() => _selectedType = null);
                      Navigator.pop(context);
                      _applyFilters();
                    },
                  ),
                  ...ConflictType.values.map((type) => ListTile(
                        title: Text(_getConflictTypeDescription(type)),
                        leading: Radio<ConflictType?>(
                          value: type,
                        ),
                        onTap: () {
                          setState(() => _selectedType = type);
                          Navigator.pop(context);
                          _applyFilters();
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStrategyFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por Estrategia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<ConflictStrategy?>(
              groupValue: _selectedStrategy,
              onChanged: (value) {
                setState(() => _selectedStrategy = value);
                Navigator.pop(context);
                _applyFilters();
              },
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Todas'),
                    leading: const Radio<ConflictStrategy?>(
                      value: null,
                    ),
                    onTap: () {
                      setState(() => _selectedStrategy = null);
                      Navigator.pop(context);
                      _applyFilters();
                    },
                  ),
                  ...ConflictStrategy.values.map((strategy) => ListTile(
                        title: Text(_getStrategyLabel(strategy)),
                        leading: Radio<ConflictStrategy?>(
                          value: strategy,
                        ),
                        onTap: () {
                          setState(() => _selectedStrategy = strategy);
                          Navigator.pop(context);
                          _applyFilters();
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _applyFilters();
    }
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Historial'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar todo el historial de conflictos? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _clearHistory();
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  void _clearHistory() {
    setState(() {
      _allConflicts.clear();
      _filteredConflicts.clear();
    });
    widget.onClearHistory?.call();
  }

  void _exportHistory() {
    // Implementar exportación del historial
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de exportación no implementada'),
      ),
    );
  }

  List<ConflictInfo> _generateSampleConflicts() {
    // Generar datos de ejemplo para demostración
    return [];
  }

  String _getEntityDisplayName(SyncableEntity entity) {
    if (entity is SyncableWatchedMovie) {
      return entity.movieTitle;
    } else if (entity is SyncableWatchlistItem) {
      return entity.movieTitle;
    } else if (entity is SyncableCustomList) {
      return entity.name;
    }
    return entity.id;
  }

  String _getConflictTypeDescription(ConflictType type) {
    switch (type) {
      case ConflictType.concurrentModification:
        return 'Modificación Concurrente';
      case ConflictType.deleteVsModify:
        return 'Eliminación vs Modificación';
      case ConflictType.duplicateCreation:
        return 'Creación Duplicada';
    }
  }

  String _getStrategyLabel(ConflictStrategy strategy) {
    switch (strategy) {
      case ConflictStrategy.localWins:
        return 'Local Gana';
      case ConflictStrategy.remoteWins:
        return 'Remoto Gana';
      case ConflictStrategy.merge:
        return 'Fusión';
      case ConflictStrategy.userChoice:
        return 'Elección Manual';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
