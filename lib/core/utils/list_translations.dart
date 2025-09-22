import '../../l10n/app_localizations.dart';

/// Helper class to get translated names and descriptions for default lists
class ListTranslations {
  /// Get translated name for a default list
  static String getListName(String listId, AppLocalizations localizations) {
    switch (listId) {
      case 'en-familia':
        return localizations.familyFriendly;
      case 'en-pareja':
        return localizations.dateNight;
      case 'clasicos':
        return localizations.classics;
      case 'sugeridas':
        return localizations.suggested;
      case 'con-amigos':
        return localizations.withFriends;
      case 'noches-lluvia':
        return localizations.rainyNights;
      case 'cortas':
        return localizations.shortMovies;
      case 'por-ver':
        return localizations.toWatch;
      case 'para-relajarse':
        return localizations.chillingMovies;
      case 'romanticas':
        return localizations.romanticMovies;
      case 'divertidas':
        return localizations.funMovies;
      case 'clasicos-pendientes':
        return localizations.pendingClassics;
      case 'accion-aventura':
        return localizations.actionAdventure;
      case 'dias-lluviosos':
        return localizations.rainyDayMovies;
      default:
        return listId; // fallback to the ID if no translation found
    }
  }

  /// Get translated description for a default list
  static String getListDescription(
      String listId, AppLocalizations localizations) {
    switch (listId) {
      case 'en-familia':
        return localizations.familyFriendlyDescription;
      case 'en-pareja':
        return localizations.dateNightDescription;
      case 'clasicos':
        return localizations.classicsDescription;
      case 'sugeridas':
        return localizations.suggestedDescription;
      case 'con-amigos':
        return localizations.withFriendsDescription;
      case 'noches-lluvia':
        return localizations.rainyNightsDescription;
      case 'cortas':
        return localizations.shortMoviesDescription;
      case 'por-ver':
        return localizations.toWatchDescription;
      case 'para-relajarse':
        return localizations.chillingMoviesDescription;
      case 'romanticas':
        return localizations.romanticMoviesDescription;
      case 'divertidas':
        return localizations.funMoviesDescription;
      case 'clasicos-pendientes':
        return localizations.pendingClassicsDescription;
      case 'accion-aventura':
        return localizations.actionAdventureDescription;
      case 'dias-lluviosos':
        return localizations.rainyDayMoviesDescription;
      default:
        return ''; // fallback to empty string
    }
  }

  /// Check if a list ID corresponds to a default/system list
  static bool isDefaultList(String listId) {
    const defaultListIds = {
      'en-familia',
      'en-pareja',
      'clasicos',
      'sugeridas',
      'con-amigos',
      'noches-lluvia',
      'cortas',
      'por-ver',
      'para-relajarse',
      'romanticas',
      'divertidas',
      'clasicos-pendientes',
      'accion-aventura',
      'dias-lluviosos',
    };
    return defaultListIds.contains(listId);
  }
}
