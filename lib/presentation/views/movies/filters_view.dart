import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';

class FiltersView extends ConsumerStatefulWidget {
  const FiltersView({super.key});

  @override
  FiltersViewState createState() => FiltersViewState();
}

class FiltersViewState extends ConsumerState<FiltersView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(movieFiltersNotifierProvider);
    final activeFiltersCount = ref.watch(activeFiltersCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtros Avanzados'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.category), text: 'Géneros'),
            Tab(icon: Icon(Icons.tune), text: 'Criterios'),
            Tab(icon: Icon(Icons.mood), text: 'Estado de Ánimo'),
            Tab(icon: Icon(Icons.sort), text: 'Ordenar'),
          ],
        ),
        actions: [
          if (activeFiltersCount > 0)
            TextButton(
              onPressed: () {
                ref.read(movieFiltersNotifierProvider.notifier).clearFilters();
              },
              child: Text(
                'Limpiar ($activeFiltersCount)',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GenresTab(),
          _CriteriaTab(),
          _MoodTab(),
          _SortTab(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(filter);
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            activeFiltersCount > 0
                ? 'Aplicar Filtros ($activeFiltersCount)'
                : 'Aplicar Filtros',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _GenresTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genreOptions = ref.watch(genreOptionsProvider);
    final selectedGenres = ref.watch(movieFiltersNotifierProvider).genres;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona los géneros que te interesan:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: genreOptions.length,
              itemBuilder: (context, index) {
                final genre = genreOptions[index];
                final isSelected = selectedGenres.contains(genre.id);

                return FilterChip(
                  selected: isSelected,
                  onSelected: (selected) {
                    final newGenres = List<String>.from(selectedGenres);
                    if (selected) {
                      newGenres.add(genre.id);
                    } else {
                      newGenres.remove(genre.id);
                    }
                    ref
                        .read(movieFiltersNotifierProvider.notifier)
                        .updateGenres(newGenres);
                  },
                  avatar: Text(genre.emoji),
                  label: Text(genre.name),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CriteriaTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(movieFiltersNotifierProvider);
    final notifier = ref.read(movieFiltersNotifierProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildYearRangeSection(filter, notifier),
          const SizedBox(height: 24),
          _buildRatingRangeSection(filter, notifier),
          const SizedBox(height: 24),
          _buildDurationRangeSection(filter, notifier),
          const SizedBox(height: 24),
          _buildLanguageSection(filter, notifier),
          const SizedBox(height: 24),
          _buildAdultContentSection(filter, notifier),
        ],
      ),
    );
  }

  Widget _buildYearRangeSection(
      MovieFilter filter, MovieFiltersNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Año de Estreno',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: filter.minYear?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Desde',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final year = int.tryParse(value);
                  notifier.updateYearRange(year, filter.maxYear);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: filter.maxYear?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Hasta',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final year = int.tryParse(value);
                  notifier.updateYearRange(filter.minYear, year);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingRangeSection(
      MovieFilter filter, MovieFiltersNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calificación: ${filter.minRating?.toStringAsFixed(1) ?? '0.0'} - ${filter.maxRating?.toStringAsFixed(1) ?? '10.0'}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        RangeSlider(
          values: RangeValues(
            filter.minRating ?? 0.0,
            filter.maxRating ?? 10.0,
          ),
          min: 0.0,
          max: 10.0,
          divisions: 20,
          labels: RangeLabels(
            filter.minRating?.toStringAsFixed(1) ?? '0.0',
            filter.maxRating?.toStringAsFixed(1) ?? '10.0',
          ),
          onChanged: (values) {
            notifier.updateRatingRange(values.start, values.end);
          },
        ),
      ],
    );
  }

  Widget _buildDurationRangeSection(
      MovieFilter filter, MovieFiltersNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duración: ${filter.minDuration ?? 60} - ${filter.maxDuration ?? 180} min',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        RangeSlider(
          values: RangeValues(
            (filter.minDuration ?? 60).toDouble(),
            (filter.maxDuration ?? 180).toDouble(),
          ),
          min: 60,
          max: 240,
          divisions: 18,
          labels: RangeLabels(
            '${filter.minDuration ?? 60} min',
            '${filter.maxDuration ?? 180} min',
          ),
          onChanged: (values) {
            notifier.updateDurationRange(
              values.start.round(),
              values.end.round(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLanguageSection(
      MovieFilter filter, MovieFiltersNotifier notifier) {
    final languages = [
      {'code': null, 'name': 'Todos los idiomas'},
      {'code': 'es', 'name': 'Español'},
      {'code': 'en', 'name': 'Inglés'},
      {'code': 'fr', 'name': 'Francés'},
      {'code': 'it', 'name': 'Italiano'},
      {'code': 'de', 'name': 'Alemán'},
      {'code': 'ja', 'name': 'Japonés'},
      {'code': 'ko', 'name': 'Coreano'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Idioma Original',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: filter.language,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: languages.map((lang) {
            return DropdownMenuItem<String?>(
              value: lang['code'],
              child: Text(lang['name'] as String),
            );
          }).toList(),
          onChanged: (value) {
            notifier.updateLanguage(value);
          },
        ),
      ],
    );
  }

  Widget _buildAdultContentSection(
      MovieFilter filter, MovieFiltersNotifier notifier) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Incluir contenido para adultos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Switch(
          value: filter.includeAdult ?? false,
          onChanged: (value) {
            notifier.updateIncludeAdult(value);
          },
        ),
      ],
    );
  }
}

class _MoodTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodOptions = ref.watch(moodOptionsProvider);
    final selectedMood = ref.watch(movieFiltersNotifierProvider).mood;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Cómo te sientes hoy?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona tu estado de ánimo y te sugeriremos películas perfectas para ti.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: moodOptions.length,
              itemBuilder: (context, index) {
                final mood = moodOptions[index];
                final isSelected = selectedMood == mood.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: mood.color.withValues(alpha: 0.2),
                      child: Text(
                        mood.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      mood.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(mood.description),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: mood.color)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      if (isSelected) {
                        ref
                            .read(movieFiltersNotifierProvider.notifier)
                            .updateMood(null);
                      } else {
                        ref
                            .read(movieFiltersNotifierProvider.notifier)
                            .applyMoodFilter(mood);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SortTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortOptions = ref.watch(sortOptionsProvider);
    final selectedSort = ref.watch(movieFiltersNotifierProvider).sortBy;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ordenar resultados por:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: sortOptions.length,
              itemBuilder: (context, index) {
                final option = sortOptions[index];
                final isSelected = selectedSort == option.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(option.icon),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(option.description),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      ref
                          .read(movieFiltersNotifierProvider.notifier)
                          .updateSortBy(isSelected ? null : option.value);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
