import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/sync_integration_provider.dart' as integration;

/// Entrada del historial de sincronización
class SyncHistoryEntry {

  const SyncHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.status,
    this.entityType,
    this.entityId,
    this.description,
    this.errorMessage,
    this.duration,
    this.itemsProcessed,
    this.itemsSuccess,
    this.itemsError,
  });
  final String id;
  final DateTime timestamp;
  final SyncOperationType type;
  final SyncOperationStatus status;
  final String? entityType;
  final String? entityId;
  final String? description;
  final String? errorMessage;
  final Duration? duration;
  final int? itemsProcessed;
  final int? itemsSuccess;
  final int? itemsError;
}

/// Tipos de operación de sincronización
enum SyncOperationType {
  fullSync('Sincronización Completa'),
  incrementalSync('Sincronización Incremental'),
  upload('Subida'),
  download('Descarga'),
  conflictResolution('Resolución de Conflicto'),
  cleanup('Limpieza'),
  initialization('Inicialización');

  const SyncOperationType(this.displayName);
  final String displayName;
}

/// Estados de operación de sincronización
enum SyncOperationStatus {
  success('Exitoso'),
  error('Error'),
  warning('Advertencia'),
  cancelled('Cancelado'),
  inProgress('En Progreso');

  const SyncOperationStatus(this.displayName);
  final String displayName;

