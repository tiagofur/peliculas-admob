import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/logging/logger_factory.dart';
import '../core/utils/error_handler_helper.dart';
import '../presentation/providers/auth_provider.dart';

class QuickLoginWidget extends ConsumerStatefulWidget {
  const QuickLoginWidget({super.key});

  @override
  ConsumerState<QuickLoginWidget> createState() => _QuickLoginWidgetState();
}

class _QuickLoginWidgetState extends ConsumerState<QuickLoginWidget> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with test data
    _emailController.text = 'test@peliculas.app';
    _passwordController.text = 'TestPassword123!';
    _nameController.text = 'Usuario de Prueba';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);

    try {
      LoggerFactory.info('🔑 Intentando login con: ${_emailController.text}');

      await ref.read(authNotifierProvider.notifier).signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );

      LoggerFactory.info('✅ Login exitoso');

      if (mounted) {
        ErrorHandlerHelper.showLoginSuccess(context);
        context.go('/');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error en login: $e');

      if (mounted) {
        ErrorHandlerHelper.handleException(context, e, onRetry: _signIn);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    try {
      LoggerFactory.info(
          '👤 Intentando crear usuario: ${_emailController.text}');

      await ref.read(authNotifierProvider.notifier).signUp(
            email: _emailController.text,
            password: _passwordController.text,
            fullName: _nameController.text,
          );

      LoggerFactory.info('✅ Usuario creado exitosamente');

      if (mounted) {
        ErrorHandlerHelper.showAccountCreated(context);
        context.go('/');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error creando usuario: $e');

      if (mounted) {
        ErrorHandlerHelper.handleException(context, e, onRetry: _signUp);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      LoggerFactory.info('🚪 Cerrando sesión...');

      await ref.read(authNotifierProvider.notifier).signOut();

      LoggerFactory.info('✅ Sesión cerrada');

      if (mounted) {
        ErrorHandlerHelper.showLogoutSuccess(context);
      }
    } catch (e) {
      LoggerFactory.error('❌ Error cerrando sesión: $e');

      if (mounted) {
        ErrorHandlerHelper.handleException(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado actual',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Autenticado: $isAuthenticated'),
            Text('Usuario: ${currentUser?.email ?? 'null'}'),
            const SizedBox(height: 24),
            if (!isAuthenticated) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'test@peliculas.app',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'TestPassword123!',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  hintText: 'Usuario de Prueba',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Iniciar Sesión'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      child: const Text('Crear Usuario'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Usuario autenticado correctamente',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                    ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _signOut,
                child: const Text('Cerrar Sesión'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/debug/profile'),
                child: const Text('Ir a Debug de Perfil'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
