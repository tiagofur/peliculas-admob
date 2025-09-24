/// Servicio de configuración de usuario para monetización
/// Permite a los usuarios controlar su experiencia con anuncios
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../config/monetization/ux_first_monetization_strategy.dart';
import '../../core/logging/logger_factory.dart';

/// Servicio que gestiona las preferencias del usuario relacionadas con anuncios
class UserMonetizationPreferencesService {
  UserMonetizationPreferencesService._();
  static UserMonetizationPreferencesService? _instance;

  static UserMonetizationPreferencesService get instance {
    _instance ??= UserMonetizationPreferencesService._();
    return _instance!;
  }

  static const String _keyUserPreferences = 'user_monetization_prefs';
  static const String _keyUserType = 'user_type';
  static const String _keyRegistrationDate = 'user_registration_date';
  static const String _keySessionCount = 'user_session_count';
  static const String _keyTotalUsageTime = 'total_usage_time';
  static const String _keyLastAdInteraction = 'last_ad_interaction';
  static const String _keyAdInteractionHistory = 'ad_interaction_history';

  SharedPreferences? _prefs;

  /// Inicializar el servicio
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _initializeNewUserIfNeeded();
      LoggerFactory.info('UserMonetizationPreferencesService inicializado');
    } catch (e) {
      LoggerFactory.error(
          'Error inicializando UserMonetizationPreferencesService: $e');
    }
  }

  /// Configurar usuario como nuevo si es la primera vez
  Future<void> _initializeNewUserIfNeeded() async {
    if (_prefs == null) return;

    final registrationDate = _prefs!.getString(_keyRegistrationDate);
    if (registrationDate == null) {
      // Es un usuario nuevo
      await _prefs!
          .setString(_keyRegistrationDate, DateTime.now().toIso8601String());
      await _prefs!.setInt(_keySessionCount, 1);
      await _prefs!.setInt(_keyTotalUsageTime, 0);
      await setUserType(UserTypeUX.newUser);

      LoggerFactory.info(
          'Usuario nuevo configurado con período de gracia de anuncios');
    } else {
      // Usuario existente - actualizar tipo basado en uso
      await _updateUserTypeBasedOnUsage();
    }
  }

  /// Obtiene las preferencias actuales del usuario
  Future<UserMonetizationPreferences> getUserPreferences() async {
    if (_prefs == null) await initialize();

    try {
      final prefsJson = _prefs!.getString(_keyUserPreferences);
      if (prefsJson != null) {
        final Map<String, dynamic> prefsMap = jsonDecode(prefsJson);
        return UserMonetizationPreferences.fromJson(prefsMap);
      }
    } catch (e) {
      LoggerFactory.warning(
          'Error cargando preferencias de usuario, usando defaults: $e');
    }

    // Retornar preferencias por defecto
    return const UserMonetizationPreferences();
  }

  /// Guarda las preferencias del usuario
  Future<void> saveUserPreferences(
      UserMonetizationPreferences preferences) async {
    if (_prefs == null) await initialize();

    try {
      final prefsJson = jsonEncode(preferences.toJson());
      await _prefs!.setString(_keyUserPreferences, prefsJson);
      LoggerFactory.info('Preferencias de usuario guardadas');
    } catch (e) {
      LoggerFactory.error('Error guardando preferencias de usuario: $e');
    }
  }

  /// Obtiene el tipo de usuario actual
  Future<UserTypeUX> getUserType() async {
    if (_prefs == null) await initialize();

    final userTypeString = _prefs!.getString(_keyUserType);
    if (userTypeString == null) {
      return UserTypeUX.newUser;
    }

    try {
      return UserTypeUX.values.firstWhere(
        (type) => type.toString() == userTypeString,
        orElse: () => UserTypeUX.casualUser,
      );
    } catch (e) {
      LoggerFactory.warning(
          'Error parseando tipo de usuario, usando casual: $e');
      return UserTypeUX.casualUser;
    }
  }

  /// Establece el tipo de usuario
  Future<void> setUserType(UserTypeUX userType) async {
    if (_prefs == null) await initialize();

    await _prefs!.setString(_keyUserType, userType.toString());
    LoggerFactory.info('Tipo de usuario actualizado a: $userType');
  }

  /// Actualiza automáticamente el tipo de usuario basado en patrones de uso
  Future<void> _updateUserTypeBasedOnUsage() async {
    if (_prefs == null) return;

    try {
      final registrationDate = _prefs!.getString(_keyRegistrationDate);
      if (registrationDate == null) return;

      final registrationDateTime = DateTime.parse(registrationDate);
      final daysSinceRegistration =
          DateTime.now().difference(registrationDateTime).inDays;
      final sessionCount = _prefs!.getInt(_keySessionCount) ?? 0;
      final totalUsageTimeMinutes = _prefs!.getInt(_keyTotalUsageTime) ?? 0;

      UserTypeUX newUserType;

      // Determinar tipo de usuario basado en métricas
      if (daysSinceRegistration <= 3) {
        newUserType = UserTypeUX.newUser;
      } else if (sessionCount >= 50 && totalUsageTimeMinutes >= 300) {
        // 5+ horas
        newUserType = UserTypeUX.powerUser;
      } else {
        newUserType = UserTypeUX.casualUser;
      }

      // Solo actualizar si cambió
      final currentType = await getUserType();
      if (currentType != newUserType) {
        await setUserType(newUserType);
      }
    } catch (e) {
      LoggerFactory.error('Error actualizando tipo de usuario: $e');
    }
  }

  /// Registra una nueva sesión del usuario
  Future<void> recordUserSession() async {
    if (_prefs == null) await initialize();

    try {
      final currentSessions = _prefs!.getInt(_keySessionCount) ?? 0;
      await _prefs!.setInt(_keySessionCount, currentSessions + 1);
      await _updateUserTypeBasedOnUsage();

      LoggerFactory.debug('Sesión #${currentSessions + 1} registrada');
    } catch (e) {
      LoggerFactory.error('Error registrando sesión de usuario: $e');
    }
  }

  /// Registra tiempo de uso de la aplicación (en minutos)
  Future<void> recordUsageTime(int minutes) async {
    if (_prefs == null) await initialize();

    try {
      final currentUsage = _prefs!.getInt(_keyTotalUsageTime) ?? 0;
      await _prefs!.setInt(_keyTotalUsageTime, currentUsage + minutes);
      await _updateUserTypeBasedOnUsage();

      LoggerFactory.debug(
          '$minutes minutos de uso registrados. Total: ${currentUsage + minutes}');
    } catch (e) {
      LoggerFactory.error('Error registrando tiempo de uso: $e');
    }
  }

  /// Registra interacción con anuncio
  Future<void> recordAdInteraction(
      AdInteractionType type, AdTypeUX adType) async {
    if (_prefs == null) await initialize();

    try {
      await _prefs!
          .setString(_keyLastAdInteraction, DateTime.now().toIso8601String());

      // Registrar en historial
      final historyJson = _prefs!.getString(_keyAdInteractionHistory) ?? '[]';
      final List<dynamic> history = jsonDecode(historyJson);

      history.add({
        'type': type.toString(),
        'adType': adType.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Mantener solo las últimas 100 interacciones
      if (history.length > 100) {
        history.removeAt(0);
      }

      await _prefs!.setString(_keyAdInteractionHistory, jsonEncode(history));

      LoggerFactory.debug('Interacción de anuncio registrada: $type - $adType');
    } catch (e) {
      LoggerFactory.error('Error registrando interacción de anuncio: $e');
    }
  }

  /// Verifica si el usuario está en período de gracia (nuevos usuarios sin anuncios)
  Future<bool> isInGracePeriod() async {
    if (_prefs == null) await initialize();

    final registrationDate = _prefs!.getString(_keyRegistrationDate);
    if (registrationDate == null) return false;

    try {
      final registrationDateTime = DateTime.parse(registrationDate);
      const gracePeriod = Duration(days: 3); // 3 días de gracia
      final gracePeriodEnd = registrationDateTime.add(gracePeriod);

      return DateTime.now().isBefore(gracePeriodEnd);
    } catch (e) {
      LoggerFactory.error('Error verificando período de gracia: $e');
      return false;
    }
  }

  /// Obtiene estadísticas de uso del usuario
  Future<UserUsageStats> getUserUsageStats() async {
    if (_prefs == null) await initialize();

    try {
      final registrationDate = _prefs!.getString(_keyRegistrationDate);
      final sessionCount = _prefs!.getInt(_keySessionCount) ?? 0;
      final totalUsageTime = _prefs!.getInt(_keyTotalUsageTime) ?? 0;
      final lastAdInteraction = _prefs!.getString(_keyLastAdInteraction);

      DateTime? registrationDateTime;
      if (registrationDate != null) {
        registrationDateTime = DateTime.parse(registrationDate);
      }

      DateTime? lastAdInteractionDateTime;
      if (lastAdInteraction != null) {
        lastAdInteractionDateTime = DateTime.parse(lastAdInteraction);
      }

      return UserUsageStats(
        registrationDate: registrationDateTime,
        sessionCount: sessionCount,
        totalUsageTimeMinutes: totalUsageTime,
        lastAdInteraction: lastAdInteractionDateTime,
        userType: await getUserType(),
        isInGracePeriod: await isInGracePeriod(),
      );
    } catch (e) {
      LoggerFactory.error('Error obteniendo estadísticas de usuario: $e');
      return const UserUsageStats(
        userType: UserTypeUX.casualUser,
        isInGracePeriod: false,
      );
    }
  }

  /// Permite al usuario actualizar sus preferencias de anuncios
  Future<void> updateAdPreference(AdPreferenceType type, bool enabled) async {
    final currentPrefs = await getUserPreferences();

    UserMonetizationPreferences updatedPrefs;

    switch (type) {
      case AdPreferenceType.bannerAds:
        updatedPrefs = currentPrefs.copyWith(allowBannerAds: enabled);
        break;
      case AdPreferenceType.interstitialAds:
        updatedPrefs = currentPrefs.copyWith(allowInterstitialAds: enabled);
        break;
      case AdPreferenceType.nativeAds:
        updatedPrefs = currentPrefs.copyWith(allowNativeAds: enabled);
        break;
      case AdPreferenceType.rewardedAds:
        updatedPrefs = currentPrefs.copyWith(allowRewardedAds: enabled);
        break;
      case AdPreferenceType.personalizedAds:
        updatedPrefs = currentPrefs.copyWith(allowPersonalizedAds: enabled);
        break;
    }

    await saveUserPreferences(updatedPrefs);
    LoggerFactory.info('Preferencia de anuncio actualizada: $type = $enabled');
  }

  /// Limpia todos los datos del usuario (para testing o reset)
  Future<void> clearUserData() async {
    if (_prefs == null) await initialize();

    try {
      await _prefs!.remove(_keyUserPreferences);
      await _prefs!.remove(_keyUserType);
      await _prefs!.remove(_keyRegistrationDate);
      await _prefs!.remove(_keySessionCount);
      await _prefs!.remove(_keyTotalUsageTime);
      await _prefs!.remove(_keyLastAdInteraction);
      await _prefs!.remove(_keyAdInteractionHistory);

      LoggerFactory.info('Datos de usuario limpiados');
    } catch (e) {
      LoggerFactory.error('Error limpiando datos de usuario: $e');
    }
  }
}

/// Preferencias de monetización del usuario
class UserMonetizationPreferences {
  const UserMonetizationPreferences({
    this.allowBannerAds = true,
    this.allowInterstitialAds = true,
    this.allowNativeAds = true,
    this.allowRewardedAds = true,
    this.allowPersonalizedAds = true,
    this.respectDoNotTrack = true,
    this.maxAdsPerSession, // null = usar defaults del sistema
    this.preferLessFrequentAds = false,
    this.optedOutOfAds = false, // para usuarios premium
  });

  factory UserMonetizationPreferences.fromJson(Map<String, dynamic> json) {
    return UserMonetizationPreferences(
      allowBannerAds: json['allowBannerAds'] ?? true,
      allowInterstitialAds: json['allowInterstitialAds'] ?? true,
      allowNativeAds: json['allowNativeAds'] ?? true,
      allowRewardedAds: json['allowRewardedAds'] ?? true,
      allowPersonalizedAds: json['allowPersonalizedAds'] ?? true,
      respectDoNotTrack: json['respectDoNotTrack'] ?? true,
      maxAdsPerSession: json['maxAdsPerSession'],
      preferLessFrequentAds: json['preferLessFrequentAds'] ?? false,
      optedOutOfAds: json['optedOutOfAds'] ?? false,
    );
  }

  final bool allowBannerAds;
  final bool allowInterstitialAds;
  final bool allowNativeAds;
  final bool allowRewardedAds;
  final bool allowPersonalizedAds;
  final bool respectDoNotTrack;
  final int? maxAdsPerSession;
  final bool preferLessFrequentAds;
  final bool optedOutOfAds;

  UserMonetizationPreferences copyWith({
    bool? allowBannerAds,
    bool? allowInterstitialAds,
    bool? allowNativeAds,
    bool? allowRewardedAds,
    bool? allowPersonalizedAds,
    bool? respectDoNotTrack,
    int? maxAdsPerSession,
    bool? preferLessFrequentAds,
    bool? optedOutOfAds,
  }) {
    return UserMonetizationPreferences(
      allowBannerAds: allowBannerAds ?? this.allowBannerAds,
      allowInterstitialAds: allowInterstitialAds ?? this.allowInterstitialAds,
      allowNativeAds: allowNativeAds ?? this.allowNativeAds,
      allowRewardedAds: allowRewardedAds ?? this.allowRewardedAds,
      allowPersonalizedAds: allowPersonalizedAds ?? this.allowPersonalizedAds,
      respectDoNotTrack: respectDoNotTrack ?? this.respectDoNotTrack,
      maxAdsPerSession: maxAdsPerSession ?? this.maxAdsPerSession,
      preferLessFrequentAds:
          preferLessFrequentAds ?? this.preferLessFrequentAds,
      optedOutOfAds: optedOutOfAds ?? this.optedOutOfAds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowBannerAds': allowBannerAds,
      'allowInterstitialAds': allowInterstitialAds,
      'allowNativeAds': allowNativeAds,
      'allowRewardedAds': allowRewardedAds,
      'allowPersonalizedAds': allowPersonalizedAds,
      'respectDoNotTrack': respectDoNotTrack,
      'maxAdsPerSession': maxAdsPerSession,
      'preferLessFrequentAds': preferLessFrequentAds,
      'optedOutOfAds': optedOutOfAds,
    };
  }
}

/// Estadísticas de uso del usuario
class UserUsageStats {
  const UserUsageStats({
    this.registrationDate,
    this.sessionCount = 0,
    this.totalUsageTimeMinutes = 0,
    this.lastAdInteraction,
    required this.userType,
    required this.isInGracePeriod,
  });

  final DateTime? registrationDate;
  final int sessionCount;
  final int totalUsageTimeMinutes;
  final DateTime? lastAdInteraction;
  final UserTypeUX userType;
  final bool isInGracePeriod;

  int get daysSinceRegistration {
    if (registrationDate == null) return 0;
    return DateTime.now().difference(registrationDate!).inDays;
  }

  double get averageSessionLengthMinutes {
    if (sessionCount == 0) return 0;
    return totalUsageTimeMinutes / sessionCount;
  }

  bool get isPowerUser => userType == UserTypeUX.powerUser;
  bool get isNewUser => userType == UserTypeUX.newUser;
  bool get isPremiumUser => userType == UserTypeUX.premiumUser;
}

/// Tipos de interacción con anuncios
enum AdInteractionType {
  viewed, // Visto
  clicked, // Clicado
  closed, // Cerrado
  skipped, // Saltado
  completed, // Completado (para rewarded)
}

/// Tipos de preferencias de anuncio
enum AdPreferenceType {
  bannerAds,
  interstitialAds,
  nativeAds,
  rewardedAds,
  personalizedAds,
}
