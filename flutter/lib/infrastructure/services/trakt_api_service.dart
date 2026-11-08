import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_keys.dart';
import '../models/trakt/trakt_models.dart';

class TraktApiService {
  static const String _baseUrl = 'https://api.trakt.tv';
  static const String _apiVersion = '2';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'trakt-api-version': _apiVersion,
        'trakt-api-key': ApiKeys.traktApiKey,
      };

  Map<String, String> get _headersWithAuth => {
        ..._headers,
        'Authorization': 'Bearer $accessToken',
      };

  String? accessToken;

  // MOVIES

  /// Get popular movies
  Future<List<MovieTrakt>> getPopularMovies(
      {int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movies/popular?page=$page&limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((movie) => MovieTrakt.fromJson(movie)).toList();
      } else {
        throw Exception(
            'Failed to load popular movies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching popular movies: $e');
    }
  }

  /// Get trending movies
  Future<List<MovieTrakt>> getTrendingMovies(
      {int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movies/trending?page=$page&limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData
            .map((item) => MovieTrakt.fromJson(item['movie']))
            .toList();
      } else {
        throw Exception(
            'Failed to load trending movies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching trending movies: $e');
    }
  }

  /// Get movie details
  Future<MovieTrakt> getMovieDetails(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movies/$id?extended=full'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return MovieTrakt.fromJson(jsonData);
      } else {
        throw Exception('Failed to load movie details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching movie details: $e');
    }
  }

  /// Search movies
  Future<List<MovieTrakt>> searchMovies(String query,
      {int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/search/movie?query=${Uri.encodeComponent(query)}&page=$page&limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData
            .map((item) => MovieTrakt.fromJson(item['movie']))
            .toList();
      } else {
        throw Exception('Failed to search movies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching movies: $e');
    }
  }

  /// Get movie recommendations
  Future<List<MovieTrakt>> getMovieRecommendations(String id,
      {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movies/$id/related?limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((movie) => MovieTrakt.fromJson(movie)).toList();
      } else {
        throw Exception(
            'Failed to load movie recommendations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching movie recommendations: $e');
    }
  }

  // SHOWS

  /// Get popular shows
  Future<List<ShowTrakt>> getPopularShows(
      {int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/shows/popular?page=$page&limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((show) => ShowTrakt.fromJson(show)).toList();
      } else {
        throw Exception('Failed to load popular shows: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching popular shows: $e');
    }
  }

  /// Get trending shows
  Future<List<ShowTrakt>> getTrendingShows(
      {int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/shows/trending?page=$page&limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData
            .map((item) => ShowTrakt.fromJson(item['show']))
            .toList();
      } else {
        throw Exception(
            'Failed to load trending shows: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching trending shows: $e');
    }
  }

  /// Search shows
  Future<List<ShowTrakt>> searchShows(String query,
      {int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/search/show?query=${Uri.encodeComponent(query)}&page=$page&limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData
            .map((item) => ShowTrakt.fromJson(item['show']))
            .toList();
      } else {
        throw Exception('Failed to search shows: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching shows: $e');
    }
  }

  // PEOPLE

  /// Search people
  Future<List<TraktPerson>> searchPeople(String query,
      {int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/search/person?query=${Uri.encodeComponent(query)}&page=$page&limit=$limit'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData
            .map((item) => TraktPerson.fromJson(item['person']))
            .toList();
      } else {
        throw Exception('Failed to search people: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching people: $e');
    }
  }

  // GENRES

  /// Get movie genres
  Future<List<String>> getMovieGenres() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/genres/movies'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((genre) => genre['name'] as String).toList();
      } else {
        throw Exception('Failed to load movie genres: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching movie genres: $e');
    }
  }

  /// Get show genres
  Future<List<String>> getShowGenres() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/genres/shows'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((genre) => genre['name'] as String).toList();
      } else {
        throw Exception('Failed to load show genres: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching show genres: $e');
    }
  }

  // AUTHENTICATION (OAuth 2.0)

  /// Generate OAuth URL for user authorization
  String getAuthorizationUrl({required String redirectUri}) {
    final params = {
      'response_type': 'code',
      'client_id': ApiKeys.traktClientId,
      'redirect_uri': redirectUri,
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://trakt.tv/oauth/authorize?$query';
  }

  /// Exchange authorization code for access token
  Future<bool> getAccessToken(String code, String redirectUri) async {
    try {
      final response = await http.post(
        Uri.parse('https://trakt.tv/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': code,
          'client_id': ApiKeys.traktClientId,
          'client_secret': ApiKeys.traktClientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        accessToken = jsonData['access_token'];
        return true;
      } else {
        throw Exception('Failed to get access token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting access token: $e');
    }
  }

  // USER DATA (requires authentication)

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (accessToken == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get user profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching user profile: $e');
    }
  }

  /// Get user's watched movies
  Future<List<MovieTrakt>> getUserWatchedMovies() async {
    if (accessToken == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me/watched/movies'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData
            .map((item) => MovieTrakt.fromJson(item['movie']))
            .toList();
      } else {
        throw Exception('Failed to get watched movies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching watched movies: $e');
    }
  }

  /// Mark movie as watched
  Future<bool> markMovieAsWatched(String movieId) async {
    if (accessToken == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sync/history'),
        headers: _headersWithAuth,
        body: json.encode({
          'movies': [
            {
              'ids': {'trakt': int.parse(movieId)},
              'watched_at': DateTime.now().toIso8601String(),
            }
          ]
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      throw Exception('Error marking movie as watched: $e');
    }
  }
}
