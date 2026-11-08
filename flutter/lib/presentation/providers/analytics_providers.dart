import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics_service.dart';

/// Provider para el servicio de analíticas
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// Provider para el dashboard de analíticas
final analyticsDashboardProvider =
    FutureProvider<AnalyticsDashboard>((ref) async {
  final analyticsService = ref.read(analyticsServiceProvider);
  return await analyticsService.getDashboard();
});

/// Provider para el filtro de fecha
final dateRangeFilterProvider = Provider<DateTimeRange?>((ref) => null);

/// Provider para el filtro de categoría
final categoryFilterProvider = Provider<String?>((ref) => null);
