class Video {
  Video(
      {required this.id,
      required this.name,
      required this.youtubeKey,
      required this.publishedAt});

  final String id;
  final String name;
  final String youtubeKey;
  final DateTime publishedAt;
}
