// This is a placeholder file for the generated localizations
// Run 'flutter gen-l10n' to generate the actual app_localizations.dart file

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  // Placeholder methods - these will be replaced by generated methods
  String get appTitle => 'Movies';
  String get settings => 'Settings';
  String get appearance => 'Appearance';
  String get themeMode => 'Theme Mode';
  String get themeColor => 'Theme Color';
  String get information => 'Information';
  String get systemThemeDescription => 'The \'System\' mode will automatically follow your device\'s theme setting.';
  String get system => 'System';
  String get systemThemeSubtitle => 'Follow device configuration';
  String get light => 'Light';
  String get lightThemeSubtitle => 'Theme with light colors';
  String get dark => 'Dark';
  String get darkThemeSubtitle => 'Theme with dark colors';
  String get language => 'Language';
  String get selectLanguage => 'Select Language';
  String get spanish => 'Spanish';
  String get english => 'English';
  String get languageDescription => 'Change the app language. The app will restart to apply the new language.';
  String get home => 'Home';
  String get favorites => 'Favorites';
  String get watchlist => 'Watchlist';
  String get profile => 'Profile';
  String get noFavorites => 'Ohhh no!!';
  String get noFavoritesMessage => 'You don\'t have any favorite movies';
  String get startSearching => 'Start searching';
  String get notWatchedYet => 'You haven\'t watched anything yet!';
  String get noWatchedMessage => 'You don\'t have any movies marked as watched';
  String get startExploring => 'Start exploring';
  String get login => 'Login';
  String get register => 'Register';
  String get streaming => 'Streaming';
  String get myLibrary => 'My Library';
  String get statistics => 'Statistics';
  String get challenges => 'Challenges';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(_lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations _lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
  }
  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Check that you have added the locale '
    'you are testing to supportedLocales on your AppLocalizations instance.',
  );
}

// English localizations
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn() : super('en');

  @override
  String get appTitle => 'Movies';
  @override
  String get settings => 'Settings';
  @override
  String get appearance => 'Appearance';
  @override
  String get themeMode => 'Theme Mode';
  @override
  String get themeColor => 'Theme Color';
  @override
  String get information => 'Information';
  @override
  String get systemThemeDescription => 'The \'System\' mode will automatically follow your device\'s theme setting.';
  @override
  String get system => 'System';
  @override
  String get systemThemeSubtitle => 'Follow device configuration';
  @override
  String get light => 'Light';
  @override
  String get lightThemeSubtitle => 'Theme with light colors';
  @override
  String get dark => 'Dark';
  @override
  String get darkThemeSubtitle => 'Theme with dark colors';
  @override
  String get language => 'Language';
  @override
  String get selectLanguage => 'Select Language';
  @override
  String get spanish => 'Spanish';
  @override
  String get english => 'English';
  @override
  String get languageDescription => 'Change the app language. The app will restart to apply the new language.';
  @override
  String get home => 'Home';
  @override
  String get favorites => 'Favorites';
  @override
  String get watchlist => 'Watchlist';
  @override
  String get profile => 'Profile';
  @override
  String get noFavorites => 'Ohhh no!!';
  @override
  String get noFavoritesMessage => 'You don\'t have any favorite movies';
  @override
  String get startSearching => 'Start searching';
  @override
  String get notWatchedYet => 'You haven\'t watched anything yet!';
  @override
  String get noWatchedMessage => 'You don\'t have any movies marked as watched';
  @override
  String get startExploring => 'Start exploring';
  @override
  String get login => 'Login';
  @override
  String get register => 'Register';
  @override
  String get streaming => 'Streaming';
  @override
  String get myLibrary => 'My Library';
  @override
  String get statistics => 'Statistics';
  @override
  String get challenges => 'Challenges';
}

// Spanish localizations
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs() : super('es');

  @override
  String get appTitle => 'Películas';
  @override
  String get settings => 'Configuración';
  @override
  String get appearance => 'Apariencia';
  @override
  String get themeMode => 'Modo de tema';
  @override
  String get themeColor => 'Color del tema';
  @override
  String get information => 'Información';
  @override
  String get systemThemeDescription => 'El modo \'Sistema\' seguirá automáticamente la configuración de tema de tu dispositivo.';
  @override
  String get system => 'Sistema';
  @override
  String get systemThemeSubtitle => 'Seguir la configuración del dispositivo';
  @override
  String get light => 'Claro';
  @override
  String get lightThemeSubtitle => 'Tema con colores claros';
  @override
  String get dark => 'Oscuro';
  @override
  String get darkThemeSubtitle => 'Tema con colores oscuros';
  @override
  String get language => 'Idioma';
  @override
  String get selectLanguage => 'Seleccionar idioma';
  @override
  String get spanish => 'Español';
  @override
  String get english => 'Inglés';
  @override
  String get languageDescription => 'Cambia el idioma de la aplicación. La aplicación se reiniciará para aplicar el nuevo idioma.';
  @override
  String get home => 'Inicio';
  @override
  String get favorites => 'Favoritos';
  @override
  String get watchlist => 'Lista de seguimiento';
  @override
  String get profile => 'Perfil';
  @override
  String get noFavorites => '¡Ohhh no!';
  @override
  String get noFavoritesMessage => 'No tienes películas favoritas';
  @override
  String get startSearching => 'Empieza a buscar';
  @override
  String get notWatchedYet => '¡Aún no has visto nada!';
  @override
  String get noWatchedMessage => 'No tienes películas marcadas como vistas';
  @override
  String get startExploring => 'Empieza a explorar';
  @override
  String get login => 'Iniciar sesión';
  @override
  String get register => 'Registrarse';
  @override
  String get streaming => 'Streaming';
  @override
  String get myLibrary => 'Mi Biblioteca';
  @override
  String get statistics => 'Estadísticas';
  @override
  String get challenges => 'Desafíos';
}