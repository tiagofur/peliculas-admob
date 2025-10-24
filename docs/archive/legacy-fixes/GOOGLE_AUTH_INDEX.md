# 📚 Documentación - Google Auth + Supabase (Android)

## 🎯 Tu app usa Supabase como backend

Esta documentación te guía para configurar Google Sign-In en tu app Android que usa Supabase.

---

## 🚀 ¿Por dónde empezar?

### 👉 **Inicio Rápido**: [GOOGLE_AUTH_README.md](./GOOGLE_AUTH_README.md)

Resumen ejecutivo con todo lo que necesitas saber.

---

## 📖 Documentación Detallada

### 1️⃣ **Checklist de Configuración** (Empieza aquí)

📄 [GOOGLE_AUTH_CHECKLIST.md](./GOOGLE_AUTH_CHECKLIST.md)

Lista de verificación paso a paso:

- [ ] Configurar huellas SHA en Google Cloud
- [ ] Obtener Client ID Web y Secret
- [ ] Configurar Supabase Dashboard
- [ ] Agregar Redirect URL
- [ ] Probar la integración

**Tiempo estimado**: 15-20 minutos

---

### 2️⃣ **Guía Completa de Configuración**

📄 [GOOGLE_AUTH_SUPABASE.md](./GOOGLE_AUTH_SUPABASE.md)

Documentación detallada que incluye:

- ✅ Código ya implementado
- 🔧 Configuración de Google Cloud Console
- 🗄️ Configuración de Supabase Dashboard
- 🔄 Flujo completo de autenticación
- 🐛 Troubleshooting común
- 🔗 Referencias útiles

**Lectura**: 10-15 minutos

---

### 3️⃣ **Diagrama Visual del Flujo**

📄 [GOOGLE_AUTH_FLOW_DIAGRAM.md](./GOOGLE_AUTH_FLOW_DIAGRAM.md)

Diagramas ASCII que muestran:

- 🔄 Flujo de autenticación completo
- 🔑 Intercambio de tokens
- 🏗️ Arquitectura de los 3 servicios
- 🔒 Proceso de validación y seguridad
- 📁 Archivos clave involucrados

**Visualización**: 5-10 minutos

---

### 4️⃣ **Preguntas Frecuentes**

📄 [GOOGLE_AUTH_FAQ.md](./GOOGLE_AUTH_FAQ.md)

Respuestas a preguntas comunes:

- 🤔 ¿Por qué 3 servicios?
- 🔑 ¿Qué Client ID uso?
- 🗄️ ¿Dónde configuro Supabase?
- 🐛 Solución a errores comunes
- 🔒 Preguntas de seguridad
- 🚀 Y mucho más...

**Consulta**: Según necesites

---

### 5️⃣ **Referencia Técnica - Huellas SHA**

📄 [GOOGLE_AUTH_SETUP.md](./GOOGLE_AUTH_SETUP.md)

Información técnica sobre:

- 🔐 Huellas SHA-1 y SHA-256 de tus keystores
- 💻 Comandos para regenerarlas
- 📋 Información de configuración

**Referencia**: Según necesites

---

## 🎨 Estructura de la Documentación

```
docs/
├── GOOGLE_AUTH_README.md          ← 🚀 EMPIEZA AQUÍ (resumen)
├── GOOGLE_AUTH_CHECKLIST.md       ← ✅ Lista de pasos
├── GOOGLE_AUTH_SUPABASE.md        ← 📖 Guía detallada
├── GOOGLE_AUTH_FLOW_DIAGRAM.md    ← 🔄 Diagramas visuales
├── GOOGLE_AUTH_FAQ.md             ← ❓ Preguntas frecuentes
├── GOOGLE_AUTH_SETUP.md           ← 🔧 Info técnica SHA
├── GOOGLE_AUTH_PLAY_STORE_SHA.md  ← 🔐 SHA de Play Store
├── GOOGLE_AUTH_FIREBASE_VS_CLOUD.md ← 🔥 Firebase vs Google Cloud
├── GOOGLE_AUTH_WEB_VS_ANDROID.md  ← 🌐 Web vs Android
├── GOOGLE_AUTH_TROUBLESHOOTING.md ← 🔧 Resolución de problemas
└── GOOGLE_AUTH_INDEX.md           ← 📚 Este archivo
```

---

## ⚡ Resumen Ultra-Rápido

### ✅ Código (ya implementado)

```
✅ Dependencia google_sign_in instalada
✅ Botón "Continuar con Google" agregado
✅ Integración con Supabase completa
✅ Manejo de errores
✅ Persistencia de sesión
```

### 🔧 Configuración (manual requerida)

```
1. Google Cloud Console
   → Agregar huellas SHA
   → Obtener Client ID Web + Secret
   → Descargar google-services.json

2. Supabase Dashboard
   → Habilitar Google Provider
   → Configurar Client ID + Secret
   → Copiar Redirect URL

3. Google Cloud Console
   → Agregar Redirect URL de Supabase
```

### 🧪 Prueba

```powershell
flutter clean
flutter pub get
flutter run
```

---

## 🎯 Flujo de Autenticación (simplificado)

