/// Gate síncrono Pro para los widgets de anuncios.
///
/// Lee el cache en memoria de [UserMonetizationPreferencesService] para
/// decidir en `build`/`initState` sin I/O asíncrono. Con Pro activo los
/// widgets de anuncios deben renderizar vacío (S1); sin Pro no cambia nada.
library;

import '../../../services/monetization/user_monetization_preferences_service.dart';

/// true cuando el usuario es Pro y los ads forzados deben ocultarse.
bool get hideAdsForPro =>
    UserMonetizationPreferencesService.isProCached;
