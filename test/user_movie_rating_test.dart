import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/user_movie_rating.dart';

void main() {
  group('UserMovieRating Tests', () {
    test('should create UserMovieRating from valid data', () {
      final rating = UserMovieRating(
        id: 'test-id',
        userId: 'user-123',
        movieId: 12345,
        movieTitle: 'Test Movie',
        moviePosterPath: '/test.jpg',
        rating: 4,
        personalNote: 'Great movie!',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(rating.id, equals('test-id'));
      expect(rating.movieId, equals(12345));
      expect(rating.rating, equals(4));
      expect(rating.personalNote, equals('Great movie!'));
      expect(rating.isValid, isTrue);
    });

    test('should validate rating range', () {
      final validRating = UserMovieRating(
        id: 'test-id',
        userId: 'user-123',
        movieId: 12345,
        movieTitle: 'Test Movie',
        rating: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(validRating.isValidRating, isTrue);

      final invalidRating = validRating.copyWith(rating: 6);
      expect(invalidRating.isValidRating, isFalse);

      final zeroRating = validRating.copyWith(rating: 0);
      expect(zeroRating.isValidRating, isFalse);
    });

    test('should validate note length', () {
      final shortNote = UserMovieRating(
        id: 'test-id',
        userId: 'user-123',
        movieId: 12345,
        movieTitle: 'Test Movie',
        rating: 4,
        personalNote: 'Short note',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(shortNote.isValidNote, isTrue);

      final longNote = 'x' * 501; // 501 characters
      final invalidNoteRating = shortNote.copyWith(personalNote: longNote);
      expect(invalidNoteRating.isValidNote, isFalse);
    });

    test('should convert to and from JSON correctly', () {
      final originalRating = UserMovieRating(
        id: 'test-id',
        userId: 'user-123',
        movieId: 12345,
        movieTitle: 'Test Movie',
        moviePosterPath: '/test.jpg',
        rating: 4,
        personalNote: 'Great movie!',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final json = originalRating.toJson();
      final recreatedRating = UserMovieRating.fromJson(json);

      expect(recreatedRating.id, equals(originalRating.id));
      expect(recreatedRating.movieId, equals(originalRating.movieId));
      expect(recreatedRating.rating, equals(originalRating.rating));
      expect(recreatedRating.personalNote, equals(originalRating.personalNote));
    });

    test('should create proper Supabase insert map', () {
      final rating = UserMovieRating(
        id: 'test-id',
        userId: 'user-123',
        movieId: 12345,
        movieTitle: 'Test Movie',
        moviePosterPath: '/test.jpg',
        rating: 4,
        personalNote: 'Great movie!',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final insertMap = rating.toSupabaseInsert();

      expect(insertMap['user_id'], equals('user-123'));
      expect(insertMap['movie_id'], equals(12345));
      expect(insertMap['rating'], equals(4));
      expect(insertMap['personal_note'], equals('Great movie!'));
      
      // Should not include id, created_at, updated_at for insert
      expect(insertMap.containsKey('id'), isFalse);
      expect(insertMap.containsKey('created_at'), isFalse);
      expect(insertMap.containsKey('updated_at'), isFalse);
    });

    test('should create copyWith correctly', () {
      final originalRating = UserMovieRating(
        id: 'test-id',
        userId: 'user-123',
        movieId: 12345,
        movieTitle: 'Test Movie',
        rating: 4,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final modifiedRating = originalRating.copyWith(
        rating: 5,
        personalNote: 'Updated note',
      );

      expect(modifiedRating.rating, equals(5));
      expect(modifiedRating.personalNote, equals('Updated note'));
      expect(modifiedRating.id, equals(originalRating.id)); // Unchanged
      expect(modifiedRating.movieId, equals(originalRating.movieId)); // Unchanged
    });
  });
}