# Paridad Android ↔ iOS (nov 2026)

Auditoría pantalla por pantalla de `native-android/` contra `native-ios/` y lo que se
corrigió en la rama `feat/android-parity-ios`. Criterio: mismas funciones y mismo
contenido; cada plataforma con sus patrones (M3 en Android, Liquid Glass en iOS).

## 1. Bugs graves que tenía Android

| Área | Problema | Arreglo |
|---|---|---|
| Build | No compilaba con el JDK de Android Studio (jvmTarget de Kotlin sin fijar) | `kotlin { jvmTarget = 17 }` |
| Pro | Sin Play Billing conectado, "comprar" **daba Pro gratis también en release** | Simulación solo en debug; release muestra error / "planes no disponibles" |
| Pro | Compras nunca reconocidas → Google las reembolsa a los 3 días | `acknowledgePurchase` en cada compra activa |
| Pro | Pro nunca se revocaba al vencer o reembolsar | Se recalcula con `queryPurchases` (subs + de por vida) al abrir y al volver |
| Pro | El paywall vive en un `Dialog`: `context as Activity` era `null` y Play nunca abría la compra | Se desenvuelve el contexto hasta la Activity |
| Pro | Precios inventados en release si Play no respondía | Solo en debug |
| Logros | La raíz llamaba `refresh` y nunca `check`: **ningún logro se desbloqueaba** | `achievements.check(counts)` |
| Biblioteca | Guardar desde un detalle abierto por enlace subía al servidor título y póster vacíos | `remember()` devuelve la foto rica y se usa en todas las ops |
| Biblioteca | Cola de sync tocada desde UI e IO sin bloqueo; borraba ops nuevas del mismo título | `synchronized` + se quita solo la op exacta enviada |
| Biblioteca | JSON escrito sin atomicidad | Temporal + rename |
| Actor | Créditos duplicados → **crash** por claves repetidas en la cuadrícula | Dedupe por `MediaKey`, solo con póster, mejor valorados primero |
| Ver todo | El infinite scroll nunca pedía la página 2 | El pie dispara `loadMore` |
| Biblioteca | Cuadrículas sin scroll (no se veía más allá de la pantalla) | `LazyVerticalGrid` |
| Detalle | Se podían marcar episodios no emitidos; tráiler con `youtube.com/embed` (Error 153) | Solo emitidos; `youtube-nocookie` con origen propio (como iOS) |
| Proveedores | Paquetes de app erróneos y sin `<queries>` → nunca abría la app; usaba el link de TMDB | Búsqueda web del proveedor (App Link a su app), mismo mapa de IDs que iOS |
| Anuncios | ID de prueba fijo en release, sin consentimiento RGPD | IDs por Gradle (`ADMOB_APP_ID`, `ADMOB_BANNER_ID`), UMP antes del SDK, banner adaptativo |
| Ciclo de vida | No sincronizaba al volver a primer plano ni guardaba al salir | `ProcessLifecycleOwner` (como `scenePhase`) |
| Inicio | Un refresco fallido vaciaba las filas | Se conserva lo anterior |

## 2. Funciones de iOS que faltaban en Android (ya añadidas)

| Pantalla | Añadido |
|---|---|
| Inicio | Continuar viendo, Visto recientemente, "Porque te gustó X", botón de cuenta, pull-to-refresh con sync, Top 10 con número solapado |
| Pósters | Pulsación larga: Watchlist, favorito, visto, listas, compartir |
| Detalle | Menú ⋯ con listas + "Nueva lista…" (límite Pro), estado de la serie, tagline, nota TMDB, sinopsis Más/Menos, tarjeta de tráiler + pantalla completa con "Abrir en YouTube", episodios con fecha/duración/sinopsis, atribución JustWatch, fallo parcial con reintentar, pull-to-refresh, compartir con enlace universal |
| Siguiente | Store compartido con caché (antes ~60 peticiones por cada cambio), secciones Continuar / Próximos / Por empezar, fecha tipo calendario + Hoy/Mañana/En N días |
| Biblioteca | Estados vacíos por sección, nota en Calificadas, portada 2×2 en listas, refresco con sync |
| Cuenta | Pro (plan, gestionar, restaurar), actividad + logros, recordatorios con permiso en contexto, sincronización, privacidad de anuncios, enlaces legales, ver bienvenida otra vez, versión, TMDB, confirmación al cerrar sesión |
| Login | Google (Credential Manager, equivalente a Sign in with Apple), legal, nombre opcional, contraseña mín. 8 |
| Recordatorios | Desactivados por defecto y activables desde Cuenta (antes se programaban siempre sin pedir permiso) |
| Navegación | Tocar la pestaña activa vuelve a su raíz; la pestaña resaltada sigue a su pila |

## 3. Pendiente fuera de la app (backend / configuración)

| Qué | Estado |
|---|---|
| `POST /v1/play/transactions` + RTDN de Play | **No existe** en el backend. La app ya reclama y reconoce compras; el servidor aún no sabe quién es Pro en Android |
| Push FCM (`platform: "android"`) | El backend rechaza dispositivos Android. Mientras `AppConfig.EPISODE_PUSH_AVAILABLE = false`, Android no promete avisos de episodios (paywall, Siguiente, Cuenta) |
| `GOOGLE_WEB_CLIENT_ID` | Sin definir, el botón de Google no aparece. Va en `~/.gradle/gradle.properties` y su ID en `GOOGLE_CLIENT_IDS` del backend |
| `ADMOB_APP_ID` / `ADMOB_BANNER_ID` | Sin definir, release usa los de prueba (igual que hoy el xcconfig de iOS) |

## 4. Diferencias de plataforma intencionales

- Barra inferior M3 con indicador en píldora (patrón Android) en vez del indicador invisible estilo iOS.
- Cuenta y Login como pantallas con barra superior y Atrás, no hojas.
- Filtro Todo/Películas/Series con `SegmentedButton`; géneros con `FilterChip` + menú.
- Proveedores por App Links en lugar de esquemas `netflix://`.

## 5. Lo que Android hace mejor y conviene llevar a iOS

1. **Filmografía completa en cuadrícula** (hasta 60) en la ficha de actor; iOS muestra una fila de 30.
2. **Logros en las categorías de Biblioteca**; en iOS solo se llega desde Cuenta.
3. **Confirmar antes de borrar una lista**; iOS la borra al instante con el swipe.
4. **Caché de imágenes real (Coil)**; iOS usa `AsyncImage` + `URLCache`, sin dedupe ni prefetch (lo cita el propio mega plan).
5. **Filtros de género visibles** (chips con el orden/año activos) en vez de un icono de menú que no dice qué filtro hay puesto.

## 6. Lo que iOS sigue teniendo y Android no

- Avisos push de episodios (bloqueado por backend, ver §3).
