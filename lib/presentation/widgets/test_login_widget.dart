import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class TestLoginWidget extends ConsumerStatefulWidget {
  const TestLoginWidget({super.key});

  @override
  ConsumerState<TestLoginWidget> createState() => _TestLoginWidgetState();
}

class _TestLoginWidgetState extends ConsumerState<TestLoginWidget> {
  bool _isLoading = false;
  String _status = 'No autenticado';

  // Credenciales de prueba
  static const String testEmail = 'test@peliculas.com';
  static const String testPassword = 'TestPassword123!';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final authNotifier = ref.watch(authNotifierProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  user != null ? Icons.person : Icons.person_off,
                  color: user != null ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Test de Autenticación',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Usuario: ${user?.email ?? 'No autenticado'}'),
            Text('Estado: $_status'),
            const SizedBox(height: 16),
            if (user == null) ...[
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _loginTest,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login Test'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerTest,
                    child: const Text('Register Test'),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _logout,
                    child: const Text('Logout'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Usuario autenticado ✅',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                ],
              ),
            ],
            if (authNotifier.hasError) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Error: ${authNotifier.error}',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loginTest() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _status = 'Haciendo login...';
    });

    try {
      await ref.read(authNotifierProvider.notifier).signIn(
            email: testEmail,
            password: testPassword,
          );

      setState(() {
        _status = 'Login exitoso';
      });
    } catch (e) {
      setState(() {
        _status = 'Error en login: $e';
      });
      print('❌ Error en login de prueba: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _registerTest() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _status = 'Registrando usuario...';
    });

    try {
      await ref.read(authNotifierProvider.notifier).signUp(
            email: testEmail,
            password: testPassword,
            fullName: 'Usuario de Prueba',
          );

      setState(() {
        _status = 'Registro exitoso';
      });
    } catch (e) {
      setState(() {
        _status = 'Error en registro: $e';
      });
      print('❌ Error en registro de prueba: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _status = 'Cerrando sesión...';
    });

    try {
      await ref.read(authNotifierProvider.notifier).signOut();

      setState(() {
        _status = 'Sesión cerrada';
      });
    } catch (e) {
      setState(() {
        _status = 'Error al cerrar sesión: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
