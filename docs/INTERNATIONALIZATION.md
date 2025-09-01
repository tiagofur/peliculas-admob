# Internationalization (i18n) Implementation

This document describes the internationalization implementation for the Películas app, providing support for Spanish and English languages.

## Overview

The app now supports:
- **Spanish (es)** - Default and primary language
- **English (en)** - Secondary language

Users can switch between languages through the Settings screen, and the app will remember their choice across sessions.

## Features Implemented

### 1. Language Selection
- Manual language selector in Settings screen
- Language preference persisted using SharedPreferences
- Automatic locale detection from system settings (when no preference is saved)

### 2. Localized UI Components
- **Settings Screen**: All labels, descriptions, and buttons
- **Bottom Navigation**: Tab labels for Home, My Library, Statistics, Streaming, Challenges
- **Empty States**: Messages in Favorites and Watched views
- **Theme Selection**: System, Light, and Dark mode labels and descriptions

### 3. Technical Implementation
- Flutter's built-in internationalization framework
- ARB (Application Resource Bundle) files for translations
- Riverpod state management for locale changes
- Generated localizations with type-safe string access

## File Structure

```
lib/
├── l10n/                          # Localization files
│   ├── app_en.arb                # English translations
│   └── app_es.arb                # Spanish translations
├── generated/
│   └── app_localizations.dart    # Generated localization classes
└── presentation/
    └── providers/
        └── locale/
            └── locale_provider.dart  # Locale state management

l10n.yaml                         # Localization configuration
```

## Adding New Translations

### 1. Add to ARB Files

**English (lib/l10n/app_en.arb):**
```json
{
  "newKey": "English Text",
  "@newKey": {
    "description": "Description of what this text is for"
  }
}
```

**Spanish (lib/l10n/app_es.arb):**
```json
{
  "newKey": "Texto en Español"
}
```

### 2. Regenerate Localizations

Run the following command to regenerate the localization files:
```bash
flutter gen-l10n
```

### 3. Use in Code

```dart
import 'package:your_app/generated/app_localizations.dart';

Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  
  return Text(l10n.newKey);
}
```

## Usage in UI

### Basic Usage
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: Text(l10n.home),
    );
  }
}
```

### With Riverpod Consumer
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final localeState = ref.watch(localeNotifierProvider);
    
    return Text(l10n.someText);
  }
}
```

## Changing Languages Programmatically

```dart
// Change to Spanish
ref.read(localeNotifierProvider.notifier).setLocale(Locale('es'));

// Change to English  
ref.read(localeNotifierProvider.notifier).setLocale(Locale('en'));

// Use system default
ref.read(localeNotifierProvider.notifier).clearLocale();
```

## Configuration

### Supported Locales
Currently supported locales are defined in:
- `AppLocalizations.supportedLocales`
- `LocaleNotifier.supportedLocales`

### Locale Persistence
Language preferences are stored using SharedPreferences with the key `'app_locale'`.

## Testing

Run the localization tests:
```bash
flutter test test/localization_test.dart
```

The tests verify:
- Correct translation loading for both languages
- Locale persistence functionality
- UI component localization
- Navigation label translations

## Future Enhancements

### Additional Languages
To add more languages:

1. Create new ARB file (e.g., `app_fr.arb` for French)
2. Add translations for all existing keys
3. Update `supportedLocales` lists in:
   - `AppLocalizations.supportedLocales`
   - `LocaleNotifier.supportedLocales`
4. Update language selector UI in Settings

### Advanced Features
- Region-specific locales (e.g., es_ES, es_MX)
- Right-to-left (RTL) language support
- Date and number formatting per locale
- Currency formatting
- Pluralization rules

## Troubleshooting

### Common Issues

1. **Missing translations**: Check that all keys exist in both ARB files
2. **Generated files not updated**: Run `flutter gen-l10n` after changing ARB files
3. **Locale not changing**: Ensure app is restarted after locale change
4. **Build errors**: Verify all ARB files have valid JSON syntax

### Debug Tips
- Check `LocaleState.isLoading` to handle loading states
- Use `Localizations.localeOf(context)` to get current system locale
- Verify SharedPreferences permissions on target platforms

## Best Practices

1. **Key Naming**: Use descriptive, hierarchical keys (e.g., `settings.theme.light`)
2. **Descriptions**: Always add `@key` descriptions in ARB files
3. **Consistency**: Maintain consistent terminology across languages
4. **Context**: Provide context in descriptions for translators
5. **Testing**: Test all languages in your UI flows
6. **Fallbacks**: Handle missing translations gracefully

This internationalization implementation provides a solid foundation for a multilingual movie app experience, allowing users to enjoy the app in their preferred language while maintaining all functionality.