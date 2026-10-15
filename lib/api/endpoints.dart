const String TMDB_API_KEY = "21c391eeb52e20048513ce13e564118d";
const String TMDB_API_BASE_URL = "https://api.themoviedb.org/3";

class Endpoints {
  /// How many years back the discovery feeds look when deciding what counts as
  /// "current". Browsing is meant to surface recent releases, so endpoints that
  /// sort by popularity are bounded to this window instead of returning hugely
  /// popular classics from every past decade.
  static const int recentWindowYears = 2;

  /// `YYYY-MM-DD` for the oldest release date inside the recent window.
  static String _recentSince() {
    final DateTime now = DateTime.now();
    return _formatDate(
      DateTime(now.year - recentWindowYears, now.month, now.day),
    );
  }

  /// Today as `YYYY-MM-DD`, the newest release date the browse feeds allow so
  /// unreleased titles are left out.
  static String _today() => _formatDate(DateTime.now());

  /// Tomorrow as `YYYY-MM-DD`, the oldest release date the "coming soon" feed
  /// allows. Starting here rather than today keeps titles opening today out of
  /// the results, matching the screen's own idea that today's films have opened.
  static String _tomorrow() {
    final DateTime now = DateTime.now();
    return _formatDate(DateTime(now.year, now.month, now.day + 1));
  }

  static String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String discoverMoviesUrl(int page) {
    return '$TMDB_API_BASE_URL/discover/movie?api_key=$TMDB_API_KEY'
        '&language=en-US&sort_by=popularity.desc'
        '&include_adult=false&include_video=false&page=$page'
        '&primary_release_date.gte=${_recentSince()}'
        '&primary_release_date.lte=${_today()}';
  }

  static String nowPlayingMoviesUrl(int page) {
    return '$TMDB_API_BASE_URL/movie/now_playing?api_key=$TMDB_API_KEY'
        '&include_adult=false&page=$page';
  }

  static String getCreditsUrl(int id) {
    return '$TMDB_API_BASE_URL/movie/$id/credits?api_key=$TMDB_API_KEY';
  }

  static String topRatedUrl(int page) {
    return '$TMDB_API_BASE_URL/movie/top_rated?api_key=$TMDB_API_KEY'
        '&include_adult=false&page=$page';
  }

  static String popularMoviesUrl(int page) {
    return '$TMDB_API_BASE_URL/movie/popular?api_key=$TMDB_API_KEY'
        '&include_adult=false&page=$page';
  }

  /// Movies that have not opened yet, ordered by how soon they arrive.
  ///
  /// Built from `discover` rather than the curated `movie/upcoming` list, which
  /// is a fixed regional window that can still contain titles already playing.
  /// The window starts tomorrow and runs to a [horizonMonths]-month horizon, and
  /// the sort is by release date, so the feed is genuinely "not out yet" and is
  /// recalculated from the calendar every time it is called.
  static String upcomingMoviesUrl(int page, {int horizonMonths = 9}) {
    final DateTime now = DateTime.now();
    final DateTime until = DateTime(now.year, now.month + horizonMonths, now.day);
    return '$TMDB_API_BASE_URL/discover/movie?api_key=$TMDB_API_KEY'
        '&language=en-US'
        '&sort_by=primary_release_date.asc'
        '&include_adult=false'
        '&include_video=false'
        '&page=$page'
        '&primary_release_date.gte=${_tomorrow()}'
        '&primary_release_date.lte=${_formatDate(until)}';
  }

  /// The last day of the current month as `YYYY-MM-DD`.
  static String _monthEnd() {
    final DateTime now = DateTime.now();
    // Day 0 of next month rolls back to the final day of the current one.
    return _formatDate(DateTime(now.year, now.month + 1, 0));
  }

  /// Movies opening between tomorrow and the end of the current month, soonest
  /// first. The lower bound excludes anything that has already opened, and the
  /// whole window is recalculated from the calendar on every call, so a title
  /// drops off the list as soon as its release date arrives.
  static String upcomingMoviesThisMonthUrl(int page) {
    return '$TMDB_API_BASE_URL/discover/movie?api_key=$TMDB_API_KEY'
        '&language=en-US'
        '&sort_by=primary_release_date.asc'
        '&include_adult=false'
        '&include_video=false'
        '&page=$page'
        '&primary_release_date.gte=${_tomorrow()}'
        '&primary_release_date.lte=${_monthEnd()}';
  }

  /// TV titles (series, shows and anime) premiering between tomorrow and the end
  /// of the current month, soonest first. Anime is not split out here: it shares
  /// the TV catalogue and is told apart from other series by language and genre.
  static String upcomingTVThisMonthUrl(int page) {
    return '$TMDB_API_BASE_URL/discover/tv?api_key=$TMDB_API_KEY'
        '&language=en-US'
        '&sort_by=first_air_date.asc'
        '&include_adult=false'
        '&page=$page'
        '&first_air_date.gte=${_tomorrow()}'
        '&first_air_date.lte=${_monthEnd()}';
  }

  static String movieDetailsUrl(int movieId) {
    return '$TMDB_API_BASE_URL/movie/$movieId?api_key=$TMDB_API_KEY&append_to_response=credits,images';
  }

  static String genresUrl() {
    return '$TMDB_API_BASE_URL/genre/movie/list?api_key=$TMDB_API_KEY&language=en-US';
  }

