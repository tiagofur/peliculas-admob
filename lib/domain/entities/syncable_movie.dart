import './movie.dart';

class SyncableMovie {
  SyncableMovie({required this.movie, required this.supabaseId});
  final Movie movie;
  final String supabaseId;
}
