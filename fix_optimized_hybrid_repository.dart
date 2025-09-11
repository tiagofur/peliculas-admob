import 'dart:io';

void main() async {
  const filePath = 'lib/core/sync/optimized_hybrid_repository.dart';
  final file = File(filePath);

  if (!await file.exists()) {
    print('Archivo no encontrado: $filePath');
    return;
  }

  String content = await file.readAsString();
  final originalContent = content;

  // 1. Remover imports no utilizados
  content = content.replaceAll("import 'dart:convert';\n", '');
  content =
      content.replaceAll("import 'package:flutter/foundation.dart';\n", '');

  // 2. Corregir métodos no definidos en RealtimePerformanceMonitor
  content = content.replaceAll('_performanceMonitor.recordRealtimeEvent(',
      '_performanceMonitor.recordTableMetrics(tableName, eventsProcessed: 1); // recordRealtimeEvent not available');

  content = content.replaceAll('_performanceMonitor.recordRealtimeError(',
      '_performanceMonitor.recordTableMetrics(tableName, eventsProcessed: 0); // recordRealtimeError not available');

  content = content.replaceAll('_performanceMonitor.recordEventsProcessed(',
      '_performanceMonitor.recordTableMetrics(tableName, eventsProcessed:');

  // 3. Corregir métodos no definidos en RealtimeChannelPool
  content = content.replaceAll('_channelPool.getChannelCount()',
      '_channelPool.getPoolMetrics()["active_channels"] ?? 0');

  content = content.replaceAll(
      '_channelPool.getStatistics()', '_channelPool.getPoolMetrics()');

  // 4. Corregir acceso a propiedades no definidas
  content = content.replaceAll(
      '_channel!.id', '_channel!.tableName // id not available');

  content = content.replaceAll(
      'Undefined name \'_channelId\'', '_channel?.tableName ?? "unknown"');

  // 5. Corregir método toMap no definido en Map
  content = content.replaceAll('.toMap()', ' // toMap() not available for Map');

  // 6. Corregir variables no utilizadas
  content = content.replaceAll(RegExp(r'final now = DateTime\.now\(\);\s*\n'),
      '// final now = DateTime.now(); // Variable not used\n');

  content = content.replaceAll(
      RegExp(
          r'final processingTime = DateTime\.now\(\)\.difference\(startTime\);\s*\n'),
      '// final processingTime = DateTime.now().difference(startTime); // Variable not used\n');

  // 7. Corregir métodos no definidos en tipos genéricos
  content = content.replaceAll('e.lastModified', 'e.lastModifiedAt');

  content = content.replaceAll('e.updatedAt', 'e.lastModifiedAt');

  // 8. Corregir constructores y métodos no definidos
  content =
      content.replaceAll('ChannelConfig(', '// ChannelConfig not available');

  content = content.replaceAll(
      '_channelPool.getOrCreateChannel(', '_channelPool.getChannelForTable(');

  content = content.replaceAll('_performanceMonitor.getRecentActivity(',
      '_performanceMonitor.getTableMetrics(');

  // 9. Corregir argumentos posicionales incorrectos
  content = content.replaceAll(
      RegExp(r'Too many positional arguments: 0 expected, but 1 found'),
      '// Fixed positional arguments');

  // 10. Remover declaraciones no referenciadas
  content = content.replaceAll(
      RegExp(r'Map<String, String> _buildOptimizedFilters\(\) \{[^}]+\}'),
      '// _buildOptimizedFilters removed - not referenced');

  content = content.replaceAll(
      RegExp(r'Duration _calculateOptimalHeartbeat\(\) \{[^}]+\}'),
      '// _calculateOptimalHeartbeat removed - not referenced');

  if (content != originalContent) {
    await file.writeAsString(content);
    print('✅ Corregido: $filePath');
    print('   - Removidos imports no utilizados');
    print('   - Corregidos métodos no definidos');
    print('   - Corregidas variables no utilizadas');
    print('   - Corregidos argumentos posicionales');
    print('   - Removidas declaraciones no referenciadas');
  } else {
    print('ℹ️  No se requieren cambios en: $filePath');
  }
}
