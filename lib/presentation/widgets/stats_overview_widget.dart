import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/enhanced_user_profile.dart';

/// Widget para mostrar estadísticas detalladas del usuario
class StatsOverviewWidget extends StatefulWidget {
  const StatsOverviewWidget({
    super.key,
    required this.stats,
  });
  final EnhancedUserStats stats;

  @override
  State<StatsOverviewWidget> createState() => _StatsOverviewWidgetState();
}

class _StatsOverviewWidgetState extends State<StatsOverviewWidget> {
  int _selectedChartIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsCards(),
        const SizedBox(height: 24),
        _buildChartSelector(),
        const SizedBox(height: 16),
        _buildSelectedChart(),
        const SizedBox(height: 24),
        _buildWatchingPatterns(),
        const SizedBox(height: 24),
        _buildYearlyProgress(),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total vistas',
            widget.stats.totalMoviesWatched.toString(),
            Icons.movie,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Calificadas',
            widget.stats.totalMoviesRated.toString(),
            Icons.star,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSelector() {
    final chartOptions = [
      'Géneros',
      'Años',
      'Países',
      'Tendencia',
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: chartOptions.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedChartIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(chartOptions[index]),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedChartIndex = index;
                  });
                }
              },
              backgroundColor: Colors.grey[100],
              selectedColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedChart() {
    switch (_selectedChartIndex) {
      case 0:
        return _buildGenreChart();
      case 1:
        return _buildYearChart();
      case 2:
        return _buildCountryChart();
      case 3:
        return _buildTrendChart();
      default:
        return _buildGenreChart();
    }
  }

  Widget _buildGenreChart() {
    if (widget.stats.genrePreferences.isEmpty) {
      return _buildEmptyChart('No hay datos de géneros disponibles');
    }

    final topGenres = widget.stats.genrePreferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayGenres = topGenres.take(6).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribución por géneros',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: displayGenres.map((entry) {
                    final index = displayGenres.indexOf(entry);
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${entry.value}',
                      color: _getGenreColor(index),
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildGenreLegend(displayGenres),
          ],
        ),
      ),
    );
  }

  Widget _buildYearChart() {
    if (widget.stats.yearPreferences.isEmpty) {
      return _buildEmptyChart('No hay datos de años disponibles');
    }

    final yearData = widget.stats.yearPreferences.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Películas por año',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  barGroups: yearData.map((entry) {
                    final index = yearData.indexOf(entry);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: Theme.of(context).colorScheme.primary,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < yearData.length) {
                            return Text(
                              yearData[value.toInt()].key.toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryChart() {
    if (widget.stats.countryPreferences.isEmpty) {
      return _buildEmptyChart('No hay datos de países disponibles');
    }

    final topCountries = widget.stats.countryPreferences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayCountries = topCountries.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Películas por país',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...displayCountries.map((entry) {
              final percentage =
                  (entry.value / widget.stats.totalMoviesWatched * 100);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${percentage.round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${entry.value}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    // Simulamos una tendencia mensual basada en datos anuales
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tendencia de visualización',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = [
                            'E',
                            'F',
                            'M',
                            'A',
                            'M',
                            'J',
                            'J',
                            'A',
                            'S',
                            'O',
                            'N',
                            'D'
                          ];
                          if (value.toInt() >= 0 &&
                              value.toInt() < months.length) {
                            return Text(months[value.toInt()]);
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(12, (index) {
                        // Simulamos datos mensuales
                        final baseValue = widget.stats.averageMoviesPerMonth;
                        final variation = (index % 3 - 1) * baseValue * 0.3;
                        return FlSpot(index.toDouble(),
                            (baseValue + variation).clamp(0, double.infinity));
                      }),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Card(
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreLegend(List<MapEntry<String, int>> genres) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: genres.map((entry) {
        final index = genres.indexOf(entry);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getGenreColor(index),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              entry.key,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getGenreColor(int index) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Widget _buildWatchingPatterns() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patrones de visualización',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPatternMetric(
                    'Promedio rating',
                    widget.stats.averageRating.toStringAsFixed(1),
                    Icons.star,
                    Colors.amber,
                  ),
                ),
                Expanded(
                  child: _buildPatternMetric(
                    'Tiempo total',
                    '${widget.stats.totalWatchTimeHours.round()}h',
                    Icons.access_time,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPatternMetric(
                    'Películas/mes',
                    widget.stats.averageMoviesPerMonth.toStringAsFixed(1),
                    Icons.calendar_month,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildPatternMetric(
                    'Géneros top',
                    widget.stats.topGenres.length.toString(),
                    Icons.category,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternMetric(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildYearlyProgress() {
    final annualStats = widget.stats.annualStats;
    final currentYear = DateTime.now().year;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progreso $currentYear',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Meta anual (ejemplo: 100 películas por año)
            _buildYearlyGoal(annualStats['moviesThisYear'] ?? 0, 100),
            const SizedBox(height: 16),

            if (annualStats.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildAnnualStat(
                      'Género favorito',
                      annualStats['topGenreThisYear']?.toString() ?? 'N/A',
                      Icons.favorite,
                    ),
                  ),
                  Expanded(
                    child: _buildAnnualStat(
                      'Mes más activo',
                      annualStats['favoriteMonthForMovies']?.toString() ??
                          'N/A',
                      Icons.trending_up,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyGoal(int current, int goal) {
    final progress = (current / goal).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Meta anual de películas',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '$current/$goal ($percentage%)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildAnnualStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
