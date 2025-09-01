import '../../domain/entities/movie.dart';
import '../models/trakt/trakt_models.dart';
import '../services/tmdb_image_service.dart';

class TraktMovieMapper {
  static final TmdbImageService _imageService = TmdbImageService();

  static Future<Movie> toEntity(MovieTrakt traktMovie) async {
    // Obtener imágenes usando TMDB ID si está disponible
    final images =
        await _imageService.getMovieImagesWithCache(traktMovie.ids.tmdb);

    return Movie(
      adult: false, // Trakt no maneja este campo explícitamente
      backdropPath: images.backdropUrl ?? '',
      genreIds: traktMovie.genres ?? [],
      id: traktMovie.ids.trakt,
      originalLanguage: traktMovie.language ?? 'en',
      originalTitle: traktMovie.title,
      overview: traktMovie.overview ?? '',
      popularity: traktMovie.watchers?.toDouble() ?? 0.0,
      posterPath: images.posterUrl ?? '',
      releaseDate: traktMovie.released ?? DateTime.now(),
      title: traktMovie.title,
      video: false,
      voteAverage: traktMovie.rating ?? 0.0,
      voteCount: traktMovie.votes ?? 0,
      runtime: traktMovie.runtime,
      homepage: traktMovie.homepage,
      imdbId: traktMovie.ids.imdb,
      status:
          'Released', // Por defecto, ya que Trakt no tiene este campo específico
      tagline: '', // Trakt no proporciona tagline directamente
    );
  }

  static MovieTrakt fromEntity(Movie movie) {
    return MovieTrakt(
      title: movie.title,
      year: movie.releaseDate.year,
      ids: TraktIds(
        trakt: movie.id,
        imdb: movie.imdbId,
        tmdb: null, // Se podría mapear si tienes la referencia
      ),
      overview: movie.overview.isNotEmpty ? movie.overview : null,
      released: movie.releaseDate,
      runtime: movie.runtime,
      homepage: movie.homepage,
      rating: movie.voteAverage > 0 ? movie.voteAverage : null,
      votes: movie.voteCount > 0 ? movie.voteCount : null,
      genres: movie.genreIds,
      language: movie.originalLanguage,
    );
  }

  static Future<List<Movie>> toEntityList(List<MovieTrakt> traktMovies) async {
    final List<Movie> movies = [];

    for (final traktMovie in traktMovies) {
      final movie = await toEntity(traktMovie);
      movies.add(movie);
    }

    return movies;
  }

  static List<MovieTrakt> fromEntityList(List<Movie> movies) {
    return movies.map((movie) => fromEntity(movie)).toList();
  }
}

class TraktPersonMapper {
  static Map<String, dynamic> toActorMap(TraktPerson person) {
    return {
      'id': person.ids.trakt,
      'name': person.name,
      'profile_path': person.tmdbImageUrl ?? '',
      'character': '', // Este campo se establece en el contexto del cast
    };
  }

  static Map<String, dynamic> toCrewMap(TraktPerson person, String job) {
    return {
      'id': person.ids.trakt,
      'name': person.name,
      'profile_path': person.tmdbImageUrl ?? '',
      'job': job,
      'department': _getDepartmentFromJob(job),
    };
  }

  static String _getDepartmentFromJob(String job) {
    switch (job.toLowerCase()) {
      case 'director':
        return 'Directing';
      case 'producer':
      case 'executive producer':
        return 'Production';
      case 'writer':
      case 'screenplay':
        return 'Writing';
      case 'cinematographer':
      case 'director of photography':
        return 'Camera';
      case 'editor':
        return 'Editing';
      case 'composer':
      case 'music':
        return 'Sound';
      default:
        return 'Crew';
    }
  }
}
