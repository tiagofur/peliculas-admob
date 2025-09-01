class TraktResponse<T> {
  TraktResponse({
    required this.results,
    this.totalResults,
    this.totalPages,
    this.currentPage,
  });

  factory TraktResponse.fromJson(
    List<dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) =>
      TraktResponse(
        results: json
            .map((item) => fromJsonT(item as Map<String, dynamic>))
            .toList(),
        totalResults: json.length,
        totalPages: 1,
        currentPage: 1,
      );

  final List<T> results;
  final int? totalResults;
  final int? totalPages;
  final int? currentPage;
}

class TraktListResponse<T> {
  TraktListResponse({
    required this.items,
    this.name,
    this.description,
    this.privacy,
    this.displayNumbers,
    this.allowComments,
    this.sortBy,
    this.sortHow,
    this.createdAt,
    this.updatedAt,
    this.itemCount,
    this.commentCount,
    this.likeCount,
    this.ids,
    this.user,
  });

  factory TraktListResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) =>
      TraktListResponse(
        items: json['items'] != null
            ? (json['items'] as List).map((item) => fromJsonT(item)).toList()
            : <T>[],
        name: json['name'],
        description: json['description'],
        privacy: json['privacy'],
        displayNumbers: json['display_numbers'],
        allowComments: json['allow_comments'],
        sortBy: json['sort_by'],
        sortHow: json['sort_how'],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'])
            : null,
        itemCount: json['item_count'],
        commentCount: json['comment_count'],
        likeCount: json['like_count'],
        ids: json['ids'] != null ? TraktListIds.fromJson(json['ids']) : null,
        user: json['user'],
      );

  final List<T> items;
  final String? name;
  final String? description;
  final String? privacy;
  final bool? displayNumbers;
  final bool? allowComments;
  final String? sortBy;
  final String? sortHow;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? itemCount;
  final int? commentCount;
  final int? likeCount;
  final TraktListIds? ids;
  final Map<String, dynamic>? user;
}

class TraktListIds {
  TraktListIds({
    required this.trakt,
    this.slug,
  });

  factory TraktListIds.fromJson(Map<String, dynamic> json) => TraktListIds(
        trakt: json['trakt'] ?? 0,
        slug: json['slug'],
      );

  final int trakt;
  final String? slug;

  Map<String, dynamic> toJson() => {
        'trakt': trakt,
        'slug': slug,
      };
}

class TraktSearchResult {
  TraktSearchResult({
    this.type,
    this.score,
    this.movie,
    this.show,
    this.person,
  });

  factory TraktSearchResult.fromJson(Map<String, dynamic> json) =>
      TraktSearchResult(
        type: json['type'],
        score: json['score']?.toDouble(),
        movie: json['movie'],
        show: json['show'],
        person: json['person'],
      );

  final String? type;
  final double? score;
  final Map<String, dynamic>? movie;
  final Map<String, dynamic>? show;
  final Map<String, dynamic>? person;
}

class TraktStats {
  TraktStats({
    this.watchers,
    this.plays,
    this.collectors,
    this.collectedEpisodes,
    this.comments,
    this.lists,
    this.votes,
  });

  factory TraktStats.fromJson(Map<String, dynamic> json) => TraktStats(
        watchers: json['watchers'],
        plays: json['plays'],
        collectors: json['collectors'],
        collectedEpisodes: json['collected_episodes'],
        comments: json['comments'],
        lists: json['lists'],
        votes: json['votes'],
      );

  final int? watchers;
  final int? plays;
  final int? collectors;
  final int? collectedEpisodes;
  final int? comments;
  final int? lists;
  final int? votes;

  Map<String, dynamic> toJson() => {
        'watchers': watchers,
        'plays': plays,
        'collectors': collectors,
        'collected_episodes': collectedEpisodes,
        'comments': comments,
        'lists': lists,
        'votes': votes,
      };
}
