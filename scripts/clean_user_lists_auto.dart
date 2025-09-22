import 'dart:convert';
import 'package:http/http.dart' as http;

const String supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const String serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTM1OTE5OCwiZXhwIjoyMDcwOTM1MTk4fQ.O5echdaf1eCKbgG7vaqaRg8q3ew9kuScvl9nVUBJeyM';
const String targetEmail = 'tiagofur@gmail.com';

void main() async {
  print('🧹 Iniciando limpieza automática de listas para $targetEmail...');

  try {
    // 1. Buscar el usuario por email
    print('📧 Buscando usuario...');
    final userId = await findUserByEmail(targetEmail);
    if (userId == null) {
      print('❌ Usuario no encontrado');
      return;
    }
    print('✅ Usuario encontrado: $userId');

    // 2. Obtener todas las listas del usuario
    print('📋 Obteniendo listas...');
    final lists = await getUserLists(userId);
    print('📊 Encontradas ${lists.length} listas');

    if (lists.isEmpty) {
      print('ℹ️ No hay listas para eliminar');
      return;
    }

    // 3. Mostrar las listas que se van a eliminar
    print('\n📝 Listas a eliminar:');
    for (var list in lists) {
      print('  - ${list['name']} (ID: ${list['id']})');
    }

    // 4. Eliminar items de las listas primero
    print('\n🗑️ Eliminando items de las listas...');
    await deleteAllListItems(userId);

    // 5. Eliminar las listas
    print('🗑️ Eliminando listas...');
    await deleteAllUserLists(userId);

    print('\n✅ ¡Limpieza completada! Todas las listas han sido eliminadas.');
    print('🔄 Puedes abrir la app ahora con listas limpias.');

  } catch (e) {
    print('❌ Error durante la limpieza: $e');
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
    print('⚠️ Warning: Error eliminando items: ${response.statusCode}');
  } else {
    print('✅ Items de listas eliminados');
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

  print('✅ Listas eliminadas');
}