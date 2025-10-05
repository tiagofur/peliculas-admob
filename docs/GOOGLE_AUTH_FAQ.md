# ❓ Preguntas Frecuentes - Google Auth + Supabase

## 🤔 Preguntas Generales

### ¿Por qué necesito configurar 3 servicios?

Porque el flujo de autenticación involucra a tres partes:

1. **Google Cloud/Firebase** - Provee el servicio de OAuth de Google y valida que tu app Android es legítima
2. **Supabase** - Tu backend que necesita validar los tokens de Google y crear usuarios en su base de datos
3. **Tu App** - Inicia el flujo y persiste la sesión

### ¿No puedo usar solo Firebase Auth?

No en este caso, porque tu backend es **Supabase**, no Firebase. Firebase Auth sería otro backend diferente.

Si usaras Firebase Auth, tendrías que:

- Usar Firestore en lugar de PostgreSQL
- Reescribir toda tu lógica de datos
- Migrar tus tablas de Supabase

### ¿Por qué no usar el método nativo de Supabase `signInWithOAuth`?

Hay dos formas de hacer Google Sign-In con Supabase:

**Opción A (la implementada): `google_sign_in` + `signInWithIdToken`**

- ✅ Selector nativo de Android (mejor UX)
- ✅ Sin WebView (más rápido)
- ✅ Funciona offline para selector
- ❌ Requiere `google_sign_in` package
- ❌ Más configuración inicial

**Opción B: `signInWithOAuth` (WebView)**

- ✅ Más simple de configurar
- ✅ No necesita `google_sign_in` package
- ❌ Abre WebView (peor UX)
- ❌ Más lento
- ❌ Requiere deep linking

La opción A (implementada) es mejor para apps nativas Android.

## 🔑 Preguntas sobre Google Cloud

### ¿Necesito crear un proyecto en Google Cloud?

Si ya tienes Firebase configurado, **NO**. Firebase y Google Cloud comparten el mismo proyecto.

Solo ve a Google Cloud Console con el mismo email y verás tu proyecto de Firebase.

### ¿Qué Client ID uso en Supabase?

**IMPORTANTE**: Usa el **Client ID Web**, NO el de Android.

Supabase necesita el Client ID Web para validar los tokens de Google en el backend.

### ¿Dónde encuentro el Client ID Web?

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. APIs y servicios → Credenciales
3. Busca "Client ID de OAuth 2.0" de tipo **"Aplicación web"**
4. Si no existe, créalo (sin URIs de redirección por ahora)

### ¿Por qué necesito agregar huellas SHA?

Las huellas SHA (SHA-1 y SHA-256) identifican tu app Android de forma única.

Google las usa para:

- Verificar que los tokens provienen de tu app legítima
- Prevenir ataques de phishing
- Generar automáticamente el Client ID de Android

Sin las huellas SHA, Google rechazará el login.

### ¿Necesito agregar ambas huellas (debug y release)?

**SÍ**, ambas:

- **Debug**: Para desarrollo local (`flutter run`)
- **Release**: Para APKs de producción

Si solo agregas release, no funcionará en desarrollo.

## 🗄️ Preguntas sobre Supabase

### ¿Dónde configuro Google en Supabase?

Supabase Dashboard → Authentication → Providers → Google

Ahí debes:

1. Habilitar el toggle
2. Pegar el Client ID Web de Google
3. Pegar el Client Secret de Google

### ¿Qué es el "Authorized Client IDs"?

Es un campo opcional en Supabase donde puedes agregar **todos** los Client IDs de tus plataformas:

- Client ID Web
- Client ID Android
- Client ID iOS

Esto permite que Supabase acepte tokens de cualquiera de estas plataformas.

### ¿Necesito configurar el Redirect URL?

**SÍ**, en dos lugares:

1. **En Supabase**: Ya está configurado automáticamente como:

   ```
   https://TU_PROYECTO.supabase.co/auth/v1/callback
   ```

