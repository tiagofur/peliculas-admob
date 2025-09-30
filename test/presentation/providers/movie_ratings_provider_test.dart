import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/syncable_movie_rating.dart';
import 'package:peliculas/domain/repositories/movie_ratings_repository.dart';
import 'package:peliculas/presentation/providers/movie_ratings_provider.dart';

class _FakeMovieRatingsRepository implements MovieRatingsRepository {
  _FakeMovieRatingsRepository({
    List<SyncableMovieRating>? ratings,
    Map<String, dynamic>? stats,
  })  : _ratings = ratings ?? const [],
        _stats = stats ??
            const {
              'totalRatings': 0,
              'averageRating': 0.0,
              'highestRating': 0.0,
              'lowestRating': 0.0,
              'ratingsWithReview': 0,
              'publicRatings': 0,
              'recentRatingsCount': 0,
            };

  final List<SyncableMovieRating> _ratings;
  final Map<String, dynamic> _stats;

  @override
  Future<void> rateMovie({
    required Movie movie,
    required double rating,
    String? review,
    bool isPublic = false,
    List<String> tags = const [],
  }) async {}

  @override
  Future<void> updateRating({
    required int movieId,
    required double rating,
    String? review,
    bool? isPublic,
    List<String>? tags,
  }) async {}

  @override
  Future<void> removeRating(int movieId) async {}

  @override
  Future<SyncableMovieRating?> getUserRating(int movieId) async => null;

  @override
  Future<bool> hasUserRatedMovie(int movieId) async => false;

  @override
  Future<List<SyncableMovieRating>> getUserRatings({
    int limit = 50,
    int offset = 0,
  }) async =>
      _ratings;

  @override
  Future<List<SyncableMovieRating>> getUserRatingsSorted({
    bool ascending = false,
    int limit = 50,
    int offset = 0,
  }) async =>
      _ratings;

  @override
  Future<List<SyncableMovieRating>> getUserRatingsByRating({
    double? minRating,
    double? maxRating,
    int limit = 50,
    int offset = 0,
  }) async =>
      _ratings;

  @override
  Future<List<SyncableMovieRating>> getUserRatingsWithReviews({
    int limit = 50,
    int offset = 0,
  }) async =>
      _ratings;

  @override
  Future<List<SyncableMovieRating>> getUserPublicRatings({
    int limit = 50,
    int offset = 0,
  }) async =>
      _ratings;

  @override
  Future<Map<String, dynamic>> getUserRatingStats() async => _stats;

  @override
  Future<List<SyncableMovieRating>> searchRatingsByTags({
    required List<String> tags,
    int limit = 50,
    int offset = 0,
  }) async =>
      _ratings;

  @override
  Future<List<SyncableMovieRating>> searchRatingsByReviewText({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async =>
      _ratings;

  @override
  Future<List<SyncableMovieRating>> getRecentRatings({
    int days = 30,
    int limit = 20,
  }) async =>
      _ratings;

  @override
  Future<List<Map<String, dynamic>>> exportUserRatings() async => const [];

  @override
  Future<void> importUserRatings(
      List<Map<String, dynamic>> ratingsData) async {}

  @override
  Stream<List<SyncableMovieRating>> watchUserRatings() =>
      Stream.value(_ratings);

  @override
  Stream<SyncableMovieRating?> watchUserRating(int movieId) =>
      Stream.value(null);

  @override
  Future<Map<String, dynamic>?> getMovieRatingSummary(int movieId) async =>
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('movieRatingsProvider initializes without accessing uninitialized state',
      () async {
    final container = ProviderContainer(
      overrides: [
        movieRatingsRepositoryProvider.overrideWithValue(
          _FakeMovieRatingsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Reading the provider should not throw
    final initialState = container.read(movieRatingsProvider);
    expect(initialState, const MovieRatingsState());

    // Allow microtasks to complete initialization
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(movieRatingsProvider);
    expect(state.isLoading, isFalse);
    expect(state.userRatings, isEmpty);
  });
}