  Color getColor(BuildContext context) {
    switch (this) {
      case SyncOperationStatus.success:
        return Colors.green;
      case SyncOperationStatus.error:
        return Theme.of(context).colorScheme.error;
      case SyncOperationStatus.warning:
        return Colors.orange;
      case SyncOperationStatus.cancelled:
        return Colors.grey;
      case SyncOperationStatus.inProgress:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData getIcon() {
    switch (this) {
      case SyncOperationStatus.success:
        return Icons.check_circle;
      case SyncOperationStatus.error:
        return Icons.error;
      case SyncOperationStatus.warning:
        return Icons.warning;
      case SyncOperationStatus.cancelled:
        return Icons.cancel;
      case SyncOperationStatus.inProgress:
        return Icons.sync;
    }
  }
}

/// Provider para el historial de sincronización
final syncHistoryProvider = StateNotifierProvider<SyncHistoryNotifier, List<SyncHistoryEntry>>((ref) {
  return SyncHistoryNotifier();
});

class SyncHistoryNotifier extends StateNotifier<List<SyncHistoryEntry>> {
  SyncHistoryNotifier() : super(_generateMockHistory());

  void addEntry(SyncHistoryEntry entry) {
    state = [entry, ...state];
  }

  void clearHistory() {
    state = [];
  }

  void removeEntry(String id) {
    state = state.where((entry) => entry.id != id).toList();
  }

  List<SyncHistoryEntry> getEntriesByType(SyncOperationType type) {
    return state.where((entry) => entry.type == type).toList();
  }

  List<SyncHistoryEntry> getEntriesByStatus(SyncOperationStatus status) {
    return state.where((entry) => entry.status == status).toList();
  }

  List<SyncHistoryEntry> getEntriesInDateRange(DateTime start, DateTime end) {
    return state.where((entry) => 
        entry.timestamp.isAfter(start) && entry.timestamp.isBefore(end)
    ).toList();
  }

  static List<SyncHistoryEntry> _generateMockHistory() {
    final now = DateTime.now();
    return [
      SyncHistoryEntry(
        id: '1',
        timestamp: now.subtract(const Duration(minutes: 5)),
        type: SyncOperationType.incrementalSync,
        status: SyncOperationStatus.success,
        description: 'Sincronización automática completada',
        duration: const Duration(seconds: 12),
        itemsProcessed: 15,
        itemsSuccess: 15,
        itemsError: 0,
      ),
      SyncHistoryEntry(
        id: '2',
        timestamp: now.subtract(const Duration(hours: 2)),
        type: SyncOperationType.upload,
        status: SyncOperationStatus.success,
        entityType: 'Película',
        entityId: 'movie_123',
        description: 'Película "Avatar" subida exitosamente',
        duration: const Duration(seconds: 8),
      ),
      SyncHistoryEntry(
        id: '3',
        timestamp: now.subtract(const Duration(hours: 4)),
        type: SyncOperationType.conflictResolution,
        status: SyncOperationStatus.warning,
        entityType: 'Película',
        entityId: 'movie_456',
        description: 'Conflicto resuelto manualmente',
        duration: const Duration(minutes: 2),
      ),
      SyncHistoryEntry(
        id: '4',
        timestamp: now.subtract(const Duration(days: 1)),
        type: SyncOperationType.fullSync,
        status: SyncOperationStatus.error,
        description: 'Error de conexión durante sincronización completa',
        errorMessage: 'No se pudo conectar al servidor',
        duration: const Duration(minutes: 1),
        itemsProcessed: 50,
        itemsSuccess: 25,
        itemsError: 25,
      ),
      SyncHistoryEntry(
        id: '5',
        timestamp: now.subtract(const Duration(days: 2)),
        type: SyncOperationType.initialization,
        status: SyncOperationStatus.success,
        description: 'Inicialización del sistema de sincronización',
        duration: const Duration(seconds: 30),
      ),
    ];
  }
}

/// Widget principal del visor de historial
class SyncHistoryViewer extends ConsumerStatefulWidget {
  const SyncHistoryViewer({super.key});

  @override
  ConsumerState<SyncHistoryViewer> createState() => _SyncHistoryViewerState();
}

/// Widget simple del visor de historial para integración
class SimpleSyncHistoryViewer extends ConsumerWidget {
  const SimpleSyncHistoryViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(integration.syncIntegrationProvider);
    final syncHistory = syncState.syncHistory;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historial de Sincronización',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref.read(integration.syncIntegrationProvider.notifier).triggerManualSync();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: syncHistory.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay historial de sincronización disponible',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: syncHistory.length,
                      itemBuilder: (context, index) {
                        final entry = syncHistory[index];
                        return _buildHistoryEntry(context, entry);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(BuildContext context, SyncHistoryEntry entry) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.status.getColor(context).withValues(alpha: 0.1),
          child: Icon(
            entry.status.getIcon(),
            color: entry.status.getColor(context),
            size: 20,
          ),
        ),
        title: Text(
          entry.type.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description != null)
              Text(
                entry.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              dateFormat.format(entry.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: entry.status.getColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            entry.status.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: entry.status.getColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncHistoryViewerState extends ConsumerState<SyncHistoryViewer> {
  SyncOperationType? _filterType;
  SyncOperationStatus? _filterStatus;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(syncHistoryProvider);
    final filteredHistory = _applyFilters(history);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Sincronización'),
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: Badge(
              isLabelVisible: _hasActiveFilters(),
              child: const Icon(Icons.filter_list),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Exportar Historial'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Limpiar Historial'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar en historial...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Estadísticas rápidas
          _buildQuickStats(history),
          
          // Lista de historial
          Expanded(
            child: filteredHistory.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      return SyncHistoryEntryTile(
                        entry: filteredHistory[index],
                        onTap: () => _showEntryDetails(filteredHistory[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(List<SyncHistoryEntry> history) {
    final today = DateTime.now();
    final todayEntries = history.where((entry) => 
        entry.timestamp.day == today.day &&
        entry.timestamp.month == today.month &&
        entry.timestamp.year == today.year
    ).toList();
    
    final successCount = todayEntries.where((e) => e.status == SyncOperationStatus.success).length;
    final errorCount = todayEntries.where((e) => e.status == SyncOperationStatus.error).length;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.today,
                label: 'Hoy',
                value: todayEntries.length.toString(),
                color: Theme.of(context).colorScheme.primary,
              ),
              _buildStatItem(
                icon: Icons.check_circle,
                label: 'Exitosos',
                value: successCount.toString(),
                color: Colors.green,
              ),
              _buildStatItem(
                icon: Icons.error,
                label: 'Errores',
                value: errorCount.toString(),
                color: Theme.of(context).colorScheme.error,
              ),
              _buildStatItem(
                icon: Icons.history,
                label: 'Total',
                value: history.length.toString(),
                color: Colors.grey,
              ),
            ],
          ),
        ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay entradas en el historial',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las operaciones de sincronización aparecerán aquí',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  List<SyncHistoryEntry> _applyFilters(List<SyncHistoryEntry> history) {
    var filtered = history;

    // Filtro por tipo
    if (_filterType != null) {
      filtered = filtered.where((entry) => entry.type == _filterType).toList();
    }

    // Filtro por estado
    if (_filterStatus != null) {
      filtered = filtered.where((entry) => entry.status == _filterStatus).toList();
    }

    // Filtro por rango de fechas
    if (_filterStartDate != null && _filterEndDate != null) {
      filtered = filtered.where((entry) => 
          entry.timestamp.isAfter(_filterStartDate!) && 
          entry.timestamp.isBefore(_filterEndDate!)
      ).toList();
    }

    // Filtro por búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) => 
          entry.description?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
          entry.entityType?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
          entry.errorMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) == true
      ).toList();
    }

    return filtered;
  }

  bool _hasActiveFilters() {
    return _filterType != null || 
           _filterStatus != null || 
           (_filterStartDate != null && _filterEndDate != null) ||
           _searchQuery.isNotEmpty;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => SyncHistoryFilterDialog(
        currentType: _filterType,
        currentStatus: _filterStatus,
        currentStartDate: _filterStartDate,
        currentEndDate: _filterEndDate,
        onApply: (type, status, startDate, endDate) {
          setState(() {
            _filterType = type;
            _filterStatus = status;
            _filterStartDate = startDate;
            _filterEndDate = endDate;
          });
        },
        onClear: () {
          setState(() {
            _filterType = null;
            _filterStatus = null;
            _filterStartDate = null;
            _filterEndDate = null;
          });
        },
      ),
    );
  }

  void _showEntryDetails(SyncHistoryEntry entry) {
    showDialog(
      context: context,
      builder: (context) => SyncHistoryEntryDialog(entry: entry),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportHistory();
        break;
      case 'clear':
        _clearHistory();
        break;
    }
  }

  void _exportHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exportación de historial - Por implementar')),
    );
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Historial'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar todo el historial de sincronización? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(syncHistoryProvider.notifier).clearHistory();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Historial eliminado')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

/// Widget para mostrar una entrada del historial
class SyncHistoryEntryTile extends StatelessWidget {

  const SyncHistoryEntryTile({
    super.key,
    required this.entry,
    this.onTap,
  });
  final SyncHistoryEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.status.getColor(context).withValues(alpha: 0.1),
          child: Icon(
            entry.status.getIcon(),
            color: entry.status.getColor(context),
            size: 20,
          ),
        ),
        title: Text(
          entry.type.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description != null)
              Text(
                entry.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  dateFormat.format(entry.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (entry.duration != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.timer,
                    size: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatDuration(entry.duration!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: entry.status.getColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                entry.status.displayName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: entry.status.getColor(context),
                ),
              ),
            ),
            if (entry.itemsProcessed != null)
              Text(
                '${entry.itemsSuccess ?? 0}/${entry.itemsProcessed}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

/// Diálogo de filtros
class SyncHistoryFilterDialog extends StatefulWidget {

  const SyncHistoryFilterDialog({
    super.key,
    this.currentType,
    this.currentStatus,
    this.currentStartDate,
    this.currentEndDate,
    required this.onApply,
    required this.onClear,
  });
  final SyncOperationType? currentType;
  final SyncOperationStatus? currentStatus;
  final DateTime? currentStartDate;
  final DateTime? currentEndDate;
  final Function(SyncOperationType?, SyncOperationStatus?, DateTime?, DateTime?) onApply;
  final VoidCallback onClear;

  @override
  State<SyncHistoryFilterDialog> createState() => _SyncHistoryFilterDialogState();
}

class _SyncHistoryFilterDialogState extends State<SyncHistoryFilterDialog> {
  SyncOperationType? _selectedType;
  SyncOperationStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentType;
    _selectedStatus = widget.currentStatus;
    _startDate = widget.currentStartDate;
    _endDate = widget.currentEndDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrar Historial'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtro por tipo
            Text(
              'Tipo de Operación',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SyncOperationType?>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Todos los tipos',
              ),
              items: [
                const DropdownMenuItem<SyncOperationType?>(
                  value: null,
                  child: Text('Todos los tipos'),
                ),
                ...SyncOperationType.values.map((type) => 
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedType = value),
            ),
            const SizedBox(height: 16),
            
            // Filtro por estado
            Text(
              'Estado',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SyncOperationStatus?>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Todos los estados',
              ),
              items: [
                const DropdownMenuItem<SyncOperationStatus?>(
                  value: null,
                  child: Text('Todos los estados'),
                ),
                ...SyncOperationStatus.values.map((status) => 
                  DropdownMenuItem(
                    value: status,
                    child: Text(status.displayName),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedStatus = value),
            ),
            const SizedBox(height: 16),
            
            // Filtro por fecha
            Text(
              'Rango de Fechas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(
                      _startDate != null
                          ? DateFormat('dd/MM/yyyy').format(_startDate!)
                          : 'Fecha inicio',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(
                      _endDate != null
                          ? DateFormat('dd/MM/yyyy').format(_endDate!)
                          : 'Fecha fin',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onClear();
            Navigator.of(context).pop();
          },
          child: const Text('Limpiar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_selectedType, _selectedStatus, _startDate, _endDate);
            Navigator.of(context).pop();
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        if (isStartDate) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }
}

/// Diálogo de detalles de entrada
class SyncHistoryEntryDialog extends StatelessWidget {

  const SyncHistoryEntryDialog({super.key, required this.entry});
  final SyncHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    
    return AlertDialog(
      title: Text(entry.type.displayName),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Estado', entry.status.displayName, 
                color: entry.status.getColor(context)),
            _buildDetailRow('Fecha', dateFormat.format(entry.timestamp)),
            if (entry.description != null)
              _buildDetailRow('Descripción', entry.description!),
            if (entry.entityType != null)
              _buildDetailRow('Tipo de Entidad', entry.entityType!),
            if (entry.entityId != null)
              _buildDetailRow('ID de Entidad', entry.entityId!),
            if (entry.duration != null)
              _buildDetailRow('Duración', _formatDuration(entry.duration!)),
            if (entry.itemsProcessed != null)
              _buildDetailRow('Elementos Procesados', entry.itemsProcessed.toString()),
            if (entry.itemsSuccess != null)
              _buildDetailRow('Elementos Exitosos', entry.itemsSuccess.toString()),
            if (entry.itemsError != null)
              _buildDetailRow('Elementos con Error', entry.itemsError.toString()),
            if (entry.errorMessage != null)
              _buildDetailRow('Mensaje de Error', entry.errorMessage!, 
                  color: Theme.of(context).colorScheme.error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}