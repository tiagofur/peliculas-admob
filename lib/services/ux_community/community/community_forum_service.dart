// lib/services/ux_community/community/community_forum_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/logger_factory.dart';

enum ForumPostType {
  discussion,
  recommendation,
  review,
  question,
  poll,
  announcement,
}

enum PostStatus {
  active,
  pinned,
  locked,
  archived,
  hidden,
}

class ForumCategory {
  const ForumCategory({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl = '',
    this.color = '#2196F3',
    this.postCount = 0,
    this.isActive = true,
    this.moderatorIds = const [],
  });

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    return ForumCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconUrl: json['iconUrl'] ?? '',
      color: json['color'] ?? '#2196F3',
      postCount: json['postCount'] ?? 0,
      isActive: json['isActive'] ?? true,
      moderatorIds: List<String>.from(json['moderatorIds'] ?? []),
    );
  }
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final String color;
  final int postCount;
  final bool isActive;
  final List<String> moderatorIds;

  ForumCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    String? color,
    int? postCount,
    bool? isActive,
    List<String>? moderatorIds,
  }) {
    return ForumCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      color: color ?? this.color,
      postCount: postCount ?? this.postCount,
      isActive: isActive ?? this.isActive,
      moderatorIds: moderatorIds ?? this.moderatorIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'color': color,
      'postCount': postCount,
      'isActive': isActive,
      'moderatorIds': moderatorIds,
    };
  }
}

class ForumPost {
  const ForumPost({
    required this.id,
    required this.categoryId,
    required this.authorId,
    required this.authorUsername,
    this.authorAvatar = '',
    required this.type,
    this.status = PostStatus.active,
    required this.title,
    required this.content,
    this.tags = const [],
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
    this.viewCount = 0,
    this.replyCount = 0,
    this.upvoteCount = 0,
    this.downvoteCount = 0,
    this.isPinned = false,
    this.isLocked = false,
    this.movieId,
    this.attachmentUrls = const [],
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'],
      categoryId: json['categoryId'],
      authorId: json['authorId'],
      authorUsername: json['authorUsername'],
      authorAvatar: json['authorAvatar'] ?? '',
      type: ForumPostType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ForumPostType.discussion,
      ),
      status: PostStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => PostStatus.active,
      ),
      title: json['title'],
      content: json['content'],
      tags: List<String>.from(json['tags'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      viewCount: json['viewCount'] ?? 0,
      replyCount: json['replyCount'] ?? 0,
      upvoteCount: json['upvoteCount'] ?? 0,
      downvoteCount: json['downvoteCount'] ?? 0,
      isPinned: json['isPinned'] ?? false,
      isLocked: json['isLocked'] ?? false,
      movieId: json['movieId'],
      attachmentUrls: List<String>.from(json['attachmentUrls'] ?? []),
    );
  }
  final String id;
  final String categoryId;
  final String authorId;
  final String authorUsername;
  final String authorAvatar;
  final ForumPostType type;
  final PostStatus status;
  final String title;
  final String content;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int viewCount;
  final int replyCount;
  final int upvoteCount;
  final int downvoteCount;
  final bool isPinned;
  final bool isLocked;
  final String? movieId;
  final List<String> attachmentUrls;

  ForumPost copyWith({
    String? id,
    String? categoryId,
    String? authorId,
    String? authorUsername,
    String? authorAvatar,
    ForumPostType? type,
    PostStatus? status,
    String? title,
    String? content,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewCount,
    int? replyCount,
    int? upvoteCount,
    int? downvoteCount,
    bool? isPinned,
    bool? isLocked,
    String? movieId,
    List<String>? attachmentUrls,
  }) {
    return ForumPost(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      type: type ?? this.type,
      status: status ?? this.status,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      replyCount: replyCount ?? this.replyCount,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      downvoteCount: downvoteCount ?? this.downvoteCount,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      movieId: movieId ?? this.movieId,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorAvatar': authorAvatar,
      'type': type.toString(),
      'status': status.toString(),
      'title': title,
      'content': content,
      'tags': tags,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'viewCount': viewCount,
      'replyCount': replyCount,
      'upvoteCount': upvoteCount,
      'downvoteCount': downvoteCount,
      'isPinned': isPinned,
      'isLocked': isLocked,
      'movieId': movieId,
      'attachmentUrls': attachmentUrls,
    };
  }
}

