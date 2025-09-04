import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions/sync_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../services/persistent_sync_queue.dart';
import '../../domain/repositories/syncable_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../services/connectivity_detector.dart';

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
    await _syncQueue.init();
    LoggerFactory.info('📦 $runtimeType initialized');
  }

  /// Check if there's internet connectivity
  @protected
  Future<void> checkOnline() async {
    final connectivityStatus = await ConnectivityDetector.instance.checkConnectivity();
    if (connectivityStatus == ConnectivityStatus.offline) {
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

      // Add overall timeout for the entire sync operation
      await Future.microtask(() async {
        // Get local and remote data with individual timeouts
        final localDataFuture = getLocalData().timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            LoggerFactory.warning('⏱️ Timeout getting local data for $runtimeType');
            throw TimeoutException('Local data fetch timeout', const Duration(seconds: 20));
          },
        );
        
        final remoteDataFuture = getRemoteData().timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            LoggerFactory.warning('⏱️ Timeout getting remote data for $runtimeType');
            throw TimeoutException('Remote data fetch timeout', const Duration(seconds: 20));
          },
        );

        // Execute in parallel with overall timeout
        final results = await Future.wait([localDataFuture, remoteDataFuture])
          .timeout(const Duration(seconds: 45), onTimeout: () {
            LoggerFactory.warning('⏱️ Overall timeout for $runtimeType sync');
            throw TimeoutException('Overall sync timeout', const Duration(seconds: 45));
          });

        final localData = results[0];
        final remoteData = results[1];

        LoggerFactory.info(
            '📊 $runtimeType sync - Local: ${localData.length}, Remote: ${remoteData.length}');

        // Process sync logic with timeout
        await _processSyncData(localData, remoteData).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            LoggerFactory.warning('⏱️ Timeout processing sync data for $runtimeType');
            throw TimeoutException('Sync processing timeout', const Duration(seconds: 60));
          },
        );
      });

      LoggerFactory.info('✅ $runtimeType sync completed successfully');
    } on TimeoutException catch (e) {
      LoggerFactory.error('⏱️ Timeout in $runtimeType sync: $e');
      throw SupabaseSyncException('Sync timeout for $runtimeType: $e');
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

    // Execute sync operations in parallel with individual error handling
    final syncTasks = <Future<void>>[];

    // Upload new local items
    if (toUpload.isNotEmpty) {
      LoggerFactory.info('⬆️ Uploading ${toUpload.length} new items');
      syncTasks.add(
        upload(toUpload).catchError((error) {
          LoggerFactory.error('❌ Upload failed: $error');
          throw SupabaseSyncException('Upload failed: $error');
        })
      );
    }

    // Download new remote items
    if (toDownload.isNotEmpty) {
      LoggerFactory.info('⬇️ Downloading ${toDownload.length} new items');
      syncTasks.add(
        download(toDownload).catchError((error) {
          LoggerFactory.error('❌ Download failed: $error');
          throw SupabaseSyncException('Download failed: $error');
        })
      );
    }

    // Resolve conflicts
    if (conflictLocalItems.isNotEmpty && conflictRemoteItems.isNotEmpty) {
      LoggerFactory.info(
          '🔧 Resolving conflicts for ${conflictLocalItems.length} items');
      syncTasks.add(
        resolveConflicts(conflictLocalItems, conflictRemoteItems).then((_) {
          LoggerFactory.info('✅ Conflicts resolved');
        }).catchError((error) {
          LoggerFactory.error('❌ Conflict resolution failed: $error');
          throw SupabaseSyncException('Conflict resolution failed: $error');
        })
      );
    }

    // Execute all sync tasks with timeout and error handling
    if (syncTasks.isNotEmpty) {
      try {
        await Future.wait(syncTasks, eagerError: false)
          .timeout(const Duration(seconds: 120), onTimeout: () {
            LoggerFactory.warning('⏱️ Timeout in sync tasks for $runtimeType');
            throw TimeoutException('Sync tasks timeout', const Duration(seconds: 120));
          });
      } catch (e) {
        LoggerFactory.warning('⚠️ Some sync tasks failed, but continuing: $e');
        // Don't rethrow to allow partial sync success
      }
    }
  }

  /// Get pending sync operations from the queue
  @override
  Future<List<String>> getPendingSyncItems() async {
    return await _syncQueue.getItems();
  }

  /// Check if there are pending sync operations
  @override
  Future<bool> hasPendingSync() async {
    return !await _syncQueue.isEmpty;
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
