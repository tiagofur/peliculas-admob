import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/services/sync_service.dart';
import '../providers/auth_provider.dart';
import '../providers/hybrid_repositories_provider.dart';

class SyncTestWidget extends ConsumerStatefulWidget {
  const SyncTestWidget({super.key});

  @override
  ConsumerState<SyncTestWidget> createState() => _SyncTestWidgetState();
}

class _SyncTestWidgetState extends ConsumerState<SyncTestWidget> {
  String _status = 'Esperando...';
  int _localFavorites = 0;
  int _remoteFavorites = 0;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = user != null;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: isAuthenticated ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Test de Sincronización',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Usuario: ${user?.email ?? 'No autenticado'}'),
            Text('Estado: $_status'),
            Text('Favoritos locales: $_localFavorites'),
            Text('Favoritos remotos: $_remoteFavorites'),
            const SizedBox(height: 16),
            if (isAuthenticated) ...[
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _testSync,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test Sync'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _checkLocal,
                    child: const Text('Check Local'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _checkRemote,
                    child: const Text('Check Remote'),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Necesitas estar autenticado para probar la sincronización',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testSync() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _status = 'Ejecutando sincronización...';
    });

    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.syncAllData();

      setState(() {
        _status = 'Sincronización completada';
      });

      // Actualizar contadores
      await _checkLocal();
      await _checkRemote();
    } catch (e) {
      setState(() {
        _status = 'Error en sincronización: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLocal() async {
    try {
      final favoritesRepo = ref.read(hybridFavoritesRepositoryProvider);
      final localData = await favoritesRepo.getLocalData();

      setState(() {
        _localFavorites = localData.length;
        _status = 'Datos locales verificados';
      });
    } catch (e) {
      setState(() {
        _status = 'Error verificando datos locales: $e';
      });
    }
  }

  Future<void> _checkRemote() async {
    try {
      final favoritesRepo = ref.read(hybridFavoritesRepositoryProvider);
      final remoteData = await favoritesRepo.getRemoteData();

      setState(() {
        _remoteFavorites = remoteData.length;
        _status = 'Datos remotos verificados';
      });
    } catch (e) {
      setState(() {
        _status = 'Error verificando datos remotos: $e';
      });
    }
  }
}
