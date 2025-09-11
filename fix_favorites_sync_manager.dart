import 'dart:io';

void main() async {
  const filePath = 'lib/core/sync/favorites_sync_manager.dart';
  final file = File(filePath);
  
  if (!await file.exists()) {
    print('Archivo no encontrado: $filePath');
    return;
  }
  
  String content = await file.readAsString();
  final originalContent = content;
  
  // 1. Corregir método 'gte' no definido para PostgrestTransformBuilder
  content = content.replaceAll(
    RegExp(r'\.gte\(\'last_modified_at\', since\.toIso8601String\(\)\);'),
    '.gt(\'last_modified_at\', since.toIso8601String());'
  );
  
  // 2. Corregir método 'filter' no definido - reemplazar con 'eq'
  content = content.replaceAll(
    RegExp(r'\.filter\(\'user_id\', \'eq\', userId\)'),
    '.eq(\'user_id\', userId)'
  );
  
  content = content.replaceAll(
    RegExp(r'\.filter\(\'is_deleted\', \'eq\', false\)'),
    '.eq(\'is_deleted\', false)'
  );
  
  // 3. Corregir otros usos del método filter
  content = content.replaceAll(
    RegExp(r'\.filter\(([^,]+), \'eq\', ([^)]+)\)'),
    '.eq(\$1, \$2)'
  );
  
  // 4. Asegurar que se use el método correcto para filtros
  content = content.replaceAll(
    'query = query.gt(',
    'query = query.gte('
  );
  
  if (content != originalContent) {
    await file.writeAsString(content);
    print('✅ Corregido: $filePath');
    print('   - Corregido método gte no definido');
    print('   - Corregido método filter no definido');
    print('   - Reemplazados con métodos válidos de Supabase');
  } else {
    print('ℹ️  No se requieren cambios en: $filePath');
  }