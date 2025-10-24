# Dependency Updates

> Tracking package updates and compatibility.

**Last Updated**: October 23, 2025

---

## Current Dependencies

### Core Framework

```yaml
flutter: SDK >= 3.0.0 < 4.0.0
```

### State Management

```yaml
flutter_riverpod: ^3.0.0
riverpod: ^3.0.0
```

### Backend & Auth

```yaml
supabase_flutter: ^2.10.2
firebase_core: ^latest
firebase_auth: ^latest
google_sign_in: ^6.3.0
```

### UI & Navigation

```yaml
go_router: ^latest
animations: ^2.0.11
```

### Ads & Monetization

```yaml
google_mobile_ads: ^5.1.0
```

### Storage

```yaml
hive: ^latest
hive_flutter: ^latest
isar: ^latest
shared_preferences: ^latest
```

---

## Pending Updates

**As of October 2025**, the following packages have available updates:

| Package          | Current | Available | Priority |
| ---------------- | ------- | --------- | -------- |
| flutter_riverpod | 3.0.0   | 3.0.3     | Low      |
| google_sign_in   | 6.3.0   | 7.2.0     | Medium   |
| supabase_flutter | 2.10.2  | 2.10.3    | Low      |

**Recommendation**: Test updates in development before production deployment.

---

## Update Strategy

### 1. Check for Updates

```bash
flutter pub outdated
```

### 2. Update Dependencies

```bash
# Update all (use with caution)
flutter pub upgrade

# Update specific package
flutter pub upgrade package_name
```

### 3. Test After Updates

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Run tests
flutter test

# Build and test
flutter run
```

---

## Breaking Changes History

### Google Sign-In 7.x (Not Yet Adopted)

- **Change**: Updated API surface
- **Impact**: Requires code changes in auth flow
- **Action**: Review before upgrading

### Supabase Flutter 2.x

- **Change**: New auth flow type (PKCE)
- **Status**: ✅ Already implemented
- **Code**:

```dart
authOptions: FlutterAuthClientOptions(
  authFlowType: AuthFlowType.pkce,
)
```

---

## Compatibility Notes

### Flutter SDK Compatibility

- **Minimum**: Flutter 3.0.0
- **Recommended**: Latest stable
- **Tested**: Flutter 3.16.x

### Platform Requirements

- **Android**: SDK 21+ (Android 5.0+)
- **iOS**: 12.0+
- **Web**: Modern browsers (Chrome, Firefox, Safari, Edge)
- **Desktop**: Windows 10+, macOS 10.14+, Ubuntu 20.04+

---

## Dependency Audit

Run security audit regularly:

```bash
flutter pub audit
```

**Last Audit**: October 2025  
**Result**: No critical vulnerabilities

---

## Resources

- [Flutter Pub](https://pub.dev/)
- [Flutter Upgrade Guide](https://docs.flutter.dev/release/upgrade)
- [Breaking Changes](https://docs.flutter.dev/release/breaking-changes)

---

**Maintainer**: @tiagofur  
**Project**: peliculas-admob
