import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/advanced_search_service.dart';

/// Provider para el servicio de búsqueda avanzada
final advancedSearchServiceProvider = Provider<AdvancedSearchService>((ref) {
  return AdvancedSearchService.instance;
});
