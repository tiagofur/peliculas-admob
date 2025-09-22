import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:peliculas/core/logging/logger_factory.dart';

const String supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const String serviceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTM1OTE5OCwiZXhwIjoyMDcwOTM1MTk4fQ.O5echdaf1eCKbgG7vaqaRg8q3ew9kuScvl9nVUBJeyM';
const String targetEmail = 'tiagofur@gmail.com';

void main() async {
  await LoggerFactory.info(
      '🧹 Iniciando limpieza automática de listas para $targetEmail...');

  try {
    // 1. Buscar el usuario por email
    await LoggerFactory.info('📧 Buscando usuario...');
    final userId = await findUserByEmail(targetEmail);
    if (userId == null) {
      await LoggerFactory.error('❌ Usuario no encontrado');
      return;
    }
    await LoggerFactory.info('✅ Usuario encontrado: $userId');

    // 2. Obtener todas las listas del usuario
    await LoggerFactory.info('📋 Obteniendo listas...');
    final lists = await getUserLists(userId);
    await LoggerFactory.info('📊 Encontradas ${lists.length} listas');

    if (lists.isEmpty) {
      await LoggerFactory.info('ℹ️ No hay listas para eliminar');
      return;
    }

    // 3. Mostrar las listas que se van a eliminar
    await LoggerFactory.info('\n📝 Listas a eliminar:');
    for (var list in lists) {
      await LoggerFactory.info('  - ${list['name']} (ID: ${list['id']})');
    }

    // 4. Eliminar items de las listas primero
    await LoggerFactory.info('\n🗑️ Eliminando items de las listas...');
    await deleteAllListItems(userId);

    // 5. Eliminar las listas
    await LoggerFactory.info('🗑️ Eliminando listas...');
    await deleteAllUserLists(userId);

    await LoggerFactory.info(
        '\n✅ ¡Limpieza completada! Todas las listas han sido eliminadas.');
    await LoggerFactory.info(
        '🔄 Puedes abrir la app ahora con listas limpias.');
  } catch (e) {
    await LoggerFactory.error('❌ Error durante la limpieza: $e');
  }
}

Future<String?> findUserByEmail(String email) async {
  final response = await http.get(
    Uri.parse('$supabaseUrl/auth/v1/admin/users'),
    headers: {
      'Authorization': 'Bearer $serviceRoleKey',
      'apikey': serviceRoleKey,
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final users = data['users'] as List;

    for (var user in users) {
      if (user['email'] == email) {
        return user['id'];
      }
    }
  }

  return null;
}

Future<List<Map<String, dynamic>>> getUserLists(String userId) async {
  final response = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/user_lists?user_id=eq.$userId&select=*'),
    headers: {
      'Authorization': 'Bearer $serviceRoleKey',
      'apikey': serviceRoleKey,
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body) as List;
    return data.cast<Map<String, dynamic>>();
  }

  throw Exception('Error obteniendo listas: ${response.statusCode}');
}

Future<void> deleteAllListItems(String userId) async {
  final response = await http.delete(
    Uri.parse('$supabaseUrl/rest/v1/user_list_items?user_id=eq.$userId'),
    headers: {
      'Authorization': 'Bearer $serviceRoleKey',
      'apikey': serviceRoleKey,
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode != 204) {
    await LoggerFactory.warning(
        '⚠️ Warning: Error eliminando items: ${response.statusCode}');
  } else {
    await LoggerFactory.info('✅ Items de listas eliminados');
  }
}

Future<void> deleteAllUserLists(String userId) async {
  final response = await http.delete(
    Uri.parse('$supabaseUrl/rest/v1/user_lists?user_id=eq.$userId'),
    headers: {
      'Authorization': 'Bearer $serviceRoleKey',
      'apikey': serviceRoleKey,
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode != 204) {
    throw Exception('Error eliminando listas: ${response.statusCode}');
  }

  await LoggerFactory.info('✅ Listas eliminadas');
}
