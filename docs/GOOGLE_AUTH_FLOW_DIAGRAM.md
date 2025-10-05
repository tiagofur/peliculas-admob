# Flujo de Autenticación Google + Supabase

## 🔄 Diagrama del flujo completo

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONFIGURACIÓN REQUERIDA                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐      ┌──────────────────┐      ┌───────────┐ │
│  │ Google Cloud    │      │ Supabase         │      │ Android   │ │
│  │ Console         │      │ Dashboard        │      │ App       │ │
│  ├─────────────────┤      ├──────────────────┤      ├───────────┤ │
│  │ • SHA-1 Debug   │─────>│ • Google enabled │<─────│ google-   │ │
│  │ • SHA-1 Release │      │ • Client ID Web  │      │ services. │ │
│  │ • Client ID Web │─────>│ • Client Secret  │      │ json      │ │
│  │ • Client Secret │      │ • Redirect URL   │      │           │ │
│  │ • Redirect URL  │<─────│                  │      │           │ │
│  └─────────────────┘      └──────────────────┘      └───────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    FLUJO DE AUTENTICACIÓN                           │
└─────────────────────────────────────────────────────────────────────┘

1️⃣  Usuario presiona "Continuar con Google"
    │
    ▼
    ┌──────────────────────────────────┐
    │  GoogleSignInButton              │
    │  (UI Widget)                     │
    └──────────────────────────────────┘
    │
    ▼
2️⃣  AuthNotifier.signInWithGoogle()
    │
    ▼
    ┌──────────────────────────────────┐
    │  AuthRepository.signInWithGoogle │
    └──────────────────────────────────┘
    │
    ▼
3️⃣  Google Sign-In SDK (google_sign_in package)
    │
    ├─> Se abre selector de cuentas nativo de Google
    │
    ├─> Usuario selecciona una cuenta
    │
    ├─> Google valida credenciales
    │
    └─> Retorna tokens:
        • idToken (JWT firmado por Google)
        • accessToken
    │
    ▼
4️⃣  Se envían tokens a Supabase
    │
    ▼
    ┌──────────────────────────────────┐
    │  supabase.auth.signInWithIdToken │
    │  (provider: OAuthProvider.google)│
    └──────────────────────────────────┘
    │
    ├─> Supabase recibe idToken
    │
    ├─> Supabase valida con Google OAuth
    │   (usando Client ID Web configurado)
    │
    ├─> Supabase verifica firma del JWT
    │
    └─> Supabase crea/recupera usuario en su BD
    │
    ▼
5️⃣  Supabase retorna respuesta
    │
    ├─> Session (access_token, refresh_token)
    │
    └─> User (id, email, metadata)
    │
    ▼
6️⃣  App procesa respuesta
    │
    ├─> Persiste sesión localmente (SharedPreferences)
    │
    ├─> Crea perfil de usuario (user_profiles table)
    │
    ├─> Ejecuta PostLoginService (sincronización)
    │
    └─> Actualiza AuthStateProvider
    │
    ▼
7️⃣  Usuario redirigido al Home
    │
    └─> ✅ Login completo

┌─────────────────────────────────────────────────────────────────────┐
│                    TOKENS Y SEGURIDAD                               │
└─────────────────────────────────────────────────────────────────────┘

Google idToken (JWT):
┌────────────────────────────────────────┐
│ {                                      │
│   "iss": "https://accounts.google.com"│
│   "sub": "USER_GOOGLE_ID",            │
│   "email": "user@gmail.com",          │
│   "email_verified": true,             │
│   "exp": 1633028400                   │
│ }                                      │
│ + Firma digital de Google             │
└────────────────────────────────────────┘
        │
        ▼ (Enviado a Supabase)
        │
Supabase valida:
✅ Firma válida (usando Google public keys)
✅ Token no expirado
✅ Issuer correcto
✅ Audience (Client ID) correcto
        │
        ▼
Supabase genera su propio token:
┌────────────────────────────────────────┐
│ Supabase Access Token (JWT)           │
│ {                                      │
│   "sub": "SUPABASE_USER_ID",          │
│   "email": "user@gmail.com",          │
│   "role": "authenticated",            │
│   "exp": 1633114800                   │
│ }                                      │
│ + Firma de Supabase                   │
└────────────────────────────────────────┘
        │
        ▼
App usa este token para:
• Consultas a la API de Supabase
• Acceso a la base de datos (RLS)
• Storage
• Realtime subscriptions

┌─────────────────────────────────────────────────────────────────────┐
│                    ARCHIVOS CLAVE                                   │
└─────────────────────────────────────────────────────────────────────┘

lib/presentation/widgets/auth/google_sign_in_button.dart
    │
    └─> Widget del botón (UI)

lib/presentation/providers/auth_provider.dart
    │
    └─> AuthNotifier.signInWithGoogle()

lib/infrastructure/repositories/auth_repository_impl.dart
    │
    ├─> _googleSignIn.signIn() → Obtiene tokens de Google
    │
    └─> _supabase.auth.signInWithIdToken() → Valida con Supabase

android/app/google-services.json
    │
    └─> Configuración de Google (Client IDs, API keys)

┌─────────────────────────────────────────────────────────────────────┐
│                    TROUBLESHOOTING                                  │
└─────────────────────────────────────────────────────────────────────┘

Error: "12500 - Developer Error"
├─> Causa: SHA no configurado en Google Cloud
└─> Solución: Agregar huellas SHA en Firebase/Google Cloud Console

Error: "Invalid idToken"
├─> Causa: Supabase no puede validar el token
└─> Solución: Verificar Client ID Web en Supabase Dashboard

Error: "Provider not enabled"
├─> Causa: Google provider deshabilitado en Supabase
└─> Solución: Habilitar en Supabase Dashboard → Authentication → Providers

Error: "Redirect URI mismatch"
├─> Causa: URL de callback no configurada
└─> Solución: Agregar callback URL en Google Cloud Console

┌─────────────────────────────────────────────────────────────────────┐
│                    VENTAJAS DEL FLUJO                               │
└─────────────────────────────────────────────────────────────────────┘

✅ Seguridad:
   • Tokens validados por Supabase
   • PKCE flow
   • Token refresh automático
   • Sesión persistente y cifrada

✅ Experiencia de usuario:
   • Selector nativo de Android
   • Sin WebView (más rápido)
   • Persistencia de sesión
   • Auto-login en siguientes aperturas

✅ Backend:
   • PostgreSQL (más potente que Firestore)
   • Row Level Security (RLS)
   • APIs RESTful automáticas
   • Realtime subscriptions
   • Storage integrado

✅ Mantenimiento:
   • Un solo backend (Supabase)
   • Migrations automáticas
   • Edge Functions
   • Monitoreo integrado
```
