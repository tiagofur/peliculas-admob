import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';

/// Utilidad para manejar timestamps del servidor de manera consistente
class ServerTimestampUtils {
  static final _logger = LoggerFactory.logger;

  /// Obtiene el timestamp actual del servidor de Supabase
  /// Si hay error, fallback a DateTime.now() local pero registra el error
  static Future<DateTime> getServerTimestamp() async {
    try {
      final client = Supabase.instance.client;

      // Usar función SQL para obtener timestamp del servidor
      final response = await client
          .rpc('get_server_timestamp')
          .timeout(const Duration(seconds: 5));

      if (response != null && response is String) {
        return DateTime.parse(response);
      }

      // Si no hay función RPC, usar una consulta simple
      final result = await client
          .from('sync_metadata')
          .select('created_at')
          .limit(1)
          .single()
          .timeout(const Duration(seconds: 5));

      // Extraer el timestamp del servidor
      final serverTime = result['created_at'] as String?;
      if (serverTime != null) {
        return DateTime.parse(serverTime);
      }

      throw Exception('No se pudo obtener timestamp del servidor');
    } catch (e) {
      _logger
          .warning('⚠️ No se pudo obtener server timestamp, usando local: $e');
      return DateTime.now();
    }
  }

  /// Obtiene el timestamp del servidor como String ISO8601
  static Future<String> getServerTimestampString() async {
    final timestamp = await getServerTimestamp();
    return timestamp.toIso8601String();
  }

  /// Obtiene el timestamp del servidor de manera síncrona usando cache
  /// Solo debe usarse cuando ya se ha llamado a getServerTimestamp() recientemente
  static DateTime getCachedServerTimestamp() {
    final cached = _cachedServerTime;
    final now = DateTime.now();

    // Si tenemos un timestamp cached y no ha pasado más de 30 segundos, usarlo
    if (cached != null &&
        _lastCacheUpdate != null &&
        now.difference(_lastCacheUpdate!).inSeconds < 30) {
      // Ajustar por el tiempo transcurrido
      final elapsed = now.difference(_lastCacheUpdate!);
      return cached.add(elapsed);
    }

    // Si no hay cache válido, usar tiempo local
    _logger.debug('Usando timestamp local por falta de cache válido');
    return now;
  }

  /// Cache interno para timestamps del servidor
  static DateTime? _cachedServerTime;
  static DateTime? _lastCacheUpdate;

  /// Actualiza el cache de timestamp del servidor
  static Future<void> updateServerTimestampCache() async {
    try {
      _cachedServerTime = await getServerTimestamp();
      _lastCacheUpdate = DateTime.now();
      _logger.debug('✅ Server timestamp cache actualizado');
    } catch (e) {
      _logger.warning('⚠️ Error actualizando server timestamp cache: $e');
    }
  }

  /// Calcula la diferencia entre el servidor y el tiempo local
  static Future<Duration> getServerClockDifference() async {
    try {
      final localBefore = DateTime.now();
      final serverTime = await getServerTimestamp();
      final localAfter = DateTime.now();

      // Promedio del tiempo local para reducir latencia de red
      final localAverage = localBefore.add(Duration(
          milliseconds:
              localAfter.difference(localBefore).inMilliseconds ~/ 2));

      return serverTime.difference(localAverage);
    } catch (e) {
      _logger.warning('⚠️ Error calculando diferencia de reloj: $e');
      return Duration.zero;
    }
  }

  /// Convierte un timestamp local a timestamp del servidor estimado
  static Future<DateTime> localToServerTime(DateTime localTime) async {
    try {
      final difference = await getServerClockDifference();
      return localTime.add(difference);
    } catch (e) {
      _logger.warning('⚠️ Error convirtiendo a server time: $e');
      return localTime;
    }
  }

  /// Obtiene timestamp para operaciones de sync (con fallback rápido)
  static Future<DateTime> getSyncTimestamp() async {
    try {
      // Intentar obtener del servidor con timeout corto
      return await getServerTimestamp().timeout(const Duration(seconds: 2));
    } catch (e) {
      _logger.debug('Usando timestamp local para sync por timeout/error: $e');
      return DateTime.now();
    }
  }

  /// Para operaciones críticas donde el timestamp del servidor es esencial
  static Future<DateTime> getCriticalServerTimestamp() async {
    const maxRetries = 3;
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        attempts++;
        return await getServerTimestamp().timeout(const Duration(seconds: 10));
      } catch (e) {
        if (attempts >= maxRetries) {
          _logger.error(
              '❌ No se pudo obtener server timestamp después de $maxRetries intentos: $e');
          rethrow;
        }
        _logger.warning(
            '⚠️ Reintentando obtener server timestamp (intento $attempts): $e');
        await Future.delayed(Duration(seconds: attempts));
      }
    }

    throw Exception('No se pudo obtener server timestamp crítico');
  }
}
