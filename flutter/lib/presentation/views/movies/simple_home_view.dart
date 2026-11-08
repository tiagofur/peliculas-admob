import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';

class SimpleHomeView extends ConsumerWidget {
  const SimpleHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LoggerFactory.debug(
      '🏠 SimpleHomeView - Building minimal UI for web testing',
      data: {'view': 'SimpleHomeView'},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Películas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              Icon(
                Icons.movie,
                size: 64,
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              Text(
                '¡Aplicación Web Funcionando!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'La aplicación se está ejecutando correctamente en web',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Estado de los Servicios',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('✅ Router: Configurado'),
                      Text('✅ Theme: Cargado'),
                      Text('✅ Riverpod: Inicializado'),
                      Text('✅ Web Platform: Compatible'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
