import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/services/token_refresh_service.dart';
import '../providers/auth_provider.dart';
import '../providers/persistent_auth_provider.dart';

/// Widget de debug para mostrar el estado de autenticación persistente
/// Solo se muestra en modo debug
class PersistentAuthDebugWidget extends ConsumerWidget {
  const PersistentAuthDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo mostrar en modo debug
    if (!kDebugMode) return const SizedBox.shrink();

    final authState = ref.watch(appStateProvider);
    final persistentAuthInfo = ref.watch(persistentAuthInfoProvider);
    final tokenRefreshEvents = ref.watch(tokenRefreshEventsProvider);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              authState.isAuthenticated
                  ? Icons.verified_user
                  : Icons.person_outline,
              color: authState.isAuthenticated ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('Auth Debug', style: TextStyle(fontSize: 14)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estado básico de autenticación
                _buildAuthStateSection(authState),
                const Divider(height: 20),

                // Información de sesión persistente
                _buildPersistentSessionSection(persistentAuthInfo),
                const Divider(height: 20),

                // Eventos de refresco de tokens
                _buildTokenEventsSection(tokenRefreshEvents),
                const Divider(height: 20),

                // Acciones de debug
                _buildDebugActions(ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthStateSection(AppState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Auth State', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Mode: ${authState.mode.toString().split('.').last}'),
        Text('Is Authenticated: ${authState.isAuthenticated}'),
        Text('Is Guest: ${authState.isGuest}'),
        Text('Has Local Data: ${authState.hasLocalData}'),
        if (authState.user != null) ...[
          Text('User ID: ${authState.user?.id ?? 'N/A'}'),
          Text('Email: ${authState.user?.email ?? 'N/A'}'),
        ],
      ],
    );
  }

  Widget _buildPersistentSessionSection(
      AsyncValue<Map<String, dynamic>> persistentAuthInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Persistent Session',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        persistentAuthInfo.when(
          data: (info) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Has Persisted: ${info['has_persisted_session']}'),
              if (info['token_status'] != null) ...[
                Text('Token Valid: ${info['token_status']['is_valid']}'),
                Text('Token Healthy: ${info['token_status']['is_healthy']}'),
                Text('Needs Refresh: ${info['token_status']['needs_refresh']}'),
                Text('Is Refreshing: ${info['token_status']['is_refreshing']}'),
                if (info['token_status']['time_until_expiry_minutes'] != null)
                  Text(
                      'Expires in: ${info['token_status']['time_until_expiry_minutes']} min'),
                if (info['token_status']['error'] != null)
                  Text('Error: ${info['token_status']['error']}',
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          loading: () => const Text('Loading session info...'),
          error: (error, _) => Text('Error: $error',
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildTokenEventsSection(AsyncValue<TokenRefreshEvent> tokenEvents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Token Events',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        tokenEvents.when(
          data: (event) => Text(
            _formatTokenEvent(event),
            style: TextStyle(
              fontSize: 12,
              color: _getEventColor(event),
            ),
          ),
          loading: () => const Text('Listening for events...',
              style: TextStyle(fontSize: 12)),
          error: (error, _) => Text('Event error: $error',
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ),
      ],
    );
  }

  String _formatTokenEvent(TokenRefreshEvent event) {
    switch (event) {
      case UserSignedInEvent(userId: final userId):
        return 'User signed in: $userId';
      case UserSignedOutEvent():
        return 'User signed out';
      case RefreshStartedEvent(userId: final userId):
        return 'Token refresh started: $userId';
      case TokenRefreshedEvent(userId: final userId):
        return 'Token refreshed: $userId';
      case RefreshFailedEvent(error: final error):
        return 'Refresh failed: $error';
      case SessionInvalidatedEvent():
        return 'Session invalidated';
    }
  }

  Color _getEventColor(TokenRefreshEvent event) {
    switch (event) {
      case UserSignedInEvent():
      case TokenRefreshedEvent():
        return Colors.green;
      case RefreshFailedEvent():
      case SessionInvalidatedEvent():
        return Colors.red;
      case RefreshStartedEvent():
        return Colors.orange;
      case UserSignedOutEvent():
        return Colors.grey;
    }
  }

  Widget _buildDebugActions(WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Debug Actions',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(tokenRefreshNotifierProvider.notifier)
                    .forceRefresh();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 32),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Force Refresh'),
            ),
            ElevatedButton(
              onPressed: () async {
                final authRepo = ref.read(authRepositoryProvider);
                final sessionInfo = await authRepo.getSessionInfo();
                debugPrint('Session Info: ${sessionInfo ?? 'null'}');

                if (ref.context.mounted) {
                  ScaffoldMessenger.of(ref.context).showSnackBar(
                    const SnackBar(
                        content: Text('Session info printed to debug console')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 32),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Log Session'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Forzar invalidación de providers para refresh de estado
                ref.invalidate(persistentAuthInfoProvider);
                ref.invalidate(tokenStatusProvider);

                if (ref.context.mounted) {
                  ScaffoldMessenger.of(ref.context).showSnackBar(
                    const SnackBar(content: Text('Auth state refreshed')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 32),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Refresh State'),
            ),
          ],
        ),
      ],
    );
  }
}
