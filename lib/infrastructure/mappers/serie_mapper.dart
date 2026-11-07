import '../../domain/entities/episodio.dart';
import '../../domain/entities/serie.dart';
import '../../domain/entities/temporada.dart';
import '../models/moviedb/serie_moviedb.dart';
import '../models/trakt/show_trakt.dart';

class SerieMapper {
  static Serie serieDBToEntity(SerieMovieDB db) => Serie(
        id: db.id,
        name: db.name,
        originalName: db.originalName,
        overview: db.overview,
        posterPath: db.posterPath,
        backdropPath: db.backdropPath,
        firstAirDate: db.firstAirDate,
        originCountry: db.originCountry,
        genreIds: db.genreIds,
        voteAverage: db.voteAverage,
        voteCount: db.voteCount,
        popularity: db.popularity,
        originalLanguage: db.originalLanguage,
      );

  static Serie serieDetailsToEntity(Map<String, dynamic> json) =>
      Serie.fromJson(json);

  static Temporada seasonToEntity(int serieId, Map<String, dynamic> json) =>
      Temporada.fromJson(serieId, json);

  static Episodio episodeToEntity(
    int serieId,
    int seasonNumber,
    Map<String, dynamic> json,
  ) =>
      Episodio.fromJson(serieId, seasonNumber, json);

  static Serie showTraktToEntity(ShowTrakt show) => Serie(
        id: show.ids.tmdb ?? 0,
        name: show.title,
        originalName: show.title,
        overview: show.overview ?? '',
        firstAirDate: show.firstAired,
        originCountry:
            show.country != null ? [show.country!] : const [],
        voteAverage: show.rating ?? 0.0,
        voteCount: show.votes ?? 0,
        originalLanguage: show.language ?? '',
        numberOfEpisodes: show.airedEpisodes ?? 0,
        status: show.status ?? '',
        networks: show.network != null ? [show.network!] : const [],
      );
}
