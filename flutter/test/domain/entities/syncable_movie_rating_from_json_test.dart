import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/syncable_movie_rating.dart';

void main() {
  group('SyncableMovieRating.fromJson', () {
    test('parses snake_case payloads from remote sources', () {
      final now = DateTime.utc(2024, 1, 1, 12, 0, 0);

      final rating = SyncableMovieRating.fromJson({
        'id': 'remote-1',
        'user_id': 'user-123',
        'movie_id': 42,
        'movie_title': 'Some Movie',
        'movie_poster_path': '/poster.png',
        'movie_backdrop_path': '/backdrop.png',
        'movie_overview': 'Overview',
        'movie_release_date': now.toIso8601String(),
        'movie_vote_average': 7.1,
        'rating': 8.5,
        'review': 'Great film',
        'rated_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'last_modified_at': now.toIso8601String(),
        'is_deleted': false,
        'sync_version': 3,
        'device_id': 'device-1',
        'is_public': true,
        'tags': ['drama', 'classic'],
      });

      expect(rating.id, 'remote-1');
      expect(rating.userId, 'user-123');
      expect(rating.movieId, 42);
      expect(rating.movieTitle, 'Some Movie');
      expect(rating.moviePosterPath, '/poster.png');
      expect(rating.movieBackdropPath, '/backdrop.png');
      expect(rating.movieOverview, 'Overview');
      expect(rating.movieReleaseDate, now);
      expect(rating.movieVoteAverage, 7.1);
      expect(rating.rating, 8.5);
      expect(rating.review, 'Great film');
      expect(rating.ratedAt, now);
      expect(rating.createdAt, now);
      expect(rating.lastModifiedAt, now);
      expect(rating.isDeleted, isFalse);
      expect(rating.syncVersion, 3);
      expect(rating.deviceId, 'device-1');
      expect(rating.isPublic, isTrue);
      expect(rating.tags, ['drama', 'classic']);
    });

    test('parses camelCase payloads persisted in Hive local storage', () {
      final now = DateTime.utc(2024, 2, 2, 10, 0, 0);

      final rating = SyncableMovieRating.fromJson({
        'id': 'local-99',
        'userId': 'local-user',
        'movieId': '777', // stored as string
        'movieTitle': 'Local Movie',
        'moviePosterPath': '/poster_local.png',
        'movieBackdropPath': '/backdrop_local.png',
        'movieOverview': 'Local Overview',
        'movieReleaseDate': now.toIso8601String(),
        'movieVoteAverage': '6.2',
        'rating': '9.0',
        'review': null,
        'ratedAt': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'lastModifiedAt': now.toIso8601String(),
        'isDeleted': 0,
        'syncVersion': '5',
        'deviceId': 'device-local',
        'isPublic': 'true',
        'tags': ['thriller'],
      });

      expect(rating.id, 'local-99');
      expect(rating.userId, 'local-user');
      expect(rating.movieId, 777);
      expect(rating.movieTitle, 'Local Movie');
      expect(rating.moviePosterPath, '/poster_local.png');
      expect(rating.movieBackdropPath, '/backdrop_local.png');
      expect(rating.movieOverview, 'Local Overview');
      expect(rating.movieReleaseDate, now);
      expect(rating.movieVoteAverage, 6.2);
      expect(rating.rating, 9.0);
      expect(rating.review, isNull);
      expect(rating.ratedAt, now);
      expect(rating.createdAt, now);
      expect(rating.lastModifiedAt, now);
      expect(rating.isDeleted, isFalse);
      expect(rating.syncVersion, 5);
      expect(rating.deviceId, 'device-local');
      expect(rating.isPublic, isTrue);
      expect(rating.tags, ['thriller']);
    });
  });
}
