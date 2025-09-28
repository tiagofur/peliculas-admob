const String _tmdbImageBaseUrl = 'https://image.tmdb.org/t/p';
const String _defaultPosterUrl =
    'https://www.movienewz.com/img/films/poster-holder.jpg';
const String _defaultBackdropUrl =
    'https://sd.keepcalms.com/i-w600/keep-calm-poster-not-found.jpg';

String resolvePosterUrl(
  String? path, {
  String size = 'w500',
  String fallback = _defaultPosterUrl,
}) =>
    resolveTmdbImageUrl(path, size: size, fallback: fallback);

String resolveBackdropUrl(
  String? path, {
  String size = 'w500',
  String fallback = _defaultBackdropUrl,
}) =>
    resolveTmdbImageUrl(path, size: size, fallback: fallback);

String resolveTmdbImageUrl(
  String? path, {
  String size = 'w500',
  String fallback = _defaultPosterUrl,
}) {
  return _resolveImageUrl(path, size: size, fallback: fallback);
}

String _resolveImageUrl(
  String? path, {
  required String size,
  required String fallback,
}) {
  if (path == null || path.trim().isEmpty) {
    return fallback;
  }

  final normalized = path.trim();
  if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
    return normalized;
  }

  final separator = normalized.startsWith('/') ? '' : '/';
  return '$_tmdbImageBaseUrl/$size$separator$normalized';
}
