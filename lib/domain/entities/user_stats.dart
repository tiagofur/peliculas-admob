class UserStats {
  const UserStats({
    required this.id,
    required this.userId,
    required this.moviesWatched,
    required this.favoritesCount,
    required this.listsCount,
    required this.lastActivity,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor para crear UserStats desde listas de películas
  factory UserStats.fromMovies({
    required List favoriteMovies,
    required List watchedMovies,
    required List customLists,
    required List defaultLists,
  }) {
    final now = DateTime.now();
    return UserStats(
      id: 'temp-id',
      userId: 'temp-user-id',
      moviesWatched: watchedMovies.length,
      favoritesCount: favoriteMovies.length,
      listsCount: customLists.length + defaultLists.length,
      lastActivity: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String userId;
  final int moviesWatched;
  final int favoritesCount;
  final int listsCount;
  final DateTime lastActivity;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserStats copyWith({
    String? id,
    String? userId,
    int? moviesWatched,
    int? favoritesCount,
    int? listsCount,
    DateTime? lastActivity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserStats(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moviesWatched: moviesWatched ?? this.moviesWatched,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      listsCount: listsCount ?? this.listsCount,
      lastActivity: lastActivity ?? this.lastActivity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  UserStats incrementMoviesWatched() {
    return copyWith(
      moviesWatched: moviesWatched + 1,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  UserStats incrementFavorites() {
    return copyWith(
      favoritesCount: favoritesCount + 1,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  UserStats decrementFavorites() {
    return copyWith(
      favoritesCount: favoritesCount > 0 ? favoritesCount - 1 : 0,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  UserStats incrementLists() {
    return copyWith(
      listsCount: listsCount + 1,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  UserStats decrementLists() {
    return copyWith(
      listsCount: listsCount > 0 ? listsCount - 1 : 0,
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  UserStats updateActivity() {
    return copyWith(
      lastActivity: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Getters útiles
  bool get isActiveUser => moviesWatched > 0 || favoritesCount > 0;
  bool get hasActivity =>
      lastActivity.isAfter(DateTime.now().subtract(const Duration(days: 30)));
  int get totalInteractions => moviesWatched + favoritesCount + listsCount;

  // Método estático para obtener nombres de meses en español
  static String getMonthName(int month) {
    const monthNames = [
      '', // Índice 0 no se usa
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    if (month < 1 || month > 12) {
      return 'Mes desconocido';
    }

    return monthNames[month];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserStats &&
        other.id == id &&
        other.userId == userId &&
        other.moviesWatched == moviesWatched &&
        other.favoritesCount == favoritesCount &&
        other.listsCount == listsCount &&
        other.lastActivity == lastActivity &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      moviesWatched,
      favoritesCount,
      listsCount,
      lastActivity,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserStats(id: $id, userId: $userId, moviesWatched: $moviesWatched, favoritesCount: $favoritesCount, listsCount: $listsCount, lastActivity: $lastActivity, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
