/// Gates de funciones Pro (S2).
///
/// Todo es ADITIVO: sin Pro la app se comporta exactamente como antes
/// (listas, temas y stats actuales intactos, sin topes nuevos). Cada gate
/// reserva el punto donde una futura UI o tope Pro vive sin tocar gratis.
library;

import 'user_monetization_preferences_service.dart';

/// Puerta de funciones Pro.
class ProFeatureGate {
  ProFeatureGate._();
  static final ProFeatureGate _instance = ProFeatureGate._();

  static ProFeatureGate get instance => _instance;

  final UserMonetizationPreferencesService _prefs =
      UserMonetizationPreferencesService.instance;

  Future<bool> isPro() => _prefs.isPro();

  /// Temas personalizados (`AdvancedThemeManager.createCustomTheme`, hoy sin
  /// exponer en UI): solo Pro podrá crearlos cuando la UI exista.
  Future<bool> canCreateCustomThemes() => _prefs.isPro();

  /// Listas personalizadas ilimitadas: hoy sin tope para nadie; el gate
  /// reserva el punto donde un futuro tope free no afectaría a Pro.
  Future<bool> hasUnlimitedLists() => _prefs.isPro();

  /// Stats avanzados: visibles solo para Pro cuando la UI Pro exista.
  Future<bool> canSeeAdvancedStats() => _prefs.isPro();
}
