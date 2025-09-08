import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/app_localizations.dart';


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
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.outline.withValues(alpha: 0.2 * 255),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_max), 
                label: l10n.home
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.library_books_outlined), 
                label: l10n.myLibrary
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.bar_chart_outlined),
                activeIcon: const Icon(Icons.bar_chart),
                label: l10n.statistics
              ),
            ],
          ),
        ],
      ),
    );
  }
}
