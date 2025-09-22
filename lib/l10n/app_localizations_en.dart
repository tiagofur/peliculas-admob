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
  String get portuguese => 'Portuguese';

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
  String get noWatchedMovies => 'You haven\'t watched any movies';

  @override
  String get noWatchedMoviesMessage =>
      'Movies you mark as watched will appear here.';

  @override
  String get emptyWatchlist => 'Your watchlist is empty';

  @override
  String get emptyWatchlistMessage =>
      'Movies you add to your watchlist will appear here.';

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

  @override
  String get conflictResolution => 'Conflict Resolution';

  @override
  String get conflictDetected => 'Synchronization Conflict Detected';

  @override
  String get conflictDescription =>
      'A conflict has been detected during synchronization. Please choose how to resolve it:';

  @override
  String get localVersion => 'Local Version';

  @override
  String get remoteVersion => 'Remote Version';

  @override
  String get mergedVersion => 'Merged Version';

  @override
  String get keepLocal => 'Keep Local';

  @override
  String get keepRemote => 'Keep Remote';

  @override
  String get mergeChanges => 'Merge Changes';

  @override
  String get manualChoice => 'Manual Choice';

  @override
  String get resolveConflict => 'Resolve Conflict';

  @override
  String get cancel => 'Cancel';

  @override
  String get conflictPreview => 'Conflict Preview';

  @override
  String get mergePreview => 'Merge Preview';

  @override
  String get conflictHistory => 'Conflict History';

  @override
  String get noConflictsRecorded => 'No conflicts recorded';

  @override
  String get conflictsWillAppearHere =>
      'Synchronization conflicts will appear here when they occur';

  @override
  String get refresh => 'Refresh';

  @override
  String get export => 'Export';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get filters => 'Filters';

  @override
  String get searchPlaceholder => 'Search by entity, type or strategy...';

  @override
  String get all => 'All';

  @override
  String get concurrentModification => 'Concurrent Modification';

  @override
  String get deleteVsModify => 'Delete vs Modify';

  @override
  String get duplicateCreation => 'Duplicate Creation';

  @override
  String get localWins => 'Local Wins';

  @override
  String get remoteWins => 'Remote Wins';

  @override
  String get merge => 'Merge';

  @override
  String get userChoice => 'Manual Choice';

  @override
  String get resolved => 'Resolved';

  @override
  String get pending => 'Pending';

  @override
  String get entity => 'Entity';

  @override
  String get detected => 'Detected';

  @override
  String get strategy => 'Strategy';

  @override
  String get reason => 'Reason';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get developedBy => 'Developed by';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get helpAndSupport => 'Help and Support';

  @override
  String get faq => 'Frequently Asked Questions (FAQ)';

  @override
  String get howToAddMovieToWatchlist =>
      'How can I add a movie to my watchlist?';

  @override
  String get howToAddMovieToWatchlistAnswer =>
      'To add a movie, simply go to the movie details and press the \'Add to Watchlist\' icon.';

  @override
  String get howDoesSyncWork => 'How does synchronization work?';

  @override
  String get howDoesSyncWorkAnswer =>
      'Your data is automatically synchronized across all your devices when you have an internet connection. If you are offline, the changes will be saved locally and will be synchronized the next time you connect.';

  @override
  String get howToContactSupport => 'How do I contact support?';

  @override
  String get howToContactSupportAnswer =>
      'You can contact us by email at: support@moviesapp.com';

  @override
  String get easy => 'Easy';

  @override
  String get medium => 'Medium';

  @override
  String get hard => 'Hard';

  @override
  String get expert => 'Expert';

  @override
  String get progress => 'Progress';

  @override
  String progressPercentage(String value) {
    return '$value% complete';
  }

  @override
  String points(String value) {
    return '$value points';
  }

  @override
  String get completed => 'Completed';

  @override
  String get expired => 'Expired';

  @override
  String get noChallengesAvailable => 'No challenges available';

  @override
  String get yourChallengeStats => 'Your Challenge Stats';

  @override
  String get active => 'Active';

  @override
  String get moviesWatched => 'Movies Watched';

  @override
  String get reviewsWritten => 'Reviews Written';

  @override
  String get moviesShared => 'Movies Shared';

  @override
  String get genresExplored => 'Genres Explored';

  @override
  String engagementScore(String value) {
    return 'Engagement Score: $value%';
  }

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(String value) {
    return '${value}m ago';
  }

  @override
  String hoursAgo(String value) {
    return '${value}h ago';
  }

  @override
  String daysAgo(String value) {
    return '${value}d ago';
  }

  @override
  String badges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count badges',
      one: '1 badge',
    );
    return '$_temp0';
  }

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String hoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours left',
      one: '1 hour left',
    );
    return '$_temp0';
  }

  @override
  String minutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes left',
      one: '1 minute left',
    );
    return '$_temp0';
  }
}
