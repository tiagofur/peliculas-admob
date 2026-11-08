import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';

// ✅ SIMPLIFIED LOADING: Always return false to show UI immediately
final initialLoadingProvider = Provider<bool>((ref) {
  LoggerFactory.debug(
      'InitialLoadingProvider: DISABLED - showing UI immediately');
  return false; // Always show UI immediately, load data lazily
});
