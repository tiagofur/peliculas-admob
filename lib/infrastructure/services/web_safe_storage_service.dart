import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Servicio de almacenamiento que funciona tanto en plataformas nativas como en Web
/// Sin usar path_provider ni ObjectBox
class WebSafeStorageService {
  WebSafeStorageService._();
  static WebSafeStorageService? _instance;
  static WebSafeStorageService get instance =>
      _instance ??= WebSafeStorageService._();

  /// Obtener una instancia de SharedPreferences de manera segura
  Future<SharedPreferences> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo SharedPreferences: $e');
      }
      rethrow;
    }
  }

  /// Guardar un objeto JSON
  Future<bool> saveJson(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await _getPrefs();
      final jsonString = jsonEncode(data);
      return await prefs.setString(key, jsonString);
    } catch (e) {
      if (kDebugMode) {
        print('Error guardando JSON para key $key: $e');
      }
      return false;
    }
  }

  /// Obtener un objeto JSON
  Future<Map<String, dynamic>?> getJson(String key) async {
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(key);
      if (jsonString == null) return null;

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo JSON para key $key: $e');
      }
      return null;
    }
  }

  /// Guardar una lista de objetos JSON
  Future<bool> saveJsonList(
      String key, List<Map<String, dynamic>> dataList) async {
    try {
      final prefs = await _getPrefs();
      final jsonStringList = dataList.map((data) => jsonEncode(data)).toList();
      return await prefs.setStringList(key, jsonStringList);
    } catch (e) {
      if (kDebugMode) {
        print('Error guardando lista JSON para key $key: $e');
      }
      return false;
    }
  }

  /// Obtener una lista de objetos JSON
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    try {
      final prefs = await _getPrefs();
      final jsonStringList = prefs.getStringList(key);
      if (jsonStringList == null) return [];

      return jsonStringList
          .map((jsonString) => jsonDecode(jsonString) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo lista JSON para key $key: $e');
      }
      return [];
    }
  }

  /// Guardar una cadena
  Future<bool> saveString(String key, String value) async {
    try {
      final prefs = await _getPrefs();
      return await prefs.setString(key, value);
    } catch (e) {
      if (kDebugMode) {
        print('Error guardando string para key $key: $e');
      }
      return false;
    }
  }

  /// Obtener una cadena
  Future<String?> getString(String key) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(key);
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo string para key $key: $e');
      }
      return null;
    }
  }

  /// Guardar un booleano
  Future<bool> saveBool(String key, bool value) async {
    try {
      final prefs = await _getPrefs();
      return await prefs.setBool(key, value);
    } catch (e) {
      if (kDebugMode) {
        print('Error guardando bool para key $key: $e');
      }
      return false;
    }
  }

  /// Obtener un booleano
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo bool para key $key: $e');
      }
      return defaultValue;
    }
  }

  /// Guardar un entero
  Future<bool> saveInt(String key, int value) async {
    try {
      final prefs = await _getPrefs();
      return await prefs.setInt(key, value);
    } catch (e) {
      if (kDebugMode) {
        print('Error guardando int para key $key: $e');
      }
      return false;
    }
  }

  /// Obtener un entero
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getInt(key) ?? defaultValue;
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo int para key $key: $e');
      }
      return defaultValue;
    }
  }

  /// Eliminar una clave
  Future<bool> remove(String key) async {
    try {
      final prefs = await _getPrefs();
      return await prefs.remove(key);
    } catch (e) {
      if (kDebugMode) {
        print('Error eliminando key $key: $e');
      }
      return false;
    }
  }

  /// Verificar si existe una clave
  Future<bool> containsKey(String key) async {
    try {
      final prefs = await _getPrefs();
      return prefs.containsKey(key);
    } catch (e) {
      if (kDebugMode) {
        print('Error verificando key $key: $e');
      }
      return false;
    }
  }

  /// Limpiar todas las claves con un prefijo específico
  Future<bool> clearWithPrefix(String prefix) async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((key) => key.startsWith(prefix));

      for (final key in keys) {
        await prefs.remove(key);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error limpiando keys con prefijo $prefix: $e');
      }
      return false;
    }
  }

  /// Obtener todas las claves disponibles
  Future<Set<String>> getAllKeys() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getKeys();
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo todas las keys: $e');
      }
      return <String>{};
    }
  }

  /// Limpiar todo el almacenamiento
  Future<bool> clearAll() async {
    try {
      final prefs = await _getPrefs();
      return await prefs.clear();
    } catch (e) {
      if (kDebugMode) {
        print('Error limpiando todo el almacenamiento: $e');
      }
      return false;
    }
  }
}
