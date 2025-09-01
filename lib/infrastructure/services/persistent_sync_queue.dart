import 'package:flutter/foundation.dart';

import '../../core/logging/logger_factory.dart';
import 'web_safe_storage_service.dart';

class PersistentSyncQueue {
  static const String _keyPrefix = 'sync_queue_';
  static const String _itemsListKey = 'sync_queue_items';

  final WebSafeStorageService _storage = WebSafeStorageService.instance;

  Future<void> init() async {
    // No necesita inicialización específica con SharedPreferences
    if (kDebugMode) {
      LoggerFactory.info(
          'PersistentSyncQueue inicializado para ${kIsWeb ? 'Web' : 'nativo'}');
    }
  }

  Future<void> addItem(String itemId) async {
    try {
      final currentItems = await getItems();
      if (!currentItems.contains(itemId)) {
        currentItems.add(itemId);
        await _saveItems(currentItems);
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error agregando item a sync queue: $e');
      }
    }
  }

  Future<void> removeItem(String itemId) async {
    try {
      final currentItems = await getItems();
      if (currentItems.remove(itemId)) {
        await _saveItems(currentItems);
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error removiendo item de sync queue: $e');
      }
    }
  }

  Future<List<String>> getItems() async {
    try {
      final itemsJson = await _storage.getJsonList(_itemsListKey);
      return itemsJson.map((item) => item['id'] as String).toList();
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error obteniendo items de sync queue: $e');
      }
      return [];
    }
  }

  Future<bool> get isEmpty async {
    final items = await getItems();
    return items.isEmpty;
  }

  Future<void> clear() async {
    try {
      await _storage.remove(_itemsListKey);
      await _storage.clearWithPrefix(_keyPrefix);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error limpiando sync queue: $e');
      }
    }
  }

  // Método privado para guardar la lista de items
  Future<void> _saveItems(List<String> items) async {
    try {
      final itemsJson = items.map((id) => {'id': id}).toList();
      await _storage.saveJsonList(_itemsListKey, itemsJson);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('Error guardando items en sync queue: $e');
      }
    }
  }

  // Método para obtener el tamaño de la cola
  Future<int> get size async {
    final items = await getItems();
    return items.length;
  }

  // Método para verificar si un item específico está en la cola
  Future<bool> contains(String itemId) async {
    final items = await getItems();
    return items.contains(itemId);
  }
}
