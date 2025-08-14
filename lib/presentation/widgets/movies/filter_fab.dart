import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../views/views.dart';

class FilterFab extends ConsumerWidget {
  const FilterFab({
    super.key,
    this.onFiltersApplied,
  });

  final VoidCallback? onFiltersApplied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFiltersCount = ref.watch(activeFiltersCountProvider);
    final hasActiveFilters = activeFiltersCount > 0;

    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.of(context).push<MovieFilter>(
          MaterialPageRoute(
            builder: (context) => const FiltersView(),
          ),
        );

        if (result != null && onFiltersApplied != null) {
          onFiltersApplied!();
        }
      },
      icon: Stack(
        children: [
          const Icon(Icons.filter_list),
          if (hasActiveFilters)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '$activeFiltersCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      label: Text(
        hasActiveFilters ? 'Filtros ($activeFiltersCount)' : 'Filtros',
      ),
      backgroundColor: hasActiveFilters ? Colors.orange : null,
    );
  }
}

class QuickFiltersBar extends ConsumerWidget {
  const QuickFiltersBar({
    super.key,
    this.onFilterChanged,
  });

  final VoidCallback? onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodOptions = ref.watch(moodOptionsProvider);
    final selectedMood = ref.watch(movieFiltersNotifierProvider).mood;
    final notifier = ref.read(movieFiltersNotifierProvider.notifier);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Filtro rápido: Mejor calificadas
          _QuickFilterChip(
            label: 'Mejor Calificadas',
            icon: Icons.star,
            isSelected: ref.watch(movieFiltersNotifierProvider).minRating != null,
            onTap: () {
              final currentFilter = ref.read(movieFiltersNotifierProvider);
              if (currentFilter.minRating != null) {
                notifier.updateRatingRange(null, null);
              } else {
                notifier.applyQuickFilter(
                  minRating: 7.0,
                  sortBy: 'vote_average.desc',
                );
              }
              onFilterChanged?.call();
            },
          ),
          const SizedBox(width: 8),
          // Filtro rápido: Más recientes
          _QuickFilterChip(
            label: 'Más Recientes',
            icon: Icons.new_releases,
            isSelected: ref.watch(movieFiltersNotifierProvider).minYear != null,
            onTap: () {
              final currentFilter = ref.read(movieFiltersNotifierProvider);
              if (currentFilter.minYear != null) {
                notifier.updateYearRange(null, null);
              } else {
                notifier.applyQuickFilter(
                  minYear: DateTime.now().year - 2,
                  sortBy: 'primary_release_date.desc',
                );
              }
              onFilterChanged?.call();
            },
          ),
          const SizedBox(width: 8),
          // Filtro rápido: Populares
          _QuickFilterChip(
            label: 'Populares',
            icon: Icons.trending_up,
            isSelected: ref.watch(movieFiltersNotifierProvider).sortBy == 'popularity.desc',
            onTap: () {
              final currentFilter = ref.read(movieFiltersNotifierProvider);
              if (currentFilter.sortBy == 'popularity.desc') {
                notifier.updateSortBy(null);
              } else {
                notifier.applyQuickFilter(sortBy: 'popularity.desc');
              }
              onFilterChanged?.call();
            },
          ),
          const SizedBox(width: 16),
          // Separador
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.withValues(alpha: 0.3),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(width: 8),
          // Estados de ánimo
          ...moodOptions.take(4).map((mood) {
            final isSelected = selectedMood == mood.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _QuickFilterChip(
                label: mood.name,
                emoji: mood.emoji,
                color: mood.color,
                isSelected: isSelected,
                onTap: () {
                  if (isSelected) {
                    notifier.updateMood(null);
                    notifier.updateGenres([]);
                  } else {
                    notifier.applyMoodFilter(mood);
                  }
                  onFilterChanged?.call();
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    this.icon,
    this.emoji,
    this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final String? emoji;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Theme.of(context).primaryColor)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? Theme.of(context).primaryColor)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(
                emoji!,
                style: const TextStyle(fontSize: 16),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            if (emoji != null || icon != null) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}