class ForumReply {
  const ForumReply({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    this.authorAvatar = '',
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.upvoteCount = 0,
    this.downvoteCount = 0,
    this.parentReplyId,
    this.attachmentUrls = const [],
    this.isModeratorReply = false,
  });

  factory ForumReply.fromJson(Map<String, dynamic> json) {
    return ForumReply(
      id: json['id'],
      postId: json['postId'],
      authorId: json['authorId'],
      authorUsername: json['authorUsername'],
      authorAvatar: json['authorAvatar'] ?? '',
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      upvoteCount: json['upvoteCount'] ?? 0,
      downvoteCount: json['downvoteCount'] ?? 0,
      parentReplyId: json['parentReplyId'],
      attachmentUrls: List<String>.from(json['attachmentUrls'] ?? []),
      isModeratorReply: json['isModeratorReply'] ?? false,
    );
  }
  final String id;
  final String postId;
  final String authorId;
  final String authorUsername;
  final String authorAvatar;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int upvoteCount;
  final int downvoteCount;
  final String? parentReplyId;
  final List<String> attachmentUrls;
  final bool isModeratorReply;

  ForumReply copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorUsername,
    String? authorAvatar,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? upvoteCount,
    int? downvoteCount,
    String? parentReplyId,
    List<String>? attachmentUrls,
    bool? isModeratorReply,
  }) {
    return ForumReply(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      downvoteCount: downvoteCount ?? this.downvoteCount,
      parentReplyId: parentReplyId ?? this.parentReplyId,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      isModeratorReply: isModeratorReply ?? this.isModeratorReply,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorAvatar': authorAvatar,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'upvoteCount': upvoteCount,
      'downvoteCount': downvoteCount,
      'parentReplyId': parentReplyId,
      'attachmentUrls': attachmentUrls,
      'isModeratorReply': isModeratorReply,
    };
  }
}

enum ForumSortBy {
  latest,
  mostReplied,
  mostUpvoted,
  oldest,
  trending,
}

class ForumFilter {
  const ForumFilter({
    this.categoryId,
    this.type,
    this.status,
    this.authorId,
    this.tags,
    this.movieId,
    this.fromDate,
    this.toDate,
    this.searchQuery,
    this.sortBy = ForumSortBy.latest,
    this.ascending = false,
  });
  final String? categoryId;
  final ForumPostType? type;
  final PostStatus? status;
  final String? authorId;
  final List<String>? tags;
  final String? movieId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? searchQuery;
  final ForumSortBy sortBy;
  final bool ascending;
}

class CommunityForumService {
  static const String _categoriesKey = 'forum_categories';
  static const String _postsKey = 'forum_posts';
  static const String _repliesKey = 'forum_replies';
  static const String _votesKey = 'forum_votes';

  SharedPreferences? _prefs;
  final Map<String, ForumCategory> _categories = {};
  final Map<String, ForumPost> _posts = {};
  final Map<String, List<ForumReply>> _replies = {}; // postId -> replies
  final Map<String, Map<String, int>> _votes = {}; // itemId -> {userId: vote}

  final StreamController<List<ForumPost>> _postsController =
      StreamController.broadcast();
  final StreamController<List<ForumCategory>> _categoriesController =
      StreamController.broadcast();

  // Getters
  Stream<List<ForumPost>> get postsStream => _postsController.stream;
  Stream<List<ForumCategory>> get categoriesStream =>
      _categoriesController.stream;