2. **En Google Cloud Console**: Debes agregar esta misma URL en:
   - Credenciales → Client ID Web → URIs de redirección autorizados

### ¿Funciona sin el Redirect URL?

Para el flujo nativo con `signInWithIdToken` que implementamos, técnicamente **SÍ puede funcionar sin el Redirect URL**.

Pero es **altamente recomendado** agregarlo por:

- Compatibilidad futura
- Si decides usar `signInWithOAuth` después
- Para integraciones web

### ¿Cómo verifico que está configurado correctamente?

En Supabase Dashboard:

1. Ve a Authentication → Providers → Google
2. Verifica que el toggle esté verde (habilitado)
3. Verifica que los campos tengan valores
4. Guarda cambios

Luego prueba la app y verifica en:

- Authentication → Users que se crea el usuario

## 📱 Preguntas sobre la App

### ¿Qué archivo es google-services.json?

Es la configuración de Firebase/Google Cloud para tu app Android.

Contiene:

- IDs de proyecto
- API keys
- Client IDs
- URLs de servicios

**Ubicación**: `android/app/google-services.json`

### ¿Necesito actualizar google-services.json cada vez?

**SÍ**, después de agregar las huellas SHA en Firebase/Google Cloud.

Esto es porque el archivo incluye los Client IDs generados para tu app.

### ¿Dónde está el botón de Google en la app?

En dos pantallas:

- **LoginScreen**: Entre el divisor "o" y "Crear Cuenta"
- **RegisterScreen**: Entre el divisor "o" y "Iniciar Sesión"

Widget: `lib/presentation/widgets/auth/google_sign_in_button.dart`

### ¿Cómo pruebo que funciona?

1. Ejecuta la app: `flutter run`
2. Ve a Login o Registro
3. Presiona "Continuar con Google"
4. Debería abrir el selector de cuenta nativo
5. Selecciona una cuenta
6. Debería redirigirte al Home
7. Verifica en Supabase Dashboard → Users que se creó el usuario

## 🔒 Preguntas sobre Seguridad

### ¿Es seguro este flujo?

**SÍ**, muy seguro porque:

1. **Tokens validados por múltiples partes**:

   - Google valida que el usuario es legítimo
   - Supabase valida que el token viene de Google
   - App verifica la sesión de Supabase

2. **No exponemos contraseñas**: El usuario se autentica con Google, no con tu app

3. **PKCE flow**: Supabase usa PKCE (Proof Key for Code Exchange) para prevenir ataques

4. **Tokens tienen expiración**: Los tokens de Google expiran en 1 hora

5. **Refresh automático**: Supabase refresca tokens automáticamente

### ¿Dónde se almacena la sesión?

Localmente en el dispositivo usando:

- `SharedPreferences` para metadata
- Almacenamiento seguro para tokens

La implementación usa `AuthSessionManager` que:

- Cifra tokens sensibles
- Valida expiración
- Refresca automáticamente
- Limpia en logout

### ¿Qué pasa si roban el token?

Los tokens tienen varias protecciones:

1. **Expiración**: Solo válidos por 1 hora
2. **Refresh token**: Necesario para renovar
3. **Device binding**: Vinculado al dispositivo
4. **RLS en Supabase**: Row Level Security previene acceso no autorizado

Además, si detectas acceso no autorizado:

- Puedes revocar el token en Supabase Dashboard
- Cambiar la contraseña de Google invalida tokens

## 🐛 Preguntas sobre Errores

### Error: "12500 - Developer Error"

**Causa**: Google no puede validar tu app.

**Solución**:

1. Verifica que las huellas SHA estén en Firebase/Google Cloud
2. Verifica que usas el keystore correcto (debug o release)
3. Descarga el `google-services.json` actualizado
4. `flutter clean && flutter pub get`

### Error: "Invalid idToken"

**Causa**: Supabase no puede validar el token de Google.

**Solución**:

