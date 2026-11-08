/// Resultado de una operación de sincronización
class SyncResult {
  const SyncResult({
    required this.success,
    required this.itemsProcessed,
    this.itemsSuccessful = 0,
    this.itemsFailed = 0,
    this.errors = const [],
    this.duration,
    this.message,
  });

  /// Constructor para resultado exitoso
  factory SyncResult.success({
    required int itemsProcessed,
    int? itemsSuccessful,
    Duration? duration,
    String? message,
  }) {
    return SyncResult(
      success: true,
      itemsProcessed: itemsProcessed,
      itemsSuccessful: itemsSuccessful ?? itemsProcessed,
      itemsFailed: 0,
      duration: duration,
      message: message,
    );
  }

  /// Constructor para resultado con errores
  factory SyncResult.failure({
    required int itemsProcessed,
    required List<String> errors,
    int itemsSuccessful = 0,
    Duration? duration,
    String? message,
  }) {
    return SyncResult(
      success: false,
      itemsProcessed: itemsProcessed,
      itemsSuccessful: itemsSuccessful,
      itemsFailed: itemsProcessed - itemsSuccessful,
      errors: errors,
      duration: duration,
      message: message,
    );
  }

  /// Indica si la operación fue exitosa
  final bool success;

  /// Número total de items procesados
  final int itemsProcessed;

  /// Número de items procesados exitosamente
  final int itemsSuccessful;

  /// Número de items que fallaron
  final int itemsFailed;

  /// Lista de errores ocurridos durante la sincronización
  final List<String> errors;

  /// Duración de la operación
  final Duration? duration;

  /// Mensaje descriptivo del resultado
  final String? message;

  /// Tasa de éxito (0.0 - 1.0)
  double get successRate =>
      itemsProcessed > 0 ? itemsSuccessful / itemsProcessed : 0.0;

  /// Indica si hubo errores parciales
  bool get hasPartialErrors => itemsFailed > 0 && itemsSuccessful > 0;

  /// Indica si falló completamente
  bool get isComplete => itemsSuccessful == itemsProcessed;

  @override
  String toString() {
    return 'SyncResult(success: $success, processed: $itemsProcessed, '
        'successful: $itemsSuccessful, failed: $itemsFailed, '
        'duration: ${duration?.inMilliseconds}ms)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncResult &&
        other.success == success &&
        other.itemsProcessed == itemsProcessed &&
        other.itemsSuccessful == itemsSuccessful &&
        other.itemsFailed == itemsFailed &&
        _listEquals(other.errors, errors) &&
        other.duration == duration &&
        other.message == message;
  }

  @override
  int get hashCode {
    return Object.hash(
      success,
      itemsProcessed,
      itemsSuccessful,
      itemsFailed,
      Object.hashAll(errors),
      duration,
      message,
    );
  }

  /// Utilidad para comparar listas
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