```
Usuario presiona botón
    ↓
Selector de cuenta de Google (nativo)
    ↓
Obtiene tokens (idToken, accessToken)
    ↓
Envía a Supabase
    ↓
Supabase valida con Google
    ↓
Crea sesión en Supabase
    ↓
Usuario redirigido al Home
    ↓
✅ Login completo
```

---

## 🔗 Servicios Involucrados

### 1. Google Cloud / Firebase

**Rol**: Proveedor de OAuth, valida credenciales de Google

**Necesitas configurar**:

- Huellas SHA (debug y release)
- Client ID Web y Secret
- google-services.json

**URL**: https://console.firebase.google.com/

---

### 2. Supabase

**Rol**: Tu backend, valida tokens de Google y crea usuarios

**Necesitas configurar**:

- Habilitar Google Provider
- Client ID y Secret de Google
- Redirect URL

**URL**: https://supabase.com/dashboard

---

### 3. Tu App Android

**Rol**: Inicia el flujo, persiste la sesión

**Ya implementado**:

- google_sign_in package
- signInWithIdToken() de Supabase
- UI del botón
- Manejo de sesión

**Código**: `lib/infrastructure/repositories/auth_repository_impl.dart`

---

## 🐛 Troubleshooting Rápido

| Error                 | Causa                            | Solución                        |
| --------------------- | -------------------------------- | ------------------------------- |
| 12500                 | SHA no configurado               | Agregar SHA en Google Cloud     |
| Invalid idToken       | Client ID incorrecto en Supabase | Verificar Client ID Web         |
| Provider not enabled  | Google deshabilitado             | Habilitar en Supabase Dashboard |
| Redirect URI mismatch | URL no configurada               | Agregar callback URL en Google  |

**Más detalles**: Ver [FAQ](./GOOGLE_AUTH_FAQ.md) o [Guía completa](./GOOGLE_AUTH_SUPABASE.md)

---

## 📦 Paquetes Utilizados

| Paquete            | Versión | Uso                       |
| ------------------ | ------- | ------------------------- |
| `google_sign_in`   | ^6.2.2  | Selector nativo de Google |
| `supabase_flutter` | ^2.9.1  | Cliente de Supabase       |

---

## 📁 Archivos Clave en el Código

| Archivo                                                     | Descripción                              |
| ----------------------------------------------------------- | ---------------------------------------- |
| `lib/presentation/widgets/auth/google_sign_in_button.dart`  | Widget del botón UI                      |
| `lib/presentation/providers/auth_provider.dart`             | Provider con método `signInWithGoogle()` |
| `lib/infrastructure/repositories/auth_repository_impl.dart` | Lógica de autenticación                  |
| `lib/domain/repositories/auth_repository.dart`              | Interfaz del repositorio                 |
| `android/app/google-services.json`                          | Configuración de Google                  |

---

## ✨ Características Implementadas

- ✅ Autenticación con Google nativa (sin WebView)
- ✅ Integración con Supabase
- ✅ Manejo robusto de errores
- ✅ Persistencia de sesión
- ✅ Creación automática de perfil de usuario
- ✅ Sincronización post-login automática
- ✅ UI consistente con diseño de la app
- ✅ Soporte para logout de Google
- ✅ Logging detallado para debugging

---

## 🔒 Seguridad

El flujo implementado incluye:

- ✅ PKCE flow para auth
- ✅ Token refresh automático
- ✅ Validación de tokens por múltiples partes
- ✅ Tokens con expiración
- ✅ Persistencia segura de sesión
- ✅ Logout completo (Google + Supabase)
- ✅ Row Level Security en Supabase

---

## 🚀 Próximos Pasos

1. **Lee el resumen**: [GOOGLE_AUTH_README.md](./GOOGLE_AUTH_README.md)
2. **Sigue el checklist**: [GOOGLE_AUTH_CHECKLIST.md](./GOOGLE_AUTH_CHECKLIST.md)
3. **Consulta detalles**: [GOOGLE_AUTH_SUPABASE.md](./GOOGLE_AUTH_SUPABASE.md)
4. **Entiende el flujo**: [GOOGLE_AUTH_FLOW_DIAGRAM.md](./GOOGLE_AUTH_FLOW_DIAGRAM.md)
5. **Resuelve dudas**: [GOOGLE_AUTH_FAQ.md](./GOOGLE_AUTH_FAQ.md)

---

## 📞 Soporte

Si tienes problemas:

1. ✅ Revisa el [Checklist](./GOOGLE_AUTH_CHECKLIST.md)
2. 🐛 Consulta [Troubleshooting](./GOOGLE_AUTH_TROUBLESHOOTING.md)
3. 📖 Lee la [Guía completa](./GOOGLE_AUTH_SUPABASE.md)
4. ❓ Consulta las [FAQ](./GOOGLE_AUTH_FAQ.md)
5. 📊 Verifica el [Diagrama de Flujo](./GOOGLE_AUTH_FLOW_DIAGRAM.md)

---

## 🎉 Estado Actual

- ✅ **Código**: 100% implementado
- ⏳ **Configuración**: Pendiente (manual)
- 🧪 **Pruebas**: Después de configuración

**El código está listo. Solo falta la configuración manual en los 3 servicios.**

---

**Última actualización**: Octubre 4, 2025
**Versión**: 1.0.0
