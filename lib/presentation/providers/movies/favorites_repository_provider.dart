import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/repositories/favorites_repository.dart';
import '../../../infrastructure/repositories/hybrid_favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  // This is a mock implementation. Replace with your actual implementation.
  return HybridFavoritesRepository(userId: 'mock');
});
