import '../entities/custom_list.dart';
import '../entities/movie.dart';

/// Repository interface for managing user's custom movie lists
/// Supports both local storage and remote sync with Supabase
abstract class CustomListsRepository {
  /// Get all custom lists for the current user
  Future<List<CustomList>> getCustomLists();

  /// Get a specific custom list by ID
  Future<CustomList?> getCustomListById(String listId);

  /// Create a new custom list
  Future<CustomList> createCustomList({
    required String name,
    String? description,
    bool isPublic = false,
  });

  /// Update an existing custom list
  Future<CustomList> updateCustomList(CustomList list);

  /// Delete a custom list
  Future<void> deleteCustomList(String listId);

  /// Add a movie to a custom list
  Future<void> addMovieToList(String listId, Movie movie);

  /// Remove a movie from a custom list
  Future<void> removeMovieFromList(String listId, int movieId);

  /// Get movies in a specific custom list
  Future<List<Movie>> getMoviesInList(String listId);

  /// Sync custom lists with remote storage (if user is authenticated)
  Future<void> syncWithRemote();

  /// Clear all local custom lists data (useful for logout)
  Future<void> clearLocalData();

  /// Check if there are pending sync operations
  Future<bool> hasPendingSync();

  /// Get default lists
  Future<List<CustomList>> getDefaultLists();

  /// Save custom lists
  Future<void> saveCustomLists(List<CustomList> lists);

  /// Save default lists
  Future<void> saveDefaultLists(List<CustomList> lists);
}
