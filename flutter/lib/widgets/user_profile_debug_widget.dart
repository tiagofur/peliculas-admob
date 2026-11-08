import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/logger_factory.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/user_profile/user_profile_providers.dart';

class UserProfileDebugWidget extends ConsumerWidget {
  const UserProfileDebugWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userProfileAsync = ref.watch(userProfileNotifierProvider);
    final userProfileAlert = ref.watch(userProfileAlertProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug User Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado de Autenticación',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Is Authenticated: $isAuthenticated'),
            Text('Current User: ${currentUser?.id ?? 'null'}'),
            Text('User Email: ${currentUser?.email ?? 'null'}'),
            const SizedBox(height: 16),
            Text(
              'Estado del Perfil',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            userProfileAsync.when(
              data: (profile) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile ID: ${profile?.id ?? 'null'}'),
                  Text('Full Name: ${profile?.fullName ?? 'null'}'),
                  Text('Username: ${profile?.username ?? 'null'}'),
                  Text('Avatar URL: ${profile?.avatarUrl ?? 'null'}'),
                  Text('Created At: ${profile?.createdAt ?? 'null'}'),
                ],
              ),
              loading: () => const Text('Cargando perfil...'),
              error: (error, stack) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Error: $error'),
                  const SizedBox(height: 8),
                  Text('Stack: ${stack.toString().substring(0, 200)}...'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (userProfileAlert != null) ...[
              Text(
                'Alertas',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kind: ${userProfileAlert.kind}'),
                    Text('Message: ${userProfileAlert.message}'),
                    Text('Timestamp: ${userProfileAlert.timestamp}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isAuthenticated && currentUser != null) ...[
              ElevatedButton(
                onPressed: () async {
                  try {
                    LoggerFactory.info('🔄 Refrescando perfil de usuario...');
                    await ref
                        .read(userProfileNotifierProvider.notifier)
                        .refreshProfile();
                    LoggerFactory.info('✅ Perfil refrescado exitosamente');
                  } catch (e) {
                    LoggerFactory.error('❌ Error refrescando perfil: $e');
                  }
                },
                child: const Text('Refrescar Perfil'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  try {
                    LoggerFactory.info(
                        '🧪 Probando actualización de perfil...');
                    await ref
                        .read(userProfileNotifierProvider.notifier)
                        .updateProfileFields(
                          fullName:
                              'Usuario de Prueba ${DateTime.now().millisecondsSinceEpoch}',
                        );
                    LoggerFactory.info('✅ Perfil actualizado exitosamente');
                  } catch (e) {
                    LoggerFactory.error('❌ Error actualizando perfil: $e');
                  }
                },
                child: const Text('Probar Actualización'),
              ),
            ] else ...[
              const Text('No hay usuario autenticado para probar operaciones'),
            ],
          ],
        ),
      ),
    );
  }
}
