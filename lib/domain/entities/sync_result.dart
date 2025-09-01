/// Resultado de una operación de sincronización
class SyncResult {
  SyncResult({
    required this.repositoryResults,
    required this.timestamp,
    required this.duration,
    this.errors = const [],
  })  : totalRepositories = repositoryResults.length,
        successfulRepositories =
            repositoryResults.values.where((success) => success).length,
        failedRepositories =
            repositoryResults.values.where((success) => !success).length;
  final Map<String, bool> repositoryResults;
  final DateTime timestamp;
  final Duration duration;
  final List<String> errors;
  final int totalRepositories;
  final int successfulRepositories;
  final int failedRepositories;

  /// Indica si la sincronización fue completamente exitosa
  bool get isFullySuccessful => failedRepositories == 0;

  /// Indica si hubo al menos una sincronización exitosa
  bool get hasAnySuccess => successfulRepositories > 0;

  /// Porcentaje de éxito de la sincronización
  double get successRate => totalRepositories > 0
      ? (successfulRepositories / totalRepositories) * 100
      : 0.0;

  SyncResult copyWith({
    Map<String, bool>? repositoryResults,
    DateTime? timestamp,
    Duration? duration,
    List<String>? errors,
  }) {
    return SyncResult(
      repositoryResults: repositoryResults ?? this.repositoryResults,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      errors: errors ?? this.errors,
    );
  }

  @override
  String toString() {
    return 'SyncResult(success: $successfulRepositories/$totalRepositories, '
        'duration: ${duration.inMilliseconds}ms, '
        'errors: ${errors.length})';
  }

  /// Convierte el resultado a un mapa para logging
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'duration_ms': duration.inMilliseconds,
      'total_repositories': totalRepositories,
      'successful_repositories': successfulRepositories,
      'failed_repositories': failedRepositories,
      'success_rate': successRate,
      'is_fully_successful': isFullySuccessful,
      'repository_results': repositoryResults,
      'errors': errors,
    };
  }
}
