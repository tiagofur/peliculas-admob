/// Abstracción de compras Pro (pago único lifetime).
///
/// El billing real de tiendas (StoreKit / Google Play) se conecta en T4;
/// esta capa define el contrato y la implementación local offline-first
/// que persiste el entitlement y lo sincroniza con las preferencias de
/// monetización (premiumUser + optedOutOfAds).
library;

import 'dart:async';

import '../../core/logging/logger_factory.dart';
import 'user_monetization_preferences_service.dart';

/// ID de producto de la compra lifetime (se crea igual en ambas consolas).
const String proLifetimeProductId = 'peliculas_pro_lifetime';

/// Origen del entitlement Pro.
enum ProEntitlementSource {
  purchase,
  restore,
  dev,
}

/// Entitlement Pro: quién es Pro, desde cuándo y por qué vía.
class ProEntitlement {
  const ProEntitlement({
    required this.isPro,
    required this.source,
    this.productId = proLifetimeProductId,
    this.purchaseDate,
  });

  final bool isPro;
  final ProEntitlementSource source;
  final String productId;
  final DateTime? purchaseDate;
}

/// Contrato de compras Pro.
abstract class PurchasesService {
  /// Emite el estado Pro cada vez que cambia.
  Stream<bool> get onProChanged;

  Future<void> initialize();
  Future<bool> isPro();
  Future<ProEntitlement> purchasePro();
  Future<ProEntitlement> restorePurchases();
  Future<void> dispose();
}

/// Implementación local offline-first del contrato de compras.
///
/// Persiste el entitlement en SharedPreferences vía
/// [UserMonetizationPreferencesService] y funciona sin red ni tiendas,
/// lo que permite probar paywall, gates y restore sin Sandbox.
/// El backend de billing real sustituye [purchasePro]/[restorePurchases]
/// sin cambiar a los consumidores.
class LocalPurchasesService implements PurchasesService {
  LocalPurchasesService._();
  static LocalPurchasesService? _instance;

  static LocalPurchasesService get instance {
    _instance ??= LocalPurchasesService._();
    return _instance!;
  }

  final UserMonetizationPreferencesService _prefs =
      UserMonetizationPreferencesService.instance;
  final StreamController<bool> _proChangedController =
      StreamController<bool>.broadcast();

  bool _isInitialized = false;

  @override
  Stream<bool> get onProChanged => _proChangedController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _prefs.initialize();
    _isInitialized = true;
    LoggerFactory.info('LocalPurchasesService inicializado');
  }

  @override
  Future<bool> isPro() async {
    if (!_isInitialized) await initialize();
    return _prefs.isPro();
  }

  @override
  Future<ProEntitlement> purchasePro() async {
    if (!_isInitialized) await initialize();
    await _prefs.setProActive(true);
    _proChangedController.add(true);
    LoggerFactory.info('Compra Pro registrada (origen: purchase)');
    return ProEntitlement(
      isPro: true,
      source: ProEntitlementSource.purchase,
      purchaseDate: DateTime.now(),
    );
  }

  @override
  Future<ProEntitlement> restorePurchases() async {
    if (!_isInitialized) await initialize();
    // Relee el entitlement persistido y re-sincroniza premiumUser por si
    // la app se reinstaló o el tipo quedó desactualizado.
    final active = await _prefs.isPro();
    if (active) {
      await _prefs.setProActive(true);
    }
    _proChangedController.add(active);
    LoggerFactory.info('Restore Pro completado: isPro=$active');
    return ProEntitlement(
      isPro: active,
      source: ProEntitlementSource.restore,
    );
  }

  @override
  Future<void> dispose() async {
    await _proChangedController.close();
  }
}
