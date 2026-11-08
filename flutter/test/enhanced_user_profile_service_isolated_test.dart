import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/services/enhanced_user_profile_service.dart';

/// Test aislado para validar la funcionalidad básica del servicio de perfil de usuario
/// sin dependencias externas problemáticas
void main() {
  group('EnhancedUserProfileService - Isolated Tests', () {
    test('should create service instance', () {
      // Act
      final service = EnhancedUserProfileService.instance;

      // Assert
      expect(service, isNotNull);
      expect(service, isA<EnhancedUserProfileService>());
    });

    test('should return singleton instance', () {
      // Act
      final service1 = EnhancedUserProfileService.instance;
      final service2 = EnhancedUserProfileService.instance;

      // Assert
      expect(service1, same(service2));
    });

    test('should handle basic user profile generation', () async {
      // Arrange
      final service = EnhancedUserProfileService.instance;
      const userId = 'test_user_basic';
      const displayName = 'Basic User';

      // Act & Assert - no debería lanzar excepción
      expect(
        () async {
          final profile = await service.getUserProfile(
            userId,
            displayName: displayName,
          );
          expect(profile, isNotNull);
          expect(profile.id, equals(userId));
          expect(profile.displayName, equals(displayName));
        },
        returnsNormally,
      );
    });
  });
}
