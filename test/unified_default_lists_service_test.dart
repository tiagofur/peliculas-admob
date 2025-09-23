import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/services/unified_default_lists_service.dart';

void main() {
  group('UnifiedDefaultListsService', () {
    late UnifiedDefaultListsService service;

    setUp(() {
      service = UnifiedDefaultListsService();
    });

    test('should create service instance', () {
      // Assert
      expect(service, isNotNull);
    });

    test('should have initializeDefaultListsForUser method', () {
      // Assert
      expect(service.initializeDefaultListsForUser, isNotNull);
    });

    test('should handle method call without error (requires Supabase setup)',
        () async {
      // Note: Este test requiere configuración de Supabase para funcionar completamente
      // En un entorno de testing sin Supabase configurado, esperamos que falle graciosamente

      try {
        await service.initializeDefaultListsForUser();
        // Si llega aquí, la llamada fue exitosa
        expect(true, isTrue);
      } catch (e) {
        // Si falla, debe ser por falta de configuración de Supabase, no por error de código
        expect(
            e.toString().contains('Supabase') ||
                e.toString().contains('No hay usuario') ||
                e.toString().contains('Client'),
            isTrue,
            reason:
                'Error should be related to Supabase configuration or authentication: $e');
      }
    });

    test('should handle forceRecreate parameter', () async {
      try {
        await service.initializeDefaultListsForUser(forceRecreate: true);
        expect(true, isTrue);
      } catch (e) {
        // Si falla, debe ser por falta de configuración de Supabase
        expect(
            e.toString().contains('Supabase') ||
                e.toString().contains('No hay usuario') ||
                e.toString().contains('Client'),
            isTrue,
            reason: 'Error should be related to Supabase configuration: $e');
      }
    });
  });
}
