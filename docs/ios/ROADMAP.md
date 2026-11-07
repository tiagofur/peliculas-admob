# Roadmap iOS + Apple TV — Películas nativa

> Foco actual: 100% Apple (iPhone primero, Apple TV después).
> Código: [`native-ios/`](../../native-ios/) · Producto: [`PRODUCT.md`](../../PRODUCT.md)
> Seguimiento en GitHub: issue épica [#146](https://github.com/tiagofur/peliculas-admob/issues/146) y los hitos `iOS 1.0`, `iOS 1.1`, `iOS 1.2`, `tvOS 1.0`.

## 1. Posicionamiento

No competimos como "otra app de películas". La propuesta es:

> **Seguimiento de series + dónde verla + lo mejor de iOS nativo, en español y portugués.**

### Competencia y huecos

| App | Fuerte en | Hueco que aprovechamos |
|---|---|---|
| Letterboxd | Películas, social | Floja en series |
| TV Time | Seguimiento de series | Cargada de anuncios, usuarios quejándose |
| Serializd | Series, social | Poca presencia en LatAm/Brasil |
| JustWatch | Dónde verla | No es biblioteca personal ni tracker |
| Trakt | Power users | Interfaz poco amigable |
| Callsheet | Nativa iOS, info rica | Prueba que el modelo indie con suscripción funciona |

Diferenciadores:
1. **Primero en ES / PT** (LatAm y Brasil) — l10n ya existe.
2. **Nativa de verdad**: Liquid Glass, widgets, Live Activities, Siri, Apple Intelligence. Es lo que el equipo editorial de Apple destaca.
3. **Sin anuncios agresivos**: nunca intersticiales.

## 2. Funciones (por impacto)

1. **Próximo episodio y calendario** — pestaña "Siguiente", marcar visto, avisos de episodios nuevos. Es lo que trae a la gente cada día.
2. **¿Dónde la veo?** — TMDB `/watch/providers` por país + filtro "solo mis plataformas". Requiere crédito a JustWatch.
3. **Nativo iOS** — widgets (inicio y bloqueo), Live Activity / Dynamic Island con cuenta atrás, App Intents / Siri / Spotlight, recomendaciones con Foundation Models en el dispositivo (iOS 26+).
4. **"Qué vemos hoy" en grupo** — deslizar pósters, match entre personas, enlace o SharePlay. Viral.
5. **Importar** desde TV Time, Trakt y Letterboxd (CSV). Ya hay un trakt mapper en Flutter.
6. **Wrapped anual** compartible (imagen para Instagram).
7. **Detalles que gustan** — escena post-créditos (keywords TMDB `duringcreditsstinger` / `aftercreditsstinger`), resúmenes sin spoilers, duración total de temporada.

## 3. Monetización

Modelo principal: **freemium con suscripción Pro (StoreKit 2)**. AdMob solo como apoyo en la versión gratis.

| Modelo | Uso |
|---|---|
| Suscripción Pro | Principal |
| Pago de por vida | Opción dentro del paywall |
| AdMob | Solo banners discretos en gratis. Sin intersticiales |
| Rewarded → Pro 24 h | Reutiliza el patrón de Flutter (#117) |
| Propinas | Opcional, más adelante |

**Precios orientativos** (Apple ajusta por país): 1,99 USD/mes · 9,99–14,99 USD/año · 24,99–29,99 USD de por vida.
**Comisión**: apuntarse al App Store Small Business Program (15% en vez de 30%).

| Gratis | Pro |
|---|---|
| Explorar, buscar, detalle, tráilers | Sin anuncios |
| Watchlist, favoritos, vistas | Avisos de episodios nuevos |
| Seguimiento básico de series | Widgets y Live Activities |
| Hasta 3 listas propias | Listas ilimitadas |
| | Filtro "mis plataformas" |
| | Recomendaciones IA |
| | Estadísticas y Wrapped |
| | Iconos alternativos |

> El reparto gratis/Pro se valida con datos tras el lanzamiento. Lo que trae a la gente cada día (marcar visto, "Siguiente") se queda gratis.

## 4. Apple TV (tvOS)

**Sí, pero después del lanzamiento de iOS 1.0.** Motivos:

- Encaja con el estilo "Apple TV" que ya tiene el diseño y con el uso en el sofá.
- Mucho código SwiftUI se comparte (Core, modelos, TMDB, Supabase, StoreKit).
- Con **Universal Purchase** el Pro se compra una vez y vale en iPhone y Apple TV. Es un argumento de venta del Pro.
- Hay muy pocas apps de seguimiento buenas en tvOS: más fácil destacar.

Cosas a tener en cuenta:
- **AdMob no soporta tvOS** → en Apple TV solo hay Pro (o versión gratis sin anuncios).
- **WebKit no existe en tvOS** → los tráilers de YouTube no se pueden embeber; abrir la app de YouTube por deep link o usar otra fuente.
- La interfaz se maneja con el **foco** del mando (no táctil): rails y detalle hay que adaptarlos.
- **Top Shelf extension** con "Siguiente" para aparecer en la pantalla de inicio del Apple TV.

## 5. Hitos

Las fechas son objetivos, no compromisos.

### iOS 1.0 — Lanzamiento (objetivo: 2026-11-30)
- [ ] Series: marcar episodios vistos y progreso (#119)
- [ ] Pestaña "Siguiente" + calendario de estrenos (#120)
- [ ] Notificaciones de episodios nuevos (#121)
- [ ] ¿Dónde la veo? + filtro mis plataformas (#122)
- [ ] Paywall Pro con StoreKit 2 (mensual / anual / de por vida) (#123)
- [ ] AdMob real (SPM) + consentimiento (UMP/ATT) + rewarded 24 h (#124)
- [ ] Borrar cuenta desde la app (obligatorio en App Review) (#125)
- [ ] Privacidad: Privacy Manifest, etiquetas de privacidad, política y términos (#126)
- [ ] Licencia comercial TMDB + crédito JustWatch (#127)
- [ ] App Store Connect: productos, grupo de suscripción, Small Business Program (#128)
- [ ] Métricas básicas (crashes + conversión del paywall) (#129)
- [ ] Ficha App Store ES/EN/PT (capturas, keywords, vídeo) (#130)
- [ ] Beta en TestFlight (#131)

### iOS 1.1 — Retención y nativo (objetivo: 2026-12-21)
- [ ] Widgets (inicio + bloqueo) (#132)
- [ ] Live Activity / Dynamic Island con cuenta atrás de estreno (#133)
- [ ] App Intents / Siri / Spotlight (#134)
- [ ] Recomendaciones IA en el dispositivo (iOS 26+) (#135)
- [ ] Importar desde TV Time / Trakt / Letterboxd (#136)
- [ ] Post-créditos y duración de temporada (#137)

### iOS 1.2 — Social y crecimiento (objetivo: 2027-01-31)
- [ ] "Qué vemos hoy" en grupo (#138)
- [ ] Wrapped anual compartible (#139)
- [ ] Iconos alternativos (Pro) (#140)

### tvOS 1.0 — Apple TV (objetivo: 2027-02-28)
- [ ] Target tvOS compartiendo Core (#141)
- [ ] Interfaz con foco (home, detalle, biblioteca) (#142)
- [ ] Tráilers sin WebKit (#143)
- [ ] Universal Purchase y Pro compartido (#144)
- [ ] Top Shelf con "Siguiente" (#145)

## 6. Riesgos

| Riesgo | Mitigación |
|---|---|
| Licencia TMDB para uso comercial | Revisar términos / contactar a TMDB antes de cobrar |
| Rechazo por guía 4.2/4.3 (funcionalidad mínima / copia) | Funciones nativas y seguimiento de series desde la 1.0 |
| Suscripción sin "valor continuo" (guía 3.1.2) | Pro centrado en avisos, widgets e IA, que dan valor recurrente |
| eCPM bajo de AdMob en LatAm | AdMob solo como apoyo; ingresos vía Pro |
| Mínimo iOS 15 vs APIs nuevas | `#available` con fallback; funciones iOS 26+ solo como extra |

## 7. Criterios de lanzamiento (iOS 1.0)

- Sin crashes conocidos en TestFlight durante 1 semana.
- Compra, restauración y cancelación del Pro probadas en sandbox.
- App Review: cuenta demo, borrar cuenta, privacidad y términos enlazados.
- Ficha publicada en ES, EN y PT.
