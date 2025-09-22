# AdSense Implementation Guide

## Current Status
The app now includes placeholder AdSense widgets that show on Web only. AdMob continues to work on mobile platforms.

## AdSense Widget Implementation

### Files Created
- `lib/presentation/widgets/adsense/adsense_widget.dart` - ResponsiveAdWidget and AdSenseWidget

### Usage in Movie Screen
The movie details screen now uses `ResponsiveAdWidget` which:
- Shows AdMob ads on mobile/tablet
- Shows AdSense placeholders on Web
- Maintains monetization across all platforms

### Ad Slots Configured
1. `movie-banner-1` - Banner ad after movie rating section
2. `movie-native-1` - Native ad between stats and lists
3. `movie-native-2` - Native ad before recommendations

## To Implement Real AdSense

### 1. Add AdSense Package
```yaml
dependencies:
  # Add AdSense package when available
  google_adsense_flutter: ^x.x.x # When released
```

### 2. Configure AdSense Account
1. Create Google AdSense account
2. Add your domain to AdSense
3. Create ad units for each slot
4. Get publisher ID and ad unit IDs

### 3. Update AdSenseWidget
Replace the placeholder in `adsense_widget.dart`:

```dart
// Replace placeholder with real AdSense implementation
return GoogleAdSenseWidget(
  publisherId: 'ca-pub-XXXXXXXXXX',
  adUnitId: slot,
  width: width,
  height: height,
);
```

### 4. Environment Configuration
Add to `.env`:
```
ADSENSE_PUBLISHER_ID=ca-pub-XXXXXXXXXX
ADSENSE_MOVIE_BANNER_1=XXXXXXXXXX
ADSENSE_MOVIE_NATIVE_1=XXXXXXXXXX
ADSENSE_MOVIE_NATIVE_2=XXXXXXXXXX
```

### 5. Privacy Policy
Update privacy policy to include AdSense data collection.

### 6. Testing
- Test ad loading performance
- Verify ads don't block UI
- Test on different screen sizes
- Monitor Core Web Vitals

## Performance Considerations
- Ads load asynchronously
- Fallback to placeholder on load failure
- Lazy loading for better performance
- Cache ads when possible

## Revenue Optimization
- Monitor CTR and RPM
- A/B test ad positions
- Adjust ad density based on user engagement
- Use responsive ad sizes

## Current Placeholders
The current implementation shows styled placeholders that:
- Match the app's design system
- Show slot information for debugging
- Have consistent spacing and layout
- Don't impact performance

These will be replaced with real AdSense ads once the package is available and account is configured.