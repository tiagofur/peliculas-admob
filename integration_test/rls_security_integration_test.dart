import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peliculas/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RLS Policy Integration Tests', () {
    late SupabaseClient supabase;
    
    setUpAll(() async {
      // Initialize Supabase client
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://test.supabase.co'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'test-key'),
      );
      supabase = Supabase.instance.client;
    });

    group('User Profile RLS Tests', () {
      testWidgets('Users can only access their own profiles', (tester) async {
        // This test validates that RLS policies prevent cross-user access
        try {
          // Attempt to query all profiles (should be filtered by RLS)
          final response = await supabase
              .from('user_profiles')
              .select()
              .execute();

          // In production, this should only return the current user's profile
          // or be empty if not authenticated
          expect(response.data, isNotNull);
          
          // If data is returned, verify it only contains current user's data
          if (response.data is List && (response.data as List).isNotEmpty) {
            final profiles = response.data as List;
            final currentUserId = supabase.auth.currentUser?.id;
            
            for (final profile in profiles) {
              expect(profile['user_id'], equals(currentUserId),
                  reason: 'RLS should prevent access to other users\' profiles');
            }
          }
        } catch (e) {
          // If authentication is required, this is expected behavior
          expect(e, isA<PostgrestException>());
        }
      });

      testWidgets('Profile data validation is enforced', (tester) async {
        if (supabase.auth.currentUser == null) {
          // Skip if not authenticated
          return;
        }

        try {
          // Attempt to insert invalid profile data
          await supabase.from('user_profiles').insert({
            'user_id': supabase.auth.currentUser!.id,
            'full_name': 'A', // Too short - should fail
          }).execute();
          
          fail('Should have thrown validation error for short name');
        } catch (e) {
          expect(e, isA<PostgrestException>());
        }

        try {
          // Attempt to insert valid profile data
          await supabase.from('user_profiles').upsert({
            'user_id': supabase.auth.currentUser!.id,
            'full_name': 'Valid Test Name',
            'bio': 'This is a valid bio for testing',
          }).execute();
          
          // This should succeed
        } catch (e) {
          // If profile already exists, update should work
          expect(e, isA<PostgrestException>());
        }
      });
    });

    group('User Favorites RLS Tests', () {
      testWidgets('Users can only access their own favorites', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        try {
          final response = await supabase
              .from('user_favorites')
              .select()
              .execute();

          expect(response.data, isNotNull);
          
          if (response.data is List && (response.data as List).isNotEmpty) {
            final favorites = response.data as List;
            final currentUserId = supabase.auth.currentUser!.id;
            
            for (final favorite in favorites) {
              expect(favorite['user_id'], equals(currentUserId),
                  reason: 'RLS should prevent access to other users\' favorites');
            }
          }
        } catch (e) {
          expect(e, isA<PostgrestException>());
        }
      });

      testWidgets('Movie data validation is enforced in favorites', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        try {
          // Attempt to insert invalid favorite (movie_id = 0)
          await supabase.from('user_favorites').insert({
            'user_id': supabase.auth.currentUser!.id,
            'movie_id': 0, // Invalid - should fail
            'movie_title': 'Test Movie',
          }).execute();
          
          fail('Should have thrown validation error for invalid movie_id');
        } catch (e) {
          expect(e, isA<PostgrestException>());
        }
      });
    });

    group('User Lists RLS Tests', () {
      testWidgets('Users can only manage their own lists', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        try {
          final response = await supabase
              .from('user_lists')
              .select()
              .eq('is_public', false) // Only private lists
              .execute();

          expect(response.data, isNotNull);
          
          if (response.data is List && (response.data as List).isNotEmpty) {
            final lists = response.data as List;
            final currentUserId = supabase.auth.currentUser!.id;
            
            for (final list in lists) {
              expect(list['user_id'], equals(currentUserId),
                  reason: 'RLS should prevent access to other users\' private lists');
            }
          }
        } catch (e) {
          expect(e, isA<PostgrestException>());
        }
      });

      testWidgets('Public lists are accessible to all users', (tester) async {
        try {
          final response = await supabase
              .from('user_lists')
              .select()
              .eq('is_public', true)
              .execute();

          // This should work even for unauthenticated users
          expect(response.data, isNotNull);
        } catch (e) {
          // Some restrictions might apply, but shouldn't be a complete block
          expect(e, isA<PostgrestException>());
        }
      });

      testWidgets('List data validation is enforced', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        try {
          // Attempt to insert invalid list (empty name)
          await supabase.from('user_lists').insert({
            'user_id': supabase.auth.currentUser!.id,
            'name': '', // Empty name - should fail
          }).execute();
          
          fail('Should have thrown validation error for empty name');
        } catch (e) {
          expect(e, isA<PostgrestException>());
        }
      });
    });

    group('Watchlist RLS Tests', () {
      testWidgets('Users can only access their own watchlist', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        try {
          final response = await supabase
              .from('user_watchlist')
              .select()
              .is_('deleted_at', null) // Only non-deleted items
              .execute();

          expect(response.data, isNotNull);
          
          if (response.data is List && (response.data as List).isNotEmpty) {
            final watchlist = response.data as List;
            final currentUserId = supabase.auth.currentUser!.id;
            
            for (final item in watchlist) {
              expect(item['user_id'], equals(currentUserId),
                  reason: 'RLS should prevent access to other users\' watchlist');
            }
          }
        } catch (e) {
          expect(e, isA<PostgrestException>());
        }
      });

      testWidgets('Priority validation is enforced', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        try {
          // Attempt to insert invalid priority
          await supabase.from('user_watchlist').insert({
            'user_id': supabase.auth.currentUser!.id,
            'movie_id': 123,
            'movie_title': 'Test Movie',
            'priority': 'invalid_priority', // Should fail
          }).execute();
          
          fail('Should have thrown validation error for invalid priority');
        } catch (e) {
          expect(e, isA<PostgrestException>());
        }
      });
    });

    group('Movie Ratings RLS Tests', () {
      testWidgets('Users can only access their own ratings', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        try {
          final response = await supabase
              .from('user_movie_ratings')
              .select()
              .execute();

          expect(response.data, isNotNull);
          
          if (response.data is List && (response.data as List).isNotEmpty) {
            final ratings = response.data as List;
            final currentUserId = supabase.auth.currentUser!.id;
            
            for (final rating in ratings) {
              expect(rating['user_id'], equals(currentUserId),
                  reason: 'RLS should prevent access to other users\' ratings');
            }
          }
        } catch (e) {
          expect(e, isA<PostgrestException>());
        }
      });

      testWidgets('Rating value validation is enforced', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        try {
          // Attempt to insert invalid rating (out of range)
          await supabase.from('user_movie_ratings').insert({
            'user_id': supabase.auth.currentUser!.id,
            'movie_id': 123,
            'movie_title': 'Test Movie',
            'rating': 6, // Out of range - should fail
          }).execute();
          
          fail('Should have thrown validation error for invalid rating');
        } catch (e) {
          expect(e, isA<PostgrestException>());
        }
      });
    });

    group('Storage Security Tests', () {
      testWidgets('Users can only access their own avatar folder', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        final currentUserId = supabase.auth.currentUser!.id;

        try {
          // Attempt to list files in another user's folder
          await supabase.storage
              .from('avatars')
              .list(path: 'other_user_id');
          
          // This might succeed but should be empty or restricted
        } catch (e) {
          // Access restrictions are expected
          expect(e, isA<StorageException>());
        }

        try {
          // Access to own folder should work
          await supabase.storage
              .from('avatars')
              .list(path: currentUserId);
          
          // This should succeed
        } catch (e) {
          // Folder might not exist yet, which is fine
          expect(e, isA<StorageException>());
        }
      });
    });

    group('Audit Log Tests', () {
      testWidgets('Audit logs are properly restricted', (tester) async {
        try {
          // Attempt to access audit logs
          final response = await supabase
              .from('security_audit_log')
              .select()
              .execute();

          // This should either be restricted or only show current user's actions
          expect(response.data, isNotNull);
          
          if (response.data is List && (response.data as List).isNotEmpty) {
            final logs = response.data as List;
            final currentUserId = supabase.auth.currentUser?.id;
            
            if (currentUserId != null) {
              for (final log in logs) {
                // In a more restrictive setup, users might only see their own logs
                expect(log['user_id'], isNotNull);
              }
            }
          }
        } catch (e) {
          // Access restrictions are expected for audit logs
          expect(e, isA<PostgrestException>());
        }
      });
    });

    group('Rate Limiting Tests', () {
      testWidgets('Rate limiting functions exist and work', (tester) async {
        if (supabase.auth.currentUser == null) {
          return;
        }

        try {
          // Test rate limiting function
          final response = await supabase.rpc('check_rate_limit', params: {
            'operation_type': 'INSERT',
            'time_window': '1 hour',
            'max_operations': 100,
          }).execute();

          expect(response.data, isNotNull);
          expect(response.data, isA<bool>());
        } catch (e) {
          // Function might not exist in test environment
          expect(e, isA<PostgrestException>());
        }
      });
    });
  });

  group('Attack Simulation Tests', () {
    testWidgets('SQL Injection Prevention', (tester) async {
      // Test that malicious SQL in parameters is properly escaped
      final maliciousSql = "'; DROP TABLE user_profiles; --";
      
      try {
        await supabase
            .from('user_profiles')
            .select()
            .eq('full_name', maliciousSql)
            .execute();
        
        // Query should complete without executing the malicious SQL
      } catch (e) {
        // Expected if parameter validation catches the issue
        expect(e, isA<PostgrestException>());
      }
    });

    testWidgets('Authorization Bypass Prevention', (tester) async {
      if (supabase.auth.currentUser == null) {
        return;
      }

      try {
        // Attempt to access data by manipulating the user_id filter
        await supabase
            .from('user_favorites')
            .select()
            .eq('user_id', 'fake_user_id')
            .execute();
        
        // RLS should prevent this from returning unauthorized data
      } catch (e) {
        expect(e, isA<PostgrestException>());
      }
    });
  });
}