1. Verifica que el **Client ID Web** esté correcto en Supabase
2. Verifica que el **Client Secret** esté correcto
3. Asegúrate de que Google Provider esté habilitado en Supabase

### Error: "Provider not enabled"

**Causa**: Google Provider no está habilitado en Supabase.

**Solución**:

1. Supabase Dashboard → Authentication → Providers → Google
2. Activa el toggle
3. Configura Client ID y Secret
4. Guarda cambios

### Error: "Sign in cancelled"

**Causa**: El usuario canceló el flujo de Google.

**Esto es normal**, el usuario puede cancelar en cualquier momento.

### El botón no hace nada

**Debugging**:

1. Ejecuta con logs: `flutter run -v`
2. Busca mensajes con 🔑, ✅ o ❌
3. Verifica que no haya errores de importación
4. Verifica que `google_sign_in` esté instalado: `flutter pub get`

## 🔄 Preguntas sobre Sincronización

### ¿Se sincronizan mis datos locales después del login?

**SÍ**, automáticamente.

La implementación usa `PostLoginService` que:

1. Detecta datos locales (películas vistas, calificaciones, listas)
2. Migra todo a Supabase
3. Sincroniza con el servidor
4. Mantiene todo actualizado

### ¿Puedo usar la app sin autenticarme?

**SÍ**, la app funciona en modo **guest**.

En modo guest:

- ✅ Puedes navegar películas
- ✅ Datos se guardan localmente
- ❌ No se sincronizan con el servidor
- ❌ No funcionan features sociales

Al autenticarte, tus datos locales se migran automáticamente.

## 🌐 Preguntas sobre Plataformas

### ¿Funciona en iOS?

El código **SÍ funciona en iOS**, pero necesitas configuración adicional:

1. Client ID de iOS en Google Cloud
2. Configuración en Xcode
3. URLScheme para callbacks

Documentación: [google_sign_in iOS setup](https://pub.dev/packages/google_sign_in#ios-integration)

### ¿Funciona en Web?

**SÍ**, pero usa un flujo diferente.

Para web necesitas:

- Configurar el SDK de Google para JavaScript
- O usar `signInWithOAuth` de Supabase (WebView)

La implementación actual está optimizada para móvil nativo.

## 📊 Preguntas sobre Usuarios

### ¿Dónde se guardan los usuarios?

En **dos lugares**:

1. **Supabase Auth**: Tabla `auth.users` (gestionada por Supabase)

   - Credenciales
   - Email
   - Metadata básico

2. **Tu base de datos**: Tabla `user_profiles`
   - Perfil extendido
   - Estadísticas
   - Preferencias

La app crea automáticamente el perfil en `user_profiles` después del login.

### ¿Cómo accedo al perfil del usuario en código?

```dart
// Usuario actual
final user = ref.watch(currentUserProvider);

// Perfil extendido
final profile = await ref.read(authRepositoryProvider)
    .getUserProfile(user!.id);

// Email
final email = user.email;
```

### ¿Puedo tener múltiples métodos de login?

**SÍ**, Supabase soporta múltiples providers simultáneamente:

- ✅ Email/Password (ya implementado)
- ✅ Google (implementado ahora)
- ➕ Facebook (puedes agregar)
- ➕ Apple (puedes agregar)
- ➕ GitHub (puedes agregar)

Todos se vinculan al mismo usuario si usan el mismo email.

## 🚀 Siguiente Paso

Si aún tienes dudas, consulta:

- [GOOGLE_AUTH_CHECKLIST.md](./GOOGLE_AUTH_CHECKLIST.md) - Pasos específicos
- [GOOGLE_AUTH_SUPABASE.md](./GOOGLE_AUTH_SUPABASE.md) - Guía detallada
- [GOOGLE_AUTH_FLOW_DIAGRAM.md](./GOOGLE_AUTH_FLOW_DIAGRAM.md) - Diagramas visuales

O pregúntame directamente. 😊
