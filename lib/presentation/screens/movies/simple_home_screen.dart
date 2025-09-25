import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SimpleHomeScreen extends StatelessWidget {
  const SimpleHomeScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const name = 'simple-home-screen';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Películas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Mi Biblioteca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Estadísticas',
          ),
        ],
      ),
    );
  }
}
