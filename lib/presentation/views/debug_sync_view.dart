import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../services/data_migration_service.dart';
import '../providers/auth_provider.dart';

/// Vista de debug para verificar el estado de sincronización de datos
class DebugSyncView extends ConsumerStatefulWidget {
  const DebugSyncView({super.key});

  @override
  ConsumerState<DebugSyncView> createState() => _DebugSyncViewState();
}

class _DebugSyncViewState extends ConsumerState<DebugSyncView> {
  String _syncStatus = 'Esperando...';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Sincronización'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estado de Autenticación:',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Autenticado: $isAuthenticated'),
                    Text('Usuario: ${currentUser?.email ?? "No disponible"}'),
                    Text('ID Usuario: ${currentUser?.id ?? "No disponible"}'),
                    Text('Estado Auth: ${authState.when(
                      data: (user) =>
                          user != null ? 'Conectado' : 'Desconectado',
                      loading: () => 'Cargando...',
                      error: (error, _) => 'Error: $error',
                    )}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estado de Sincronización:',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_syncStatus),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: isAuthenticated ? _testSync : null,
                        child: const Text('Probar Sincronización Manual'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Acciones:',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _checkLocalData,
                      child: const Text('Verificar Datos Locales'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: isAuthenticated ? _forceFullSync : null,
                      child: const Text('Forzar Sincronización Completa'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testSync() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Probando sincronización...';
    });

    try {
      final dataMigrationService = ref.read(dataMigrationServiceProvider);
      final user = ref.read(currentUserProvider);

      if (user == null) {
        setState(() {
          _syncStatus = 'Error: Usuario no disponible';
          _isLoading = false;
        });
        return;
      }

      LoggerFactory.info(
          '🔄 Iniciando prueba de sincronización para usuario: ${user.id}');

      // Ejecutar la migración y sincronización
      final result = await dataMigrationService.migrateAndSyncData(user.id);

      setState(() {
        _syncStatus = '''Sincronización completada:
• Películas vistas migradas: ${result.migratedWatchedMovies}
• Calificaciones migradas: ${result.migratedRatings}
• Listas personalizadas migradas: ${result.migratedCustomLists}
• Éxito: ${result.success}
• Error: ${result.error ?? "Ninguno"}''';
        _isLoading = false;
      });

      LoggerFactory.info('✅ Sincronización completada con éxito');
    } catch (e) {
      LoggerFactory.error('❌ Error durante la sincronización: $e');

      if (mounted) {
        setState(() {
          _syncStatus = 'Error durante sincronización: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _checkLocalData() {
    setState(() {
      _syncStatus = 'Verificando datos locales... (implementar)';
    });
    LoggerFactory.info('📊 Verificando datos locales');
    // Aquí podrías implementar verificación de datos locales
  }

  Future<void> _forceFullSync() async {
    if (!mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _syncStatus = 'Forzando sincronización completa...';
    });

    try {
      final dataMigrationService = ref.read(dataMigrationServiceProvider);

      LoggerFactory.info('🔄 Forzando sincronización completa');

      // Forzar una nueva sincronización
      final result = await dataMigrationService.migrateAndSyncData(user.id);

      setState(() {
        _syncStatus = '''Sincronización forzada completada:
• Películas vistas: ${result.migratedWatchedMovies}
• Calificaciones: ${result.migratedRatings}  
• Listas personalizadas: ${result.migratedCustomLists}
• Resultado: ${result.success ? "Éxito" : "Falló"}''';
        _isLoading = false;
      });
    } catch (e) {
      LoggerFactory.error('❌ Error forzando sincronización: $e');

      if (mounted) {
        setState(() {
          _syncStatus = 'Error forzando sincronización: $e';
          _isLoading = false;
        });
      }
    }
  }
}
