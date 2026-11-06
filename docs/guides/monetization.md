# Monetization Guide

> AdMob and AdSense integration for the peliculas-admob app.

**Status**: ✅ Implemented  
**Platforms**: Android, iOS, Web  
**Last Updated**: October 23, 2025

---

## Overview

The app uses Google's advertising platforms:

- **AdMob** for mobile (Android/iOS)
- **AdSense** for web platform
- **Smart placement** to avoid disrupting UX

---

## AdMob Setup (Mobile)

### 1. Create AdMob Account

1. Go to [AdMob Console](https://apps.admob.com/)
2. Create account and add your app
3. Get your **App ID**

### 2. Configure App IDs

**Android**: `android/app/src/main/AndroidManifest.xml`

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

**iOS**: `ios/Runner/Info.plist`

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>
```

### 3. Add Dependencies

**File**: `pubspec.yaml`

```yaml
dependencies:
  google_mobile_ads: ^5.1.0
```

### 4. Initialize AdMob

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(MyApp());
}
```

---

## Ad Unit Types

### 1. Banner Ads

**Best for**: Bottom of lists, between content sections

```dart
class BannerAdWidget extends StatefulWidget {
  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ID
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          LoggerFactory.error('Banner ad failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return SizedBox(height: 50); // Placeholder
    }

    return SizedBox(
      height: _bannerAd!.size.height.toDouble(),
      width: _bannerAd!.size.width.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
```

### 2. Interstitial Ads

**Best for**: Between major navigation events

```dart
class InterstitialAdManager {
  InterstitialAd? _interstitialAd;
  int _numInterstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;

  void createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // Test ID
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          _numInterstitialLoadAttempts += 1;
          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            createInterstitialAd();
          }
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        createInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        createInterstitialAd();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}
```

### 3. Rewarded Ads

**Best for**: Unlock features, remove ads temporarily

```dart
class RewardedAdManager {
  RewardedAd? _rewardedAd;

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ID
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          LoggerFactory.error('Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    if (_rewardedAd == null) return false;

    bool userEarnedReward = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        userEarnedReward = true;
        LoggerFactory.info('User earned reward: ${reward.amount}');
      },
    );

    _rewardedAd = null;
    return userEarnedReward;
  }

  void dispose() {
    _rewardedAd?.dispose();
  }
}
```

---

## AdSense Setup (Web)

### 1. Create AdSense Account

1. Go to [Google AdSense](https://www.google.com/adsense/)
2. Sign up and get approved
3. Get your **Publisher ID** (starts with `pub-`)

### 2. Add AdSense Code

**File**: `web/index.html`

```html
<head>
  <!-- AdSense -->
  <script
    async
    src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXXXXXXXXXXXXXX"
    crossorigin="anonymous"
  ></script>
</head>
```

### 3. Create Ad Units

In AdSense dashboard:

1. Create new ad unit
2. Select "Display ads"
3. Choose responsive size
4. Copy the ad code

### 4. Insert Ad Units in Web

```html
<!-- Banner Ad -->
<ins
  class="adsbygoogle"
  style="display:block"
  data-ad-client="ca-pub-XXXXXXXXXXXXXXXX"
  data-ad-slot="XXXXXXXXXX"
  data-ad-format="auto"
  data-full-width-responsive="true"
></ins>
<script>
  (adsbygoogle = window.adsbygoogle || []).push({});
</script>
```

---

## Ad Placement Strategy

### Best Practices

1. **Don't oversaturate**: Max 3 ads per screen
2. **Natural breaks**: Place ads at natural content breaks
3. **Non-intrusive**: Avoid blocking critical UI elements
4. **Progressive**: Show more ads to engaged users

### Recommended Placements

**Home Screen**:

- Banner ad at bottom of "Now Playing" section
- Interstitial after 5 movie detail views

**Movie Details**:

- Banner ad between cast and reviews
- Native ad in "Similar Movies" section

**Lists/Favorites**:

- Banner ad every 10-15 items
- Rewarded ad to unlock "Export List" feature

### Frequency Capping

```dart
class AdFrequencyManager {
  static const int detailViewsBeforeInterstitial = 5;
  static const Duration interstitialCooldown = Duration(minutes: 3);

  int _detailViews = 0;
  DateTime? _lastInterstitialShown;

  bool shouldShowInterstitial() {
    _detailViews++;

    if (_detailViews < detailViewsBeforeInterstitial) {
      return false;
    }

    if (_lastInterstitialShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastInterstitialShown!);
      if (timeSinceLastAd < interstitialCooldown) {
        return false;
      }
    }

    _detailViews = 0;
    _lastInterstitialShown = DateTime.now();
    return true;
  }
}
```

---

## Test Ads

**Always use test ad unit IDs during development**

### AdMob Test IDs

```dart
class AdConfig {
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';
    }
    return _productionBannerId;
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';
    }
    return _productionInterstitialId;
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-3940256099942544/1712485313';
    }
    return _productionRewardedId;
  }
}
```

---

## GDPR & Privacy

### 1. Consent Management

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> handleConsent() async {
  final params = ConsentRequestParameters();
  ConsentInformation.instance.requestConsentInfoUpdate(
    params,
    () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        loadConsentForm();
      }
    },
    (error) {
      LoggerFactory.error('Consent error: $error');
    },
  );
}

