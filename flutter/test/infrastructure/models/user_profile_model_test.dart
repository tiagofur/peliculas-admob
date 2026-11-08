import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/infrastructure/models/user_profile_model.dart';

void main() {
  group('UserProfileModel', () {
    test('fromJson falls back to display_name and normalizes username', () {
      final now = DateTime.now().toUtc();
      final profile = UserProfileModel.fromJson({
        'id': 'profile-1',
        'user_id': 'user-123',
        'display_name': '  CineFan  ',
        'username': ' Cine_Fan ',
        'avatar_url': 'https://example.com/avatar.png',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      expect(profile.fullName, equals('CineFan'));
      expect(profile.username, equals('cine_fan'));
      expect(profile.bio, isNull);
      expect(profile.stats, isEmpty);
      expect(profile.preferences, isEmpty);
    });

    test('toInsertJson serializes display_name and normalized username', () {
      final profile = UserProfileModel.create(
        userId: 'user-456',
        fullName: 'Test User',
        username: 'Test_User',
      );

      final json = profile.toInsertJson();

      expect(json['display_name'], equals('Test User'));
      expect(json['username'], equals('test_user'));
      expect(json.containsKey('stats'), isFalse);
      expect(json.containsKey('preferences'), isFalse);
      expect(json.containsKey('full_name'), isFalse);
    });
  });
}
