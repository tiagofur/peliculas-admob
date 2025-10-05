# Configuración de Google Auth para Supabase (Android)

## 🎯 Arquitectura: Supabase + Google Sign-In

Tu app usa **Supabase como backend**, por lo que la configuración es diferente a usar solo Firebase. El flujo es:

```
Usuario → Google Sign-In → Obtener tokens → Supabase valida → Sesión creada
```

## ✅ Código ya implementado

La implementación actual usa `google_sign_in` + `signInWithIdToken()` de Supabase, que es la forma recomendada para apps nativas Android. Ya está todo listo en el código.

## 📋 Configuración requerida (3 servicios)

### 1️⃣ Google Cloud Console - Obtener Client ID

#### Opción A: Si ya tienes Firebase configurado

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Ve a **Configuración del proyecto** → **Configuración general**
4. En la sección "Tus aplicaciones", busca tu app Android
5. **Agrega las huellas SHA** (si no lo has hecho):

   **Debug keystore:**

   ```
   SHA-1: 2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10
   SHA-256: E3:B9:E7:2C:78:ED:8A:F7:FD:8C:59:98:C4:35:85:14:3E:6F:44:1E:E4:34:8E:22:2E:6A:0C:1F:7F:0C:56:4B
   ```

   **Release keystore:**

   ```
   SHA-1: DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B
   SHA-256: CC:BB:5D:3C:6E:54:69:8A:1F:80:B3:BA:D5:7A:0D:F4:C8:AD:42:AA:F9:B2:57:E1:EC:FD:6F:11:17:BD:17:5F
   ```

6. Descarga el archivo `google-services.json` actualizado
7. Reemplázalo en `android/app/google-services.json`

