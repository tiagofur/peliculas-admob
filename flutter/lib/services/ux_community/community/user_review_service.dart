// lib/services/ux_community/community/user_review_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/logger_factory.dart';

enum ReviewSentiment {
  positive,
  neutral,
  negative,
}

enum ReviewCategory {
  plot,
  acting,
  cinematography,
  soundtrack,
  direction,
  visualEffects,
  writing,
  overall,
}

class Review {
  const Review({
    required this.id,
    required this.movieId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.title,
    required this.content,
    this.categories = const [],
    required this.sentiment,
    this.categoryRatings = const {},
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.repliesCount = 0,
    this.isVerified = false,
    this.isSpoiler = false,
    this.isRecommended = true,
    this.parentReviewId,
    this.metadata = const {},
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      movieId: json['movieId'],
      userId: json['userId'],
      userName: json['userName'],
      userAvatar: json['userAvatar'],
      rating: json['rating']?.toDouble() ?? 0.0,
      title: json['title'],
      content: json['content'],
      categories: (json['categories'] as List<dynamic>?)
              ?.map((c) => ReviewCategory.values.firstWhere(
                    (e) => e.toString() == c,
                    orElse: () => ReviewCategory.overall,
                  ))
              .toList() ??
          [],
      sentiment: ReviewSentiment.values.firstWhere(
        (e) => e.toString() == json['sentiment'],
        orElse: () => ReviewSentiment.neutral,
      ),
      categoryRatings: Map<String, double>.from(json['categoryRatings'] ?? {}),
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      likesCount: json['likesCount'] ?? 0,
      dislikesCount: json['dislikesCount'] ?? 0,
      repliesCount: json['repliesCount'] ?? 0,
      isVerified: json['isVerified'] ?? false,
      isSpoiler: json['isSpoiler'] ?? false,
      isRecommended: json['isRecommended'] ?? true,
      parentReviewId: json['parentReviewId'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  final String id;
  final String movieId;
  final String userId;
  final String userName;
  final String userAvatar;
  final double rating;
  final String title;
  final String content;
  final List<ReviewCategory> categories;
  final ReviewSentiment sentiment;
  final Map<String, double> categoryRatings;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final int dislikesCount;
  final int repliesCount;
  final bool isVerified;
  final bool isSpoiler;
  final bool isRecommended;
  final String? parentReviewId; // For replies
  final Map<String, dynamic> metadata;

  Review copyWith({
    String? id,
    String? movieId,
    String? userId,
    String? userName,
    String? userAvatar,
    double? rating,
    String? title,
    String? content,
    List<ReviewCategory>? categories,
    ReviewSentiment? sentiment,
    Map<String, double>? categoryRatings,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? dislikesCount,
    int? repliesCount,
    bool? isVerified,
    bool? isSpoiler,
    bool? isRecommended,
    String? parentReviewId,
    Map<String, dynamic>? metadata,
  }) {
    return Review(
      id: id ?? this.id,
      movieId: movieId ?? this.movieId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      content: content ?? this.content,
      categories: categories ?? this.categories,
      sentiment: sentiment ?? this.sentiment,
      categoryRatings: categoryRatings ?? this.categoryRatings,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      repliesCount: repliesCount ?? this.repliesCount,
      isVerified: isVerified ?? this.isVerified,
      isSpoiler: isSpoiler ?? this.isSpoiler,
      isRecommended: isRecommended ?? this.isRecommended,
      parentReviewId: parentReviewId ?? this.parentReviewId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movieId': movieId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'rating': rating,
      'title': title,
      'content': content,
      'categories': categories.map((c) => c.toString()).toList(),
      'sentiment': sentiment.toString(),
      'categoryRatings': categoryRatings,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'likesCount': likesCount,
      'dislikesCount': dislikesCount,
      'repliesCount': repliesCount,
      'isVerified': isVerified,
      'isSpoiler': isSpoiler,
      'isRecommended': isRecommended,
      'parentReviewId': parentReviewId,
      'metadata': metadata,
    };
  }
}

class ReviewFilter {
  const ReviewFilter({
    this.minRating,
    this.maxRating,
    this.sentiment,
    this.categories,
    this.onlyVerified,
    this.includeSpoilers,
    this.fromDate,
    this.toDate,
    this.tags,
    this.searchQuery,
    this.sortBy = ReviewSortBy.createdAt,
    this.ascending = false,
  });
  final double? minRating;
  final double? maxRating;
  final ReviewSentiment? sentiment;
  final List<ReviewCategory>? categories;
  final bool? onlyVerified;
  final bool? includeSpoilers;
  final DateTime? fromDate;
  final DateTime? toDate;
  final List<String>? tags;
  final String? searchQuery;
  final ReviewSortBy sortBy;
  final bool ascending;
}

enum ReviewSortBy {
  createdAt,
  rating,
  likesCount,
  repliesCount,
  relevance,
}

class ReviewStats {
  const ReviewStats({
    required this.totalReviews,
    required this.averageRating,
    required this.ratingDistribution,
    required this.sentimentDistribution,
    required this.categoryAverages,
    required this.topTags,
    required this.recommendationPercentage,
  });
  final int totalReviews;
  final double averageRating;
  final Map<int, int> ratingDistribution;
  final Map<ReviewSentiment, int> sentimentDistribution;
  final Map<ReviewCategory, double> categoryAverages;
  final List<String> topTags;
  final double recommendationPercentage;
}

class UserReviewService {
  static const String _reviewsKey = 'user_reviews';
  static const String _reviewLikesKey = 'review_likes';
  static const String _reviewDislikesKey = 'review_dislikes';

  SharedPreferences? _prefs;
  final Map<String, Review> _reviews = {};
  final Map<String, Set<String>> _userLikes = {}; // reviewId -> Set<userId>
  final Map<String, Set<String>> _userDislikes = {}; // reviewId -> Set<userId>

  final StreamController<List<Review>> _reviewsController =
      StreamController.broadcast();
  final StreamController<ReviewStats> _statsController =
      StreamController.broadcast();

  // Getters
  Stream<List<Review>> get reviewsStream => _reviewsController.stream;
  Stream<ReviewStats> get statsStream => _statsController.stream;
  Map<String, Review> get allReviews => Map.unmodifiable(_reviews);

  // Initialize
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadReviews();
      await _loadReviewInteractions();
      LoggerFactory.info('UserReviewService initialized successfully');
    } catch (e) {
      LoggerFactory.error('Error initializing UserReviewService: $e');
    }
  }

  // Create Review
  Future<String?> createReview({
    required String movieId,
    required String userId,
    required String userName,
    String userAvatar = '',
    required double rating,
    required String title,
    required String content,
    List<ReviewCategory> categories = const [],
    Map<String, double> categoryRatings = const {},
    List<String> tags = const [],
    bool isSpoiler = false,
    bool isRecommended = true,
    String? parentReviewId,
  }) async {
    try {
      final reviewId =
          'review_${DateTime.now().millisecondsSinceEpoch}_$userId';
      final sentiment = _analyzeSentiment(content, rating);

      final review = Review(
        id: reviewId,
        movieId: movieId,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        rating: rating,
        title: title,
        content: content,
        categories: categories,
        sentiment: sentiment,
        categoryRatings: categoryRatings,
        tags: tags,
        createdAt: DateTime.now(),
        isSpoiler: isSpoiler,
        isRecommended: isRecommended,
        parentReviewId: parentReviewId,
      );

      _reviews[reviewId] = review;

      // Update parent review reply count
      if (parentReviewId != null && _reviews.containsKey(parentReviewId)) {
        final parentReview = _reviews[parentReviewId]!;
        _reviews[parentReviewId] = parentReview.copyWith(
          repliesCount: parentReview.repliesCount + 1,
        );
      }

      await _saveReviews();
      _notifyReviewsChanged();
      await _updateStats();

      LoggerFactory.info('Review created successfully: $reviewId');
      return reviewId;
    } catch (e) {
      LoggerFactory.error('Error creating review: $e');
      return null;
    }
  }

  // Update Review
  Future<bool> updateReview({
    required String reviewId,
    String? title,
    String? content,
    double? rating,
    List<ReviewCategory>? categories,
    Map<String, double>? categoryRatings,
    List<String>? tags,
    bool? isSpoiler,
    bool? isRecommended,
  }) async {
    try {
      final existingReview = _reviews[reviewId];
      if (existingReview == null) return false;

      final updatedContent = content ?? existingReview.content;
      final updatedRating = rating ?? existingReview.rating;
      final sentiment = _analyzeSentiment(updatedContent, updatedRating);

      _reviews[reviewId] = existingReview.copyWith(
        title: title ?? existingReview.title,
        content: updatedContent,
        rating: updatedRating,
        categories: categories ?? existingReview.categories,
        sentiment: sentiment,
        categoryRatings: categoryRatings ?? existingReview.categoryRatings,
        tags: tags ?? existingReview.tags,
        isSpoiler: isSpoiler ?? existingReview.isSpoiler,
        isRecommended: isRecommended ?? existingReview.isRecommended,
        updatedAt: DateTime.now(),
      );

      await _saveReviews();
      _notifyReviewsChanged();
      await _updateStats();

      LoggerFactory.info('Review updated successfully: $reviewId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error updating review: $e');
      return false;
    }
  }

  // Delete Review
  Future<bool> deleteReview(String reviewId) async {
    try {
      final review = _reviews[reviewId];
      if (review == null) return false;

      _reviews.remove(reviewId);

      // Remove likes/dislikes
      _userLikes.remove(reviewId);
      _userDislikes.remove(reviewId);

      // Update parent review reply count
      if (review.parentReviewId != null &&
          _reviews.containsKey(review.parentReviewId!)) {
        final parentReview = _reviews[review.parentReviewId!]!;
        _reviews[review.parentReviewId!] = parentReview.copyWith(
          repliesCount:
              (parentReview.repliesCount - 1).clamp(0, double.infinity).toInt(),
        );
      }

      // Delete all replies to this review
      final repliesToDelete = _reviews.values
          .where((r) => r.parentReviewId == reviewId)
          .map((r) => r.id)
          .toList();

      for (final replyId in repliesToDelete) {
        _reviews.remove(replyId);
        _userLikes.remove(replyId);
        _userDislikes.remove(replyId);
      }

      await _saveReviews();
      await _saveReviewInteractions();
      _notifyReviewsChanged();
      await _updateStats();

      LoggerFactory.info('Review deleted successfully: $reviewId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error deleting review: $e');
      return false;
    }
  }

  // Like/Unlike Review
  Future<bool> toggleLikeReview(String reviewId, String userId) async {
    try {
      _userLikes.putIfAbsent(reviewId, () => <String>{});
      _userDislikes.putIfAbsent(reviewId, () => <String>{});

      final isLiked = _userLikes[reviewId]!.contains(userId);

      if (isLiked) {
        _userLikes[reviewId]!.remove(userId);
      } else {
        _userLikes[reviewId]!.add(userId);
        _userDislikes[reviewId]!.remove(userId); // Remove dislike if exists
      }

      await _updateReviewCounts(reviewId);
      await _saveReviewInteractions();
      _notifyReviewsChanged();

      return !isLiked;
    } catch (e) {
      LoggerFactory.error('Error toggling like: $e');
      return false;
    }
  }

  // Dislike/Undislike Review
  Future<bool> toggleDislikeReview(String reviewId, String userId) async {
    try {
      _userLikes.putIfAbsent(reviewId, () => <String>{});
      _userDislikes.putIfAbsent(reviewId, () => <String>{});

      final isDisliked = _userDislikes[reviewId]!.contains(userId);

      if (isDisliked) {
        _userDislikes[reviewId]!.remove(userId);
      } else {
        _userDislikes[reviewId]!.add(userId);
        _userLikes[reviewId]!.remove(userId); // Remove like if exists
      }

      await _updateReviewCounts(reviewId);
      await _saveReviewInteractions();
      _notifyReviewsChanged();

      return !isDisliked;
    } catch (e) {
      LoggerFactory.error('Error toggling dislike: $e');
      return false;
    }
  }

  // Get Reviews
  List<Review> getReviewsForMovie(
    String movieId, {
    ReviewFilter? filter,
    int? limit,
    int offset = 0,
  }) {
    var reviews =
        _reviews.values.where((review) => review.movieId == movieId).toList();

    if (filter != null) {
      reviews = _applyFilter(reviews, filter);
    }

    // Sort
    reviews.sort((a, b) => _compareReviews(a, b,
        filter?.sortBy ?? ReviewSortBy.createdAt, filter?.ascending ?? false));

    // Pagination
    if (limit != null) {
      final start = offset.clamp(0, reviews.length);
      final end = (offset + limit).clamp(0, reviews.length);
      reviews = reviews.sublist(start, end);
    }

    return reviews;
  }

  List<Review> getReviewsByUser(String userId) {
    return _reviews.values.where((review) => review.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Review> getRepliesForReview(String reviewId) {
    return _reviews.values
        .where((review) => review.parentReviewId == reviewId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Review? getReview(String reviewId) {
    return _reviews[reviewId];
  }

  // Statistics
  Future<ReviewStats> getStatsForMovie(String movieId) async {
    final movieReviews =
        _reviews.values.where((review) => review.movieId == movieId).toList();

    if (movieReviews.isEmpty) {
      return const ReviewStats(
        totalReviews: 0,
        averageRating: 0,
        ratingDistribution: {},
        sentimentDistribution: {},
        categoryAverages: {},
        topTags: [],
        recommendationPercentage: 0,
      );
    }

    final totalReviews = movieReviews.length;
    final averageRating =
        movieReviews.map((r) => r.rating).reduce((a, b) => a + b) /
            totalReviews;

    // Rating distribution (1-5 stars)
    final ratingDistribution = <int, int>{};
    for (int i = 1; i <= 5; i++) {
      ratingDistribution[i] =
          movieReviews.where((r) => r.rating.round() == i).length;
    }

    // Sentiment distribution
    final sentimentDistribution = <ReviewSentiment, int>{};
    for (final sentiment in ReviewSentiment.values) {
      sentimentDistribution[sentiment] =
          movieReviews.where((r) => r.sentiment == sentiment).length;
    }

    // Category averages
    final categoryAverages = <ReviewCategory, double>{};
    for (final category in ReviewCategory.values) {
      final categoryReviews = movieReviews
          .where((r) => r.categoryRatings.containsKey(category.toString()))
          .toList();
      if (categoryReviews.isNotEmpty) {
        final avg = categoryReviews
                .map((r) => r.categoryRatings[category.toString()]!)
                .reduce((a, b) => a + b) /
            categoryReviews.length;
        categoryAverages[category] = avg;
      }
    }

    // Top tags
    final allTags = <String>[];
    for (final review in movieReviews) {
      allTags.addAll(review.tags);
    }
    final tagCounts = <String, int>{};
    for (final tag in allTags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(10);

    // Recommendation percentage
    final recommendedCount = movieReviews.where((r) => r.isRecommended).length;
    final recommendationPercentage = (recommendedCount / totalReviews) * 100;

    return ReviewStats(
      totalReviews: totalReviews,
      averageRating: averageRating,
      ratingDistribution: ratingDistribution,
      sentimentDistribution: sentimentDistribution,
      categoryAverages: categoryAverages,
      topTags: topTags.map((e) => e.key).toList(),
      recommendationPercentage: recommendationPercentage,
    );
  }

  // Search
  List<Review> searchReviews({
    required String query,
    String? movieId,
    ReviewFilter? filter,
    int? limit,
  }) {
    var reviews = _reviews.values.toList();

    if (movieId != null) {
      reviews = reviews.where((r) => r.movieId == movieId).toList();
    }

    // Text search
    if (query.isNotEmpty) {
      final lowercaseQuery = query.toLowerCase();
      reviews = reviews.where((review) {
        return review.title.toLowerCase().contains(lowercaseQuery) ||
            review.content.toLowerCase().contains(lowercaseQuery) ||
            review.tags
                .any((tag) => tag.toLowerCase().contains(lowercaseQuery));
      }).toList();
    }

    if (filter != null) {
      reviews = _applyFilter(reviews, filter);
    }

    reviews.sort((a, b) => _calculateRelevanceScore(b, query)
        .compareTo(_calculateRelevanceScore(a, query)));

    if (limit != null) {
      reviews = reviews.take(limit).toList();
    }

    return reviews;
  }

  // Helper Methods
  ReviewSentiment _analyzeSentiment(String content, double rating) {
    // Simple sentiment analysis based on rating and keywords
    if (rating >= 4.0) return ReviewSentiment.positive;
    if (rating <= 2.0) return ReviewSentiment.negative;

    final lowercaseContent = content.toLowerCase();
    final positiveWords = [
      'great',
      'excellent',
      'amazing',
      'wonderful',
      'fantastic',
      'loved',
      'perfect'
    ];
    final negativeWords = [
      'bad',
      'terrible',
      'awful',
      'horrible',
      'hate',
      'worst',
      'disappointing'
    ];

    final positiveCount =
        positiveWords.where((word) => lowercaseContent.contains(word)).length;
    final negativeCount =
        negativeWords.where((word) => lowercaseContent.contains(word)).length;

    if (positiveCount > negativeCount) return ReviewSentiment.positive;
    if (negativeCount > positiveCount) return ReviewSentiment.negative;

    return ReviewSentiment.neutral;
  }

  List<Review> _applyFilter(List<Review> reviews, ReviewFilter filter) {
    return reviews.where((review) {
      if (filter.minRating != null && review.rating < filter.minRating!) {
        return false;
      }
      if (filter.maxRating != null && review.rating > filter.maxRating!) {
        return false;
      }
      if (filter.sentiment != null && review.sentiment != filter.sentiment!) {
        return false;
      }
      if (filter.onlyVerified == true && !review.isVerified) return false;
      if (filter.includeSpoilers == false && review.isSpoiler) return false;
      if (filter.fromDate != null &&
          review.createdAt.isBefore(filter.fromDate!)) {
        return false;
      }
      if (filter.toDate != null && review.createdAt.isAfter(filter.toDate!)) {
        return false;
      }

      if (filter.categories != null && filter.categories!.isNotEmpty) {
        final hasCategory =
            filter.categories!.any((cat) => review.categories.contains(cat));
        if (!hasCategory) return false;
      }

      if (filter.tags != null && filter.tags!.isNotEmpty) {
        final hasTag = filter.tags!.any((tag) => review.tags.contains(tag));
        if (!hasTag) return false;
      }

      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        final hasMatch = review.title.toLowerCase().contains(query) ||
            review.content.toLowerCase().contains(query) ||
            review.tags.any((tag) => tag.toLowerCase().contains(query));
        if (!hasMatch) return false;
      }

      return true;
    }).toList();
  }

  int _compareReviews(Review a, Review b, ReviewSortBy sortBy, bool ascending) {
    int comparison;

    switch (sortBy) {
      case ReviewSortBy.createdAt:
        comparison = a.createdAt.compareTo(b.createdAt);
        break;
      case ReviewSortBy.rating:
        comparison = a.rating.compareTo(b.rating);
        break;
      case ReviewSortBy.likesCount:
        comparison = a.likesCount.compareTo(b.likesCount);
        break;
      case ReviewSortBy.repliesCount:
        comparison = a.repliesCount.compareTo(b.repliesCount);
        break;
      case ReviewSortBy.relevance:
        comparison = _calculateRelevanceScore(a, '')
            .compareTo(_calculateRelevanceScore(b, ''));
        break;
    }

    return ascending ? comparison : -comparison;
  }

  double _calculateRelevanceScore(Review review, String query) {
    double score = 0;

    // Base score from likes and replies
    score += review.likesCount * 2;
    score += review.repliesCount * 1.5;
    score -= review.dislikesCount;

    // Verified reviews get boost
    if (review.isVerified) score += 10;

    // Recent reviews get slight boost
    final daysSinceCreated = DateTime.now().difference(review.createdAt).inDays;
    if (daysSinceCreated < 7) {
      score += 5;
    } else if (daysSinceCreated < 30) {
      score += 2;
    }

    // Query relevance
    if (query.isNotEmpty) {
      final lowercaseQuery = query.toLowerCase();
      if (review.title.toLowerCase().contains(lowercaseQuery)) score += 20;
      if (review.content.toLowerCase().contains(lowercaseQuery)) score += 10;
      score += review.tags
              .where((tag) => tag.toLowerCase().contains(lowercaseQuery))
              .length *
          5;
    }

    return score;
  }

  Future<void> _updateReviewCounts(String reviewId) async {
    final review = _reviews[reviewId];
    if (review == null) return;

    final likesCount = _userLikes[reviewId]?.length ?? 0;
    final dislikesCount = _userDislikes[reviewId]?.length ?? 0;

    _reviews[reviewId] = review.copyWith(
      likesCount: likesCount,
      dislikesCount: dislikesCount,
    );

    await _saveReviews();
  }

  Future<void> _updateStats() async {
    // Calculate overall stats and emit
    final allMovieIds = _reviews.values.map((r) => r.movieId).toSet();
    for (final movieId in allMovieIds) {
      final stats = await getStatsForMovie(movieId);
      _statsController.add(stats);
    }
  }

  void _notifyReviewsChanged() {
    _reviewsController.add(_reviews.values.toList());
  }

  // Persistence
  Future<void> _loadReviews() async {
    final json = _prefs?.getString(_reviewsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _reviews.clear();
      data.forEach((key, value) {
        _reviews[key] = Review.fromJson(value);
      });
    }
  }

  Future<void> _saveReviews() async {
    final data = <String, dynamic>{};
    _reviews.forEach((key, review) {
      data[key] = review.toJson();
    });
    final json = jsonEncode(data);
    await _prefs?.setString(_reviewsKey, json);
  }

  Future<void> _loadReviewInteractions() async {
    // Load likes
    final likesJson = _prefs?.getString(_reviewLikesKey);
    if (likesJson != null) {
      final likesData = jsonDecode(likesJson) as Map<String, dynamic>;
      _userLikes.clear();
      likesData.forEach((reviewId, userIds) {
        _userLikes[reviewId] = Set<String>.from(userIds);
      });
    }

    // Load dislikes
    final dislikesJson = _prefs?.getString(_reviewDislikesKey);
    if (dislikesJson != null) {
      final dislikesData = jsonDecode(dislikesJson) as Map<String, dynamic>;
      _userDislikes.clear();
      dislikesData.forEach((reviewId, userIds) {
        _userDislikes[reviewId] = Set<String>.from(userIds);
      });
    }
  }

  Future<void> _saveReviewInteractions() async {
    // Save likes
    final likesData = <String, List<String>>{};
    _userLikes.forEach((reviewId, userIds) {
      likesData[reviewId] = userIds.toList();
    });
    await _prefs?.setString(_reviewLikesKey, jsonEncode(likesData));

    // Save dislikes
    final dislikesData = <String, List<String>>{};
    _userDislikes.forEach((reviewId, userIds) {
      dislikesData[reviewId] = userIds.toList();
    });
    await _prefs?.setString(_reviewDislikesKey, jsonEncode(dislikesData));
  }

  // Dispose
  void dispose() {
    _reviewsController.close();
    _statsController.close();
  }
}
