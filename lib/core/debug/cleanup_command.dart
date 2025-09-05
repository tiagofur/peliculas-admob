import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../logging/logger_factory.dart';
import '../services/hive_cleanup_service.dart';

/// Comandos de debug para limpieza manual (solo en debug mode)
class CleanupCommands {
  
  /// Comando para limpiar datos corruptos manualmente
  /// Solo disponible en modo debug
  static Future<void> cleanupCorruptedData() async {
    if (!kDebugMode) {
      LoggerFactory.warning('⚠️ Cleanup commands solo disponibles en modo debug');
      return;
    }
    
    LoggerFactory.warning('🧹 COMANDO MANUAL: Limpiando datos corruptos...');
    
    try {
      await HiveCleanupService.clearCorruptedBoxes();
      LoggerFactory.info('✅ Limpieza manual completada');
    } catch (e) {
      LoggerFactory.error('❌ Error en limpieza manual: $e');
    }
  }

  /// Comando para reset completo (DESTRUCTIVO - solo debug)
  static Future<void> resetAllData() async {
    if (!kDebugMode) {
      LoggerFactory.warning('⚠️ Reset commands solo disponibles en modo debug');
      return;
    }
    
    LoggerFactory.warning('🚨 COMANDO MANUAL: RESET COMPLETO DE DATOS...');
    
    try {
      await HiveCleanupService.resetLocalStorage();
      LoggerFactory.info('✅ Reset completo manual finalizado');
    } catch (e) {
      LoggerFactory.error('❌ Error en reset completo manual: $e');
    }
  }

  /// Comando para validar integridad
  static Future<void> validateIntegrity() async {
    if (!kDebugMode) {
      LoggerFactory.warning('⚠️ Validation commands solo disponibles en modo debug');
      return;
    }
    
    LoggerFactory.info('🔍 COMANDO MANUAL: Validando integridad de datos...');
    
    try {
      final results = await HiveCleanupService.validateDataIntegrity();
      LoggerFactory.info('📊 Resultados de validación: $results');
    } catch (e) {
      LoggerFactory.error('❌ Error en validación manual: $e');
    }
  }
}

/// Widget helper para debugging (solo disponible en debug)
class DebugCleanupWidget extends StatelessWidget {
  const DebugCleanupWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        ElevatedButton(
          onPressed: CleanupCommands.validateIntegrity,
          child: const Text('Validar Integridad'),
        ),
        ElevatedButton(
          onPressed: CleanupCommands.cleanupCorruptedData,
          child: const Text('Limpiar Datos Corruptos'),
        ),
        ElevatedButton(
          onPressed: CleanupCommands.resetAllData,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('RESET COMPLETO'),
        ),
      ],
    );
  }
}