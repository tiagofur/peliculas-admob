# 📋 Guía: Obtener API Key de Trakt.tv

## Pasos para Obtener una API Key Válida

### 1. Crear Cuenta en Trakt.tv
1. Visitar [https://trakt.tv](https://trakt.tv)
2. Hacer clic en "Sign Up" si no tienes cuenta
3. Completar el registro con email y contraseña
4. Verificar email si es requerido

### 2. Acceder a OAuth Applications
1. Iniciar sesión en tu cuenta de Trakt.tv
2. Ir a [https://trakt.tv/oauth/applications](https://trakt.tv/oauth/applications)
3. Hacer clic en "New Application"

### 3. Crear Nueva Aplicación
Completar el formulario con la siguiente información:

#### Información Requerida:
- **Name**: `Películas App` (o el nombre de tu aplicación)
- **Description**: `Aplicación Flutter para gestión de películas`
- **Website**: `http://localhost:3000` (para desarrollo)
- **Redirect URI**: `http://localhost:3000/auth/callback`
- **Javascript Origins**: `http://localhost:3000`

#### Para Producción:
- **Website**: URL de tu aplicación en producción
- **Redirect URI**: `https://tudominio.com/auth/callback`
- **Javascript Origins**: `https://tudominio.com`

### 4. Obtener Credenciales
Después de crear la aplicación, obtendrás:

- **Client ID**: Identificador público de tu aplicación
- **Client Secret**: Clave secreta (mantener privada)
- **API Key**: Clave para requests no autenticados

### 5. Configurar en el Proyecto

#### Actualizar archivo .env
```env
# Trakt.tv API Configuration
TRAKT_API_KEY=tu_api_key_aqui
TRAKT_CLIENT_ID=tu_client_id_aqui
TRAKT_CLIENT_SECRET=tu_client_secret_aqui
```

#### Para Flutter Web (api_keys.dart)
```dart
class ApiKeys {
  // Trakt.tv Configuration
  static const String traktApiKey = 'tu_api_key_aqui';
  static const String traktClientId = 'tu_client_id_aqui';
  static const String traktClientSecret = 'tu_client_secret_aqui';
}
```

### 6. Verificar Configuración

Ejecutar el script de verificación:
```bash
dart test_apis_verification.dart
```

Deberías ver:
```
✅ Trakt.tv API funcionando correctamente
```

### 7. Activar en la Aplicación

Cambiar el provider en `movies_repository_provider.dart`:

```dart
// Comentar TMDB (rollback temporal)
// final movieRepositoryProvider = Provider((ref) {
//   return MovieRepositoryImpl(MoviedbDatasource());
// });

// Descomentar Trakt.tv
final traktApiServiceProvider = Provider<TraktApiService>((ref) {
  return TraktApiService();
});

final movieRepositoryProvider = Provider((ref) {
  final traktApiService = ref.watch(traktApiServiceProvider);
  return TraktMoviesRepositoryImpl(traktApiService);
});
```

## Límites de la API

### Trakt.tv API Limits
- **Requests por minuto**: 1,000 (autenticado)
- **Requests por minuto**: 1,000 (no autenticado)
- **Requests por día**: Sin límite específico

### Buenas Prácticas
1. **Cachear respuestas** cuando sea posible
2. **Implementar retry logic** para errores temporales
3. **Usar paginación** para listas grandes
4. **Respetar rate limits** con delays entre requests

## Troubleshooting

### Error 403 Forbidden
- Verificar que el Client ID sea correcto
- Confirmar que la aplicación esté activa en Trakt.tv
- Revisar que los headers sean correctos:
  ```
  Content-Type: application/json
  trakt-api-version: 2
  trakt-api-key: [CLIENT_ID]
  ```

### Error 401 Unauthorized
- Para endpoints que requieren autenticación
- Necesitas implementar OAuth flow completo
- Obtener access token del usuario

### Error 429 Too Many Requests
- Has excedido el rate limit
- Implementar backoff exponencial
- Reducir frecuencia de requests

## Recursos Adicionales

- **Documentación oficial**: [https://trakt.docs.apiary.io](https://trakt.docs.apiary.io)
- **OAuth Applications**: [https://trakt.tv/oauth/applications](https://trakt.tv/oauth/applications)
- **API Status**: [https://status.trakt.tv](https://status.trakt.tv)
- **Community Forum**: [https://trakt.tv/forums](https://trakt.tv/forums)

---

**Nota**: Las credenciales actuales del proyecto YA son válidas y funcionales. Esta guía es para referencia futura o para crear nuevas aplicaciones.