8. **Obtén tu Client ID Web:**
   - Ve a [Google Cloud Console](https://console.cloud.google.com/)
   - Selecciona tu proyecto de Firebase
   - Ve a **APIs y servicios** → **Credenciales**
   - Busca el "Client ID de OAuth 2.0" de tipo **"Web application"**
   - Copia el **Client ID** (termina en `.apps.googleusercontent.com`)
   - **IMPORTANTE**: Si no existe, créalo:
     - Haz clic en **"Crear credenciales"** → **"ID de cliente de OAuth 2.0"**
     - Tipo: **Aplicación web**
     - Nombre: "Web client (auto created by Google Service)"
     - **NO necesitas agregar URIs de redirección aún**
     - Copia el Client ID generado

#### Opción B: Si NO usas Firebase

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un proyecto o selecciona uno existente
3. Ve a **APIs y servicios** → **Credenciales**
4. Crea un **Client ID de OAuth 2.0** para:
   - **Android**: Usa el package name `mx.creapolis.peliculas` y las huellas SHA de arriba
   - **Web**: Sin URIs de redirección (lo necesitas para Supabase)
5. Copia ambos Client IDs

### 2️⃣ Supabase Dashboard - Configurar Google Provider

Ahora configuramos Supabase para que acepte tokens de Google:

1. Ve a [Supabase Dashboard](https://supabase.com/dashboard)
2. Selecciona tu proyecto
3. Ve a **Authentication** → **Providers**
4. Busca **Google** en la lista de providers
5. Habilita el toggle de **Google**
6. Completa los campos:

   **Client ID (for OAuth):**

   ```
   TU_CLIENT_ID_WEB.apps.googleusercontent.com
   ```

   > ⚠️ **IMPORTANTE**: Usa el Client ID **Web**, NO el de Android

   **Client Secret (for OAuth):**

   ```
   TU_CLIENT_SECRET
   ```

   > Lo encuentras en Google Cloud Console → Credenciales → Client ID Web → Detalles

   **Authorized Client IDs (opcional pero recomendado):**

   ```
   TU_CLIENT_ID_WEB.apps.googleusercontent.com
   TU_CLIENT_ID_ANDROID.apps.googleusercontent.com
   TU_CLIENT_ID_IOS.apps.googleusercontent.com
   ```

   > Agrega todos los Client IDs de tus plataformas (Android, iOS, Web)

7. **Configura la Redirect URL** (opcional para web):

   ```
   https://TU_PROYECTO.supabase.co/auth/v1/callback
   ```

8. Haz clic en **Save**

### 3️⃣ Google Cloud Console - Agregar Redirect URL de Supabase

Vuelve a Google Cloud Console:

1. Ve a **APIs y servicios** → **Credenciales**
2. Haz clic en tu **Client ID Web**
3. En **"URIs de redirección autorizados"**, agrega:
   ```
   https://TU_PROYECTO.supabase.co/auth/v1/callback
   ```
4. Guarda los cambios

## 🧪 Verificar la configuración

### Archivo de configuración Android

El archivo `android/app/google-services.json` debe tener tu configuración de Firebase/Google Cloud.

### Test de autenticación

```dart
// El código ya está implementado en tu app
// Solo prueba presionando el botón "Continuar con Google"
```

## 🔄 Flujo completo implementado

```
1. Usuario presiona "Continuar con Google"
   ↓
2. Se abre el selector de cuenta de Google (google_sign_in)
   ↓
3. Usuario selecciona una cuenta
   ↓
4. Se obtienen tokens (idToken, accessToken)
   ↓
5. Se envían a Supabase con signInWithIdToken()
   ↓
6. Supabase valida los tokens con Google
   ↓
7. Supabase crea/recupera el usuario
   ↓
8. Se crea la sesión en Supabase
   ↓
9. Se persiste la sesión localmente
   ↓
10. Se crea el perfil de usuario automáticamente
    ↓
11. Usuario redirigido al Home
```

## 🎨 Configuración del botón (Opcional)

### Branding de Google

Si quieres usar el logo oficial de Google:

1. Descarga de [Google Brand Resources](https://developers.google.com/identity/branding-guidelines)
2. Guarda como `assets/images/google_logo.png`
3. El botón lo usará automáticamente

Si no lo descargas, el botón usa un fallback con la letra "G" (ya implementado).

## 🐛 Troubleshooting

### Error: "Invalid idToken"

**Causa**: Supabase no puede validar el token de Google

**Solución**:

1. Verifica que el **Client ID Web** esté correcto en Supabase
2. Verifica que las huellas SHA estén en Google Cloud/Firebase
3. Asegúrate de que el `google-services.json` esté actualizado

### Error: "12500 - Developer Error"

**Causa**: Google Sign-In no está configurado correctamente

**Solución**:

1. Verifica que las huellas SHA estén en Firebase/Google Cloud
2. Descarga el `google-services.json` actualizado
3. Ejecuta `flutter clean && flutter pub get`

### Error: "Provider not enabled"

**Causa**: Google provider no está habilitado en Supabase

**Solución**:

1. Ve a Supabase Dashboard → Authentication → Providers
2. Habilita Google
3. Configura el Client ID y Client Secret

### Error: "Redirect URI mismatch"

**Causa**: La URL de redirección no coincide

**Solución**:

1. Agrega la URL de callback de Supabase en Google Cloud Console
2. Formato: `https://TU_PROYECTO.supabase.co/auth/v1/callback`

### El selector de cuenta no aparece

**Causa**: Caché de Google Sign-In

**Solución**:

```dart
// Desloguea primero
await _googleSignIn.signOut();
// Luego vuelve a intentar
await _googleSignIn.signIn();
```

## 📊 Diferencias vs Firebase Auth standalone

| Aspecto             | Firebase Auth            | Supabase + Google                  |
| ------------------- | ------------------------ | ---------------------------------- |
| Backend             | Firebase                 | Supabase                           |
| OAuth Provider      | Firebase                 | Google (validado por Supabase)     |
| Base de datos       | Firestore                | PostgreSQL                         |
| Client ID requerido | Solo Android             | Web (para Supabase) + Android      |
| Configuración       | Firebase Console         | Firebase + Supabase + Google Cloud |
| Implementación      | `signInWithCredential()` | `signInWithIdToken()`              |

## ✨ Ventajas de usar Supabase

- ✅ Base de datos PostgreSQL (más potente)
- ✅ Row Level Security (RLS)
- ✅ Realtime subscriptions
- ✅ Storage integrado
- ✅ Edge Functions
- ✅ APIs RESTful automáticas

## 🔐 Seguridad

El flujo implementado usa:

- ✅ PKCE flow para auth
- ✅ Token refresh automático
- ✅ Persistencia segura de sesión
- ✅ Validación de tokens en Supabase
- ✅ Logout completo (Google + Supabase)

## 📝 Siguiente paso

Después de completar la configuración:

```powershell
# Limpia el proyecto
flutter clean

# Reinstala dependencias
flutter pub get

# Ejecuta la app
flutter run
```

Luego prueba el botón "Continuar con Google" en la pantalla de Login o Registro.

## 🔗 Referencias útiles

- [Supabase - Google OAuth](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Google Sign-In Flutter](https://pub.dev/packages/google_sign_in)
- [Supabase Flutter](https://supabase.com/docs/reference/dart/introduction)
- [Google Cloud Console](https://console.cloud.google.com/)
