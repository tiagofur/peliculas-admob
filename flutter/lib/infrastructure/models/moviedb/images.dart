class Images {
  Images({
    required this.id,
    required this.backdrops,
    required this.logos,
    required this.posters,
  });

  factory Images.fromJson(Map<String, dynamic> json) => Images(
        id: json['id'] ?? 0,
        backdrops: json['backdrops'] != null
            ? List<ImageData>.from(
                json['backdrops'].map((x) => ImageData.fromJson(x)))
            : <ImageData>[],
        logos: json['logos'] != null
            ? List<ImageData>.from(
                json['logos'].map((x) => ImageData.fromJson(x)))
            : <ImageData>[],
        posters: json['posters'] != null
            ? List<ImageData>.from(
                json['posters'].map((x) => ImageData.fromJson(x)))
            : <ImageData>[],
      );

  final int id;
  final List<ImageData> backdrops;
  final List<ImageData> logos;
  final List<ImageData> posters;

  Map<String, dynamic> toJson() => {
        'id': id,
        'backdrops': List<dynamic>.from(backdrops.map((x) => x.toJson())),
        'logos': List<dynamic>.from(logos.map((x) => x.toJson())),
        'posters': List<dynamic>.from(posters.map((x) => x.toJson())),
      };
}

class ImageData {
  ImageData({
    required this.aspectRatio,
    required this.height,
    required this.iso6391,
    required this.filePath,
    required this.voteAverage,
    required this.voteCount,
    required this.width,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) => ImageData(
        aspectRatio: json['aspect_ratio']?.toDouble() ?? 0.0,
        height: json['height'] ?? 0,
        iso6391: json['iso_639_1'],
        filePath: json['file_path'] ?? '',
        voteAverage: json['vote_average']?.toDouble() ?? 0.0,
        voteCount: json['vote_count'] ?? 0,
        width: json['width'] ?? 0,
      );

  final double aspectRatio;
  final int height;
  final String? iso6391;
  final String filePath;
  final double voteAverage;
  final int voteCount;
  final int width;

  Map<String, dynamic> toJson() => {
        'aspect_ratio': aspectRatio,
        'height': height,
        'iso_639_1': iso6391,
        'file_path': filePath,
        'vote_average': voteAverage,
        'vote_count': voteCount,
        'width': width,
      };
}
