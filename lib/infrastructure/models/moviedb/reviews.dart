class Reviews {
  Reviews({
    required this.id,
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  factory Reviews.fromJson(Map<String, dynamic> json) => Reviews(
        id: json['id'] ?? 0,
        page: json['page'] ?? 1,
        results:
            List<Review>.from(json['results']?.map((x) => Review.fromJson(x)) ?? []),
        totalPages: json['total_pages'] ?? 0,
        totalResults: json['total_results'] ?? 0,
      );

  final int id;
  final int page;
  final List<Review> results;
  final int totalPages;
  final int totalResults;

  Map<String, dynamic> toJson() => {
        'id': id,
        'page': page,
        'results': List<dynamic>.from(results.map((x) => x.toJson())),
        'total_pages': totalPages,
        'total_results': totalResults,
      };
}

class Review {
  Review({
    required this.author,
    required this.authorDetails,
    required this.content,
    required this.createdAt,
    required this.id,
    required this.updatedAt,
    required this.url,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        author: json['author'] ?? '',
        authorDetails: json['author_details'] != null 
            ? AuthorDetails.fromJson(json['author_details'])
            : AuthorDetails(name: '', username: '', avatarPath: null, rating: null),
        content: json['content'] ?? '',
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        id: json['id'] ?? '',
        updatedAt: json['updated_at'] != null 
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
        url: json['url'] ?? '',
      );

  final String author;
  final AuthorDetails authorDetails;
  final String content;
  final DateTime createdAt;
  final String id;
  final DateTime updatedAt;
  final String url;

  Map<String, dynamic> toJson() => {
        'author': author,
        'author_details': authorDetails.toJson(),
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'id': id,
        'updated_at': updatedAt.toIso8601String(),
        'url': url,
      };
}

class AuthorDetails {
  AuthorDetails({
    required this.name,
    required this.username,
    required this.avatarPath,
    required this.rating,
  });

  factory AuthorDetails.fromJson(Map<String, dynamic> json) => AuthorDetails(
        name: json['name'] ?? '',
        username: json['username'] ?? '',
        avatarPath: json['avatar_path'],
        rating: json['rating']?.toDouble(),
      );

  final String name;
  final String username;
  final String? avatarPath;
  final double? rating;

  Map<String, dynamic> toJson() => {
        'name': name,
        'username': username,
        'avatar_path': avatarPath,
        'rating': rating,
      };
}