  static String getMoviesForGenre(int genreId, int page) {
    return '$TMDB_API_BASE_URL/discover/movie?api_key=$TMDB_API_KEY'
        '&language=en-US'
        '&sort_by=popularity.desc'
        '&include_adult=false'
        '&include_video=false'
        '&page=$page'
        '&with_genres=$genreId'
        '&primary_release_date.gte=${_recentSince()}'
        '&primary_release_date.lte=${_today()}';
  }

  static String movieReviewsUrl(int movieId, int page) {
    return '$TMDB_API_BASE_URL/movie/$movieId/reviews?api_key=$TMDB_API_KEY'
        '&language=en-US&page=$page';
  }

  static String movieSearchUrl(String query) {
    return "$TMDB_API_BASE_URL/search/movie?query=$query&api_key=$TMDB_API_KEY";
  }

  static String personSearchUrl(String query) {
    return "$TMDB_API_BASE_URL/search/person?query=$query&api_key=$TMDB_API_KEY";
  }

  static String getPerson(int personId) {
    return "$TMDB_API_BASE_URL/person/$personId?api_key=$TMDB_API_KEY&append_to_response=movie_credits";
  }

  static String getMovieVideos(int movieId) {
    return "$TMDB_API_BASE_URL/movie/$movieId/videos?api_key=$TMDB_API_KEY";
  }

  /// Legal streaming, rental and purchase options for a title.
  ///
  /// Backed by JustWatch data, so the links are the rights holders' own pages
  /// rather than a third-party scraper. [region] is the ISO 3166-1 alpha-2
  /// country code the availability should be reported for; omitting it makes
  /// TMDB guess from the caller's IP, which is wrong for a VPN or a server.
  static String watchProvidersUrl(int movieId, String region) {
    return "$TMDB_API_BASE_URL/movie/$movieId/watch/providers"
        '?api_key=$TMDB_API_KEY&language=en-US&watch_region=${region.toUpperCase()}';
  }

  /// The Blender open-movie catalogue the download button draws from.
  ///
  /// These are feature films the creators published for free download, so
  /// fetching one is permitted by its licence. The app bundles a short
  /// hard-coded list of direct file URLs rather than scraping a third-party
  /// video site.
  static const List<String> openMovieTitles = <String>[
    'Big Buck Bunny',
    'Sintel',
    'Tears of Steel',
  ];

  // TV Shows endpoints
  static String discoverTVUrl(int page) {
    return '$TMDB_API_BASE_URL/discover/tv?api_key=$TMDB_API_KEY'
        '&language=en-US&sort_by=popularity.desc'
        '&include_adult=false&page=$page'
        '&first_air_date.gte=${_recentSince()}'
        '&first_air_date.lte=${_today()}';
  }

  static String topRatedTVUrl(int page) {
    return '$TMDB_API_BASE_URL/tv/top_rated?api_key=$TMDB_API_KEY'
        '&page=$page';
  }

  static String popularTVUrl(int page) {
    return '$TMDB_API_BASE_URL/tv/popular?api_key=$TMDB_API_KEY'
        '&page=$page';
  }

  static String airingTodayTVUrl(int page) {
    return '$TMDB_API_BASE_URL/tv/airing_today?api_key=$TMDB_API_KEY'
        '&page=$page';
  }

  static String tvSearchUrl(String query) {
    return "$TMDB_API_BASE_URL/search/tv?query=$query&api_key=$TMDB_API_KEY";
  }

  static String getTVDetailsUrl(int tvId) {
    return '$TMDB_API_BASE_URL/tv/$tvId?api_key=$TMDB_API_KEY&append_to_response=credits,images';
  }

  static String getTVVideos(int tvId) {
    return "$TMDB_API_BASE_URL/tv/$tvId/videos?api_key=$TMDB_API_KEY";
  }

  static String getTVGenres() {
    return '$TMDB_API_BASE_URL/genre/tv/list?api_key=$TMDB_API_KEY&language=en-US';
  }

  static String getTVForGenre(int genreId, int page) {
    return '$TMDB_API_BASE_URL/discover/tv?api_key=$TMDB_API_KEY'
        '&language=en-US'
        '&sort_by=popularity.desc'
        '&page=$page'
        '&with_genres=$genreId'
        '&first_air_date.gte=${_recentSince()}'
        '&first_air_date.lte=${_today()}';
  }

  /// Anime, isolated the conventional way: TMDB has no dedicated anime list, so
  /// this pairs the Animation genre (16) with a Japanese original language.
  static String discoverAnimeUrl(int page) {
    return '$TMDB_API_BASE_URL/discover/tv?api_key=$TMDB_API_KEY'
        '&language=en-US&sort_by=popularity.desc'
        '&include_adult=false&page=$page'
        '&with_genres=16'
        '&with_original_language=ja'
        '&first_air_date.gte=${_recentSince()}'
        '&first_air_date.lte=${_today()}';
  }

  /// Anime within one TV genre, filtered to Japanese animation.
  static String getAnimeForGenre(int genreId, int page) {
    return '$TMDB_API_BASE_URL/discover/tv?api_key=$TMDB_API_KEY'
        '&language=en-US'
        '&sort_by=popularity.desc'
        '&page=$page'
        '&with_genres=$genreId'
        '&with_original_language=ja'
        '&first_air_date.gte=${_recentSince()}'
        '&first_air_date.lte=${_today()}';
  }
}
