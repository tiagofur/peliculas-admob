# Deep Linking and Movie Sharing Implementation

This document explains how the movie sharing functionality with deep links and web fallback works in the Películas app.

## Overview

The implementation provides seamless movie sharing with automatic app opening when the app is installed, and graceful fallback to the web version when the app is not installed.

## Architecture

### 1. Deep Link Handler (`lib/config/deep_links/deep_link_handler.dart`)

Main class responsible for:
- Generating app scheme URLs (`peliculas://`)
- Handling web deep link detection and routing
- Providing analytics tracking for deep link events
- Supporting movie, list, and recommendation deep links

#### Key Methods:
- `initialize(GoRouter router)` - Initializes deep link handling for web
- `generateMovieDeepLink(String movieId)` - Creates app scheme URLs
- `parseAndHandleUrl(String url, GoRouter router)` - Processes incoming URLs

### 2. Enhanced ShareService (`lib/services/share_service.dart`)

Extended with new methods:
- `generateMovieAppDeepLink(int movieId)` - App scheme URLs
- `generateListAppDeepLink(String listId)` - List app URLs
- `generateRecommendationAppDeepLink(String type, String id)` - Recommendation URLs

### 3. Web Implementation

#### Enhanced `web/index.html`:
- Dynamic meta tags for better social sharing
- JavaScript deep link detection script
- Automatic redirection from share URLs to main app
- App installation detection

#### Updated `web/manifest.json`:
- PWA support with proper app metadata
- Protocol handlers for deep linking
- Share target configuration

### 4. Platform Configuration

#### Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<!-- Deep Link Intent Filters -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="peliculas" />
</intent-filter>

<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https"
          android:host="peliculas.creapolis.dev" />
</intent-filter>
```

#### iOS (`ios/Runner/Info.plist`):
```xml
<!-- Deep Link URL Schemes -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>mx.creapolis.peliculas.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>peliculas</string>
        </array>
    </dict>
</array>

<!-- Associated Domains for Universal Links -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:peliculas.creapolis.dev</string>
</array>
```

## URL Schemes

### App Scheme URLs (Deep Links)
- Movies: `peliculas://movie/{movieId}`
- Lists: `peliculas://list/{listId}`
- Recommendations: `peliculas://recommendations/{type}/{id}`

### Web URLs
- Movies: `https://peliculas.creapolis.dev/movie/{movieId}`
- Lists: `https://peliculas.creapolis.dev/list/{listId}`
- Recommendations: `https://peliculas.creapolis.dev/recommendations/{type}/{id}`

### Share URLs (Web Fallback)
- Movies: `https://peliculas.creapolis.dev/movie/{movieId}/share`
- Lists: `https://peliculas.creapolis.dev/list/{listId}/share`
- Recommendations: `https://peliculas.creapolis.dev/recommendations/{type}/{id}/share`

## User Flow

### 1. Movie Sharing from App
1. User taps share button in MovieScreen
2. `ShareService.shareMovie()` is called
3. Native share dialog opens with share URL
4. User selects sharing method (WhatsApp, Twitter, etc.)

### 2. Opening Shared Link (App Installed)
1. User clicks shared link
2. If on mobile with app installed:
   - Android: Intent filter catches URL, opens app
   - iOS: URL scheme or Universal Link opens app
3. App navigates to appropriate screen

### 3. Opening Shared Link (App Not Installed)
1. User clicks shared link
2. Web browser opens share URL
3. JavaScript detects it's a share URL
4. Attempts to open app with deep link
5. If app doesn't open after 2 seconds, redirects to main app route
6. User sees web version with movie information

### 4. Web Fallback Features
- Dynamic meta tags for rich previews
- "Open in App" button (with app store fallback)
- Responsive design for mobile and desktop
- SEO-optimized content

## Testing

### Unit Tests (`test/deep_link_test.dart`)
- URL generation validation
- Deep link format verification
- URL parsing and extraction
- Share URL detection

### Integration Tests (`integration_test/sharing_integration_test.dart`)
- End-to-end sharing workflow
- URL consistency validation
- Navigation testing

## Analytics

Deep link events are automatically tracked:
- `movie_share_redirect` - When redirecting from share URL to movie
- `list_share_redirect` - When redirecting from share URL to list
- `recommendation_share_redirect` - When redirecting from share URL to recommendation
- `movie_direct_link` - Direct movie deep link access
- `list_direct_link` - Direct list deep link access
- `recommendation_direct_link` - Direct recommendation deep link access

## Usage Examples

```dart
// Generate share URLs
final movieShareUrl = ShareService.generateMovieShareUrl(12345);
final movieAppUrl = ShareService.generateMovieAppDeepLink(12345);

// Check URL validity
if (ShareService.isValidShareableUrl(url)) {
  final movieId = ShareService.extractMovieIdFromUrl(url);
}

// Deep link validation
if (DeepLinkHandler.isValidDeepLink(url)) {
  // Handle deep link
}
```

## Future Enhancements

1. **QR Code Generation**: Generate QR codes for easy sharing
2. **Custom Share Messages**: Allow users to customize share text
3. **Share Analytics**: Track sharing performance and popular content
4. **Dynamic Links**: Implement Firebase Dynamic Links for better attribution
5. **Web App Install Prompts**: Encourage PWA installation on web