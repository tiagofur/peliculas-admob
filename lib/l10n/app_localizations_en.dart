// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get systemThemeDescription =>
      'The \'System\' mode will automatically follow your device\'s theme setting.';

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
  String get languageDescription =>
      'Change the app language. The app will restart to apply the new language.';

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
