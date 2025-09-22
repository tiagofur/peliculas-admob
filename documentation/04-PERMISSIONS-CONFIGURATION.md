# 📱 System Permissions Configuration

## Status: NOT CONFIGURED ❌

## Required Permissions by Platform

### Android

**File**: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Network -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <!-- Storage (for caching) -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                     android:maxSdkVersion="28" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

    <!-- Camera/Gallery (for profile pictures) -->
    <uses-permission android:name="android.permission.CAMERA" />

    <!-- Notifications -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <!-- AdMob -->
    <uses-permission android:name="com.google.android.gms.permission.AD_ID" />

    <application>
        <!-- Add Google Mobile Ads App ID -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-XXXXX~XXXXX"/>
    </application>
</manifest>
```

### iOS

**File**: `ios/Runner/Info.plist`

```xml
<dict>
    <!-- Camera -->
    <key>NSCameraUsageDescription</key>
    <string>This app needs camera access to take profile pictures</string>

    <!-- Photo Library -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>This app needs photo library access to select profile pictures</string>
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>This app needs permission to save movie posters to your photo library</string>

    <!-- Network -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>

    <!-- Notifications -->
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>remote-notification</string>
    </array>

    <!-- AdMob -->
    <key>GADApplicationIdentifier</key>
    <string>ca-app-pub-XXXXX~XXXXX</string>
    <key>SKAdNetworkItems</key>
    <array>
        <dict>
            <key>SKAdNetworkIdentifier</key>
            <string>cstr6suwn9.skadnetwork</string>
        </dict>
    </array>
</dict>
```

### macOS

**File**: `macos/Runner/Info.plist`

```xml
<dict>
    <!-- Network -->
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>

    <!-- File Access -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>

    <!-- Camera (if needed) -->
    <key>NSCameraUsageDescription</key>
    <string>This app needs camera access for profile pictures</string>

    <!-- Photo Library -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>This app needs photo library access for profile pictures</string>
</dict>
```

**File**: `macos/Runner/DebugProfile.entitlements` & `macos/Runner/Release.entitlements`

```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
</dict>
```

### Windows

**File**: `windows/runner/Runner.rc`

Windows typically doesn't require explicit permissions in manifest, but for future features:

```cpp
// For notifications (future)
// Add to Package.appxmanifest if using MSIX
<Capability Name="internetClient" />
<Capability Name="internetClientServer" />
<Capability Name="picturesLibrary" />
```

### Web

**File**: `web/index.html`

```html
<!-- Add permissions for web features -->
<script>
  // Request notification permission
  if ("Notification" in window) {
    Notification.requestPermission();
  }

  // Register service worker for PWA
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("flutter_service_worker.js");
  }
</script>
```

## Runtime Permission Requests

### Flutter Implementation

```dart
// File: lib/core/permissions/permission_handler.dart

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> requestGalleryPermission() async {
    final status = await Permission.photos.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status == PermissionStatus.granted;
  }

  static Future<void> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.photos,
      Permission.notification,
    ].request();

    // Handle denied permissions
    statuses.forEach((permission, status) {
      if (status == PermissionStatus.denied) {
        // Show explanation dialog
      } else if (status == PermissionStatus.permanentlyDenied) {
        // Direct to settings
        openAppSettings();
      }
    });
  }
}
```

## Testing Permissions

### Manual Testing Checklist

- [ ] Install fresh app on Android device
- [ ] Install fresh app on iOS device
- [ ] Install fresh app on macOS
- [ ] Test camera permission request
- [ ] Test gallery permission request
- [ ] Test notification permission request
- [ ] Test with permissions denied
- [ ] Test with permissions permanently denied

### Automated Testing

```dart
// Test file: test/permissions/permission_test.dart
void main() {
  test('Permissions are requested on first launch', () async {
    // Mock permission handler
    // Verify permission requests
  });
}
```

## Common Issues

### Android

- **Issue**: App crashes when accessing camera
- **Solution**: Add camera permission to manifest

### iOS

- **Issue**: App rejected from App Store
- **Solution**: Provide clear usage descriptions

### macOS

- **Issue**: Network requests fail
- **Solution**: Add network entitlements

## Compliance Notes

- GDPR: Must request consent for ad tracking
- COPPA: Special handling for users under 13
- App Store: Clear descriptions required
- Play Store: Declare all permissions used

---

**Status**: TO BE IMPLEMENTED
**Priority**: CRITICAL
**Target**: Beta Release
