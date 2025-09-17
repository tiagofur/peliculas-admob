import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/logger_factory.dart';

/// Servicio para verificar el estado de la base de datos de Supabase
/// y asegurar que todas las tablas y campos necesarios estén presentes
class DatabaseVerificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Verifica el estado completo de la base de datos
  Future<DatabaseVerificationResult> verifyDatabase() async {
    LoggerFactory.info('Iniciando verificación de la base de datos');

    final result = DatabaseVerificationResult();

    try {
      // Verificar tablas principales
      await _verifyUserTables(result);
      await _verifySyncTables(result);
      await _verifyIndexes(result);
      await _verifyPermissions(result);

      LoggerFactory.info(
          'Verificación completada. Estado: ${result.isHealthy ? 'SALUDABLE' : 'PROBLEMAS DETECTADOS'}');
    } catch (e, stackTrace) {
      LoggerFactory.error(
          'Error durante la verificación de la base de datos: $e',
          stackTrace: stackTrace);
      result.addError('Error general de verificación: $e');
    }

    return result;
  }

  /// Verifica las tablas de usuario principales
  Future<void> _verifyUserTables(DatabaseVerificationResult result) async {
    final requiredTables = {
      'user_profiles': [
        'id',
        'user_id',
        'display_name',
        'avatar_url',
        'created_at',
        'updated_at'
      ],
      'user_favorites': [
        'id',
        'user_id',
        'movie_id',
        'movie_title',
        'is_deleted',
        'last_modified_at'
      ],
      'user_watchlist': [
        'id',
        'user_id',
        'movie_id',
        'movie_title',
        'priority',
        'is_deleted',
        'last_modified_at'
      ],
      'user_watched_movies': [
        'id',
        'user_id',
        'movie_id',
        'movie_title',
        'watched_at',
        'is_deleted',
        'last_modified_at'
      ],
      'user_lists': [
        'id',
        'user_id',
        'name',
        'description',
        'is_deleted',
        'last_modified_at'
      ],
      'user_list_items': [
        'id',
        'list_id',
        'movie_id',
        'movie_title',
        'position',
        'is_deleted',
        'last_modified_at'
      ],
    };

    for (final entry in requiredTables.entries) {
      await _verifyTable(entry.key, entry.value, result);
    }
  }

  /// Verifica las tablas de sincronización
  Future<void> _verifySyncTables(DatabaseVerificationResult result) async {
    final syncTables = {
      'user_stats': [
        'id',
        'user_id',
        'total_movies_watched',
        'total_favorites',
        'updated_at'
      ],
      'trakt_search_attempts': ['id', 'user_id', 'search_query', 'created_at'],
      'deletion_history': [
        'id',
        'table_name',
        'record_id',
        'deleted_at',
        'deleted_by'
      ],
    };

    for (final entry in syncTables.entries) {
      await _verifyTable(entry.key, entry.value, result);
    }
  }

  /// Verifica que una tabla específica exista con las columnas requeridas
  Future<void> _verifyTable(String tableName, List<String> requiredColumns,
      DatabaseVerificationResult result) async {
    try {
      // Intentar hacer una consulta simple para verificar que la tabla existe
      await _supabase.from(tableName).select('*').limit(1).maybeSingle();

      result.addSuccess('Tabla $tableName: ✓ Existe y es accesible');

      // Verificar columnas específicas haciendo una consulta con esas columnas
      final columnCheck = requiredColumns.join(', ');
      await _supabase
          .from(tableName)
          .select(columnCheck)
          .limit(1)
          .maybeSingle();

      result.addSuccess(
          'Tabla $tableName: ✓ Todas las columnas requeridas están presentes');
    } catch (e) {
      if (e.toString().contains('relation') &&
          e.toString().contains('does not exist')) {
        result.addError('Tabla $tableName: ✗ No existe');
      } else if (e.toString().contains('column') &&
          e.toString().contains('does not exist')) {
        result.addError(
            'Tabla $tableName: ✗ Faltan columnas requeridas: ${e.toString()}');
      } else {
        result.addError('Tabla $tableName: ✗ Error de acceso: ${e.toString()}');
      }
    }
  }

  /// Verifica índices importantes para el rendimiento
  Future<void> _verifyIndexes(DatabaseVerificationResult result) async {
    try {
      // Esta verificación es básica ya que no tenemos acceso directo a los metadatos del sistema
      // En su lugar, verificamos que las consultas comunes funcionen eficientemente

      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Probar consultas que deberían usar índices
        await _supabase
            .from('user_favorites')
            .select('id')
            .filter('user_id', 'eq', user.id)
            .limit(1);

        await _supabase
            .from('user_watchlist')
            .select('id')
            .filter('user_id', 'eq', user.id)
            .limit(1);

        result.addSuccess(
            'Índices: ✓ Consultas por user_id funcionan correctamente');
      } else {
        result.addWarning(
            'Índices: ⚠ No se puede verificar sin usuario autenticado');
      }
    } catch (e) {
      result.addError('Índices: ✗ Error en verificación: ${e.toString()}');
    }
  }

  /// Verifica permisos RLS (Row Level Security)
  Future<void> _verifyPermissions(DatabaseVerificationResult result) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        result.addWarning(
            'Permisos: ⚠ No se puede verificar RLS sin usuario autenticado');
        return;
      }

      // Intentar operaciones básicas para verificar permisos
      final tables = [
        'user_favorites',
        'user_watchlist',
        'user_watched_movies',
        'user_lists'
      ];

      for (final table in tables) {
        try {
          await _supabase
              .from(table)
              .select('id')
              .filter('user_id', 'eq', user.id)
              .limit(1);

          result.addSuccess('Permisos $table: ✓ Lectura permitida');
        } catch (e) {
          if (e.toString().contains('permission denied')) {
            result.addError('Permisos $table: ✗ Acceso denegado');
          } else {
            result.addWarning(
                'Permisos $table: ⚠ Error de verificación: ${e.toString()}');
          }
        }
      }
    } catch (e) {
      result.addError('Permisos: ✗ Error general: ${e.toString()}');
    }
  }

  /// Ejecuta una verificación rápida de conectividad
  Future<bool> quickHealthCheck() async {
    try {
      await _supabase.from('user_profiles').select('id').limit(1);
      return true;
    } catch (e) {
      LoggerFactory.error('Fallo en verificación rápida de salud: $e');
      return false;
    }
  }
}

