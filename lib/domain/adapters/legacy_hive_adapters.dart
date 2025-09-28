import 'package:hive/hive.dart';

import '../entities/movie.dart';

/// Legacy adapters to support reading data saved with older Hive type IDs.
final MovieAdapter _movieAdapterDelegate = MovieAdapter();
final LegacyMovieAdapter32 _legacyAdapter32Instance =
    LegacyMovieAdapter32._internal();

void ensureMovieAdaptersRegistered() {
  if (!Hive.isAdapterRegistered(_movieAdapterDelegate.typeId)) {
    Hive.registerAdapter(_movieAdapterDelegate);
  }
  if (!Hive.isAdapterRegistered(_legacyAdapter32Instance.typeId)) {
    Hive.registerAdapter(_legacyAdapter32Instance);
  }
}

class LegacyMovieAdapter32 extends TypeAdapter<Movie> {
  LegacyMovieAdapter32() : this._internal();

  LegacyMovieAdapter32._internal();

  static final MovieAdapter _delegate = MovieAdapter();

  @override
  final int typeId = 32;

  @override
  Movie read(BinaryReader reader) {
    return _delegate.read(reader);
  }

  @override
  void write(BinaryWriter writer, Movie obj) {
    _delegate.write(writer, obj);
  }
}
