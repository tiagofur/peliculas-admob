# Guía de preparación y publicación en Google Play Console

> Ficha de la app Android nativa «Películas» (`native-android/`).
> Paridad con la ficha de App Store en iOS ([`docs/ios/ROADMAP.md`](../ios/ROADMAP.md)).
>
> Fecha: 2026-11-08 · Estado: 📋 Checklist listo para lanzamiento

---

## 1. Identidad de la aplicación

| Parámetro | Valor |
|---|---|
| **Package name** | `mx.creapolis.peliculas.android` |
| **Nombre de la app** | Películas |
| **Categoría principal** | Entretenimiento |
| **Monetización** | Freemium (gratuita con banners AdMob discretos + suscripción Pro) |
| **Público objetivo** | Mayores de 13 años (sin contenido dirigido específicamente a niños) |
| **Idiomas principales** | Español (base), Portugués (Brasil), Inglés |

---

## 2. Textos de la ficha (ES / PT / EN)

### Español (Base)
- **Título**: Películas: Series y Streaming
- **Descripción corta (80 car.)**: Tu biblioteca de cine y series: seguimiento, dónde verla y recomendaciones.
- **Descripción completa**:
```
Películas es la app definitiva para amantes del cine y las series en español y portugués.

FUNCIONES PRINCIPALES:
• Sigue tus series: Próximo episodio por ver, progreso por temporada y avisos de estreno.
• ¿Dónde verla?: Descubre qué plataforma tiene tu título (Netflix, Prime Video, Disney+, Max y más) y ábrela en un toque.
• Descubre contenido: Tendencias diarias, próximos estrenos en cines, 8 estados de ánimo curados ("Joyas ocultas", "Noche romántica"...) y filtros por año y valoración.
• Biblioteca personal: Watchlist, favoritos, vistas, notas con estrellas y reseñas personales.
• Estadísticas e historial: Conoce cuántas películas has visto, tus épocas favoritas por década y tu actividad mensual con gráficas nativas.
• Logros y niveles: Gana puntos y desbloquea insignias a medida que ves y calificas títulos.
• En todos tus dispositivos: Sincronización automática de tu biblioteca con tu cuenta.
• Widget de inicio: Consulta las tendencias del día directamente desde tu pantalla de inicio.

Versión Pro:
Disfruta de la app sin anuncios, listas ilimitadas y avisos inmediatos cuando salgan nuevos episodios de tus series favoritas.
```

### Português (Brasil)
- **Título**: Películas: Filmes e Séries
- **Descrição curta (80 car.)**: Seu guia de filmes e séries: acompanhe episódios, onde assistir e descubra mais.
- **Descrição completa**:
```
Películas é o aplicativo definitivo para fãs de cinema e séries.

RECURSOS PRINCIPAIS:
• Acompanhe suas séries: Próximo episódio a assistir, progresso por temporada e lembretes de estreia.
• Onde assistir?: Saiba em qual streaming o título está disponível (Netflix, Prime Video, Disney+, Max e mais) e abra com um toque.
• Descubra o que assistir: Tendências diárias, estreias no cinema, 8 humores selecionados e filtros por ano e nota.
• Biblioteca pessoal: Watchlist, favoritos, vistos, avaliações com estrelas e resenhas pessoais.
• Estatísticas e histórico: Veja seus filmes assistidos, suas décadas favoritas e gráficos de atividade mensal.
• Conquistas e níveis: Ganhe pontos e suba de nível enquanto assiste e avalia títulos.
• Em todos os seus dispositivos: Sincronização automática com sua conta.
• Widget na tela inicial: Tendências do dia direto na sua tela.

Películas Pro:
Experiência sem anúncios, listas ilimitadas e alertas de novos episódios das suas séries favoritas.
```

### English
- **Title**: Películas: Movies & TV Shows
- **Short description (80 chars)**: Movie & TV show tracker: where to stream, up next episodes & recommendations.

---

## 3. Requisitos técnicos para Google Play

1. **Android App Bundle (AAB)**:
   ```bash
   cd native-android
   ./gradlew bundleRelease
   ```
   Ruta del artefacto: `app/build/outputs/bundle/release/app-release.aab`.

2. **Firma de producción**:
   - Generar un Keystore de producción seguro o utilizar Google Play App Signing.
   - Extraer la huella SHA-256 del certificado de firma y actualizar `native-android/appserver/assetlinks.json` en el VPS para que los App Links mantengan `autoVerify="true"` en la versión de producción.

3. **Target SDK & APIs**:
   - `minSdk = 26` (Android 8.0)
   - `targetSdk = 36` (Cumple el requisito oficial de Google Play Store para 2026)
   - `compileSdk = 37`

4. **App Links verificados**:
   - `https://peliculas.creapolis.dev/.well-known/assetlinks.json` ya está activo en producción y validado.

---

## 4. Productos de Google Play Billing

En Google Play Console › **Monetización** › **Productos integrados en la aplicación**:

| ID de producto | Tipo | Precio sugerido |
|---|---|---|
| `peliculas_pro_monthly` | Suscripción (mensual) | $1.99 USD / mes (con 7 días de prueba) |
| `peliculas_pro_yearly` | Suscripción (anual) | $11.99 USD / año (ahorro del 40%) |
| `peliculas_pro_lifetime` | Compra única (in-app) | $29.99 USD (pago único de por vida) |

---

## 5. Declaración de seguridad de datos (Data Safety)

- **Datos recopilados**:
  - Información de la cuenta: Nombre, correo electrónico (para autenticación y sync).
  - Actividad de la app: Títulos guardados, vistas y notas (para la biblioteca personal).
  - Identificadores de dispositivo: Para notificaciones push y publicidad AdMob.
- **Seguridad**:
  - Cifrado en tránsito (HTTPS / TLS 1.3).
  - Opción de eliminación de cuenta disponible dentro de la app (Ajustes › Cuenta › Borrar cuenta y datos) y vía soporte.

---

## 6. Proceso de lanzamiento recomendado

1. **Paso 1: Pruebas internas (Internal Testing)**:
   - Subir el primer `.aab` a la pista interna.
   - Verificar compras con cuentas de prueba de licencia en Google Play Console.
2. **Paso 2: Pruebas cerradas (Closed Testing)**:
   - Requisito de Google Play para cuentas personales: 20 evaluadores durante 14 días.
3. **Paso 3: Lanzamiento a producción**:
   - Despliegue escalonado inicial (10% → 25% → 50% → 100%).
