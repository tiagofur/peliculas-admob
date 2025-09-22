import '../../domain/entities/movie.dart';
import '../models/moviedb/movie_details.dart';
import '../models/moviedb/movie_moviedb.dart';

class MovieMapper {
  // Mapeo de IDs de géneros TMDB a nombres
  static const Map<int, String> genreMap = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western'
  };

  /// Convierte IDs de géneros a nombres
  static List<String> getGenreNames(List<int> genreIds) {
    return genreIds
        .map((id) => genreMap[id] ?? 'Unknown')
        .where((genre) => genre != 'Unknown')
        .toList();
  }

  static Movie movieDBToEntity(MovieMovieDB moviedb) => Movie(
      adult: moviedb.adult,
      backdropPath: (moviedb.backdropPath != '')
          ? 'https://image.tmdb.org/t/p/w500${moviedb.backdropPath}'
          : 'https://sd.keepcalms.com/i-w600/keep-calm-poster-not-found.jpg',
      genreIds: getGenreNames(moviedb.genreIds),
      id: moviedb.id,
      originalLanguage: moviedb.originalLanguage,
      originalTitle: moviedb.originalTitle,
      overview: moviedb.overview,
      popularity: moviedb.popularity,
      posterPath: (moviedb.posterPath != '')
          ? 'https://image.tmdb.org/t/p/w500${moviedb.posterPath}'
          : 'https://www.movienewz.com/img/films/poster-holder.jpg',
      releaseDate: moviedb.releaseDate ?? DateTime.now(),
      title: moviedb.title,
      video: moviedb.video,
      voteAverage: moviedb.voteAverage,
      voteCount: moviedb.voteCount);

  static Movie movieDetailsToEntity(MovieDetails moviedb) => Movie(
      adult: moviedb.adult,
      backdropPath: (moviedb.backdropPath.isNotEmpty)
          ? 'https://image.tmdb.org/t/p/w500${moviedb.backdropPath}'
          : 'https://sd.keepcalms.com/i-w600/keep-calm-poster-not-found.jpg',
      genreIds: moviedb.genres.map((e) => e.name).toList(),
      id: moviedb.id,
      originalLanguage: moviedb.originalLanguage,
      originalTitle: moviedb.originalTitle,
      overview: moviedb.overview ?? '',
      popularity: moviedb.popularity ?? 0.0,
      posterPath: (moviedb.posterPath?.isNotEmpty == true)
          ? 'https://image.tmdb.org/t/p/w500${moviedb.posterPath}'
          : 'https://sd.keepcalms.com/i-w600/keep-calm-poster-not-found.jpg',
      releaseDate: moviedb.releaseDate ?? DateTime.now(),
      title: moviedb.title,
      video: moviedb.video,
      voteAverage: moviedb.voteAverage ?? 0.0,
      voteCount: moviedb.voteCount ?? 0,
      // Campos opcionales que pueden ser null
      runtime: moviedb.runtime,
      budget: moviedb.budget,
      revenue: moviedb.revenue,
      homepage: moviedb.homepage?.isNotEmpty == true ? moviedb.homepage : null,
      imdbId: moviedb.imdbId?.isNotEmpty == true ? moviedb.imdbId : null,
      status: moviedb.status.isNotEmpty ? moviedb.status : null,
      tagline: moviedb.tagline.isNotEmpty ? moviedb.tagline : null,
      // Listas de producción - verificar que no estén vacías y manejar elementos null
      productionCompanies: moviedb.productionCompanies.isNotEmpty
          ? moviedb.productionCompanies
              .where((e) => e.name.isNotEmpty)
              .map((e) => e.name)
              .toList()
          : null,
      productionCountries: moviedb.productionCountries.isNotEmpty
          ? moviedb.productionCountries
              .where((e) => e.name.isNotEmpty)
              .map((e) => e.name)
              .toList()
          : null,
      spokenLanguages: moviedb.spokenLanguages.isNotEmpty
          ? moviedb.spokenLanguages
              .where((e) => e.name.isNotEmpty)
              .map((e) => e.name)
              .toList()
          : null,
      belongsToCollection: moviedb.belongsToCollection?.name,
      // Datos adicionales de append_to_response
      credits: moviedb.credits?.toJson(),
      images: moviedb.images?.toJson(),
      reviews: moviedb.reviews?.toJson(),
      similar: moviedb.similar,
      watchProviders: moviedb.watchProviders);
}