  // Initialize
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCategories();
      await _loadPosts();
      await _loadReplies();
      await _loadVotes();
      await _initializeDefaultCategories();
      LoggerFactory.info('CommunityForumService initialized successfully');
    } catch (e) {
      LoggerFactory.error('Error initializing CommunityForumService: $e');
    }
  }

  // Categories Management
  Future<String?> createCategory({
    required String name,
    required String description,
    String iconUrl = '',
    String color = '#2196F3',
    List<String> moderatorIds = const [],
  }) async {
    try {
      final categoryId = 'category_${DateTime.now().millisecondsSinceEpoch}';

      final category = ForumCategory(
        id: categoryId,
        name: name,
        description: description,
        iconUrl: iconUrl,
        color: color,
        moderatorIds: moderatorIds,
      );

      _categories[categoryId] = category;
      await _saveCategories();
      _categoriesController.add(_categories.values.toList());

      LoggerFactory.info('Category created successfully: $categoryId');
      return categoryId;
    } catch (e) {
      LoggerFactory.error('Error creating category: $e');
      return null;
    }
  }

  Future<bool> updateCategory(
    String categoryId, {
    String? name,
    String? description,
    String? iconUrl,
    String? color,
    List<String>? moderatorIds,
    bool? isActive,
  }) async {
    try {
      final existingCategory = _categories[categoryId];
      if (existingCategory == null) return false;

      _categories[categoryId] = existingCategory.copyWith(
        name: name ?? existingCategory.name,
        description: description ?? existingCategory.description,
        iconUrl: iconUrl ?? existingCategory.iconUrl,
        color: color ?? existingCategory.color,
        moderatorIds: moderatorIds ?? existingCategory.moderatorIds,
        isActive: isActive ?? existingCategory.isActive,
      );

      await _saveCategories();
      _categoriesController.add(_categories.values.toList());

      return true;
    } catch (e) {
      LoggerFactory.error('Error updating category: $e');
      return false;
    }
  }

  List<ForumCategory> getCategories({bool activeOnly = true}) {
    var categories = _categories.values.toList();

    if (activeOnly) {
      categories = categories.where((c) => c.isActive).toList();
    }

    categories.sort((a, b) => a.name.compareTo(b.name));
    return categories;
  }

  ForumCategory? getCategory(String categoryId) {
    return _categories[categoryId];
  }

  // Posts Management
  Future<String?> createPost({
    required String categoryId,
    required String authorId,
    required String authorUsername,
    String authorAvatar = '',
    required ForumPostType type,
    required String title,
    required String content,
    List<String> tags = const [],
    String? movieId,
    List<String> attachmentUrls = const [],
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final category = _categories[categoryId];
      if (category == null || !category.isActive) return null;

      final postId = 'post_${DateTime.now().millisecondsSinceEpoch}_$authorId';

      final post = ForumPost(
        id: postId,
        categoryId: categoryId,
        authorId: authorId,
        authorUsername: authorUsername,
        authorAvatar: authorAvatar,
        type: type,
        title: title,
        content: content,
        tags: tags,
        movieId: movieId,
        attachmentUrls: attachmentUrls,
        metadata: metadata,
        createdAt: DateTime.now(),
      );

      _posts[postId] = post;
      _replies[postId] = [];

      // Update category post count
      await _updateCategoryPostCount(categoryId);

      await _savePosts();
      await _saveReplies();
      _postsController.add(_posts.values.toList());

      LoggerFactory.info('Post created successfully: $postId');
      return postId;
    } catch (e) {
      LoggerFactory.error('Error creating post: $e');
      return null;
    }
  }

  Future<bool> updatePost({
    required String postId,
    String? title,
    String? content,
    List<String>? tags,
    PostStatus? status,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final existingPost = _posts[postId];
      if (existingPost == null) return false;

      _posts[postId] = existingPost.copyWith(
        title: title ?? existingPost.title,
        content: content ?? existingPost.content,
        tags: tags ?? existingPost.tags,
        status: status ?? existingPost.status,
        metadata: metadata ?? existingPost.metadata,
        updatedAt: DateTime.now(),
      );

      await _savePosts();
      _postsController.add(_posts.values.toList());

      return true;
    } catch (e) {
      LoggerFactory.error('Error updating post: $e');
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      final post = _posts[postId];
      if (post == null) return false;

      _posts.remove(postId);
      _replies.remove(postId);
      _votes.remove(postId);

      // Update category post count
      await _updateCategoryPostCount(post.categoryId);

      await _savePosts();
      await _saveReplies();
      await _saveVotes();
      _postsController.add(_posts.values.toList());

      return true;
    } catch (e) {
      LoggerFactory.error('Error deleting post: $e');
      return false;
    }
  }

  Future<bool> pinPost(String postId, bool isPinned) async {
    return await updatePost(
        postId: postId,
        status: isPinned ? PostStatus.pinned : PostStatus.active);
  }

  Future<bool> lockPost(String postId, bool isLocked) async {
    return await updatePost(
        postId: postId,
        status: isLocked ? PostStatus.locked : PostStatus.active);
  }

  // Replies Management
  Future<String?> createReply({
    required String postId,
    required String authorId,
    required String authorUsername,
    String authorAvatar = '',
    required String content,
    String? parentReplyId,
    List<String> attachmentUrls = const [],
    bool isModeratorReply = false,
  }) async {
    try {
      final post = _posts[postId];
      if (post == null || post.isLocked) return null;

      final replyId =
          'reply_${DateTime.now().millisecondsSinceEpoch}_$authorId';

      final reply = ForumReply(
        id: replyId,
        postId: postId,
        authorId: authorId,
        authorUsername: authorUsername,
        authorAvatar: authorAvatar,
        content: content,
        parentReplyId: parentReplyId,
        attachmentUrls: attachmentUrls,
        isModeratorReply: isModeratorReply,
        createdAt: DateTime.now(),
      );

      _replies.putIfAbsent(postId, () => []);
      _replies[postId]!.add(reply);

      // Update post reply count
      _posts[postId] = post.copyWith(
        replyCount: _replies[postId]!.length,
      );

      await _savePosts();
      await _saveReplies();
      _postsController.add(_posts.values.toList());

      LoggerFactory.info('Reply created successfully: $replyId');
      return replyId;
    } catch (e) {
      LoggerFactory.error('Error creating reply: $e');
      return null;
    }
  }

  Future<bool> updateReply({
    required String postId,
    required String replyId,
    String? content,
  }) async {
    try {
      final replies = _replies[postId] ?? [];
      final replyIndex = replies.indexWhere((r) => r.id == replyId);

      if (replyIndex == -1) return false;

      _replies[postId]![replyIndex] = replies[replyIndex].copyWith(
        content: content ?? replies[replyIndex].content,
        updatedAt: DateTime.now(),
      );

      await _saveReplies();
      return true;
    } catch (e) {
      LoggerFactory.error('Error updating reply: $e');
      return false;
    }
  }

  Future<bool> deleteReply(String postId, String replyId) async {
    try {
      final replies = _replies[postId] ?? [];
      final replyIndex = replies.indexWhere((r) => r.id == replyId);

      if (replyIndex == -1) return false;

      _replies[postId]!.removeAt(replyIndex);
      _votes.remove(replyId);

      // Update post reply count
      final post = _posts[postId];
      if (post != null) {
        _posts[postId] = post.copyWith(replyCount: _replies[postId]!.length);
      }

      await _savePosts();
      await _saveReplies();
      await _saveVotes();
      _postsController.add(_posts.values.toList());

      return true;
    } catch (e) {
      LoggerFactory.error('Error deleting reply: $e');
      return false;
    }
  }

  // Voting System
  Future<bool> voteOnPost(String postId, String userId, int vote) async {
    return await _vote(postId, userId, vote, true);
  }

  Future<bool> voteOnReply(String replyId, String userId, int vote) async {
    return await _vote(replyId, userId, vote, false);
  }

  Future<bool> _vote(
      String itemId, String userId, int vote, bool isPost) async {
    try {
      // vote: 1 for upvote, -1 for downvote, 0 to remove vote
      if (vote < -1 || vote > 1) return false;

      _votes.putIfAbsent(itemId, () => {});

      if (vote == 0) {
        _votes[itemId]!.remove(userId);
      } else {
        _votes[itemId]![userId] = vote;
      }

      await _updateVoteCounts(itemId, isPost);
      await _saveVotes();

      if (isPost) {
        _postsController.add(_posts.values.toList());
      }

      return true;
    } catch (e) {
      LoggerFactory.error('Error voting: $e');
      return false;
    }
  }

  int getUserVote(String itemId, String userId) {
    return _votes[itemId]?[userId] ?? 0;
  }

  // View Tracking
  Future<void> incrementViewCount(String postId) async {
    try {
      final post = _posts[postId];
      if (post == null) return;

      _posts[postId] = post.copyWith(viewCount: post.viewCount + 1);
      await _savePosts();
    } catch (e) {
      LoggerFactory.error('Error incrementing view count: $e');
    }
  }

  // Query Methods
  List<ForumPost> getPosts({
    ForumFilter? filter,
    int limit = 50,
    int offset = 0,
  }) {
    var posts = _posts.values.toList();

    if (filter != null) {
      posts = _applyFilter(posts, filter);
    }

    // Sort
    posts.sort((a, b) => _comparePosts(a, b,
        filter?.sortBy ?? ForumSortBy.latest, filter?.ascending ?? false));

    // Pagination
    final start = offset.clamp(0, posts.length);
    final end = (offset + limit).clamp(0, posts.length);

    return posts.sublist(start, end);
  }

  List<ForumPost> getPostsByCategory(String categoryId, {int limit = 50}) {
    return getPosts(
      filter: ForumFilter(categoryId: categoryId),
      limit: limit,
    );
  }

  List<ForumPost> getPostsByUser(String userId, {int limit = 50}) {
    return getPosts(
      filter: ForumFilter(authorId: userId),
      limit: limit,
    );
  }

  List<ForumPost> getTrendingPosts({int limit = 20}) {
    return getPosts(
      filter: const ForumFilter(sortBy: ForumSortBy.trending),
      limit: limit,
    );
  }

  ForumPost? getPost(String postId) {
    return _posts[postId];
  }

  List<ForumReply> getReplies(String postId) {
    return _replies[postId] ?? [];
  }

  List<ForumPost> searchPosts({
    required String query,
    ForumFilter? additionalFilter,
    int limit = 50,
  }) {
    final filter = ForumFilter(
      searchQuery: query,
      categoryId: additionalFilter?.categoryId,
      type: additionalFilter?.type,
      status: additionalFilter?.status,
      sortBy: ForumSortBy.latest,
    );

    return getPosts(filter: filter, limit: limit);
  }

  // Helper Methods
  List<ForumPost> _applyFilter(List<ForumPost> posts, ForumFilter filter) {
    return posts.where((post) {
      if (filter.categoryId != null && post.categoryId != filter.categoryId) {
        return false;
      }
      if (filter.type != null && post.type != filter.type) return false;
      if (filter.status != null && post.status != filter.status) return false;
      if (filter.authorId != null && post.authorId != filter.authorId) {
        return false;
      }
      if (filter.movieId != null && post.movieId != filter.movieId) {
        return false;
      }
      if (filter.fromDate != null &&
          post.createdAt.isBefore(filter.fromDate!)) {
        return false;
      }
      if (filter.toDate != null && post.createdAt.isAfter(filter.toDate!)) {
        return false;
      }

      if (filter.tags != null && filter.tags!.isNotEmpty) {
        final hasTag = filter.tags!.any((tag) => post.tags.contains(tag));
        if (!hasTag) return false;
      }

      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        final hasMatch = post.title.toLowerCase().contains(query) ||
            post.content.toLowerCase().contains(query) ||
            post.tags.any((tag) => tag.toLowerCase().contains(query));
        if (!hasMatch) return false;
      }

      return true;
    }).toList();
  }

  int _comparePosts(
      ForumPost a, ForumPost b, ForumSortBy sortBy, bool ascending) {
    int comparison;

    switch (sortBy) {
      case ForumSortBy.latest:
        comparison = a.createdAt.compareTo(b.createdAt);
        break;
      case ForumSortBy.mostReplied:
        comparison = a.replyCount.compareTo(b.replyCount);
        break;
      case ForumSortBy.mostUpvoted:
        comparison = a.upvoteCount.compareTo(b.upvoteCount);
        break;
      case ForumSortBy.oldest:
        comparison = a.createdAt.compareTo(b.createdAt);
        ascending = true; // Override for oldest
        break;
      case ForumSortBy.trending:
        comparison =
            _calculateTrendingScore(a).compareTo(_calculateTrendingScore(b));
        break;
    }

    return ascending ? comparison : -comparison;
  }

  double _calculateTrendingScore(ForumPost post) {
    final hoursSinceCreated = DateTime.now().difference(post.createdAt).inHours;
    final ageScore = 1.0 / (hoursSinceCreated + 1);
    final engagementScore = (post.upvoteCount + post.replyCount * 2) * ageScore;
    return engagementScore;
  }

  Future<void> _updateVoteCounts(String itemId, bool isPost) async {
    final votes = _votes[itemId] ?? {};
    final upvotes = votes.values.where((v) => v == 1).length;
    final downvotes = votes.values.where((v) => v == -1).length;

    if (isPost) {
      final post = _posts[itemId];
      if (post != null) {
        _posts[itemId] = post.copyWith(
          upvoteCount: upvotes,
          downvoteCount: downvotes,
        );
        await _savePosts();
      }
    } else {
      // Handle reply vote counts (would need to find the reply in the appropriate post)
      for (final postReplies in _replies.values) {
        final replyIndex = postReplies.indexWhere((r) => r.id == itemId);
        if (replyIndex != -1) {
          postReplies[replyIndex] = postReplies[replyIndex].copyWith(
            upvoteCount: upvotes,
            downvoteCount: downvotes,
          );
          await _saveReplies();
          break;
        }
      }
    }
  }

  Future<void> _updateCategoryPostCount(String categoryId) async {
    final postCount =
        _posts.values.where((p) => p.categoryId == categoryId).length;
    final category = _categories[categoryId];

    if (category != null) {
      _categories[categoryId] = category.copyWith(postCount: postCount);
      await _saveCategories();
      _categoriesController.add(_categories.values.toList());
    }
  }

  Future<void> _initializeDefaultCategories() async {
    if (_categories.isEmpty) {
      final defaultCategories = [
        const ForumCategory(
          id: 'general',
          name: 'General Discussion',
          description: 'General movie discussions and off-topic conversations',
          color: '#2196F3',
        ),
        const ForumCategory(
          id: 'recommendations',
          name: 'Movie Recommendations',
          description: 'Share and discover great movies',
          color: '#4CAF50',
        ),
        const ForumCategory(
          id: 'reviews',
          name: 'Movie Reviews',
          description: 'In-depth movie reviews and analysis',
          color: '#FF9800',
        ),
        const ForumCategory(
          id: 'news',
          name: 'Movie News',
          description: 'Latest movie news and industry updates',
          color: '#F44336',
        ),
        const ForumCategory(
          id: 'technical',
          name: 'Technical Discussions',
          description:
              'Filmmaking techniques, cinematography, and technical aspects',
          color: '#9C27B0',
        ),
      ];

      for (final category in defaultCategories) {
        _categories[category.id] = category;
      }

      await _saveCategories();
      _categoriesController.add(_categories.values.toList());
    }
  }

  // Persistence
  Future<void> _loadCategories() async {
    final json = _prefs?.getString(_categoriesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _categories.clear();
      data.forEach((key, value) {
        _categories[key] = ForumCategory.fromJson(value);
      });
    }
  }

  Future<void> _saveCategories() async {
    final data = <String, dynamic>{};
    _categories.forEach((key, category) {
      data[key] = category.toJson();
    });
    final json = jsonEncode(data);
    await _prefs?.setString(_categoriesKey, json);
  }

  Future<void> _loadPosts() async {
    final json = _prefs?.getString(_postsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _posts.clear();
      data.forEach((key, value) {
        _posts[key] = ForumPost.fromJson(value);
      });
    }
  }

  Future<void> _savePosts() async {
    final data = <String, dynamic>{};
    _posts.forEach((key, post) {
      data[key] = post.toJson();
    });
    final json = jsonEncode(data);
    await _prefs?.setString(_postsKey, json);
  }

  Future<void> _loadReplies() async {
    final json = _prefs?.getString(_repliesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _replies.clear();
      data.forEach((postId, repliesList) {
        _replies[postId] = (repliesList as List<dynamic>)
            .map((r) => ForumReply.fromJson(r))
            .toList();
      });
    }
  }

  Future<void> _saveReplies() async {
    final data = <String, dynamic>{};
    _replies.forEach((postId, replies) {
      data[postId] = replies.map((r) => r.toJson()).toList();
    });
    await _prefs?.setString(_repliesKey, jsonEncode(data));
  }

  Future<void> _loadVotes() async {
    final json = _prefs?.getString(_votesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _votes.clear();
      data.forEach((itemId, votes) {
        _votes[itemId] = Map<String, int>.from(votes);
      });
    }
  }

  Future<void> _saveVotes() async {
    final json = jsonEncode(_votes);
    await _prefs?.setString(_votesKey, json);
  }

  // Dispose
  void dispose() {
    _postsController.close();
    _categoriesController.close();
  }
}
