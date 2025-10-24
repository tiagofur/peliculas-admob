# Resumen de Configuración - Autenticación de Google para Android con SUPABASE

> **🎯 IMPORTANTE**: Esta app usa **Supabase** como backend, NO Firebase Auth standalone.
> El flujo es: Google Sign-In → Tokens → Supabase valida → Sesión creada

## 📚 Documentación Completa

| Documento                                                       | Descripción                                  |
| --------------------------------------------------------------- | -------------------------------------------- |
| 📋 [GOOGLE_AUTH_CHECKLIST.md](./GOOGLE_AUTH_CHECKLIST.md)       | **EMPIEZA AQUÍ** - Checklist paso a paso     |
| 📖 [GOOGLE_AUTH_SUPABASE.md](./GOOGLE_AUTH_SUPABASE.md)         | Guía detallada de configuración con Supabase |
| 🔄 [GOOGLE_AUTH_FLOW_DIAGRAM.md](./GOOGLE_AUTH_FLOW_DIAGRAM.md) | Diagrama visual del flujo completo           |
| 🔧 [GOOGLE_AUTH_SETUP.md](./GOOGLE_AUTH_SETUP.md)               | Info sobre huellas SHA                       |

## ✅ Completado en el Código

### 1. Dependencias instaladas

- ✅ `google_sign_in: ^6.2.2` agregado a `pubspec.yaml`
- ✅ `flutter pub get` ejecutado exitosamente

### 2. Implementación del código

- ✅ Interfaz `signInWithGoogle()` agregada en `AuthRepository`
- ✅ Implementación completa en `AuthRepositoryImpl` con:
  - Flujo de autenticación de Google nativo
  - Integración con Supabase usando `signInWithIdToken()`
  - Manejo de errores
  - Persistencia de sesión
  - Creación automática de perfil de usuario
- ✅ Método `signInWithGoogle()` agregado en `AuthNotifier` (provider)
- ✅ Widget `GoogleSignInButton` creado para reutilización
- ✅ Botón agregado en `LoginScreen`
- ✅ Botón agregado en `RegisterScreen`
- ✅ Análisis estático sin errores (`flutter analyze`)

## 📋 Pasos Pendientes (Manual) - CONFIGURACIÓN DE 3 SERVICIOS

### Paso 1: Google Cloud Console - Configurar OAuth

**IMPORTANTE**: Necesitas configurar Google Cloud, no solo Firebase

1. **Agrega las huellas SHA**

   - Ve a: https://console.firebase.google.com/ (o Google Cloud Console)
   - Configuración del proyecto → Tu app Android
   - Agrega las huellas SHA (están en `GOOGLE_AUTH_SETUP.md`)

   **Para desarrollo (Debug keystore):**

   ```
   SHA-1: 2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10
   SHA-256: E3:B9:E7:2C:78:ED:8A:F7:FD:8C:59:98:C4:35:85:14:3E:6F:44:1E:E4:34:8E:22:2E:6A:0C:1F:7F:0C:56:4B
   ```

   **Para producción (Release keystore - peliculas_new.jks):**

   ```
   SHA-1: DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B
   SHA-256: CC:BB:5D:3C:6E:54:69:8A:1F:80:B3:BA:D5:7A:0D:F4:C8:AD:42:AA:F9:B2:57:E1:EC:FD:6F:11:17:BD:17:5F
   ```

2. **Habilita Google Sign-In**

   - Ve a **Authentication** → **Sign-in method**
   - Habilita el proveedor **Google**
   - Configura el email de soporte del proyecto
   - Guarda los cambios

3. **Descarga google-services.json actualizado**
   - Vuelve a **Configuración del proyecto**
   - En tu app Android, haz clic en **Descargar google-services.json**
   - **IMPORTANTE**: Reemplaza el archivo existente en:
     ```
     android/app/google-services.json
     ```

### Paso 2: Configurar Supabase (Si aplica)

Si estás usando Supabase para autenticación:

1. Ve a tu proyecto en Supabase Dashboard
2. Ve a **Authentication** → **Providers**
3. Habilita el proveedor de **Google**
4. Agrega el **Google Client ID** que Firebase generó automáticamente
   - Puedes encontrarlo en Firebase Console → Configuración del proyecto → Credenciales OAuth

### Paso 3: Verificar la Configuración

Después de completar los pasos anteriores:

```powershell
# Limpia el proyecto
flutter clean

# Reinstala dependencias
flutter pub get

# Prueba en modo debug
flutter run

# O construye el APK
flutter build apk --debug
```

## 🧪 Cómo Probar

### En LoginScreen o RegisterScreen:

1. Abre la aplicación
2. Ve a la pantalla de Login o Registro
3. Verás un botón **"Continuar con Google"** debajo del divisor
4. Presiona el botón
5. Debería abrir el selector de cuenta de Google
6. Selecciona una cuenta
7. La app debería autenticarte y redirigirte al Home

