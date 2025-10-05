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
/// import 'generated/app_localizations.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
    Locale('pt', 'BR')
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

  /// Portuguese (Brazil) language option
  ///
  /// In en, this message translates to:
  /// **'Portuguese (Brazil)'**
  String get portugueseBrazil;

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

  /// Title for the now playing movies section on home
  ///
  /// In en, this message translates to:
  /// **'Now in theaters'**
  String get homeNowPlayingTitle;

  /// Subtitle for the now playing movies section on home
  ///
  /// In en, this message translates to:
  /// **'Monday 20'**
  String get homeNowPlayingSubtitle;

  /// Title for the popular movies section on home
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get homePopularTitle;

  /// Subtitle for the popular movies section on home
  ///
  /// In en, this message translates to:
  /// **'Top picks right now'**
  String get homePopularSubtitle;

  /// Title for the upcoming movies section on home
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get homeUpcomingTitle;

  /// Subtitle for the upcoming movies section on home
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get homeUpcomingSubtitle;

  /// Title for the top rated movies section on home
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get homeTopRatedTitle;

  /// Subtitle for the top rated movies section on home
  ///
  /// In en, this message translates to:
  /// **'All-time favorites'**
  String get homeTopRatedSubtitle;

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

  /// Default message for an unknown error
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Tooltip for toggling to light mode
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get appBarToggleToLightMode;

  /// Tooltip for toggling to dark mode
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get appBarToggleToDarkMode;

  /// Tooltip for the search movies button
  ///
  /// In en, this message translates to:
  /// **'Search movies'**
  String get searchMoviesTooltip;

  /// Title for the guest mode banner
  ///
  /// In en, this message translates to:
  /// **'Unlock more features!'**
  String get guestBannerTitle;

  /// Subtitle describing benefits for creating an account
  ///
  /// In en, this message translates to:
  /// **'Create a free account and get:'**
  String get guestBannerSubtitle;

  /// Title for the cloud sync benefit
  ///
  /// In en, this message translates to:
  /// **'Cloud synchronization'**
  String get guestBannerBenefitCloudSyncTitle;

  /// Description for the cloud sync benefit
  ///
  /// In en, this message translates to:
  /// **'Your favorites and watched movies on all your devices'**
  String get guestBannerBenefitCloudSyncDescription;

  /// Title for the social features benefit
  ///
  /// In en, this message translates to:
  /// **'Social features'**
  String get guestBannerBenefitSocialTitle;

  /// Description for the social features benefit
  ///
  /// In en, this message translates to:
  /// **'Share reviews and connect with other movie lovers'**
  String get guestBannerBenefitSocialDescription;

  /// Title for the advanced statistics benefit
  ///
  /// In en, this message translates to:
  /// **'Advanced statistics'**
  String get guestBannerBenefitStatsTitle;

  /// Description for the advanced statistics benefit
  ///
  /// In en, this message translates to:
  /// **'Detailed insights about your movie habits'**
  String get guestBannerBenefitStatsDescription;

  /// Title for the secure backup benefit
  ///
  /// In en, this message translates to:
  /// **'Secure backup'**
  String get guestBannerBenefitBackupTitle;

  /// Description for the secure backup benefit
  ///
  /// In en, this message translates to:
  /// **'Never lose your movie history'**
  String get guestBannerBenefitBackupDescription;

  /// Button text to create an account from the guest banner
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get guestBannerCreateAccount;

  /// Button text to log in from the guest banner
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get guestBannerLogin;

  /// Message shown when an image fails to load
  ///
  /// In en, this message translates to:
  /// **'Image not available'**
  String get imageNotAvailable;

  /// Message shown when a connection error occurs
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

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

  /// Title for rating a movie
  ///
  /// In en, this message translates to:
  /// **'Rate this movie'**
  String get rateThisMovie;

  /// Label for user's rating
  ///
  /// In en, this message translates to:
  /// **'Your Rating'**
  String get yourRating;

  /// Quick rating button text
  ///
  /// In en, this message translates to:
  /// **'Quick Rate'**
  String get quickRate;

  /// Full rating and review button text
  ///
  /// In en, this message translates to:
  /// **'Rate & Review'**
  String get rateAndReview;

  /// Subtitle for rating section
  ///
  /// In en, this message translates to:
  /// **'Share your opinion with the community'**
  String get shareYourOpinion;

  /// Edit rating button text
  ///
  /// In en, this message translates to:
  /// **'Edit Rating'**
  String get editRating;

  /// Delete rating dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Rating'**
  String get deleteRating;

  /// Confirm delete rating message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your rating for this movie?'**
  String get confirmDeleteRating;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Success message after deleting rating
  ///
  /// In en, this message translates to:
  /// **'Rating deleted successfully!'**
  String get ratingDeletedSuccessfully;

  /// Message when user has no custom lists
  ///
  /// In en, this message translates to:
  /// **'No custom lists yet!'**
  String get noCustomLists;

  /// Detailed message when no custom lists exist
  ///
  /// In en, this message translates to:
  /// **'You haven\'t created any custom movie lists'**
  String get noCustomListsMessage;

  /// Button text to start creating lists
  ///
  /// In en, this message translates to:
  /// **'Start creating'**
  String get startCreating;

  /// Call to action for creating first custom list
  ///
  /// In en, this message translates to:
  /// **'Create your first list'**
  String get createYourFirstList;

  /// Watched tab label
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get watched;

  /// Lists tab label
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get lists;

  /// Movies label for counts and stats
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movies;

  /// Relative date label for today
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get relativeToday;

  /// Relative date label for yesterday
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get relativeYesterday;

  /// Relative date label for days ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} day ago} other {{count} days ago}}'**
  String relativeDaysAgo(num count);

  /// Relative date label for weeks ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} week ago} other {{count} weeks ago}}'**
  String relativeWeeksAgo(num count);

  /// Tooltip for creating a new custom list
  ///
  /// In en, this message translates to:
  /// **'Create new list'**
  String get customListsCreateTooltip;

  /// Title for default lists tab with count
  ///
  /// In en, this message translates to:
  /// **'Default ({count})'**
  String customListsDefaultTab(Object count);

  /// Title for custom lists tab with count
  ///
  /// In en, this message translates to:
  /// **'Custom ({count})'**
  String customListsCustomTab(Object count);

  /// Label for custom lists statistic
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customListsStatsCustom;

  /// Message when there are no default lists
  ///
  /// In en, this message translates to:
  /// **'No default lists available'**
  String get customListsNoDefault;

  /// Badge text for default list
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get customListsDefaultBadge;

  /// Movie count label for list cards
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} movie} other {{count} movies}}'**
  String customListsMovieCount(num count);

  /// Last updated label for lists
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String customListsUpdatedAt(Object date);

  /// Menu action to edit a list
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get customListsMenuEdit;

  /// Menu action to duplicate a list
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get customListsMenuDuplicate;

  /// Menu action to clear a list
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get customListsMenuClear;

  /// Menu action to delete a list
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get customListsMenuDelete;

  /// Title for confirm clear list dialog
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get customListsClearDialogTitle;

  /// Message for confirm clear list dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove all movies from \"{listName}\"?'**
  String customListsClearDialogMessage(Object listName);

  /// Confirmation button text for clearing a list
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get customListsClearConfirm;

  /// Snackbar shown when list is cleared
  ///
  /// In en, this message translates to:
  /// **'List \"{listName}\" cleared'**
  String customListsClearSuccess(Object listName);

  /// Error shown when clearing a list fails
  ///
  /// In en, this message translates to:
  /// **'Failed to clear list: {error}'**
  String customListsClearError(Object error);

  /// Title for confirm delete list dialog
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get customListsDeleteDialogTitle;

  /// Message for confirm delete list dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{listName}\"? This action can\'t be undone.'**
  String customListsDeleteDialogMessage(Object listName);

  /// Confirmation button text for deleting a list
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get customListsDeleteConfirm;

  /// Snackbar shown when a list is deleted
  ///
  /// In en, this message translates to:
  /// **'List \"{listName}\" deleted'**
  String customListsDeleteSuccess(Object listName);

  /// Error shown when deleting a list fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete list: {error}'**
  String customListsDeleteError(Object error);

  /// Title for empty custom list state
  ///
  /// In en, this message translates to:
  /// **'Empty list'**
  String get customListsEmptyTitle;

  /// Description for empty custom list state
  ///
  /// In en, this message translates to:
  /// **'Add movies to this list from any movie details screen'**
  String get customListsEmptyDescription;

  /// Button to explore movies from empty state
  ///
  /// In en, this message translates to:
  /// **'Explore movies'**
  String get customListsExploreButton;

  /// Label for add movie button
  ///
  /// In en, this message translates to:
  /// **'Add movie'**
  String get customListsAddMovieButton;

  /// Title for create list dialog
  ///
  /// In en, this message translates to:
  /// **'Create new list'**
  String get customListsCreateDialogTitle;

  /// Label for list name field
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get customListsCreateNameLabel;

  /// Hint for list name field
  ///
  /// In en, this message translates to:
  /// **'E.g. Horror movies'**
  String get customListsCreateNameHint;

  /// Label for description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get customListsCreateDescriptionLabel;

  /// Hint for description field
  ///
  /// In en, this message translates to:
  /// **'Describe the purpose of this list'**
  String get customListsCreateDescriptionHint;

  /// Label for emoji selector
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get customListsCreateEmojiLabel;

  /// Label for color selector
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get customListsCreateColorLabel;

  /// Confirmation button for creating a list
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get customListsCreateConfirm;

  /// Snackbar shown when list is created
  ///
  /// In en, this message translates to:
  /// **'List \"{listName}\" created'**
  String customListsCreateSuccess(Object listName);

  /// Error shown when creating a list fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create list: {error}'**
  String customListsCreateError(Object error);

  /// Title for edit list dialog
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get customListsEditDialogTitle;

  /// Label for list name field in edit dialog
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get customListsEditNameLabel;

  /// Label for description field in edit dialog
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get customListsEditDescriptionLabel;

  /// Label for optional description field in edit dialog
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get customListsEditDescriptionOptionalLabel;

  /// Confirmation button for editing a list
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get customListsEditConfirm;

  /// Snackbar shown when list is updated
  ///
  /// In en, this message translates to:
  /// **'List \"{listName}\" updated'**
  String customListsEditSuccess(Object listName);

  /// Error shown when editing a list fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update list: {error}'**
  String customListsEditError(Object error);

  /// Title for duplicate list dialog
  ///
  /// In en, this message translates to:
  /// **'Duplicate list'**
  String get customListsDuplicateDialogTitle;

  /// Message for duplicate list dialog
  ///
  /// In en, this message translates to:
  /// **'A copy of \"{listName}\" with all its movies will be created.'**
  String customListsDuplicateMessage(Object listName);

  /// Label for new list name field in duplicate dialog
  ///
  /// In en, this message translates to:
  /// **'New list name'**
  String get customListsDuplicateNameLabel;

  /// Confirmation button for duplicating a list
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get customListsDuplicateConfirm;

  /// Snackbar shown when list is duplicated
  ///
  /// In en, this message translates to:
  /// **'List \"{listName}\" duplicated'**
  String customListsDuplicateSuccess(Object listName);

  /// Error shown when duplicating a list fails
  ///
  /// In en, this message translates to:
  /// **'Failed to duplicate list: {error}'**
  String customListsDuplicateError(Object error);

  /// Default description when sharing a list
  ///
  /// In en, this message translates to:
  /// **'A curated collection of {count} selected movies'**
  String customListsShareDefaultDescription(Object count);

  /// Error shown when sharing a list fails
  ///
  /// In en, this message translates to:
  /// **'Failed to share list: {error}'**
  String customListsShareError(Object error);

  /// Title when a list is not found
  ///
  /// In en, this message translates to:
  /// **'List not found'**
  String get customListsNotFoundTitle;

  /// Message when a list is not found
  ///
  /// In en, this message translates to:
  /// **'The requested list doesn\'t exist'**
  String get customListsNotFoundMessage;

  /// Message showing the searched list id
  ///
  /// In en, this message translates to:
  /// **'Searched ID: {id}'**
  String customListsNotFoundId(Object id);

  /// Generic back button label
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Generic view action label
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Error shown when loading list movies fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load movies: {error}'**
  String customListsLoadError(Object error);

  /// Title for add movie dialog
  ///
  /// In en, this message translates to:
  /// **'Add movie'**
  String get customListsAddMovieDialogTitle;

  /// Label for movie search field
  ///
  /// In en, this message translates to:
  /// **'Search movie'**
  String get customListsAddMovieSearchLabel;

  /// Hint for movie search field
  ///
  /// In en, this message translates to:
  /// **'Type a movie name'**
  String get customListsAddMovieSearchHint;

  /// Message when no search results
  ///
  /// In en, this message translates to:
  /// **'Type a movie name to search'**
  String get customListsAddMovieSearchEmpty;

  /// Error message when searching movies fails
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String customListsAddMovieSearchError(Object error);

  /// Snackbar shown when a movie is added to a list
  ///
  /// In en, this message translates to:
  /// **'{title} added to the list'**
  String customListsAddMovieSuccess(Object title);

  /// Error shown when adding a movie fails
  ///
  /// In en, this message translates to:
  /// **'Failed to add movie: {error}'**
  String customListsAddMovieError(Object error);

  /// Label for the watchlist tab
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get watchlistTitle;

  /// Label for high priority
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get watchlistPriorityHigh;

  /// Label for normal priority
  ///
  /// In en, this message translates to:
  /// **'Normal priority'**
  String get watchlistPriorityNormal;

  /// Label for low priority
  ///
  /// In en, this message translates to:
  /// **'Low priority'**
  String get watchlistPriorityLow;

  /// Title shown when watchlist has no movies
  ///
  /// In en, this message translates to:
  /// **'Your watchlist is empty'**
  String get watchlistEmptyTitle;

  /// Message when no movies match selected priority
  ///
  /// In en, this message translates to:
  /// **'No movies with {priority}.'**
  String watchlistEmptyFiltered(Object priority);

  /// Description for empty watchlist
  ///
  /// In en, this message translates to:
  /// **'Add movies you want to watch later'**
  String get watchlistEmptyDescription;

  /// Button to explore movies from watchlist empty state
  ///
  /// In en, this message translates to:
  /// **'Explore movies'**
  String get watchlistExploreButton;

  /// Title for remove from watchlist dialog
  ///
  /// In en, this message translates to:
  /// **'Remove from watchlist'**
  String get watchlistRemoveDialogTitle;

  /// Message for remove from watchlist dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{title}\" from your watchlist?'**
  String watchlistRemoveDialogMessage(Object title);

  /// Confirmation button for removing from watchlist
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get watchlistRemoveDialogConfirm;

  /// Snackbar shown when movie removed from watchlist
  ///
  /// In en, this message translates to:
  /// **'{title} removed from watchlist'**
  String watchlistRemoveSuccess(Object title);

  /// Snackbar shown when movie added to watchlist
  ///
  /// In en, this message translates to:
  /// **'{title} added to watchlist with {priority} priority'**
  String watchlistAddSuccess(Object title, Object priority);

  /// Label showing when movie was added to watchlist
  ///
  /// In en, this message translates to:
  /// **'Added: {date}'**
  String watchlistAddedLabel(Object date);

  /// Title for add to watchlist dialog
  ///
  /// In en, this message translates to:
  /// **'Add to watchlist'**
  String get watchlistAddDialogTitle;

  /// Label showing movie name in dialog
  ///
  /// In en, this message translates to:
  /// **'Movie: {title}'**
  String watchlistAddDialogMovieLabel(Object title);

  /// Instruction to select a priority
  ///
  /// In en, this message translates to:
  /// **'Select priority:'**
  String get watchlistAddDialogPriorityLabel;

  /// Confirmation button for adding to watchlist
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get watchlistAddDialogConfirm;

  /// Title for statistics view
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsTitle;

  /// Achievements tab label
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// Error loading movie data
  ///
  /// In en, this message translates to:
  /// **'Could not load movie'**
  String get errorMovieLoadFailed;

  /// Error loading custom list
  ///
  /// In en, this message translates to:
  /// **'Could not load list'**
  String get errorListLoadFailed;

  /// Network/connectivity error
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection'**
  String get errorNetworkError;

  /// Server error
  ///
  /// In en, this message translates to:
  /// **'Server is not responding'**
  String get errorServerError;

  /// Timeout error
  ///
  /// In en, this message translates to:
  /// **'Request took too long'**
  String get errorTimeout;

  /// Generic error
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get errorGeneric;

  /// Retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Dismiss/close action
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get actionDismiss;

  /// Error loading advertisement
  ///
  /// In en, this message translates to:
  /// **'Error loading ad'**
  String get errorLoadingAd;

  /// Error creating custom list
  ///
  /// In en, this message translates to:
  /// **'Error creating list'**
  String get errorCreateList;

  /// Error opening external URL
  ///
  /// In en, this message translates to:
  /// **'Could not open URL'**
  String get errorOpenUrl;

  /// Error when login is required
  ///
  /// In en, this message translates to:
  /// **'You must log in to continue'**
  String get errorLoginRequired;

  /// Success logging in
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get successLoginComplete;

  /// Success logging out
  ///
  /// In en, this message translates to:
  /// **'Session closed'**
  String get successLogoutComplete;

  /// Success creating account
  ///
  /// In en, this message translates to:
  /// **'Account created successfully'**
  String get successAccountCreated;

  /// Success registering vote
  ///
  /// In en, this message translates to:
  /// **'Your vote has been registered'**
  String get successVoteRegistered;

  /// Error sending feedback
  ///
  /// In en, this message translates to:
  /// **'Error sending feedback'**
  String get errorSendingFeedback;

  /// Error loading ML explanation
  ///
  /// In en, this message translates to:
  /// **'Error loading explanation'**
  String get errorLoadingExplanation;

  /// Title for streaming providers section
  ///
  /// In en, this message translates to:
  /// **'Available on:'**
  String get streamingProvidersTitle;

  /// Loading message for streaming providers
  ///
  /// In en, this message translates to:
  /// **'Searching streaming providers...'**
  String get streamingProvidersLoading;

  /// Message when no provider information is available
  ///
  /// In en, this message translates to:
  /// **'Streaming information not available'**
  String get streamingProvidersNotAvailable;

  /// Error message when getting providers fails
  ///
  /// In en, this message translates to:
  /// **'Error getting streaming providers'**
  String get streamingProvidersError;

  /// Button to retry getting providers
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get streamingProvidersRetry;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt': {
  switch (locale.countryCode) {
    case 'BR': return AppLocalizationsPtBr();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
