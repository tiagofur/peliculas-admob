class SyncException implements Exception {
  final String message;
  final String? code;

  SyncException(this.message, {this.code});

  @override
  String toString() => 'SyncException: $message (code: ${code ?? 'n/a'})';
}

class NetworkException extends SyncException {
  NetworkException({String message = 'Error de red. Comprueba tu conexión a internet.'}) 
      : super(message, code: 'network_error');
}

class SupabaseSyncException extends SyncException {
  SupabaseSyncException(String message, {String? code}) 
      : super('Error de Supabase: $message', code: code ?? 'supabase_error');
}

class ConflictException extends SyncException {
  final dynamic localData;
  final dynamic remoteData;

  ConflictException({
    String message = 'Conflicto de datos detectado.',
    this.localData,
    this.remoteData,
  }) : super(message, code: 'conflict');
}

class LocalStorageException extends SyncException {
  LocalStorageException(String message) 
      : super('Error de almacenamiento local: $message', code: 'local_storage_error');
}
