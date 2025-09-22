import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

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
    Locale('es'),
    Locale('pt')
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

  /// Portuguese language option
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get portuguese;

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

  /// Title for empty watched movies list
  ///
  /// In en, this message translates to:
  /// **'You haven\'t watched any movies'**
  String get noWatchedMovies;

  /// Message for empty watched movies list
  ///
  /// In en, this message translates to:
  /// **'Movies you mark as watched will appear here.'**
  String get noWatchedMoviesMessage;

  /// Title for empty watchlist
  ///
  /// In en, this message translates to:
  /// **'Your watchlist is empty'**
  String get emptyWatchlist;

  /// Message for empty watchlist
  ///
  /// In en, this message translates to:
  /// **'Movies you add to your watchlist will appear here.'**
  String get emptyWatchlistMessage;

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

  /// About screen title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Developed by label
  ///
  /// In en, this message translates to:
  /// **'Developed by'**
  String get developedBy;

  /// Privacy policy label
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Help and support screen title
  ///
  /// In en, this message translates to:
  /// **'Help and Support'**
  String get helpAndSupport;

  /// FAQ section title
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions (FAQ)'**
  String get faq;

  /// FAQ question about adding movies to watchlist
  ///
  /// In en, this message translates to:
  /// **'How can I add a movie to my watchlist?'**
  String get howToAddMovieToWatchlist;

  /// FAQ answer about adding movies to watchlist
  ///
  /// In en, this message translates to:
  /// **'To add a movie, simply go to the movie details and press the \'Add to Watchlist\' icon.'**
  String get howToAddMovieToWatchlistAnswer;

  /// FAQ question about synchronization
  ///
  /// In en, this message translates to:
  /// **'How does synchronization work?'**
  String get howDoesSyncWork;

  /// FAQ answer about synchronization
  ///
  /// In en, this message translates to:
  /// **'Your data is automatically synchronized across all your devices when you have an internet connection. If you are offline, the changes will be saved locally and will be synchronized the next time you connect.'**
  String get howDoesSyncWorkAnswer;

  /// FAQ question about contacting support
  ///
  /// In en, this message translates to:
  /// **'How do I contact support?'**
  String get howToContactSupport;

  /// FAQ answer about contacting support
  ///
  /// In en, this message translates to:
  /// **'You can contact us by email at: support@moviesapp.com'**
  String get howToContactSupportAnswer;

  /// Easy difficulty label
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// Medium difficulty label
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// Hard difficulty label
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hard;

  /// Expert difficulty label
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get expert;

  /// Progress label
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @progressPercentage.
  ///
  /// In en, this message translates to:
  /// **'{value}% complete'**
  String progressPercentage(String value);

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'{value} points'**
  String points(String value);

  /// Completed status label
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Expired status label
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// Message when no challenges are available
  ///
  /// In en, this message translates to:
  /// **'No challenges available'**
  String get noChallengesAvailable;

  /// Challenge statistics section title
  ///
  /// In en, this message translates to:
  /// **'Your Challenge Stats'**
  String get yourChallengeStats;

  /// Active status label
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Movies watched statistic label
  ///
  /// In en, this message translates to:
  /// **'Movies Watched'**
  String get moviesWatched;

  /// Reviews written statistic label
  ///
  /// In en, this message translates to:
  /// **'Reviews Written'**
  String get reviewsWritten;

  /// Movies shared statistic label
  ///
  /// In en, this message translates to:
  /// **'Movies Shared'**
  String get moviesShared;

  /// Genres explored statistic label
  ///
  /// In en, this message translates to:
  /// **'Genres Explored'**
  String get genresExplored;

  /// No description provided for @engagementScore.
  ///
  /// In en, this message translates to:
  /// **'Engagement Score: {value}%'**
  String engagementScore(String value);

  /// Time indicator for just now
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{value}m ago'**
  String minutesAgo(String value);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{value}h ago'**
  String hoursAgo(String value);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{value}d ago'**
  String daysAgo(String value);

  /// Number of badges earned
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 badge}other{{count} badges}}'**
  String badges(int count);

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 day left}other{{count} days left}}'**
  String daysLeft(int count);

  /// No description provided for @hoursLeft.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 hour left}other{{count} hours left}}'**
  String hoursLeft(int count);

  /// No description provided for @minutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 minute left}other{{count} minutes left}}'**
  String minutesLeft(int count);

  /// Loading movie text
  ///
  /// In en, this message translates to:
  /// **'Loading movie...'**
  String get loadingMovie;

  /// Challenge completion celebration text
  ///
  /// In en, this message translates to:
  /// **'Challenge Completed!'**
  String get challengeCompleted;

  /// Family-friendly list name
  ///
  /// In en, this message translates to:
  /// **'Family-Friendly'**
  String get familyFriendly;

  /// Family-friendly list description
  ///
  /// In en, this message translates to:
  /// **'Movies suitable for the whole family'**
  String get familyFriendlyDescription;

  /// Date night list name
  ///
  /// In en, this message translates to:
  /// **'Date Night'**
  String get dateNight;

  /// Date night list description
  ///
  /// In en, this message translates to:
  /// **'Romantic movies and date films'**
  String get dateNightDescription;

  /// Classics list name
  ///
  /// In en, this message translates to:
  /// **'Classics'**
  String get classics;

  /// Classics list description
  ///
  /// In en, this message translates to:
  /// **'Unmissable cinema classics'**
  String get classicsDescription;

  /// Suggested list name
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get suggested;

  /// Suggested list description
  ///
  /// In en, this message translates to:
  /// **'Personalized recommendations'**
  String get suggestedDescription;

  /// With friends list name
  ///
  /// In en, this message translates to:
  /// **'With Friends'**
  String get withFriends;

  /// With friends list description
  ///
  /// In en, this message translates to:
  /// **'Movies for groups and gatherings'**
  String get withFriendsDescription;

  /// Rainy nights list name
  ///
  /// In en, this message translates to:
  /// **'Rainy Nights'**
  String get rainyNights;

  /// Rainy nights list description
  ///
  /// In en, this message translates to:
  /// **'Cozy movies for rainy days'**
  String get rainyNightsDescription;

  /// Short movies list name
  ///
  /// In en, this message translates to:
  /// **'Short Movies'**
  String get shortMovies;

  /// Short movies list description
  ///
  /// In en, this message translates to:
  /// **'Movies under 100 minutes'**
  String get shortMoviesDescription;

  /// To watch list name
  ///
  /// In en, this message translates to:
  /// **'To Watch'**
  String get toWatch;

  /// To watch list description
  ///
  /// In en, this message translates to:
  /// **'Movies I want to watch soon'**
  String get toWatchDescription;

  /// Chilling movies list name
  ///
  /// In en, this message translates to:
  /// **'Chilling Movies'**
  String get chillingMovies;

  /// Chilling movies list description
  ///
  /// In en, this message translates to:
  /// **'Perfect movies for relaxing'**
  String get chillingMoviesDescription;

  /// Romantic movies list name
  ///
  /// In en, this message translates to:
  /// **'Romantic Movies'**
  String get romanticMovies;

  /// Romantic movies list description
  ///
  /// In en, this message translates to:
  /// **'Romantic movies to watch as a couple'**
  String get romanticMoviesDescription;

  /// Fun movies list name
  ///
  /// In en, this message translates to:
  /// **'Fun Movies'**
  String get funMovies;

  /// Fun movies list description
  ///
  /// In en, this message translates to:
  /// **'Fun movies to watch in groups'**
  String get funMoviesDescription;

  /// Pending classics list name
  ///
  /// In en, this message translates to:
  /// **'Pending Classics'**
  String get pendingClassics;

  /// Pending classics list description
  ///
  /// In en, this message translates to:
  /// **'Classic movies I need to watch'**
  String get pendingClassicsDescription;

  /// Action and adventure list name
  ///
  /// In en, this message translates to:
  /// **'Action & Adventure'**
  String get actionAdventure;

  /// Action and adventure list description
  ///
  /// In en, this message translates to:
  /// **'Action and adventure movies'**
  String get actionAdventureDescription;

  /// Rainy day movies list name
  ///
  /// In en, this message translates to:
  /// **'Rainy Day Movies'**
  String get rainyDayMovies;

  /// Rainy day movies list description
  ///
  /// In en, this message translates to:
  /// **'Perfect movies for rainy days'**
  String get rainyDayMoviesDescription;

  /// Based on favorites recommendation type
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get basedOnFavorites;

  /// Trending recommendation type
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// For you recommendation type
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get forYou;

  /// Mood recommendation type
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get mood;

  /// Similar recommendation type
  ///
  /// In en, this message translates to:
  /// **'Similar'**
  String get similar;

  /// Based on watched recommendation type
  ///
  /// In en, this message translates to:
  /// **'Based on Watched'**
  String get basedOnWatched;

  /// Based on genre recommendation type
  ///
  /// In en, this message translates to:
  /// **'Based on Genre'**
  String get basedOnGenre;

  /// Realtime synchronization dashboard title
  ///
  /// In en, this message translates to:
  /// **'Realtime Sync Dashboard'**
  String get realtimeSyncDashboard;

  /// Synchronization system status
  ///
  /// In en, this message translates to:
  /// **'System Status'**
  String get systemStatus;

  /// System performance score
  ///
  /// In en, this message translates to:
  /// **'Performance Score'**
  String get performanceScore;

  /// Connection status
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get connectionStatus;

  /// Online status
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// Offline status
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// Synchronization latency
  ///
  /// In en, this message translates to:
  /// **'Sync Latency'**
  String get syncLatency;

  /// Latency target for synchronization
  ///
  /// In en, this message translates to:
  /// **'Target: < 1.5 seconds (Issue #69 requirement)'**
  String get latencyTarget;

  /// Average synchronization
  ///
  /// In en, this message translates to:
  /// **'Avg Sync'**
  String get avgSync;

  /// Average realtime
  ///
  /// In en, this message translates to:
  /// **'Avg Realtime'**
  String get avgRealtime;

  /// Realtime events
  ///
  /// In en, this message translates to:
  /// **'Realtime Events'**
  String get realtimeEvents;

  /// Events received
  ///
  /// In en, this message translates to:
  /// **'Events Received'**
  String get eventsReceived;

  /// Streaming availability
  ///
  /// In en, this message translates to:
  /// **'Available on:'**
  String get availableOn;

  /// High priority
  ///
  /// In en, this message translates to:
  /// **'High Priority'**
  String get highPriority;

  /// Normal priority
  ///
  /// In en, this message translates to:
  /// **'Normal Priority'**
  String get normalPriority;

  /// Low priority
  ///
  /// In en, this message translates to:
  /// **'Low Priority'**
  String get lowPriority;

  /// Error loading similar movies
  ///
  /// In en, this message translates to:
  /// **'Could not load similar movies'**
  String get couldNotLoadSimilarMovies;

  /// Open in YouTube
  ///
  /// In en, this message translates to:
  /// **'Open YouTube'**
  String get openYouTube;

  /// YouTube
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get youTube;

  /// Remove from watchlist
  ///
  /// In en, this message translates to:
  /// **'Remove from watchlist'**
  String get removeFromWatchlist;

  /// Add to watchlist
  ///
  /// In en, this message translates to:
  /// **'Add to watchlist'**
  String get addToWatchlist;

  /// In watchlist
  ///
  /// In en, this message translates to:
  /// **'In Watchlist'**
  String get inWatchlist;

  /// Add to watchlist dialog title
  ///
  /// In en, this message translates to:
  /// **'Add to Watchlist'**
  String get addToWatchlistTitle;

  /// Select priority
  ///
  /// In en, this message translates to:
  /// **'Select priority:'**
  String get selectPriority;

  /// Add button
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Calculating user engagement
  ///
  /// In en, this message translates to:
  /// **'Calculating engagement...'**
  String get calculatingEngagement;

  /// Analyzing user behavior
  ///
  /// In en, this message translates to:
  /// **'Analyzing behavior...'**
  String get analyzingBehavior;

  /// Generating user insights
  ///
  /// In en, this message translates to:
  /// **'Generating insights...'**
  String get generatingInsights;

  /// Uploading status
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// Downloading status
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// Synchronizing status
  ///
  /// In en, this message translates to:
  /// **'Synchronizing...'**
  String get synchronizing;

  /// Synchronize action
  ///
  /// In en, this message translates to:
  /// **'Synchronize'**
  String get synchronize;

  /// Notifications and reminders
  ///
  /// In en, this message translates to:
  /// **'Notifications and Reminders'**
  String get notificationsAndReminders;

  /// Enable button
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// Reminder permissions
  ///
  /// In en, this message translates to:
  /// **'Reminder Permissions'**
  String get reminderPermissions;

  /// Change language
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// Language change confirmation
  ///
  /// In en, this message translates to:
  /// **'The app will restart to apply the new language. Do you want to continue?'**
  String get languageChangeConfirmation;

  /// Confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Language changed
  ///
  /// In en, this message translates to:
  /// **'Language changed. Restarting app...'**
  String get languageChanged;

  /// App restart required
  ///
  /// In en, this message translates to:
  /// **'App Restart Required'**
  String get appRestartRequired;

  /// Restart app message
  ///
  /// In en, this message translates to:
  /// **'Please restart the app to apply the language change.'**
  String get restartAppMessage;

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Active subscriptions
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeSubscriptions;

  /// No movies in watchlist yet
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any movies to your watchlist yet'**
  String get noWatchlistMoviesYet;
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
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

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
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
