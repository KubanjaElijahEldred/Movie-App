const String tmdbApiBaseUrl = "https://api.themoviedb.org/3";
const String tmdbApiKey = "21c391eeb52e20048513ce13e564118d";
const String tmdbBaseImageUrl = "https://image.tmdb.org/t/p/";
const String TMDB_BASE_IMAGE_URL = "https://image.tmdb.org/t/p/";

/// Builds a TMDB image URL, or null when the title has no image at all.
///
/// Concatenating an empty path produced ".../w500/", which TMDB answers with a
/// 404. Placed inside a BoxDecoration that surfaces as an uncaught exception,
/// because DecorationImage has no errorBuilder. Several upcoming and trending
/// titles genuinely have no poster_path, so callers must handle null.
String? tmdbImageUrl(String? path, {String size = 'w500'}) {
  if (path == null || path.isEmpty) return null;
  return '$TMDB_BASE_IMAGE_URL$size$path';
}
