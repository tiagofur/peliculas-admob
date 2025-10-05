# 🚀 Inicio Rápido - Google Auth + Supabase

> **Esta app usa SUPABASE como backend**. Sigue estos documentos en orden:

## 📋 Paso 1: Checklist de Configuración

**📄 [GOOGLE_AUTH_CHECKLIST.md](./GOOGLE_AUTH_CHECKLIST.md)** ← **EMPIEZA AQUÍ**

Checklist completo con todos los pasos que debes hacer:

- ✅ Configurar huellas SHA en Google Cloud
- ✅ Obtener Client ID Web y Secret
- ✅ Configurar Supabase Dashboard
- ✅ Agregar Redirect URL
- ✅ Probar la integración

## 📖 Paso 2: Guía Detallada

**📄 [GOOGLE_AUTH_SUPABASE.md](./GOOGLE_AUTH_SUPABASE.md)**

Documentación completa con:

- Explicación del flujo de autenticación
- Instrucciones detalladas para cada servicio
- Troubleshooting común
- Referencias útiles

## 🔄 Paso 3: Entender el Flujo

**📄 [GOOGLE_AUTH_FLOW_DIAGRAM.md](./GOOGLE_AUTH_FLOW_DIAGRAM.md)**

Diagramas visuales que muestran:

- Cómo interactúan los 3 servicios (Google, Supabase, App)
- Flujo de tokens y validación
- Archivos clave involucrados
- Seguridad del proceso

## 🔧 Referencia: Huellas SHA

**📄 [GOOGLE_AUTH_SETUP.md](./GOOGLE_AUTH_SETUP.md)**

Información técnica sobre las huellas SHA extraídas de tus keystores.

---

## ⚡ Resumen Ultra-Rápido

### ✅ Ya está hecho (código)

- ✅ Dependencia `google_sign_in` instalada
- ✅ Botón "Continuar con Google" en Login y Registro
- ✅ Integración completa con Supabase
- ✅ Manejo de errores y persistencia de sesión

### 🔧 Lo que DEBES hacer (configuración manual)

#### 1. Google Cloud Console

```
→ Agregar huellas SHA (debug y release)
→ Obtener Client ID Web y Client Secret
→ Descargar google-services.json
```

#### 2. Supabase Dashboard

```
→ Habilitar Google Provider
→ Configurar Client ID y Secret
→ Copiar Redirect URL
```

#### 3. Google Cloud Console (de nuevo)

```
→ Agregar Redirect URL de Supabase
```

### 🧪 Probar

```powershell
flutter clean
flutter pub get
flutter run
```

## 🎯 Flujo de Autenticación

```
Usuario presiona botón
    ↓
Google Sign-In (selector nativo)
    ↓
Obtiene tokens (idToken, accessToken)
    ↓
Envía a Supabase.signInWithIdToken()
    ↓
Supabase valida con Google OAuth
    ↓
Supabase crea sesión
    ↓
Usuario redirigido al Home
    ↓
✅ Login completo
```

## 🆘 Si algo falla

Consulta la sección **Troubleshooting** en:

- [GOOGLE_AUTH_SUPABASE.md](./GOOGLE_AUTH_SUPABASE.md#-troubleshooting)
- [GOOGLE_AUTH_FLOW_DIAGRAM.md](./GOOGLE_AUTH_FLOW_DIAGRAM.md#troubleshooting)

---

## 📞 Información Técnica

### Servicios involucrados

1. **Google Cloud/Firebase** - Provee el OAuth y valida credenciales
2. **Supabase** - Backend que valida tokens y crea sesiones
3. **Tu App Android** - Inicia el flujo y persiste la sesión

### Paquetes usados

- `google_sign_in: ^6.2.2` - Selector nativo de cuenta de Google
- `supabase_flutter: ^2.9.1` - Cliente de Supabase

### Archivos clave

- `lib/presentation/widgets/auth/google_sign_in_button.dart` - Botón UI
- `lib/infrastructure/repositories/auth_repository_impl.dart` - Lógica de auth
- `android/app/google-services.json` - Configuración de Google

### Métodos principales

```dart
// En AuthRepository
Future<User> signInWithGoogle();

// Implementación
await _googleSignIn.signIn(); // Obtiene tokens
await _supabase.auth.signInWithIdToken(); // Valida con Supabase
```

---

**🎉 Todo el código está listo. Solo falta la configuración manual en los 3 servicios.**

**Sigue el [CHECKLIST](./GOOGLE_AUTH_CHECKLIST.md) paso a paso.**
