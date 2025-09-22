import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base provider que maneja automáticamente la limpieza de recursos
/// para prevenir memory leaks
abstract class BaseProviderWithCleanup<T> extends StateNotifier<T> {
  BaseProviderWithCleanup(T state) : super(state);

  /// Lista de suscripciones que se cancelarán automáticamente al disponer
  final List<StreamSubscription> _subscriptions = [];

  /// Lista de timers que se cancelarán automáticamente al disponer
  final List<Timer> _timers = [];

  /// Agrega una suscripción que se limpiará automáticamente
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Agrega un timer que se cancelará automáticamente
  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  /// Cancela una suscripción específica y la remueve de la lista
  void cancelSubscription(StreamSubscription subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }

  /// Cancela un timer específico y lo remueve de la lista
  void cancelTimer(Timer timer) {
    timer.cancel();
    _timers.remove(timer);
  }

  /// Cancelar todas las suscripciones sin disponer el provider
  void cancelAllSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Cancelar todos los timers sin disponer el provider
  void cancelAllTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    // Cancelar todas las suscripciones
    cancelAllSubscriptions();

    // Cancelar todos los timers
    cancelAllTimers();

    // Llamar al dispose personalizado si existe
    onDispose();

    super.dispose();
  }

  /// Override este método en subclases para limpiar recursos adicionales
  /// Este método se llamará antes del dispose() del padre
  void onDispose() {}
}

/// Versión async del base provider
abstract class BaseAsyncProviderWithCleanup<T> extends AsyncNotifier<T> {
  /// Lista de suscripciones que se cancelarán automáticamente al disponer
  final List<StreamSubscription> _subscriptions = [];

  /// Lista de timers que se cancelarán automáticamente al disponer
  final List<Timer> _timers = [];

  /// Agrega una suscripción que se limpiará automáticamente
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Agrega un timer que se cancelará automáticamente
  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  /// Cancela una suscripción específica y la remueve de la lista
  void cancelSubscription(StreamSubscription subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }

  /// Cancela un timer específico y lo remueve de la lista
  void cancelTimer(Timer timer) {
    timer.cancel();
    _timers.remove(timer);
  }

  /// Cancelar todas las suscripciones sin disponer el provider
  void cancelAllSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Cancelar todos los timers sin disponer el provider
  void cancelAllTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Override este método en subclases para limpiar recursos adicionales
  void onDispose() {}

  @override
  void dispose() {
    // Cancelar todas las suscripciones
    cancelAllSubscriptions();

    // Cancelar todos los timers
    cancelAllTimers();

    // Llamar al dispose personalizado si existe
    onDispose();

    super.dispose();
  }
}

/// Mixin para providers que necesitan cleanup automático
mixin AutoCleanupMixin<T> on StateNotifier<T> {
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];

  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  void cancelSubscription(StreamSubscription subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }

  void cancelTimer(Timer timer) {
    timer.cancel();
    _timers.remove(timer);
  }

  void cancelAllSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  void cancelAllTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    cancelAllSubscriptions();
    cancelAllTimers();
    super.dispose();
  }
}