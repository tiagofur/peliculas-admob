# Google Authentication Setup

> Complete guide for setting up Google Sign-In with Firebase and Supabase.

**Last Updated**: October 23, 2025  
**Platforms**: Android, iOS, Web  
**Status**: ✅ Production Ready

---

## Quick Start

### Prerequisites

- Firebase project created
- Supabase project (optional, if using Supabase Auth)
- Keystores generated (debug and release)

### Essential SHA Fingerprints

#### Release Keystore (peliculas_new.jks)

- **SHA-1**: `DF:D4:2D:FF:3F:6D:39:4B:71:34:13:8B:06:69:71:76:DD:5C:D2:8B`
- **SHA-256**: `CC:BB:5D:3C:6E:54:69:8A:1F:80:B3:BA:D5:7A:0D:F4:C8:AD:42:AA:F9:B2:57:E1:EC:FD:6F:11:17:BD:17:5F`

#### Debug Keystore (development)

- **SHA-1**: `2C:9F:A2:63:9F:19:AB:62:99:C2:E0:CE:52:B8:2E:8F:6A:8B:9C:10`
- **SHA-256**: `E3:B9:E7:2C:78:ED:8A:F7:FD:8C:59:98:C4:35:85:14:3E:6F:44:1E:E4:34:8E:22:2E:6A:0C:1F:7F:0C:56:4B`

---

## Firebase Configuration

### 1. Add SHA Fingerprints

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Project Settings** (gear icon)
4. Under "Your apps", find `mx.creapolis.peliculas`
5. Click **"Add fingerprint"**
6. Add both debug and release SHA-1 and SHA-256 fingerprints

### 2. Enable Google Sign-In

1. Go to **Authentication** → **Sign-in method**
2. Enable **Google** provider
3. Set project support email
4. Save changes

### 3. Download Updated Config

1. Return to **Project Settings**
2. Download `google-services.json`
3. Replace file at: `android/app/google-services.json`

---

## Supabase Integration (Optional)

If using Supabase Auth with Google Sign-In:

### 1. Get OAuth Client ID from Firebase

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Navigate to **APIs & Services** → **Credentials**
4. Copy the **Web Client ID** (ends with `.apps.googleusercontent.com`)

### 2. Configure in Supabase

1. Go to [Supabase Dashboard](https://app.supabase.com/)
2. Select your project
3. Navigate to **Authentication** → **Providers**
4. Enable **Google**
5. Paste the Client ID from Firebase
6. Add authorized redirect URIs

### 3. Flow Comparison

**Firebase Direct**:

```dart
final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
final credential = GoogleAuthProvider.credential(
  accessToken: googleAuth.accessToken,
  idToken: googleAuth.idToken,
);
await FirebaseAuth.instance.signInWithCredential(credential);
```

**Supabase with Google**:

```dart
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'your-app-scheme://login-callback',
);
```

---

## Platform-Specific Setup

### Android

**File**: `android/app/build.gradle`

```gradle
dependencies {
    implementation 'com.google.android.gms:play-services-auth:20.7.0'
}
```

**File**: `android/app/google-services.json`

- Must be present and updated with SHA fingerprints

### iOS

**File**: `ios/Runner/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_CLIENT_ID` with your reversed client ID from `GoogleService-Info.plist`.

### Web

**File**: `web/index.html`

```html
<meta
  name="google-signin-client_id"
  content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
/>
```

---

## Common Issues & Solutions

### Error: 12500 (Developer Error)

**Cause**: SHA fingerprints not configured or `google-services.json` outdated

**Solution**:

1. Verify SHA fingerprints in Firebase Console
2. Download latest `google-services.json`
3. Clean and rebuild: `flutter clean && flutter build apk`

### Error: 10 (Developer Error)

**Cause**: Package name mismatch

**Solution**:

1. Verify package name in Firebase matches `mx.creapolis.peliculas`
2. Check `google-services.json` is in correct location
3. Ensure `applicationId` in `build.gradle` matches

### Error: Sign in failed (no specific code)

**Possible causes**:

- Google Sign-In not enabled in Firebase Authentication
- Network connectivity issues
- Incorrect OAuth configuration in Supabase (if used)

**Solution**:

1. Enable Google provider in Firebase Authentication
2. Check internet connection
3. Verify Supabase OAuth settings (if applicable)

### Web: 403 Redirect URI Mismatch

**Cause**: Redirect URI not authorized

**Solution**:

1. Go to Google Cloud Console → Credentials
2. Add your web app URL to authorized redirect URIs
3. Add both `http://localhost:port` (dev) and production URL

---

## Testing Checklist

- [ ] Debug build signs in successfully
- [ ] Release build signs in successfully
- [ ] iOS signs in successfully (if applicable)
- [ ] Web signs in successfully (if applicable)
- [ ] User data syncs to Supabase (if using Supabase)
- [ ] Sign out works correctly
- [ ] Re-authentication works after app restart

---

## Storage Configuration (Supabase)

When using Supabase, ensure proper storage handling for Google Auth:

**Issue**: Web platform uses localStorage, which can cause issues

**Solution**: Use proper storage adapter

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

await Supabase.initialize(
  url: supabaseUrl,
  anonKey: supabaseKey,
  authOptions: FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
    // Uses secure storage on mobile, localStorage on web
  ),
);
```

---

## Resources

- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Google Sign-In Flutter Package](https://pub.dev/packages/google_sign_in)
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Google Cloud Console](https://console.cloud.google.com/)

---

**Maintainer**: @tiagofur  
**Project**: peliculas-admob  
**Status**: Production-ready authentication system