Future<void> loadConsentForm() async {
  ConsentForm.loadConsentForm(
    (ConsentForm consentForm) async {
      final status = await ConsentInformation.instance.getConsentStatus();
      if (status == ConsentStatus.required) {
        consentForm.show((FormError? formError) {
          loadConsentForm(); // Reload if needed
        });
      }
    },
    (FormError formError) {
      LoggerFactory.error('Form error: $formError');
    },
  );
}
```

### 2. Privacy Policy

**Required**: Link to privacy policy in app and store listing

**Must include**:

- What data is collected
- How ads use data
- Third-party ad networks
- User rights (GDPR/CCPA)

---

## Analytics & Optimization

### Track Ad Performance

```dart
class AdAnalytics {
  static void logAdImpression(String adType) {
    LoggerFactory.info('📊 Ad impression: $adType');
    // Send to analytics (Firebase, etc.)
  }

  static void logAdClick(String adType) {
    LoggerFactory.info('🎯 Ad clicked: $adType');
    // Track user engagement
  }

  static void logAdRevenue(String adType, double revenue) {
    LoggerFactory.info('💰 Ad revenue: $$revenue from $adType');
    // Track earnings
  }
}
```

### A/B Testing

Test different ad placements:

1. Create variants (A: bottom banner, B: inline native)
2. Randomly assign users to groups
3. Track metrics: CTR, revenue, user retention
4. Choose winner after statistical significance

---

## Troubleshooting

### Ads not showing

**Possible causes**:

- Using test IDs in production (or vice versa)
- AdMob account not fully approved
- App not added to AdMob account
- Insufficient ad inventory (try test ads)

**Solution**:

1. Check ad unit IDs match AdMob dashboard
2. Verify app is approved in AdMob
3. Test with test ad units first
4. Check logs for error messages

### Low fill rate

**Possible causes**:

- Geographic location (less demand)
- App content (limited advertiser interest)
- User demographics

**Solution**:

1. Enable all ad formats (banner, interstitial, native)
2. Use mediation to increase competition
3. Improve app content quality
4. Target global audience

### App rejected from AdMob

**Common reasons**:

- Insufficient content
- Policy violations
- Low quality traffic

**Solution**:

1. Review AdMob policies
2. Ensure app has substantial content
3. Remove any policy-violating features
4. Appeal with explanation

---

## Películas Pro (pago único)

Compra lifetime `peliculas_pro_lifetime` que quita todos los ads forzados
(banner/intersticial/native/grid/fullwidth, AdMob + AdSense) y desbloquea
funciones Pro. Los rewarded quedan como opt-in voluntario.

- Fuente de verdad: `UserMonetizationPreferencesService.isPro()` +
  cache síncrono `isProCached` para widgets.
- Compras: `PurchasesService` + `LocalPurchasesService` (offline-first);
  el billing real se conecta implementando el contrato (ver
  `docs/guides/pro-store-setup.md`).
- Gates: `AdaptiveMonetizationManager`, `AdvancedAdMobService`,
  `ControlledAdWidget`, `AdIntegrationHelper`, leaf widgets admob,
  `AdAwareScreen`/`AdTrigger`/`ListAdInserter`, `ProFeatureGate`.
- UI: `ProPaywallScreen` en ruta `/pro-paywall`, entrada en ajustes.

## Resources

- [AdMob Documentation](https://developers.google.com/admob)
- [AdSense Help](https://support.google.com/adsense)
- [Google Mobile Ads Flutter Plugin](https://pub.dev/packages/google_mobile_ads)
- [Ad Policy Guidelines](https://support.google.com/admob/answer/6128543)

---

**Status**: Production-ready monetization system  
**Maintainer**: @tiagofur  
**Project**: peliculas-admob
