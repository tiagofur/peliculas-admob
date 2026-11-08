// lib/services/ux_community/community/social_interaction_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/logger_factory.dart';

enum FollowStatus {
  notFollowing,
  following,
  followingBack,
  blocked,
}

enum NotificationType {
  follow,
  reviewLike,
  reviewReply,
  movieRecommendation,
  watchlistShare,
  achievement,
  general,
}

enum ActivityType {
  reviewCreated,
  reviewLiked,
  movieWatched,
  movieRated,
  listCreated,
  listShared,
  achievementUnlocked,
  userFollowed,
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl = '',
    this.bio = '',
    required this.joinDate,
    this.stats = const {},
    this.badges = const [],
    this.preferences = const {},
    this.isVerified = false,
    this.isPrivate = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'],
      username: json['username'],
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'] ?? '',
      bio: json['bio'] ?? '',
      joinDate: DateTime.parse(json['joinDate']),
      stats: Map<String, dynamic>.from(json['stats'] ?? {}),
      badges: List<String>.from(json['badges'] ?? []),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      isVerified: json['isVerified'] ?? false,
      isPrivate: json['isPrivate'] ?? false,
    );
  }
  final String userId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bio;
  final DateTime joinDate;
  final Map<String, dynamic> stats;
  final List<String> badges;
  final Map<String, dynamic> preferences;
  final bool isVerified;
  final bool isPrivate;

  UserProfile copyWith({
    String? userId,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    DateTime? joinDate,
    Map<String, dynamic>? stats,
    List<String>? badges,
    Map<String, dynamic>? preferences,
    bool? isVerified,
    bool? isPrivate,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      joinDate: joinDate ?? this.joinDate,
      stats: stats ?? this.stats,
      badges: badges ?? this.badges,
      preferences: preferences ?? this.preferences,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'joinDate': joinDate.toIso8601String(),
      'stats': stats,
      'badges': badges,
      'preferences': preferences,
      'isVerified': isVerified,
      'isPrivate': isPrivate,
    };
  }
}

class SocialNotification {
  const SocialNotification({
    required this.id,
    required this.recipientUserId,
    required this.senderUserId,
    required this.senderUsername,
    this.senderAvatar = '',
    required this.type,
    required this.title,
    required this.message,
    this.data = const {},
    required this.createdAt,
    this.isRead = false,
    this.actionUrl,
  });

  factory SocialNotification.fromJson(Map<String, dynamic> json) {
    return SocialNotification(
      id: json['id'],
      recipientUserId: json['recipientUserId'],
      senderUserId: json['senderUserId'],
      senderUsername: json['senderUsername'],
      senderAvatar: json['senderAvatar'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => NotificationType.general,
      ),
      title: json['title'],
      message: json['message'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
      actionUrl: json['actionUrl'],
    );
  }
  final String id;
  final String recipientUserId;
  final String senderUserId;
  final String senderUsername;
  final String senderAvatar;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;
  final String? actionUrl;

  SocialNotification copyWith({
    String? id,
    String? recipientUserId,
    String? senderUserId,
    String? senderUsername,
    String? senderAvatar,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? isRead,
    String? actionUrl,
  }) {
    return SocialNotification(
      id: id ?? this.id,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      senderUserId: senderUserId ?? this.senderUserId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipientUserId': recipientUserId,
      'senderUserId': senderUserId,
      'senderUsername': senderUsername,
      'senderAvatar': senderAvatar,
      'type': type.toString(),
      'title': title,
      'message': message,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'actionUrl': actionUrl,
    };
  }
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar = '',
    required this.type,
    required this.description,
    this.data = const {},
    required this.timestamp,
    this.isPublic = true,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'],
      userId: json['userId'],
      username: json['username'],
      userAvatar: json['userAvatar'] ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ActivityType.reviewCreated,
      ),
      description: json['description'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      timestamp: DateTime.parse(json['timestamp']),
      isPublic: json['isPublic'] ?? true,
    );
  }
  final String id;
  final String userId;
  final String username;
  final String userAvatar;
  final ActivityType type;
  final String description;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isPublic;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'type': type.toString(),
      'description': description,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'isPublic': isPublic,
    };
  }
}

class SocialInteractionService {
  static const String _profilesKey = 'user_profiles';
  static const String _followersKey = 'user_followers';
  static const String _followingKey = 'user_following';
  static const String _blockedUsersKey = 'blocked_users';
  static const String _notificationsKey = 'social_notifications';
  static const String _activitiesKey = 'user_activities';

