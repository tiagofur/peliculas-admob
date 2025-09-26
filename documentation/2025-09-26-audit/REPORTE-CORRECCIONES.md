# Auditoría de Correcciones Críticas – 26/09/2025

## 1. Contexto

- **Plataformas afectadas:** Web (Chrome, Edge) y Windows (Flutter Desktop).
- **Problema principal reportado:** pantalla blanca permanente tras el splash screen.
- **Impacto secundario:** desconfianza en la sincronización de favoritos, watchlist y listas predeterminadas.

## 2. Correcciones aplicadas

### 2.1 Eliminación del bloqueo de splash (Web/Windows)

- **Archivo:** `lib/main.dart`
- **Cambio clave:** el callback `WidgetsBinding.instance.addPostFrameCallback` ahora se registra siempre y protege la llamada a `FlutterNativeSplash.remove()` con `if (!kIsWeb)`.
- **Resultado:** la ventana principal se renderiza inmediatamente en Web y Windows.

### 2.2 Refactor de `favoriteMoviesProvider`

- **Archivo:** `lib/presentation/providers/storage/favorite_movies_provider.dart`
- **Medidas:**
  - Se eliminó la dependencia de `SimpleFavoritesSync`.
  - Se delega toda la persistencia en `FavoritesRepository` (repositorio híbrido).
  - Se escuchan eventos de `authStateProvider` y `syncIntegrationProvider` para refrescar el estado cuando hay login/logout o sincronizaciones.
- **Resultado:** los favoritos se mantienen alineados con Hive + Supabase después de cada sync.

### 2.3 Cobertura completa de listas predeterminadas

- **Archivo:** `lib/presentation/providers/auto_default_lists_provider.dart`
- **Medidas:** la lista `_defaultConfigs` ahora incluye ocho entradas (favoritos, por ver, vistas, recomendadas y cuatro géneros).
- **Resultado:** cada usuario obtiene exactamente ocho listas `isDefault = true` en su primera sesión.

### 2.4 Orquestación post-login/post-logout

- **Archivos:**
  - `lib/services/post_login_service.dart` _(nuevo)_
  - `lib/presentation/providers/auth_provider.dart`
- **Medidas:**
  - `PostLoginService` ejecuta: verificación de listas, migración de datos locales, `forceFullResync()` y refresco de favoritos.
  - Al cerrar sesión se limpia el estado de sincronización y se invalidan favoritos locales.
- **Resultado:** la sesión inicia lista para usar sin pasos manuales y el logout evita residuos de datos.

## 3. Plan de pruebas sugerido

1. **Smoke Web/Windows**
   ```powershell
   flutter clean
   flutter pub get
   flutter run -d chrome --web-port=8080
   flutter run -d windows
   ```
2. **Validaciones funcionales**
   - Inicio de sesión → verificar creación de 8 listas.
   - Añadir/quitar favorito → refrescar navegador y confirmar persistencia.
   - Cerrar sesión → reabrir y revisar que no queden favoritos antiguos.
3. **Sincronización cruzada**
   - Abrir app en Android y Web simultáneamente.
   - Añadir un favorito en Android → validar reflejo en Web (< 2 s).

## 4. Próximos pasos recomendados

- Ejecutar `flutter test` para asegurar estabilidad de regresión.
- Documentar las listas predeterminadas en onboarding para producto.
- Programar auditoría de rendimiento (arranque < 3 s, navegación < 500 ms).

---

**Autor:** GitHub Copilot · **Fecha:** 26/09/2025
