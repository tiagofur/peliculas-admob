import '../../domain/datasources/series_datasource.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/series_repository.dart';

class SeriesRepositoryImpl extends SeriesRepository {
  SeriesRepositoryImpl(this.datasource);

  final SeriesDatasource datasource;

  @override
  Future<List<Serie>> getPopular({int page = 1}) {
    return datasource.getPopular(page: page);
  }

  @override
  Future<List<Serie>> getTopRated({int page = 1}) {
    return datasource.getTopRated(page: page);
  }

  @override
  Future<List<Serie>> getOnTheAir({int page = 1}) {
    return datasource.getOnTheAir(page: page);
  }

  @override
  Future<List<Serie>> getAiringToday({int page = 1}) {
    return datasource.getAiringToday(page: page);
  }

  @override
  Future<Serie> getSerieById(String id) {
    return datasource.getSerieById(id);
  }

  @override
  Future<List<Temporada>> getSeasons(int serieId) {
    return datasource.getSeasons(serieId);
  }

  @override
  Future<Temporada> getSeason(int serieId, int seasonNumber) {
    return datasource.getSeason(serieId, seasonNumber);
  }

  @override
  Future<List<Episodio>> getEpisodes(int serieId, int seasonNumber) {
    return datasource.getEpisodes(serieId, seasonNumber);
  }

  @override
  Future<List<Serie>> searchSeries(String query) {
    return datasource.searchSeries(query);
  }

  @override
  Future<List<Serie>> getSimilarSeries(int serieId) {
    return datasource.getSimilarSeries(serieId);
  }
}
