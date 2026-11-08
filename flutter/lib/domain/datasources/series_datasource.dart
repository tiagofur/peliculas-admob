import '../entities/entities.dart';

abstract class SeriesDatasource {
  Future<List<Serie>> getPopular({int page = 1});

  Future<List<Serie>> getTopRated({int page = 1});

  Future<List<Serie>> getOnTheAir({int page = 1});

  Future<List<Serie>> getAiringToday({int page = 1});

  Future<Serie> getSerieById(String id);

  Future<List<Temporada>> getSeasons(int serieId);

  Future<Temporada> getSeason(int serieId, int seasonNumber);

  Future<List<Episodio>> getEpisodes(int serieId, int seasonNumber);

  Future<List<Serie>> searchSeries(String query);

  Future<List<Serie>> getSimilarSeries(int serieId);
}
