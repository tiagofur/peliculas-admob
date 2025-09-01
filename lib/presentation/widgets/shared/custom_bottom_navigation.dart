import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_status_indicator.dart';

class CustomBottomNavigation extends ConsumerWidget {
  const CustomBottomNavigation({
    super.key, 
    required this.currentIndex,
    required this.onItemTapped,
  });

  final int currentIndex;
  final void Function(int) onItemTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.outline.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador de sincronización en la parte superior del bottom nav
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SyncStatusIndicator(
                  size: 16,
                  showText: true,
                  compact: true,
                ),
              ],
            ),
          ),
          // Bottom navigation bar
          BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onItemTapped,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            backgroundColor: colors.surface,
            selectedItemColor: colors.primary,
            unselectedItemColor: colors.onSurface.withValues(alpha: 0.6),
            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
            iconSize: 24,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_max), 
                label: 'Inicio'
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.library_books_outlined), 
                label: 'Mi Biblioteca'
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Estadísticas'
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.play_circle_outline),
                activeIcon: Icon(Icons.play_circle),
                label: 'Streaming'
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events_outlined),
                activeIcon: Icon(Icons.emoji_events),
                label: 'Desafíos'
              ),
            ],
          ),
        ],
      ),
    );
  }
}
