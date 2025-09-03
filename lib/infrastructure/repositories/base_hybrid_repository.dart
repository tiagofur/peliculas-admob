import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/services/persistent_sync_queue.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';

/// Base abstract class for hybrid repositories that support both local storage
/// and remote synchronization with Supabase. This class consolidates common
/// sync logic and provides a consistent interface for all hybrid repositories.
abstract class BaseHybridRepository<T extends Syncable>
    implements SyncableRepository<T> {
  BaseHybridRepository({required Ref ref}) : _ref = ref {
    _initializeComponents();
  }

  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  late final PersistentSyncQueue _syncQueue;

  /// Get access to the sync queue for subclasses
  PersistentSyncQueue get syncQueue => _syncQueue;

  /// Get access to Supabase client for subclasses
  SupabaseClient get supabase => _supabase;

  /// Initialize common components for sync functionality
  Future<void> _initializeComponents() async {
    _syncQueue = PersistentSyncQueue();
    await _syncQueue.initialize();
    LoggerFactory.info('📦 $runtimeType initialized');
  }

  /// Check if there's internet connectivity
  @protected
  Future<void> checkOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw NetworkException();
    }
  }

  /// Check if the user is currently authenticated
  @protected
  bool isAuthenticated() {
    final appState = _ref.read(appStateProvider);
    return appState.isAuthenticated && appState.user != null;
  }

  /// Get the current user ID
  @protected
  String? getCurrentUserId() {
    return _ref.read(appStateProvider).user?.id;
  }

  /// Template method for syncing data with Supabase
  /// This implements the common sync flow for all hybrid repositories
  @override
  Future<void> syncWithSupabase() async {
    if (!isAuthenticated()) {
      LoggerFactory.warning(
          '❌ User not authenticated, skipping $runtimeType sync');
      return;
    }

    LoggerFactory.info('🔄 Starting $runtimeType sync...');

    try {
      await checkOnline();

      // Get local and remote data
      final localData = await getLocalData();
      final remoteData = await getRemoteData();

      LoggerFactory.info(
          '📊 $runtimeType sync - Local: ${localData.length}, Remote: ${remoteData.length}');

      // Process sync logic
      await _processSyncData(localData, remoteData);

      LoggerFactory.info('✅ $runtimeType sync completed successfully');
    } on SyncException catch (e) {
      LoggerFactory.error('❌ Sync error in $runtimeType: $e');
      rethrow;
    } catch (e) {
      LoggerFactory.error('❌ Unexpected error in $runtimeType sync: $e');
      throw SupabaseSyncException('Sync failed for $runtimeType: $e');
    }
  }

  /// Process sync data - to be implemented by subclasses
  Future<void> _processSyncData(List<T> localData, List<T> remoteData) async {
    // Find items to upload (local items not in remote)
    final localIds = localData.map((item) => item.id).toSet();
    final remoteIds = remoteData.map((item) => item.id).toSet();

    final toUpload =
        localData.where((item) => !remoteIds.contains(item.id)).toList();
    final toDownload =
        remoteData.where((item) => !localIds.contains(item.id)).toList();

    // Find conflicts (items that exist both locally and remotely)
    final conflictLocalItems =
        localData.where((item) => remoteIds.contains(item.id)).toList();
    final conflictRemoteItems =
        remoteData.where((item) => localIds.contains(item.id)).toList();

    // Upload new local items
    if (toUpload.isNotEmpty) {
      LoggerFactory.info('⬆️ Uploading ${toUpload.length} new items');
      await upload(toUpload);
    }

    // Download new remote items
    if (toDownload.isNotEmpty) {
      LoggerFactory.info('⬇️ Downloading ${toDownload.length} new items');
      await download(toDownload);
    }

    // Resolve conflicts
    if (conflictLocalItems.isNotEmpty && conflictRemoteItems.isNotEmpty) {
      LoggerFactory.info(
          '🔧 Resolving conflicts for ${conflictLocalItems.length} items');
      await resolveConflicts(conflictLocalItems, conflictRemoteItems);
    }
  }

  /// Get pending sync operations from the queue
  @override
  Future<List<String>> getPendingSyncItems() async {
    final operations = _syncQueue.getPendingOperations();
    return operations.map((op) => op.id).toList();
  }

  /// Check if there are pending sync operations
  @override
  Future<bool> hasPendingSync() async {
    final stats = _syncQueue.getStats();
    return stats.pendingOperations > 0;
  }

  /// Clear sync markers for a specific item
  @override
  Future<void> clearSyncMarker(String itemId) async {
    LoggerFactory.info('🧹 Clearing sync marker for: $itemId');
    // Sync operations are automatically cleared when completed
  }

  /// Mark an item for sync (legacy method, now uses sync queue)
  @override
  Future<void> markForSync(String itemId) async {
    LoggerFactory.warning('markForSync legacy method called for: $itemId');
    // This method is kept for compatibility but should use enqueue with SyncOperation
  }

  /// Clear local data (useful for logout)
  Future<void> clearLocalData() async {
    LoggerFactory.info('🧹 Clearing local data for $runtimeType');
    await _syncQueue.clear();
    await clearRepositoryData();
  }

  // Abstract methods to be implemented by subclasses

  /// Clear repository-specific data
  Future<void> clearRepositoryData();

  /// Get the Supabase table name for this repository
  String get tableName;

  /// Map data from Supabase response to domain entity
  T mapFromSupabase(Map<String, dynamic> data);

  /// Map domain entity to Supabase format
  Map<String, dynamic> mapToSupabase(T item);
}