/// Resultado de la verificación de la base de datos
class DatabaseVerificationResult {
  final List<String> _successes = [];
  final List<String> _warnings = [];
  final List<String> _errors = [];

  List<String> get successes => List.unmodifiable(_successes);
  List<String> get warnings => List.unmodifiable(_warnings);
  List<String> get errors => List.unmodifiable(_errors);

  bool get isHealthy => _errors.isEmpty;
  bool get hasWarnings => _warnings.isNotEmpty;

  void addSuccess(String message) => _successes.add(message);
  void addWarning(String message) => _warnings.add(message);
  void addError(String message) => _errors.add(message);

  /// Genera un reporte completo del estado
  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== REPORTE DE VERIFICACIÓN DE BASE DE DATOS ===\n');

    buffer.writeln(
        'Estado General: ${isHealthy ? '✓ SALUDABLE' : '✗ PROBLEMAS DETECTADOS'}\n');

    if (_successes.isNotEmpty) {
      buffer.writeln('✅ ÉXITOS (${_successes.length}):');
      for (final success in _successes) {
        buffer.writeln('  $success');
      }
      buffer.writeln();
    }

    if (_warnings.isNotEmpty) {
      buffer.writeln('⚠️ ADVERTENCIAS (${_warnings.length}):');
      for (final warning in _warnings) {
        buffer.writeln('  $warning');
      }
      buffer.writeln();
    }

    if (_errors.isNotEmpty) {
      buffer.writeln('❌ ERRORES (${_errors.length}):');
      for (final error in _errors) {
        buffer.writeln('  $error');
      }
      buffer.writeln();
    }

    buffer.writeln('=== FIN DEL REPORTE ===');
    return buffer.toString();
  }
}
