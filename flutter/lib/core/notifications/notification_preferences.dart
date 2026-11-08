import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/base_logger.dart';
import '../logging/logger_factory.dart';
import 'notification_manager.dart';

/// Configuración de horarios para notificaciones
class NotificationSchedule {
  const NotificationSchedule({
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    this.enabled = true,
  });

  factory NotificationSchedule.fromJson(Map<String, dynamic> json) {
    return NotificationSchedule(
      startTime: TimeOfDay(
        hour: json['startHour'] ?? 9,
        minute: json['startMinute'] ?? 0,
      ),
      endTime: TimeOfDay(
        hour: json['endHour'] ?? 22,
        minute: json['endMinute'] ?? 0,
      ),
      daysOfWeek: List<int>.from(json['daysOfWeek'] ?? [1, 2, 3, 4, 5, 6, 7]),
      enabled: json['enabled'] ?? true,
    );
  }
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<int> daysOfWeek; // 1=Lunes, 7=Domingo
  final bool enabled;

  Map<String, dynamic> toJson() {
    return {
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'daysOfWeek': daysOfWeek,
      'enabled': enabled,
    };
  }

  NotificationSchedule copyWith({
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<int>? daysOfWeek,
    bool? enabled,
  }) {
    return NotificationSchedule(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Verifica si el horario actual está dentro del rango permitido
  bool isWithinSchedule([DateTime? now]) {
    if (!enabled) return false;

    now ??= DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    final currentDay = now.weekday;

    // Verificar día de la semana
    if (!daysOfWeek.contains(currentDay)) return false;

    // Verificar horario
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    if (startMinutes <= endMinutes) {
      // Horario normal (ej: 9:00 - 22:00)
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Horario que cruza medianoche (ej: 22:00 - 6:00)
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }
}

/// Configuración de frecuencia para notificaciones
enum NotificationFrequency {
  immediate,
  hourly,
  daily,
  weekly,
  disabled;

  String get displayName {
    switch (this) {
      case NotificationFrequency.immediate:
        return 'Inmediato';
      case NotificationFrequency.hourly:
        return 'Cada hora';
      case NotificationFrequency.daily:
        return 'Diario';
      case NotificationFrequency.weekly:
        return 'Semanal';
      case NotificationFrequency.disabled:
        return 'Deshabilitado';
    }
  }

  Duration? get duration {
    switch (this) {
      case NotificationFrequency.immediate:
        return null;
      case NotificationFrequency.hourly:
        return const Duration(hours: 1);
      case NotificationFrequency.daily:
        return const Duration(days: 1);
      case NotificationFrequency.weekly:
        return const Duration(days: 7);
      case NotificationFrequency.disabled:
        return null;
    }
  }
}

/// Configuración completa de preferencias de notificaciones
class UserNotificationPreferences {
  const UserNotificationPreferences({
    required this.enabledTypes,
    required this.frequencies,
    required this.priorities,
    required this.schedule,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.ledEnabled = true,
    this.showOnLockScreen = true,
    this.groupNotifications = true,
    this.maxNotificationsPerDay = 10,
    this.personalizedRecommendations = true,
    this.favoriteGenres = const [],
    this.favoriteActorIds = const [],
    this.trendingMoviesEnabled = true,
    this.newReleasesEnabled = true,
    this.includeImages = true,
    this.includeTrailers = false,
    this.includeSpoilers = false,
    this.language = 'es',
  });

  factory UserNotificationPreferences.defaultPreferences() {
    return const UserNotificationPreferences(
      enabledTypes: {
        NotificationType.newMovies: true,
        NotificationType.personalizedRecommendations: true,
        NotificationType.listUpdates: true,
        NotificationType.favoriteActorNewMovie: true,
        NotificationType.trendingMovies: false,
        NotificationType.weeklyWatchlistReminder: true,
        NotificationType.movieReleaseNotification: true,
      },
      frequencies: {
        NotificationType.newMovies: NotificationFrequency.daily,
        NotificationType.personalizedRecommendations:
            NotificationFrequency.daily,
        NotificationType.listUpdates: NotificationFrequency.immediate,
        NotificationType.favoriteActorNewMovie: NotificationFrequency.immediate,
        NotificationType.trendingMovies: NotificationFrequency.weekly,
        NotificationType.weeklyWatchlistReminder: NotificationFrequency.weekly,
        NotificationType.movieReleaseNotification:
            NotificationFrequency.immediate,
      },
      priorities: {
        NotificationType.newMovies: NotificationPriority.normal,
        NotificationType.personalizedRecommendations: NotificationPriority.high,
        NotificationType.listUpdates: NotificationPriority.normal,
        NotificationType.favoriteActorNewMovie: NotificationPriority.high,
        NotificationType.trendingMovies: NotificationPriority.low,
        NotificationType.weeklyWatchlistReminder: NotificationPriority.normal,
        NotificationType.movieReleaseNotification: NotificationPriority.high,
      },
      schedule: NotificationSchedule(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 22, minute: 0),
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        enabled: true,
      ),
    );
  }

  factory UserNotificationPreferences.fromJson(Map<String, dynamic> json) {
    return UserNotificationPreferences(
      enabledTypes: Map<NotificationType, bool>.fromEntries(
        (json['enabledTypes'] as Map<String, dynamic>? ?? {})
            .entries
            .map((e) => MapEntry(
                  NotificationType.values.firstWhere(
                    (type) => type.name == e.key,
                    orElse: () => NotificationType.newMovies,
                  ),
                  e.value as bool,
                )),
      ),
      frequencies: Map<NotificationType, NotificationFrequency>.fromEntries(
        (json['frequencies'] as Map<String, dynamic>? ?? {})
            .entries
            .map((e) => MapEntry(
                  NotificationType.values.firstWhere(
                    (type) => type.name == e.key,
                    orElse: () => NotificationType.newMovies,
                  ),
                  NotificationFrequency.values.firstWhere(
                    (freq) => freq.name == e.value,
                    orElse: () => NotificationFrequency.daily,
                  ),
                )),
      ),
      priorities: Map<NotificationType, NotificationPriority>.fromEntries(
        (json['priorities'] as Map<String, dynamic>? ?? {})
            .entries
            .map((e) => MapEntry(
                  NotificationType.values.firstWhere(
                    (type) => type.name == e.key,
                    orElse: () => NotificationType.newMovies,
                  ),
                  NotificationPriority.values.firstWhere(
                    (priority) => priority.name == e.value,
                    orElse: () => NotificationPriority.normal,
                  ),
                )),
      ),
      schedule: NotificationSchedule.fromJson(
        json['schedule'] as Map<String, dynamic>? ?? {},
      ),
      soundEnabled: json['soundEnabled'] ?? true,
      vibrationEnabled: json['vibrationEnabled'] ?? true,
      ledEnabled: json['ledEnabled'] ?? true,
      showOnLockScreen: json['showOnLockScreen'] ?? true,
      groupNotifications: json['groupNotifications'] ?? true,
      maxNotificationsPerDay: json['maxNotificationsPerDay'] ?? 10,
      personalizedRecommendations: json['personalizedRecommendations'] ?? true,
      favoriteGenres: List<String>.from(json['favoriteGenres'] ?? []),
      favoriteActorIds: List<int>.from(json['favoriteActorIds'] ?? []),
      trendingMoviesEnabled: json['trendingMoviesEnabled'] ?? true,
      newReleasesEnabled: json['newReleasesEnabled'] ?? true,
      includeImages: json['includeImages'] ?? true,
      includeTrailers: json['includeTrailers'] ?? false,
      includeSpoilers: json['includeSpoilers'] ?? false,
      language: json['language'] ?? 'es',
    );
  }
  // Configuraciones por tipo de notificación
  final Map<NotificationType, bool> enabledTypes;
  final Map<NotificationType, NotificationFrequency> frequencies;
  final Map<NotificationType, NotificationPriority> priorities;

  // Configuraciones generales
  final NotificationSchedule schedule;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool ledEnabled;
  final bool showOnLockScreen;
  final bool groupNotifications;
  final int maxNotificationsPerDay;

  // Configuraciones específicas
  final bool personalizedRecommendations;
  final List<String> favoriteGenres;
  final List<int> favoriteActorIds;
  final bool trendingMoviesEnabled;
  final bool newReleasesEnabled;

  // Configuraciones de contenido
  final bool includeImages;
  final bool includeTrailers;
  final bool includeSpoilers;
  final String language;

  Map<String, dynamic> toJson() {
    return {
      'enabledTypes':
          enabledTypes.map((key, value) => MapEntry(key.name, value)),
      'frequencies':
          frequencies.map((key, value) => MapEntry(key.name, value.name)),
      'priorities':
          priorities.map((key, value) => MapEntry(key.name, value.name)),
      'schedule': schedule.toJson(),
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'ledEnabled': ledEnabled,
      'showOnLockScreen': showOnLockScreen,
      'groupNotifications': groupNotifications,
      'maxNotificationsPerDay': maxNotificationsPerDay,
      'personalizedRecommendations': personalizedRecommendations,
      'favoriteGenres': favoriteGenres,
      'favoriteActorIds': favoriteActorIds,
      'trendingMoviesEnabled': trendingMoviesEnabled,
      'newReleasesEnabled': newReleasesEnabled,
      'includeImages': includeImages,
      'includeTrailers': includeTrailers,
      'includeSpoilers': includeSpoilers,
      'language': language,
    };
  }

  UserNotificationPreferences copyWith({
    Map<NotificationType, bool>? enabledTypes,
    Map<NotificationType, NotificationFrequency>? frequencies,
    Map<NotificationType, NotificationPriority>? priorities,
    NotificationSchedule? schedule,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? ledEnabled,
    bool? showOnLockScreen,
    bool? groupNotifications,
    int? maxNotificationsPerDay,
    bool? personalizedRecommendations,
    List<String>? favoriteGenres,
    List<int>? favoriteActorIds,
    bool? trendingMoviesEnabled,
    bool? newReleasesEnabled,
    bool? includeImages,
    bool? includeTrailers,
    bool? includeSpoilers,
    String? language,
  }) {
    return UserNotificationPreferences(
      enabledTypes: enabledTypes ?? this.enabledTypes,
      frequencies: frequencies ?? this.frequencies,
      priorities: priorities ?? this.priorities,
      schedule: schedule ?? this.schedule,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      ledEnabled: ledEnabled ?? this.ledEnabled,
      showOnLockScreen: showOnLockScreen ?? this.showOnLockScreen,
      groupNotifications: groupNotifications ?? this.groupNotifications,
      maxNotificationsPerDay:
          maxNotificationsPerDay ?? this.maxNotificationsPerDay,
      personalizedRecommendations:
          personalizedRecommendations ?? this.personalizedRecommendations,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      favoriteActorIds: favoriteActorIds ?? this.favoriteActorIds,
      trendingMoviesEnabled:
          trendingMoviesEnabled ?? this.trendingMoviesEnabled,
      newReleasesEnabled: newReleasesEnabled ?? this.newReleasesEnabled,
      includeImages: includeImages ?? this.includeImages,
      includeTrailers: includeTrailers ?? this.includeTrailers,
      includeSpoilers: includeSpoilers ?? this.includeSpoilers,
      language: language ?? this.language,
    );
  }

  /// Verifica si un tipo de notificación está habilitado
  bool isTypeEnabled(NotificationType type) {
    return enabledTypes[type] ?? false;
  }

  /// Obtiene la frecuencia para un tipo de notificación
  NotificationFrequency getFrequency(NotificationType type) {
    return frequencies[type] ?? NotificationFrequency.daily;
  }

  /// Obtiene la prioridad para un tipo de notificación
  NotificationPriority getPriority(NotificationType type) {
    return priorities[type] ?? NotificationPriority.normal;
  }

  /// Verifica si se pueden enviar notificaciones en el momento actual
  bool canSendNotificationNow([DateTime? now]) {
    return schedule.isWithinSchedule(now);
  }
}

/// Servicio para gestionar las preferencias de notificaciones del usuario
class NotificationPreferencesService {
  NotificationPreferencesService._();
  static NotificationPreferencesService? _instance;
  static NotificationPreferencesService get instance =>
      _instance ??= NotificationPreferencesService._();

  // Logger para debugging
  static void _log(String message) {
    LoggerFactory.debug(message, category: LogCategory.notifications);
  }

  static const String _preferencesKey = 'notification_preferences';
  static const String _dailyCountKey = 'daily_notification_count';
  static const String _lastResetDateKey = 'last_reset_date';

  UserNotificationPreferences? _cachedPreferences;
  int _dailyNotificationCount = 0;
  DateTime _lastResetDate = DateTime.now();

  /// Carga las preferencias del usuario
  Future<UserNotificationPreferences> loadPreferences() async {
    if (_cachedPreferences != null) {
      return _cachedPreferences!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesJson = prefs.getString(_preferencesKey);

      if (preferencesJson != null) {
        final Map<String, dynamic> data = jsonDecode(preferencesJson);
        _cachedPreferences = UserNotificationPreferences.fromJson(data);
        _log('Preferencias de notificaciones cargadas desde almacenamiento');
      } else {
        _cachedPreferences = UserNotificationPreferences.defaultPreferences();
        await savePreferences(_cachedPreferences!);
        _log(
            'Preferencias de notificaciones inicializadas con valores por defecto');
      }

      // Cargar contador diario
      await _loadDailyCount();

      return _cachedPreferences!;
    } catch (e) {
      _log('Error cargando preferencias de notificaciones: $e');
      _cachedPreferences = UserNotificationPreferences.defaultPreferences();
      return _cachedPreferences!;
    }
  }

  /// Guarda las preferencias del usuario
  Future<void> savePreferences(UserNotificationPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferencesJson = jsonEncode(preferences.toJson());

      await prefs.setString(_preferencesKey, preferencesJson);
      _cachedPreferences = preferences;

      _log('Preferencias de notificaciones guardadas');
    } catch (e) {
      _log('Error guardando preferencias de notificaciones: $e');
    }
  }

  /// Actualiza una preferencia específica
  Future<void> updatePreference<T>(String key, T value) async {
    final currentPreferences = await loadPreferences();
    UserNotificationPreferences updatedPreferences;

    switch (key) {
      case 'soundEnabled':
        updatedPreferences =
            currentPreferences.copyWith(soundEnabled: value as bool);
        break;
      case 'vibrationEnabled':
        updatedPreferences =
            currentPreferences.copyWith(vibrationEnabled: value as bool);
        break;
      case 'personalizedRecommendations':
        updatedPreferences = currentPreferences.copyWith(
            personalizedRecommendations: value as bool);
        break;
      case 'maxNotificationsPerDay':
        updatedPreferences = currentPreferences.copyWith(
            maxNotificationsPerDay:
                value is int ? value : int.tryParse(value.toString()) ?? 1);
        break;
      default:
        _log('Clave de preferencia no reconocida: $key');
        return;
    }

    await savePreferences(updatedPreferences);
  }

  /// Habilita o deshabilita un tipo de notificación
  Future<void> setNotificationTypeEnabled(
      NotificationType type, bool enabled) async {
    final currentPreferences = await loadPreferences();
    final updatedEnabledTypes =
        Map<NotificationType, bool>.from(currentPreferences.enabledTypes);
    updatedEnabledTypes[type] = enabled;

    final updatedPreferences =
        currentPreferences.copyWith(enabledTypes: updatedEnabledTypes);
    await savePreferences(updatedPreferences);

    _log(
        'Tipo de notificación ${type.name} ${enabled ? 'habilitado' : 'deshabilitado'}');
  }

  /// Actualiza la frecuencia de un tipo de notificación
  Future<void> setNotificationFrequency(
      NotificationType type, NotificationFrequency frequency) async {
    final currentPreferences = await loadPreferences();
    final updatedFrequencies =
        Map<NotificationType, NotificationFrequency>.from(
            currentPreferences.frequencies);
    updatedFrequencies[type] = frequency;

    final updatedPreferences =
        currentPreferences.copyWith(frequencies: updatedFrequencies);
    await savePreferences(updatedPreferences);

    _log(
        'Frecuencia de notificación ${type.name} actualizada a ${frequency.name}');
  }

  /// Actualiza el horario de notificaciones
  Future<void> updateNotificationSchedule(NotificationSchedule schedule) async {
    final currentPreferences = await loadPreferences();
    final updatedPreferences = currentPreferences.copyWith(schedule: schedule);
    await savePreferences(updatedPreferences);

    _log('Horario de notificaciones actualizado');
  }

  /// Agrega un género favorito
  Future<void> addFavoriteGenre(String genre) async {
    final currentPreferences = await loadPreferences();
    final updatedGenres = List<String>.from(currentPreferences.favoriteGenres);

    if (!updatedGenres.contains(genre)) {
      updatedGenres.add(genre);
      final updatedPreferences =
          currentPreferences.copyWith(favoriteGenres: updatedGenres);
      await savePreferences(updatedPreferences);

      _log('Género favorito agregado: $genre');
    }
  }

  /// Remueve un género favorito
  Future<void> removeFavoriteGenre(String genre) async {
    final currentPreferences = await loadPreferences();
    final updatedGenres = List<String>.from(currentPreferences.favoriteGenres);

    if (updatedGenres.remove(genre)) {
      final updatedPreferences =
          currentPreferences.copyWith(favoriteGenres: updatedGenres);
      await savePreferences(updatedPreferences);

      _log('Género favorito removido: $genre');
    }
  }

  /// Agrega un actor favorito
  Future<void> addFavoriteActor(int actorId) async {
    final currentPreferences = await loadPreferences();
    final updatedActors = List<int>.from(currentPreferences.favoriteActorIds);

    if (!updatedActors.contains(actorId)) {
      updatedActors.add(actorId);
      final updatedPreferences =
          currentPreferences.copyWith(favoriteActorIds: updatedActors);
      await savePreferences(updatedPreferences);

      _log('Actor favorito agregado: $actorId');
    }
  }

  /// Remueve un actor favorito
  Future<void> removeFavoriteActor(int actorId) async {
    final currentPreferences = await loadPreferences();
    final updatedActors = List<int>.from(currentPreferences.favoriteActorIds);

    if (updatedActors.remove(actorId)) {
      final updatedPreferences =
          currentPreferences.copyWith(favoriteActorIds: updatedActors);
      await savePreferences(updatedPreferences);

      _log('Actor favorito removido: $actorId');
    }
  }

  /// Verifica si se puede enviar una notificación según las preferencias
  Future<bool> canSendNotification(NotificationType type,
      [DateTime? now]) async {
    final preferences = await loadPreferences();

    // Verificar si el tipo está habilitado
    if (!preferences.isTypeEnabled(type)) {
      return false;
    }

    // Verificar horario
    if (!preferences.canSendNotificationNow(now)) {
      return false;
    }

    // Verificar límite diario
    await _checkAndResetDailyCount();
    if (_dailyNotificationCount >= preferences.maxNotificationsPerDay) {
      _log(
          'Límite diario de notificaciones alcanzado: $_dailyNotificationCount/${preferences.maxNotificationsPerDay}');
      return false;
    }

    return true;
  }

  /// Incrementa el contador de notificaciones diarias
  Future<void> incrementDailyCount() async {
    await _checkAndResetDailyCount();
    _dailyNotificationCount++;
    await _saveDailyCount();
  }

  /// Obtiene el contador actual de notificaciones diarias
  Future<int> getDailyNotificationCount() async {
    await _checkAndResetDailyCount();
    return _dailyNotificationCount;
  }

  /// Carga el contador diario desde SharedPreferences
  Future<void> _loadDailyCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dailyNotificationCount = prefs.getInt(_dailyCountKey) ?? 0;

      final lastResetString = prefs.getString(_lastResetDateKey);
      if (lastResetString != null) {
        _lastResetDate = DateTime.parse(lastResetString);
      }
    } catch (e) {
      _log('Error cargando contador diario: $e');
      _dailyNotificationCount = 0;
      _lastResetDate = DateTime.now();
    }
  }

  /// Guarda el contador diario en SharedPreferences
  Future<void> _saveDailyCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dailyCountKey, _dailyNotificationCount);
      await prefs.setString(
          _lastResetDateKey, _lastResetDate.toIso8601String());
    } catch (e) {
      _log('Error guardando contador diario: $e');
    }
  }

  /// Verifica si es necesario resetear el contador diario
  Future<void> _checkAndResetDailyCount() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastReset =
        DateTime(_lastResetDate.year, _lastResetDate.month, _lastResetDate.day);

    if (today.isAfter(lastReset)) {
      _dailyNotificationCount = 0;
      _lastResetDate = now;
      await _saveDailyCount();
      _log('Contador diario de notificaciones reseteado');
    }
  }

  /// Resetea todas las preferencias a los valores por defecto
  Future<void> resetToDefaults() async {
    final defaultPreferences = UserNotificationPreferences.defaultPreferences();
    await savePreferences(defaultPreferences);

    _dailyNotificationCount = 0;
    _lastResetDate = DateTime.now();
    await _saveDailyCount();

    _log('Preferencias de notificaciones reseteadas a valores por defecto');
  }

  /// Exporta las preferencias como JSON
  Future<Map<String, dynamic>> exportPreferences() async {
    final preferences = await loadPreferences();
    return preferences.toJson();
  }

  /// Importa preferencias desde JSON
  Future<void> importPreferences(Map<String, dynamic> json) async {
    try {
      final preferences = UserNotificationPreferences.fromJson(json);
      await savePreferences(preferences);
      _log('Preferencias de notificaciones importadas exitosamente');
    } catch (e) {
      _log('Error importando preferencias de notificaciones: $e');
      throw Exception('Error al importar preferencias: $e');
    }
  }

  /// Limpia la caché de preferencias
  void clearCache() {
    _cachedPreferences = null;
    _log('Caché de preferencias de notificaciones limpiada');
  }
}
