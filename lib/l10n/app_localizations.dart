import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get appTitle;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Appearance settings section title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Theme mode selection label
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// Theme color selection label
  ///
  /// In en, this message translates to:
  /// **'Theme Color'**
  String get themeColor;

  /// Information section title
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// Description for system theme mode
  ///
  /// In en, this message translates to:
  /// **'The \'System\' mode will automatically follow your device\'s theme setting.'**
  String get systemThemeDescription;

  /// System theme mode option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// Subtitle for system theme mode
  ///
  /// In en, this message translates to:
  /// **'Follow device configuration'**
  String get systemThemeSubtitle;

  /// Light theme mode option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// Subtitle for light theme mode
  ///
  /// In en, this message translates to:
  /// **'Theme with light colors'**
  String get lightThemeSubtitle;

  /// Dark theme mode option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Subtitle for dark theme mode
  ///
  /// In en, this message translates to:
  /// **'Theme with dark colors'**
  String get darkThemeSubtitle;

  /// Language selection section title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language selection label
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Spanish language option
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Description for language selection
  ///
  /// In en, this message translates to:
  /// **'Change the app language. The app will restart to apply the new language.'**
  String get languageDescription;

  /// Home screen title
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Favorites screen title
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// Watchlist screen title
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get watchlist;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No favorites exclamation
  ///
  /// In en, this message translates to:
  /// **'Ohhh no!!'**
  String get noFavorites;

  /// Message when user has no favorite movies
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any favorite movies'**
  String get noFavoritesMessage;

  /// Button text to start searching for movies
  ///
  /// In en, this message translates to:
  /// **'Start searching'**
  String get startSearching;

  /// Message when user hasn't watched any movies
  ///
  /// In en, this message translates to:
  /// **'You haven\'t watched anything yet!'**
  String get notWatchedYet;

  /// Message when user has no watched movies
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any movies marked as watched'**
  String get noWatchedMessage;

  /// Button text to start exploring movies
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get startExploring;

  /// Login screen title
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Register screen title
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Streaming screen title
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get streaming;

  /// My Library tab label
  ///
  /// In en, this message translates to:
  /// **'My Library'**
  String get myLibrary;

  /// Statistics tab label
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// Challenges tab label
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get challenges;

  /// Conflict resolution dialog title
  ///
  /// In en, this message translates to:
  /// **'Conflict Resolution'**
  String get conflictResolution;

  /// Conflict detection message
  ///
  /// In en, this message translates to:
  /// **'Synchronization Conflict Detected'**
  String get conflictDetected;

  /// Conflict resolution description
  ///
  /// In en, this message translates to:
  /// **'A conflict has been detected during synchronization. Please choose how to resolve it:'**
  String get conflictDescription;

  /// Local version label
  ///
  /// In en, this message translates to:
  /// **'Local Version'**
  String get localVersion;

  /// Remote version label
  ///
  /// In en, this message translates to:
  /// **'Remote Version'**
  String get remoteVersion;

  /// Merged version label
  ///
  /// In en, this message translates to:
  /// **'Merged Version'**
  String get mergedVersion;

  /// Keep local version button
  ///
  /// In en, this message translates to:
  /// **'Keep Local'**
  String get keepLocal;

  /// Keep remote version button
  ///
  /// In en, this message translates to:
  /// **'Keep Remote'**
  String get keepRemote;

  /// Merge changes button
  ///
  /// In en, this message translates to:
  /// **'Merge Changes'**
  String get mergeChanges;

  /// Manual choice button
  ///
  /// In en, this message translates to:
  /// **'Manual Choice'**
  String get manualChoice;

  /// Resolve conflict button
  ///
  /// In en, this message translates to:
  /// **'Resolve Conflict'**
  String get resolveConflict;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Conflict preview section title
  ///
  /// In en, this message translates to:
  /// **'Conflict Preview'**
  String get conflictPreview;

  /// Merge preview section title
  ///
  /// In en, this message translates to:
  /// **'Merge Preview'**
  String get mergePreview;

  /// Conflict history title
  ///
  /// In en, this message translates to:
  /// **'Conflict History'**
  String get conflictHistory;

  /// Message when no conflicts are recorded
  ///
  /// In en, this message translates to:
  /// **'No conflicts recorded'**
  String get noConflictsRecorded;

  /// Description for empty conflict history
  ///
  /// In en, this message translates to:
  /// **'Synchronization conflicts will appear here when they occur'**
  String get conflictsWillAppearHere;

  /// Refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Export button
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// Clear history button
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// Filters section title
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// Search field placeholder
  ///
  /// In en, this message translates to:
  /// **'Search by entity, type or strategy...'**
  String get searchPlaceholder;

  /// All filter option
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Concurrent modification conflict type
  ///
  /// In en, this message translates to:
  /// **'Concurrent Modification'**
  String get concurrentModification;

  /// Delete vs modify conflict type
  ///
  /// In en, this message translates to:
  /// **'Delete vs Modify'**
  String get deleteVsModify;

  /// Duplicate creation conflict type
  ///
  /// In en, this message translates to:
  /// **'Duplicate Creation'**
  String get duplicateCreation;

  /// Local wins strategy
  ///
  /// In en, this message translates to:
  /// **'Local Wins'**
  String get localWins;

  /// Remote wins strategy
  ///
  /// In en, this message translates to:
  /// **'Remote Wins'**
  String get remoteWins;

  /// Merge strategy
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// User choice strategy
  ///
  /// In en, this message translates to:
  /// **'Manual Choice'**
  String get userChoice;

  /// Resolved status
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get resolved;

  /// Pending status
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Entity label
  ///
  /// In en, this message translates to:
  /// **'Entity'**
  String get entity;

  /// Detected label
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get detected;

  /// Strategy label
  ///
  /// In en, this message translates to:
  /// **'Strategy'**
  String get strategy;

  /// Reason label
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