  SharedPreferences? _prefs;
  final Map<String, UserProfile> _profiles = {};
  final Map<String, Set<String>> _followers = {}; // userId -> Set<followerId>
  final Map<String, Set<String>> _following = {}; // userId -> Set<followingId>
  final Map<String, Set<String>> _blockedUsers = {}; // userId -> Set<blockedId>
  final Map<String, List<SocialNotification>> _notifications =
      {}; // userId -> notifications
  final List<ActivityItem> _activities = [];

  final StreamController<List<SocialNotification>> _notificationsController =
      StreamController.broadcast();
  final StreamController<List<ActivityItem>> _activitiesController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _socialUpdatesController =
      StreamController.broadcast();

  // Getters
  Stream<List<SocialNotification>> get notificationsStream =>
      _notificationsController.stream;
  Stream<List<ActivityItem>> get activitiesStream =>
      _activitiesController.stream;
  Stream<Map<String, dynamic>> get socialUpdatesStream =>
      _socialUpdatesController.stream;

  // Initialize
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadProfiles();
      await _loadFollowData();
      await _loadNotifications();
      await _loadActivities();
      LoggerFactory.info('SocialInteractionService initialized successfully');
    } catch (e) {
      LoggerFactory.error('Error initializing SocialInteractionService: $e');
    }
  }

  // Profile Management
  Future<bool> createProfile({
    required String userId,
    required String username,
    required String displayName,
    String avatarUrl = '',
    String bio = '',
  }) async {
    try {
      // Check if username already exists
      UserProfile? existingProfile;
      try {
        existingProfile = _profiles.values.firstWhere(
          (profile) => profile.username.toLowerCase() == username.toLowerCase(),
        );
      } catch (e) {
        existingProfile = null;
      }

      if (existingProfile != null) {
        LoggerFactory.warning('Username already exists: $username');
        return false;
      }

      final profile = UserProfile(
        userId: userId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
        joinDate: DateTime.now(),
        stats: {
          'reviewsCount': 0,
          'followersCount': 0,
          'followingCount': 0,
          'moviesWatched': 0,
          'listsCreated': 0,
        },
      );

      _profiles[userId] = profile;
      await _saveProfiles();

      // Add welcome activity
      await _addActivity(ActivityItem(
        id: 'activity_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        username: username,
        userAvatar: avatarUrl,
        type: ActivityType.userFollowed,
        description: 'Joined the community!',
        data: {'isWelcome': true},
        timestamp: DateTime.now(),
      ));

      LoggerFactory.info('Profile created successfully: $userId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error creating profile: $e');
      return false;
    }
  }

  Future<bool> updateProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
    String? bio,
    Map<String, dynamic>? preferences,
    bool? isPrivate,
  }) async {
    try {
      final existingProfile = _profiles[userId];
      if (existingProfile == null) return false;

      _profiles[userId] = existingProfile.copyWith(
        displayName: displayName ?? existingProfile.displayName,
        avatarUrl: avatarUrl ?? existingProfile.avatarUrl,
        bio: bio ?? existingProfile.bio,
        preferences: preferences ?? existingProfile.preferences,
        isPrivate: isPrivate ?? existingProfile.isPrivate,
      );

      await _saveProfiles();
      LoggerFactory.info('Profile updated successfully: $userId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error updating profile: $e');
      return false;
    }
  }

  UserProfile? getProfile(String userId) {
    return _profiles[userId];
  }

  List<UserProfile> searchProfiles(String query, {int limit = 20}) {
    final lowercaseQuery = query.toLowerCase();
    return _profiles.values
        .where((profile) =>
            profile.username.toLowerCase().contains(lowercaseQuery) ||
            profile.displayName.toLowerCase().contains(lowercaseQuery))
        .take(limit)
        .toList();
  }

  // Follow/Unfollow
  Future<bool> followUser(String followerId, String followingId) async {
    try {
      if (followerId == followingId) return false;

      final followerProfile = _profiles[followerId];
      final followingProfile = _profiles[followingId];

      if (followerProfile == null || followingProfile == null) return false;

      // Check if user is blocked
      if (isUserBlocked(followingId, followerId)) return false;

      _followers.putIfAbsent(followingId, () => <String>{});
      _following.putIfAbsent(followerId, () => <String>{});

      final wasAlreadyFollowing = _following[followerId]!.contains(followingId);

      _followers[followingId]!.add(followerId);
      _following[followerId]!.add(followingId);

      await _updateFollowCounts();
      await _saveFollowData();

      if (!wasAlreadyFollowing) {
        // Send notification
        await _createNotification(
          recipientUserId: followingId,
          senderUserId: followerId,
          senderUsername: followerProfile.username,
          senderAvatar: followerProfile.avatarUrl,
          type: NotificationType.follow,
          title: 'New Follower',
          message: '${followerProfile.displayName} started following you',
          data: {'followerId': followerId},
        );

        // Add activity
        await _addActivity(ActivityItem(
          id: 'activity_${DateTime.now().millisecondsSinceEpoch}',
          userId: followerId,
          username: followerProfile.username,
          userAvatar: followerProfile.avatarUrl,
          type: ActivityType.userFollowed,
          description: 'Started following ${followingProfile.displayName}',
          data: {'followingId': followingId},
          timestamp: DateTime.now(),
        ));
      }

      _emitSocialUpdate('follow', {
        'followerId': followerId,
        'followingId': followingId,
        'action': 'followed',
      });

      LoggerFactory.info('User $followerId followed $followingId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error following user: $e');
      return false;
    }
  }

  Future<bool> unfollowUser(String followerId, String followingId) async {
    try {
      _followers[followingId]?.remove(followerId);
      _following[followerId]?.remove(followingId);

      await _updateFollowCounts();
      await _saveFollowData();

      _emitSocialUpdate('unfollow', {
        'followerId': followerId,
        'followingId': followingId,
        'action': 'unfollowed',
      });

      LoggerFactory.info('User $followerId unfollowed $followingId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error unfollowing user: $e');
      return false;
    }
  }

  FollowStatus getFollowStatus(String currentUserId, String targetUserId) {
    if (currentUserId == targetUserId) return FollowStatus.notFollowing;

    if (isUserBlocked(currentUserId, targetUserId) ||
        isUserBlocked(targetUserId, currentUserId)) {
      return FollowStatus.blocked;
    }

    final isFollowing =
        _following[currentUserId]?.contains(targetUserId) ?? false;
    final isFollowedBy =
        _followers[currentUserId]?.contains(targetUserId) ?? false;

    if (isFollowing && isFollowedBy) return FollowStatus.followingBack;
    if (isFollowing) return FollowStatus.following;

    return FollowStatus.notFollowing;
  }

  List<UserProfile> getFollowers(String userId, {int? limit}) {
    final followerIds = _followers[userId] ?? <String>{};
    var followers = followerIds
        .map((id) => _profiles[id])
        .where((profile) => profile != null)
        .cast<UserProfile>()
        .toList();

    if (limit != null) {
      followers = followers.take(limit).toList();
    }

    return followers;
  }

  List<UserProfile> getFollowing(String userId, {int? limit}) {
    final followingIds = _following[userId] ?? <String>{};
    var following = followingIds
        .map((id) => _profiles[id])
        .where((profile) => profile != null)
        .cast<UserProfile>()
        .toList();

    if (limit != null) {
      following = following.take(limit).toList();
    }

    return following;
  }

  // Block/Unblock
  Future<bool> blockUser(String blockerId, String blockedId) async {
    try {
      if (blockerId == blockedId) return false;

      _blockedUsers.putIfAbsent(blockerId, () => <String>{});
      _blockedUsers[blockerId]!.add(blockedId);

      // Unfollow each other if following
      await unfollowUser(blockerId, blockedId);
      await unfollowUser(blockedId, blockerId);

      await _saveBlockedUsers();

      LoggerFactory.info('User $blockerId blocked $blockedId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error blocking user: $e');
      return false;
    }
  }

  Future<bool> unblockUser(String blockerId, String blockedId) async {
    try {
      _blockedUsers[blockerId]?.remove(blockedId);
      await _saveBlockedUsers();

      LoggerFactory.info('User $blockerId unblocked $blockedId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error unblocking user: $e');
      return false;
    }
  }

  bool isUserBlocked(String userId, String potentiallyBlockedId) {
    return _blockedUsers[userId]?.contains(potentiallyBlockedId) ?? false;
  }

  List<UserProfile> getBlockedUsers(String userId) {
    final blockedIds = _blockedUsers[userId] ?? <String>{};
    return blockedIds
        .map((id) => _profiles[id])
        .where((profile) => profile != null)
        .cast<UserProfile>()
        .toList();
  }

  // Notifications
  Future<void> _createNotification({
    required String recipientUserId,
    required String senderUserId,
    required String senderUsername,
    String senderAvatar = '',
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
    String? actionUrl,
  }) async {
    try {
      final notification = SocialNotification(
        id: 'notification_${DateTime.now().millisecondsSinceEpoch}',
        recipientUserId: recipientUserId,
        senderUserId: senderUserId,
        senderUsername: senderUsername,
        senderAvatar: senderAvatar,
        type: type,
        title: title,
        message: message,
        data: data,
        createdAt: DateTime.now(),
        actionUrl: actionUrl,
      );

      _notifications.putIfAbsent(recipientUserId, () => []);
      _notifications[recipientUserId]!.insert(0, notification);

      // Keep only last 100 notifications per user
      if (_notifications[recipientUserId]!.length > 100) {
        _notifications[recipientUserId] =
            _notifications[recipientUserId]!.take(100).toList();
      }

      await _saveNotifications();
      _notificationsController.add(_notifications[recipientUserId]!);
    } catch (e) {
      LoggerFactory.error('Error creating notification: $e');
    }
  }

  List<SocialNotification> getNotifications(String userId,
      {bool unreadOnly = false}) {
    final userNotifications = _notifications[userId] ?? [];

    if (unreadOnly) {
      return userNotifications.where((n) => !n.isRead).toList();
    }

    return userNotifications;
  }

  Future<bool> markNotificationAsRead(
      String userId, String notificationId) async {
    try {
      final userNotifications = _notifications[userId] ?? [];
      final index = userNotifications.indexWhere((n) => n.id == notificationId);

      if (index != -1) {
        _notifications[userId]![index] =
            userNotifications[index].copyWith(isRead: true);
        await _saveNotifications();
        _notificationsController.add(_notifications[userId]!);
        return true;
      }

      return false;
    } catch (e) {
      LoggerFactory.error('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllNotificationsAsRead(String userId) async {
    try {
      final userNotifications = _notifications[userId] ?? [];

      for (int i = 0; i < userNotifications.length; i++) {
        _notifications[userId]![i] =
            userNotifications[i].copyWith(isRead: true);
      }

      await _saveNotifications();
      _notificationsController.add(_notifications[userId]!);

      return true;
    } catch (e) {
      LoggerFactory.error('Error marking all notifications as read: $e');
      return false;
    }
  }

  int getUnreadNotificationsCount(String userId) {
    return getNotifications(userId, unreadOnly: true).length;
  }

  // Activities
  Future<void> _addActivity(ActivityItem activity) async {
    try {
      _activities.insert(0, activity);

      // Keep only last 1000 activities
      if (_activities.length > 1000) {
        _activities.removeRange(1000, _activities.length);
      }

      await _saveActivities();
      _activitiesController.add(_activities);
    } catch (e) {
      LoggerFactory.error('Error adding activity: $e');
    }
  }

  List<ActivityItem> getActivities({
    String? userId,
    List<String>? followingIds,
    int limit = 50,
    int offset = 0,
  }) {
    var activities = _activities.toList();

    // Filter by user if specified
    if (userId != null) {
      activities =
          activities.where((activity) => activity.userId == userId).toList();
    }

    // Filter by following users if specified
    if (followingIds != null) {
      activities = activities
          .where((activity) => followingIds.contains(activity.userId))
          .toList();
    }

    // Filter out private activities from users not being followed
    if (followingIds != null) {
      activities = activities.where((activity) {
        return activity.isPublic || followingIds.contains(activity.userId);
      }).toList();
    }

    // Apply pagination
    final start = offset.clamp(0, activities.length);
    final end = (offset + limit).clamp(0, activities.length);

    return activities.sublist(start, end);
  }

  List<ActivityItem> getFeedActivities(String userId, {int limit = 50}) {
    final followingIds = _following[userId] ?? <String>{};
    final feedFollowingIds = followingIds.toList()
      ..add(userId); // Include user's own activities

    return getActivities(followingIds: feedFollowingIds, limit: limit);
  }

  // User Stats
  Future<void> updateUserStats(
      String userId, Map<String, dynamic> stats) async {
    try {
      final profile = _profiles[userId];
      if (profile == null) return;

      final updatedStats = Map<String, dynamic>.from(profile.stats);
      stats.forEach((key, value) {
        updatedStats[key] = value;
      });

      _profiles[userId] = profile.copyWith(stats: updatedStats);
      await _saveProfiles();
    } catch (e) {
      LoggerFactory.error('Error updating user stats: $e');
    }
  }

  Future<void> incrementUserStat(String userId, String statKey,
      [int increment = 1]) async {
    try {
      final profile = _profiles[userId];
      if (profile == null) return;

      final currentValue = (profile.stats[statKey] ?? 0) as int;
      await updateUserStats(userId, {statKey: currentValue + increment});
    } catch (e) {
      LoggerFactory.error('Error incrementing user stat: $e');
    }
  }

  // Recommendations
  List<UserProfile> getSuggestedUsers(String userId, {int limit = 10}) {
    final currentProfile = _profiles[userId];
    if (currentProfile == null) return [];

    final following = _following[userId] ?? <String>{};
    final blocked = _blockedUsers[userId] ?? <String>{};

    // Get users followed by people the current user follows
    final suggestedIds = <String>{};

    for (final followingId in following) {
      final theirFollowing = _following[followingId] ?? <String>{};
      suggestedIds.addAll(theirFollowing);
    }

    // Remove current user, already following, and blocked users
    suggestedIds.remove(userId);
    suggestedIds.removeAll(following);
    suggestedIds.removeAll(blocked);

    // Get profiles and sort by follower count
    final suggestions = suggestedIds
        .map((id) => _profiles[id])
        .where((profile) => profile != null)
        .cast<UserProfile>()
        .toList();

    suggestions.sort((a, b) {
      final aFollowers = (a.stats['followersCount'] ?? 0) as int;
      final bFollowers = (b.stats['followersCount'] ?? 0) as int;
      return bFollowers.compareTo(aFollowers);
    });

    return suggestions.take(limit).toList();
  }

  // Helper Methods
  Future<void> _updateFollowCounts() async {
    for (final userId in _profiles.keys) {
      final followersCount = _followers[userId]?.length ?? 0;
      final followingCount = _following[userId]?.length ?? 0;

      await updateUserStats(userId, {
        'followersCount': followersCount,
        'followingCount': followingCount,
      });
    }
  }

  void _emitSocialUpdate(String type, Map<String, dynamic> data) {
    _socialUpdatesController.add({
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      ...data,
    });
  }

  // Persistence
  Future<void> _loadProfiles() async {
    final json = _prefs?.getString(_profilesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _profiles.clear();
      data.forEach((key, value) {
        _profiles[key] = UserProfile.fromJson(value);
      });
    }
  }

  Future<void> _saveProfiles() async {
    final data = <String, dynamic>{};
    _profiles.forEach((key, profile) {
      data[key] = profile.toJson();
    });
    final json = jsonEncode(data);
    await _prefs?.setString(_profilesKey, json);
  }

  Future<void> _loadFollowData() async {
    // Load followers
    final followersJson = _prefs?.getString(_followersKey);
    if (followersJson != null) {
      final data = jsonDecode(followersJson) as Map<String, dynamic>;
      _followers.clear();
      data.forEach((userId, followerIds) {
        _followers[userId] = Set<String>.from(followerIds);
      });
    }

    // Load following
    final followingJson = _prefs?.getString(_followingKey);
    if (followingJson != null) {
      final data = jsonDecode(followingJson) as Map<String, dynamic>;
      _following.clear();
      data.forEach((userId, followingIds) {
        _following[userId] = Set<String>.from(followingIds);
      });
    }
  }

  Future<void> _saveFollowData() async {
    // Save followers
    final followersData = <String, List<String>>{};
    _followers.forEach((userId, followerIds) {
      followersData[userId] = followerIds.toList();
    });
    await _prefs?.setString(_followersKey, jsonEncode(followersData));

    // Save following
    final followingData = <String, List<String>>{};
    _following.forEach((userId, followingIds) {
      followingData[userId] = followingIds.toList();
    });
    await _prefs?.setString(_followingKey, jsonEncode(followingData));
  }

  Future<void> _saveBlockedUsers() async {
    final data = <String, List<String>>{};
    _blockedUsers.forEach((userId, blockedIds) {
      data[userId] = blockedIds.toList();
    });
    await _prefs?.setString(_blockedUsersKey, jsonEncode(data));
  }

  Future<void> _loadNotifications() async {
    final json = _prefs?.getString(_notificationsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _notifications.clear();
      data.forEach((userId, notificationsList) {
        _notifications[userId] = (notificationsList as List<dynamic>)
            .map((n) => SocialNotification.fromJson(n))
            .toList();
      });
    }
  }

  Future<void> _saveNotifications() async {
    final data = <String, dynamic>{};
    _notifications.forEach((userId, notifications) {
      data[userId] = notifications.map((n) => n.toJson()).toList();
    });
    await _prefs?.setString(_notificationsKey, jsonEncode(data));
  }

  Future<void> _loadActivities() async {
    final json = _prefs?.getString(_activitiesKey);
    if (json != null) {
      final data = jsonDecode(json) as List<dynamic>;
      _activities.clear();
      _activities.addAll(data.map((a) => ActivityItem.fromJson(a)));
    }
  }

  Future<void> _saveActivities() async {
    final data = _activities.map((a) => a.toJson()).toList();
    await _prefs?.setString(_activitiesKey, jsonEncode(data));
  }

  // Dispose
  void dispose() {
    _notificationsController.close();
    _activitiesController.close();
    _socialUpdatesController.close();
  }
}