### Flujo esperado:

1. **Usuario selecciona Google Sign-In**

   - Se abre el selector de cuenta de Google nativo

2. **Usuario selecciona una cuenta**

   - Se obtienen los tokens de Google (idToken, accessToken)

3. **Autenticación con Supabase**

   - Los tokens se envían a Supabase
   - Supabase valida con Google
   - Se crea/recupera el usuario en Supabase

4. **Sincronización de datos**

   - Se crea automáticamente el perfil de usuario
   - Se ejecuta el PostLoginService
   - Se sincronizan datos locales si existen

5. **Navegación al Home**
   - El usuario es redirigido a la pantalla principal

## 🔧 Troubleshooting

### Error: "12500 - Developer Error"

**Causa**: Las huellas SHA no están configuradas en Firebase

**Solución**:

1. Verifica que agregaste **ambas** huellas SHA (debug y release)
2. Verifica que descargaste el `google-services.json` **después** de agregar las huellas
3. Reemplaza el archivo en `android/app/google-services.json`
4. Ejecuta `flutter clean` y reconstruye

### Error: "10 - Developer Error"

**Causa**: El package name no coincide o el archivo google-services.json es incorrecto

**Solución**:

1. Verifica que el package name en Firebase sea: `mx.creapolis.peliculas`
2. Verifica que el package name en `android/app/build.gradle` sea el mismo
3. Descarga nuevamente el `google-services.json` desde Firebase

### Error: "Sign in failed" o "Network error"

**Causa**: Google Sign-In no está habilitado en Firebase Authentication

**Solución**:

1. Ve a Firebase Console → Authentication → Sign-in method
2. Asegúrate de que Google esté **habilitado**
3. Verifica que tengas una cuenta de email configurada

### El botón no hace nada

**Causa**: Falta configuración o error en el flujo

**Solución**:

1. Revisa los logs de la app con `flutter run -v`
2. Busca mensajes que empiecen con 🔑, ✅ o ❌
3. Verifica que Supabase esté configurado correctamente

### Error: "Autenticación de Google cancelada"

**Causa**: El usuario canceló el flujo de Google

**Solución**: Esto es normal, el usuario puede cancelar en cualquier momento

## 📝 Archivos Modificados

### Código

- ✅ `pubspec.yaml` - Dependencia agregada
- ✅ `lib/domain/repositories/auth_repository.dart` - Interfaz actualizada
- ✅ `lib/infrastructure/repositories/auth_repository_impl.dart` - Implementación completa
- ✅ `lib/presentation/providers/auth_provider.dart` - Provider actualizado
- ✅ `lib/presentation/widgets/auth/google_sign_in_button.dart` - Widget nuevo
- ✅ `lib/presentation/screens/auth/login_screen.dart` - UI actualizada
- ✅ `lib/presentation/screens/auth/register_screen.dart` - UI actualizada

### Documentación

- ✅ `docs/GOOGLE_AUTH_SETUP.md` - Guía detallada con las huellas SHA
- ✅ `docs/GOOGLE_AUTH_SUMMARY.md` - Este archivo
- ✅ `assets/images/README_GOOGLE_LOGO.md` - Instrucciones para el logo

## 🎯 Próximos Pasos Recomendados

1. **Completa la configuración de Firebase** (pasos manuales arriba)
2. **Prueba el flujo en modo debug** con tu cuenta de Google
3. **Verifica que funcione en modo release** antes de publicar
4. **Agrega el logo oficial de Google** (opcional, mejora la UX)
5. **Prueba el flujo completo**:
   - Login con Google
   - Sincronización de datos
   - Logout
   - Re-login

## 📱 Notas Importantes

- **Dos keystores**: Necesitas configurar **ambos** keystores (debug y release) para que funcione en desarrollo y producción
- **google-services.json**: Debes descargar el archivo **después** de agregar las huellas SHA
- **Supabase**: Si usas Supabase, también necesitas configurar el Client ID de Google allí
- **Testing**: Prueba siempre en un dispositivo real o emulador con Google Play Services

## ✨ Características Implementadas

- ✅ Autenticación con Google usando `google_sign_in`
- ✅ Integración con Supabase
- ✅ Manejo de errores robusto
- ✅ Persistencia de sesión
- ✅ Creación automática de perfil de usuario
- ✅ Sincronización post-login automática
- ✅ UI consistente con el diseño de la app
- ✅ Soporte para logout de Google
- ✅ Logging detallado para debugging

## 🔗 Referencias

- [Documentación oficial de google_sign_in](https://pub.dev/packages/google_sign_in)
- [Firebase Authentication - Google](https://firebase.google.com/docs/auth/android/google-signin)
- [Supabase - Auth with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Google Brand Guidelines](https://developers.google.com/identity/branding-guidelines)
