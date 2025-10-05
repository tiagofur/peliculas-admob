import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';

/// Decorador de [LocalStorage] que tolera fallos de almacenamiento en Web
/// y mantiene un respaldo en memoria para no bloquear el flujo de login.
class ResilientAuthLocalStorage extends LocalStorage {
  ResilientAuthLocalStorage({required LocalStorage delegate})
      : _delegate = delegate;

  final LocalStorage _delegate;

  bool _delegateHealthy = true;
  bool _fallbackLogged = false;
  String? _inMemorySession;

  @override
  Future<void> initialize() async {
    if (!_delegateHealthy) return;

    try {
      await _delegate.initialize();
    } catch (error, stackTrace) {
      _handleFailure('initialize', error, stackTrace);
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    if (_delegateHealthy) {
      try {
        final hasToken = await _delegate.hasAccessToken();
        if (hasToken) {
          return true;
        }
      } catch (error, stackTrace) {
        _handleFailure('hasAccessToken', error, stackTrace);
      }
    }

    return _inMemorySession != null;
  }

  @override
  Future<String?> accessToken() async {
    if (_delegateHealthy) {
      try {
        final token = await _delegate.accessToken();
        if (token != null) {
          _inMemorySession = token;
          return token;
        }
      } catch (error, stackTrace) {
        _handleFailure('accessToken', error, stackTrace);
      }
    }

    return _inMemorySession;
  }

  @override
  Future<void> removePersistedSession() async {
    _inMemorySession = null;

    if (!_delegateHealthy) return;

    try {
      await _delegate.removePersistedSession();
    } catch (error, stackTrace) {
      _handleFailure('removePersistedSession', error, stackTrace);
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    _inMemorySession = persistSessionString;

    if (!_delegateHealthy) return;

    try {
      await _delegate.persistSession(persistSessionString);
    } catch (error, stackTrace) {
      _handleFailure('persistSession', error, stackTrace);
    }
  }

  void _handleFailure(String operation, Object error, StackTrace stackTrace) {
    if (_delegateHealthy) {
      _delegateHealthy = false;
      _logFallback(operation, error, stackTrace);
      return;
    }

    // Cuando la degradación ya está activa, limitamos el ruido a logs de debug.
    unawaited(LoggerFactory.debug(
      'ResilientAuthLocalStorage fallback in use for operation: $operation',
      data: {
        'operation': operation,
        'error': error.toString(),
      },
    ));
  }

  void _logFallback(String operation, Object error, StackTrace stackTrace) {
    final message = _looksLikeQuotaIssue(error)
        ? '⚠️ Supabase auth storage sin espacio en Web, usando fallback en memoria.'
        : '⚠️ Supabase auth storage falló en $operation, usando fallback en memoria.';

    if (!_fallbackLogged) {
      _fallbackLogged = true;
      unawaited(LoggerFactory.warning(
        message,
        data: {
          'operation': operation,
          'error': error.toString(),
          'fallback': 'in-memory',
        },
      ));
    } else {
      unawaited(LoggerFactory.debug(
        message,
        data: {
          'operation': operation,
          'error': error.toString(),
          'fallback': 'in-memory',
        },
      ));
    }

    if (kDebugMode) {
      // Log detallado en modo debug para facilitar diagnóstico durante QA.
      unawaited(LoggerFactory.debug(
        'Detalle stacktrace fallback auth storage: $stackTrace',
        data: {
          'operation': operation,
        },
      ));
    }
  }

  bool _looksLikeQuotaIssue(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('quota') ||
        lower.contains('limit') ||
        lower.contains('domexception') ||
        lower.contains('storage');
  }
}

/// Helper para construir almacenamiento resiliente sólo en Web.
LocalStorage? createResilientAuthLocalStorage(String supabaseUrl) {
  if (!kIsWeb) {
    return null;
  }

  final persistKey = _resolvePersistSessionKey(supabaseUrl);
  final delegate = SharedPreferencesLocalStorage(persistSessionKey: persistKey);
  return ResilientAuthLocalStorage(delegate: delegate);
}

String _resolvePersistSessionKey(String supabaseUrl) {
  try {
    final uri = Uri.parse(supabaseUrl);
    final host = uri.host;
    if (host.isEmpty) {
      return 'sb-anon-auth-token';
    }
    final parts = host.split('.');
    final projectRef = parts.isNotEmpty ? parts.first : host;
    return 'sb-$projectRef-auth-token';
  } catch (_) {
    return 'sb-anon-auth-token';
  }
}
