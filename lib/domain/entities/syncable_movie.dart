import './movie.dart';

class SyncableMovie {
  final Movie movie;
  final String supabaseId;

  SyncableMovie({required this.movie, required this.supabaseId});
}
