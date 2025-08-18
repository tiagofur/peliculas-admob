import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/services/conflict_resolver.dart';
import '../providers/hybrid_repositories_provider.dart';
import '../providers/storage/favorite_movies_provider.dart';

class MultiDeviceDebugWidget extends ConsumerWidget {
  const MultiDeviceDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔄 DEBUG: Multi-Dispositivo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () async {
                try {
                  print('\n=== 📊 ANÁLISIS MULTI-DISPOSITIVO ===');
                  
                  // 1. Obtener favoritos del provider (UI)
                  final favoritesMap = ref.read(favoriteMoviesProvider);
                  final uiFavorites = favoritesMap.values.toList();
                  print('📱 Favoritos en UI: ${uiFavorites.length}');
                  
                  // 2. Obtener favoritos del hybrid repository (sincronización)
                  final hybridRepo = ref.read(hybridFavoritesRepositoryProvider);
                  final localSyncFavorites = await hybridRepo.getLocalData();
                  final remoteSyncFavorites = await hybridRepo.getRemoteData();
                  
                  print('🗄️ Favoritos locales (sync): ${localSyncFavorites.length}');
                  print('☁️ Favoritos remotos (Supabase): ${remoteSyncFavorites.length}');
                  
                  // 3. Analizar diferencias
                  print('\n📊 ANÁLISIS DE DIFERENCIAS:');
                  
                  if (uiFavorites.length != localSyncFavorites.length) {
                    print('⚠️ DISCREPANCIA: UI (${uiFavorites.length}) vs Local Sync (${localSyncFavorites.length})');
                  }
                  
                  if (localSyncFavorites.length != remoteSyncFavorites.length) {
                    print('⚠️ DESINCRONIZACIÓN: Local (${localSyncFavorites.length}) vs Remoto (${remoteSyncFavorites.length})');
                  }
                  
                  // 4. Usar ConflictResolver para analizar qué falta sincronizar
                  final toUpload = ConflictResolver.findLocalChanges(localSyncFavorites, remoteSyncFavorites);
                  final toDownload = ConflictResolver.findRemoteChanges(localSyncFavorites, remoteSyncFavorites);
                  final conflicts = ConflictResolver.detectConflicts(localSyncFavorites, remoteSyncFavorites);
                  
                  print('\n🔄 SINCRONIZACIÓN PENDIENTE:');
                  print('📤 Para subir a Supabase: ${toUpload.length} favoritos');
                  print('📥 Para descargar de Supabase: ${toDownload.length} favoritos');
                  print('⚠️ Conflictos detectados: ${conflicts.length}');
                  
                  // 5. Detalles de favoritos para subir
                  if (toUpload.isNotEmpty) {
                    print('\n📤 FAVORITOS PENDIENTES DE SUBIR:');
                    for (int i = 0; i < toUpload.length; i++) {
                      final fav = toUpload[i];
                      print('   ${i + 1}. ${fav.movieTitle} (ID: ${fav.movieId})');
                      print('      - Agregado: ${fav.addedAt}');
                      print('      - Actualizado: ${fav.updatedAt}');
                    }
                  }
                  
                  // 6. Detalles de favoritos para descargar
                  if (toDownload.isNotEmpty) {
                    print('\n📥 FAVORITOS PENDIENTES DE DESCARGAR:');
                    for (int i = 0; i < toDownload.length; i++) {
                      final fav = toDownload[i];
                      print('   ${i + 1}. ${fav.movieTitle} (ID: ${fav.movieId})');
                      print('      - Agregado: ${fav.addedAt}');
                      print('      - Actualizado: ${fav.updatedAt}');
                    }
                  }
                  
                  // 7. Detalles de conflictos
                  if (conflicts.isNotEmpty) {
                    print('\n⚠️ CONFLICTOS DETECTADOS:');
                    for (int i = 0; i < conflicts.length; i++) {
                      final conflict = conflicts[i];
                      print('   ${i + 1}. ${conflict.local.movieTitle}');
                      print('      - Local: ${conflict.local.updatedAt}');
                      print('      - Remoto: ${conflict.remote.updatedAt}');
                    }
                  }
                  
                  print('\n=== 🎯 RECOMENDACIONES ===');
                  if (toUpload.isNotEmpty) {
                    print('🔧 Ejecutar sincronización para subir ${toUpload.length} favoritos');
                  }
                  if (toDownload.isNotEmpty) {
                    print('🔧 Hay ${toDownload.length} favoritos nuevos en Supabase para descargar');
                  }
                  if (conflicts.isNotEmpty) {
                    print('🔧 Resolver ${conflicts.length} conflictos antes de continuar');
                  }
                  if (toUpload.isEmpty && toDownload.isEmpty && conflicts.isEmpty) {
                    print('✅ Todo está sincronizado correctamente');
                  }
                  
                  print('=== FIN ANÁLISIS ===\n');
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Análisis completado. Local: ${localSyncFavorites.length}, Remoto: ${remoteSyncFavorites.length}, Pendientes: ${toUpload.length}'),
                      backgroundColor: toUpload.isEmpty ? Colors.green : Colors.orange,
                    ),
                  );
                } catch (e) {
                  print('❌ Error en análisis multi-dispositivo: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error en análisis: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('🔍 Analizar Multi-Dispositivo'),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: () async {
                try {
                  print('\n=== 🔄 FORZAR SINCRONIZACIÓN ===');
                  final hybridRepo = ref.read(hybridFavoritesRepositoryProvider);
                  
                  // Ejecutar sincronización manual
                  await hybridRepo.syncWithSupabase();
                  
                  print('✅ Sincronización manual completada');
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sincronización manual ejecutada'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                } catch (e) {
                  print('❌ Error en sincronización manual: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error en sincronización: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('🔄 Forzar Sincronización'),
            ),
            
            const SizedBox(height: 16),
            
            // Estado actual
            Consumer(
              builder: (context, ref, child) {
                final favoritesMap = ref.watch(favoriteMoviesProvider);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📊 Estado actual:'),
                    Text('   • Favoritos en UI: ${favoritesMap.length}'),
                    const Text('   • Sincronización: Ver logs en consola'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
