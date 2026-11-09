# IA local (en el dispositivo): ideas y plan

Estado: **propuesta** (9 nov 2026). Nada de esto está implementado.

## Por qué IA local

- **Coste cero por uso:** corre en el teléfono, sin servidor ni API de pago. Es ideal para un Pro
  con buen margen.
- **Privacidad:** el historial del usuario no sale del dispositivo.
- **Sin conexión:** funciona sin red una vez descargado el modelo (lo gestiona el sistema).

## Qué hay en cada plataforma

| | iOS | Android |
|---|---|---|
| API | Framework **Foundation Models** (Swift) | **ML Kit GenAI**: Prompt API (texto libre) + APIs de resumen y reescritura, sobre **Gemini Nano** (AICore) |
| Sistema mínimo | iOS 26 con Apple Intelligence activado | Android con AICore y Gemini Nano |
| Dispositivos | iPhone compatible con Apple Intelligence (iPhone 15 Pro y posteriores) | Pocos: Pixel 9/10 y algunos Samsung, vivo, Honor… la lista oficial cambia |
| Idiomas | Español y portugués soportados | Verificar por API y dispositivo |
| Salida estructurada | Sí (`@Generable`: el modelo rellena un struct de Swift) | Por prompt + JSON; validar siempre |
| Límites | Contexto pequeño (4K tokens; iOS 27 lo varía por dispositivo: leer `contextSize` en tiempo de ejecución) | Solo con la app en primer plano (nada en segundo plano) |

En iOS 27 el mismo framework también admite modelos en la nube (Private Cloud Compute y
proveedores externos). **Aquí solo usamos el modelo local**, que es el gratis.

Consecuencia: **solo una parte de los usuarios tendrá IA**, sobre todo en Android. Toda función
con IA necesita un plan B sin IA (abajo).

## La regla de oro: los datos los pone la app, la IA solo redacta

Estos modelos son pequeños (unos 3.000 millones de parámetros): escriben bien, pero **no saben
datos de películas y los inventan**, y se equivocan con las cuentas.

- La app **calcula** todas las cifras (horas vistas, géneros, notas medias) con código normal.
- La app **le pasa** los datos ya hechos: los títulos, la sinopsis de TMDB y el historial del usuario.
- La IA solo **escribe el texto** o **elige entre opciones** que la app le da.
- Nunca preguntarle "¿de qué trata X?" ni "¿quién dirigió X?": eso viene de TMDB.

Por eso los informes "normales" (estadísticas) van primero: son el producto por sí mismos y son
los datos que alimentan a la IA.

## Ideas, de más a menos recomendable

### 1. Resumen del mes y del año (Pro)
- **Sin IA (para todos los dispositivos):** tarjeta con cifras (películas, episodios, horas, top 5
  géneros, actor más visto, mejor calificada, racha más larga) y una imagen para compartir.
  iOS ya tiene `Features/Stats/StatsView.swift`: ampliarla.
- **Con IA:** un párrafo con personalidad ("Octubre fue tu mes de terror: 9 películas, casi todas
  de los 80…") y un "tipo de espectador" ("El Maratonista Nocturno").
- Implementación: `struct ResumenDatos` calculado en código → prompt corto → en iOS,
  `@Generable struct ResumenIA { titulo, parrafo, tipoEspectador }`.
- Plan B: plantillas de texto con las mismas cifras.

### 2. Búsqueda en lenguaje natural
"Algo de terror que no dé mucho miedo, corto, para ver en pareja" → la IA lo convierte en
**filtros** (géneros, duración máxima, años, nota mínima) y la app llama a TMDB `discover`.
- La IA no recomienda títulos de memoria: solo traduce la frase a filtros. Los resultados son de TMDB.
- iOS: `@Generable struct Filtros { generos: [Genero], duracionMax: Int?, desde: Int?, … }`, con
  los géneros como `enum` para que no se invente ninguno.
- Plan B: la búsqueda normal y los filtros a mano que ya existen.

### 3. "Por qué te puede gustar"
En el detalle: la app pasa la sinopsis de TMDB y 5 títulos que el usuario calificó alto; la IA
escribe una frase ("Si te gustó *Zodiac*, esta tiene el mismo ritmo de investigación lenta").
Plan B: no mostrar nada, o "Porque te gustó X" (ya existe en Inicio).

### 4. Ayuda para escribir reseñas (cuando existan, ver `docs/SOCIAL.md`)
- Sugerir el tono, corregir ortografía (ML Kit tiene una API de corrección).
- **Detectar spoilers** y ofrecer marcarlos ("¿Ocultar como spoiler?").
- **Pre-moderación:** avisar antes de publicar si el texto parece ofensivo. Ayuda con la guía
  1.2 de Apple, pero **no sustituye** la moderación del servidor (denuncias y bloqueo).

### 5. Resumen de reseñas de amigos (fase social)
"Tus amigos dicen: buena fotografía, final flojo". Solo con varias reseñas y con el texto de
ellos como entrada.

### Descartadas
- **"Qué pasó hasta el episodio X":** el modelo no conoce las series y se lo inventaría.
- **Chat de recomendaciones libre:** inventa títulos; mejor la búsqueda natural (idea 2).

## ¿Gratis o Pro?

- Informes con cifras (sin IA): lo básico gratis (resumen del mes); el anual y la imagen para
  compartir, Pro.
- Todo lo que usa IA: **buen candidato a Pro**, porque no cuesta nada por uso. Pero el paywall
  debe aclarar que necesita un dispositivo compatible, y nunca vender Pro *solo* por la IA (muchos
  Android no la tendrán).
- Búsqueda natural: puede ser gratis para atraer usuarios, porque solo crea filtros.

## Detalles técnicos

- **Disponibilidad:** en iOS, `SystemLanguageModel.default.availability` (no soportado, Apple
  Intelligence apagado, modelo descargándose). En Android, comprobar la disponibilidad de la
  función en ML Kit antes de mostrar el botón. Si no está disponible, ocultar o usar el plan B,
  sin mensajes de error.
- **iOS 15 → 26:** el proyecto soporta versiones viejas; envolver todo en `if #available(iOS 26, *)`.
- **Contexto pequeño:** mandar resúmenes (top 10, conteos), no el historial entero.
- **Latencia:** de 1 a 5 s; mostrar el texto en streaming o con un indicador, y guardar en caché
  el resultado (el resumen del mes no cambia).
- **Android en primer plano:** generar solo con la pantalla abierta; nada de tareas en segundo plano.
- **Pruebas:** con datos fijos, revisar a mano que no invente cifras ni títulos; probar en español,
  inglés y portugués.
- **TMDB:** pasar sinopsis o títulos al modelo local es procesar los datos, no entrenar. Igual,
  revisar los términos de la API de TMDB sobre IA antes de lanzar.

## Orden sugerido

1. Estadísticas y resumen del mes **sin IA** en las dos apps (sirve para todos y alimenta lo demás).
2. Párrafo con IA en el resumen (iOS primero: más usuarios con IA disponible).
3. Búsqueda en lenguaje natural.
4. Lo de reseñas, junto con la fase social.

## Fuentes

- Apple: Foundation Models y guía de iOS de la WWDC26 — https://developer.apple.com/wwdc26/guides/ios/
- Google: ML Kit GenAI — https://developers.google.com/ml-kit/genai
- Google: Prompt API de ML Kit — https://developer.android.com/blog/posts/ml-kit-s-prompt-api-unlock-custom-on-device-gemini-nano-experiences
- Google: inferencia en el dispositivo (jul 2026) — https://android-developers.googleblog.com/2026/07/android-on-device-inference.html
