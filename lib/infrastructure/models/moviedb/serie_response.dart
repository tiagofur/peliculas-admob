import 'serie_moviedb.dart';

class SerieDbResponse {
  SerieDbResponse({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  factory SerieDbResponse.fromJson(Map<String, dynamic> json) =>
      SerieDbResponse(
        page: (json['page'] as num?)?.toInt() ?? 0,
        results: List<SerieMovieDB>.from(
            json['results']?.map((x) => SerieMovieDB.fromJson(x)) ?? []),
        totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
        totalResults: (json['total_results'] as num?)?.toInt() ?? 0,
      );

  final int page;
  final List<SerieMovieDB> results;
  final int totalPages;
  final int totalResults;

  Map<String, dynamic> toJson() => {
        'page': page,
        'results': List<dynamic>.from(results.map((x) => x.toJson())),
        'total_pages': totalPages,
        'total_results': totalResults,
      };
}
