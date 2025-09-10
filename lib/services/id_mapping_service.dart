import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar el mapeo de IDs entre local y Supabase
class IdMappingService {
  final SharedPreferences _prefs;
  
  static const String _idMappingKey = 'id_mapping_data';
  
  IdMappingService(this._prefs);
  
  /// Guarda un mapeo de ID local a ID de Supabase
  Future<void> saveMapping(String localId, String supabaseId) async {
    final mappings = getMappings();
    mappings[localId] = supabaseId;
    await _saveMappings(mappings);
  }
  
  /// Obtiene el ID de Supabase para un ID local
  String? getSupabaseId(String localId) {
    final mappings = getMappings();
    return mappings[localId];
  }
  
  /// Obtiene el ID local para un ID de Supabase
  String? getLocalId(String supabaseId) {
    final mappings = getMappings();
    for (final entry in mappings.entries) {
      if (entry.value == supabaseId) {
        return entry.key;
      }
    }
    return null;
  }
  
  /// Obtiene todos los mapeos
  Map<String, String> getMappings() {
    final mappingsJson = _prefs.getString(_idMappingKey);
    if (mappingsJson == null) return {};
    
    try {
      final Map<String, dynamic> decoded = json.decode(mappingsJson);
      return decoded.cast<String, String>();
    } catch (e) {
      return {};
    }
  }
  
  /// Exporta todos los mapeos para backup
  Map<String, String> exportMappings() {
    return Map.from(getMappings());
  }
  
  /// Importa mapeos desde un backup
  Future<void> importMappings(Map<String, String> mappings) async {
    await _saveMappings(mappings);
  }
  
  /// Elimina un mapeo específico
  Future<void> removeMapping(String localId) async {
    final mappings = getMappings();
    mappings.remove(localId);
    await _saveMappings(mappings);
  }
  
  /// Limpia todos los mapeos
  Future<void> clearAllMappings() async {
    await _prefs.remove(_idMappingKey);
  }
  
  /// Guarda los mapeos en SharedPreferences
  Future<void> _saveMappings(Map<String, String> mappings) async {
    final mappingsJson = json.encode(mappings);
    await _prefs.setString(_idMappingKey, mappingsJson);
  }
  
  /// Verifica si existe un mapeo para un ID local
  bool hasMapping(String localId) {
    return getMappings().containsKey(localId);
  }
  
  /// Obtiene el número total de mapeos
  int get mappingCount => getMappings().length;
}