import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movies/api/endpoints.dart';
import 'package:movies/services/download_service.dart';
import 'package:movies/constants/api_constants.dart';
import 'package:movies/constants/app_theme.dart';
import 'package:movies/modal_class/function.dart';
import 'package:movies/modal_class/genres.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/modal_class/video.dart';
import 'package:movies/screens/browse_page.dart';
import 'package:movies/screens/coming_soon_page.dart';
import 'package:movies/screens/downloaded_page.dart';
import 'package:movies/screens/favorites_page.dart';
import 'package:movies/screens/home_sections.dart';
import 'package:movies/screens/login.dart';
import 'package:movies/screens/movie_detail.dart';
import 'package:movies/screens/settings_page.dart';
import 'package:movies/screens/support_page.dart';
import 'package:movies/screens/trailer_player.dart';

class ElijahDashboard extends StatefulWidget {
  @override
  _ElijahDashboardState createState() => _ElijahDashboardState();
}

class _ElijahDashboardState extends State<ElijahDashboard> {
  /// Lets the mobile app bar open and close the navigation drawer.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Movie>? trendingMovies;

  /// Slides for the top banner. Sourced from TMDB's "now playing" list so the
  /// banner rotates through the newest releases, falling back to the trending
  /// feed if that request comes back empty.
  List<Movie> heroMovies = const <Movie>[];
  List<Movie>? continueWatching;
  List<Movie>? topRated;
  List<Movie>? recentDownloads;
  List<Movie>? bookmarked;
  List<Movie>? popular;
  List<Movie>? recommended;
  List<Genres> genres = [];
  List<int> bookmarkedIds = []; // Track bookmarked movie IDs
  List<int> watchlistIds = []; // Track watchlist movie IDs
  bool isLoading = true;
  bool isLoadingGenre = false;
  String selectedTab = 'Movie';
  String selectedGenre = 'Action';
  String currentPage = 'Home';
  TextEditingController searchController = TextEditingController();
  List<Movie>? searchResults;

  /// Lets the mobile app bar jump straight to the search box.
  final GlobalKey _searchFieldKey = GlobalKey();
  final FocusNode _searchFocusNode = FocusNode();

  /// Drives the top banner slideshow.
  final PageController _heroController = PageController();
  Timer? _heroTimer;
  int _heroPage = 0;

  /// Owns every download so progress survives navigating between pages.
  final DownloadService _downloadService = DownloadService();

  /// How long each banner slide stays up.
  static const Duration _heroInterval = Duration(seconds: 5);

  /// Movies for the Discovery page, loaded per genre.
  List<Movie> genreMovies = [];

  /// Whether the right sidebar sections are showing all their titles.
  bool showAllPopular = false;
  bool showAllRecommended = false;

  /// Rows shown on the redesigned home page: a recent release row plus one row
  /// per genre.
  List<Movie> recentMovies = <Movie>[];
  final Map<String, List<Movie>> genreRows = <String, List<Movie>>{};
  bool isLoadingRows = true;

  /// The genre rows on the home page, in display order.
  ///
  /// Series pulls from the TV endpoints because a genre list of films would
  /// not be a series row.
  static const List<_GenreRow> _homeRows = <_GenreRow>[
    _GenreRow('Action', 28, Icons.local_fire_department_outlined),
    _GenreRow('Adventure', 12, Icons.explore_outlined),
    _GenreRow('Sci-Fi', 878, Icons.rocket_launch_outlined),
    _GenreRow('Drama', 18, Icons.theater_comedy_outlined),
    _GenreRow('Horror', 27, Icons.dark_mode_outlined),
    _GenreRow('Thriller', 53, Icons.bolt_outlined),
    _GenreRow('Series', 0, Icons.live_tv_outlined, isSeries: true),
  ];

  /// How many titles each row keeps. TMDB returns 20 per page, so every row
  /// shows well over ten.
  static const int _moviesPerRow = 14;

  /// The movies the user has actually bookmarked, resolved from every list the
  /// dashboard has loaded so the Bookmarked page shows real titles.
  List<Movie> get bookmarkedMovies {
    final Map<int, Movie> byId = <int, Movie>{};
    for (final List<Movie>? list in <List<Movie>?>[
      trendingMovies,
      topRated,
      popular,
      recommended,
      continueWatching,
      recentDownloads,
      genreMovies,
    ]) {
      if (list == null) continue;
      for (final Movie movie in list) {
        final int? id = movie.id;
        if (id != null && bookmarkedIds.contains(id)) byId[id] = movie;
      }
    }
    return byId.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadHomeRows();
  }

  void _onHeroPageChanged(int page) {
    setState(() => _heroPage = page);
  }

  /// Starts the auto-advance timer, replacing any existing one.
  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (heroMovies.length < 2) return;
    _heroTimer = Timer.periodic(_heroInterval, (Timer timer) {
      if (!mounted || !_heroController.hasClients) return;
      if (!_heroController.position.isScrollingNotifier.value) {
        final int next = (_heroPage + 1) % heroMovies.length;
        _heroController.animateToPage(
          next,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    _downloadService.dispose();
    searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Puts the cursor in the search box. If the user is on a pushed screen such
  /// as Coming soon there is no top bar, so return to Home first.
  void _focusSearch() {
    if (_searchFieldKey.currentContext == null) {
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      setState(() {
        currentPage = 'Home';
        searchResults = null;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final genresList = await fetchGenres();
      List<Movie> trending;
      List<Movie> rated;
      List<Movie> popular;

      // Load different content based on selected tab
      if (selectedTab == 'Series' || selectedTab == 'TV Shows') {
        // For TV shows, we'll use movie API temporarily
        // In production, you'd use TV-specific endpoints
        trending = await fetchMovies(Endpoints.discoverMoviesUrl(1));
        rated = await fetchMovies(Endpoints.topRatedUrl(1));
        popular = await fetchMovies(Endpoints.popularMoviesUrl(1));
      } else {
        trending = await fetchMovies(Endpoints.discoverMoviesUrl(1));
        rated = await fetchMovies(Endpoints.topRatedUrl(1));
        popular = await fetchMovies(Endpoints.popularMoviesUrl(1));
      }

      // The banner rotates through the seven newest releases, so it wants
      // "now playing" rather than the popularity-sorted trending feed.
      List<Movie> nowPlaying = const <Movie>[];
      try {
        nowPlaying = await fetchMovies(Endpoints.nowPlayingMoviesUrl(1));
      } catch (_) {
        // Not fatal: the banner falls back to trending below.
      }

      setState(() {
        genres = genresList.genres ?? [];
        trendingMovies = trending;
        heroMovies = _pickHeroSlides(nowPlaying, trending);
        topRated = rated;
        // Safe to call inside setState: the timer only touches the controller
        // once the frame is built.
        if (heroMovies.length > 1) _startHeroTimer();
        continueWatching = trending.take(4).toList();
        recentDownloads = popular.take(10).toList();
        bookmarked = rated.take(4).toList();
        this.popular = rated.take(3).toList();
        this.recommended = popular.take(3).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  /// Number of slides the top banner rotates through.
  static const int _heroSlideCount = 7;

  /// Chooses the banner slides, preferring the newest releases.
  ///
  /// Only titles with artwork are kept, because a slide with neither a backdrop
  /// nor a poster would render as an empty panel. Falls back to the trending
  /// feed when "now playing" is empty or unusable, and de-duplicates by id so
  /// the same film never occupies two slides.
  List<Movie> _pickHeroSlides(List<Movie> nowPlaying, List<Movie> trending) {
    final List<Movie> source = nowPlaying.isNotEmpty ? nowPlaying : trending;
    final List<Movie> slides = <Movie>[];
    final Set<int> seen = <int>{};

    for (final Movie movie in source) {
      if (slides.length == _heroSlideCount) break;
      if (movie.id != null && !seen.add(movie.id!)) continue;
      if (movie.backdropPath == null && movie.posterPath == null) continue;
      slides.add(movie);
    }
    return slides;
  }

  // Navigate to movie details
  void _watchMovie(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailPage(
          movie: movie,
          themeData: Theme.of(context),
          heroId: '${movie.id}',
          genres: genres,
          downloadService: _downloadService,
        ),
      ),
    );
  }

  // Toggle bookmark
  void _toggleBookmark(Movie movie) {
    setState(() {
      if (bookmarkedIds.contains(movie.id)) {
        bookmarkedIds.remove(movie.id);
        _showSnackBar('Removed from bookmarks', Icons.bookmark_remove);
      } else {
        bookmarkedIds.add(movie.id!);
        _showSnackBar('Added to bookmarks', Icons.bookmark_added);
      }
    });
  }
  // Toggle watchlist
  void _toggleWatchlist(Movie movie) {
    setState(() {
      if (watchlistIds.contains(movie.id)) {
        watchlistIds.remove(movie.id);
        _showSnackBar('Removed from watchlist', Icons.remove_circle);
      } else {
        watchlistIds.add(movie.id!);
        _showSnackBar('Added to watchlist', Icons.add_circle);
      }
    });
  }

  /// Titles with a finished download on disk, resolved from every list the
  /// dashboard has loaded so the Downloaded page shows real files.
  List<Movie> get _downloadedMovies {
    final Map<int, Movie> byId = <int, Movie>{};
    for (final List<Movie>? list in <List<Movie>?>[
      trendingMovies,
      topRated,
      popular,
      recommended,
      continueWatching,
      recentDownloads,
      genreMovies,
      heroMovies,
    ]) {
      for (final Movie movie in list ?? const <Movie>[]) {
        if (movie.id != null) byId[movie.id!] = movie;
      }
    }

    return byId.entries
        .where((MapEntry<int, Movie> entry) =>
            _downloadService.isDownloaded(entry.key))
        .map((MapEntry<int, Movie> entry) => entry.value)
        .toList();
  }

  /// Drops a title from the Downloaded page so its Remove button is a real
  /// action rather than a placeholder.
  void _removeDownload(Movie movie) {
    _downloadService.remove(movie.id);
    setState(() {
      recentDownloads?.removeWhere((Movie m) => m.id == movie.id);
    });
    _showSnackBar('Removed ${movie.title ?? 'title'}', Icons.delete_outline);
  }

  // Show snackbar feedback
  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppPalette.brand,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// A cover-fitted TMDB image decoration, or null when the title has no image.
  ///
  /// Returning null keeps a missing poster_path from becoming a 404, which
  /// inside a BoxDecoration is reported as an uncaught error, because
  /// DecorationImage has no errorBuilder.
  DecorationImage? _coverImage(String? path, {String size = 'w500'}) {
    final String? url = tmdbImageUrl(path, size: size);
    return url == null
        ? null
        : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover);
  }

  // Search movies
  Future<void> _searchMovies(String query) async {
    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }

    try {
      final List<Movie> results =
          await fetchMovies(Endpoints.movieSearchUrl(query.trim()));
      if (!mounted) return;
      setState(() => searchResults = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => searchResults = const <Movie>[]);
      _showSnackBar('Search failed', Icons.error);
    }
  }

  /// Drops the search overlay and returns to the active sidebar page.
  void _clearSearch() {
    searchController.clear();
    if (searchResults == null) return;
    setState(() => searchResults = null);
  }

  /// Fetches a list, turning a failure into an empty list so one bad genre
  /// request cannot empty every row on the home page.
  Future<List<Movie>> _safeFetch(String url) async {
    try {
      return await fetchMovies(url);
    } catch (_) {
      return <Movie>[];
    }
  }

  /// Loads the Recent movies row and every genre row in parallel, so the home
  /// page paints its sections as one block instead of eight separate spinners.
  Future<void> _loadHomeRows() async {
    if (mounted) setState(() => isLoadingRows = true);

    final List<List<Movie>> results = await Future.wait<List<Movie>>(
      <Future<List<Movie>>>[
        _safeFetch(Endpoints.nowPlayingMoviesUrl(1)),
        for (final _GenreRow row in _homeRows)
          _safeFetch(
            row.isSeries
                ? Endpoints.popularTVUrl(1)
                : Endpoints.getMoviesForGenre(row.genreId, 1),
          ),
      ],
    );
    if (!mounted) return;

    setState(() {
      recentMovies = results.first.take(_moviesPerRow).toList();
      genreRows.clear();
      for (int i = 0; i < _homeRows.length; i++) {
        final List<Movie> movies = results[i + 1];
        if (movies.isEmpty) continue;
        genreRows[_homeRows[i].label] = movies.take(_moviesPerRow).toList();
      }
      isLoadingRows = false;
    });
  }

  // Filter by genre
  Future<void> _filterByGenre(String genreName) async {
    setState(() {
      selectedGenre = genreName;
      isLoading = true;
    });

    try {
      // Find genre ID from name
      final genre = genres.firstWhere(
        (g) => g.name == genreName,
        orElse: () => Genres(id: 28, name: 'Action'), // Default to Action
      );

      final filtered =
          await fetchMovies(Endpoints.getMoviesForGenre(genre.id!, 1));
      setState(() {
        trendingMovies = filtered;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Failed to filter by genre', Icons.error);
    }
  }

  // Handle page navigation
  //
  // Collection pages (Home, Discovery, Community, Recent, Top rated,
  // Downloaded) swap the main content in place so the shell and sidebar stay
  // put. Pages that already exist as their own screen are pushed on top, and
  // Logout is a destructive action so it opens a confirmation dialog.
  Future<void> _navigateToPage(String page) async {
    // Close the mobile drawer first so the destination is visible. The drawer
    // is a local history entry on this Navigator, so popping closes it.
    final ScaffoldState? scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
    }

    switch (page) {
      case 'Coming soon':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ComingSoonPage(genres: genres)),
        );
        return;

      case 'Settings':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => SettingsPage()));
        return;

      case 'Help':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => SupportPage()));
        return;

      case 'Bookmarked':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FavoritesPage(genres: genres, movies: bookmarkedMovies),
          ),
        );
        return;

      case 'Logout':
        final bool confirmed = await _confirmLogout();
        if (confirmed && mounted) {
          await Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (_) => LoginScreen(themeData: Theme.of(context))),
            (Route<dynamic> route) => false,
          );
        }
        return;

      default:
        // A collection page. Discovery needs its own data before it is shown.
        if (page == 'Discovery' && genreMovies.isEmpty) {
          await _loadGenreMovies(selectedGenre);
        }
        if (!mounted) return;
        setState(() => currentPage = page);
    }
  }

  Future<bool> _confirmLogout() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151827),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Log out?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'You will be returned to the sign in screen.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Log out',
                style: TextStyle(color: AppPalette.action),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Loads the catalogue for a genre, used by the Discovery page.
  Future<void> _loadGenreMovies(String genreName) async {
    setState(() {
      isLoadingGenre = true;
      selectedGenre = genreName;
    });

    try {
      final Genres genre = genres.firstWhere(
        (Genres g) => g.name == genreName,
        orElse: () => Genres(id: 28, name: 'Action'),
      );
      final List<Movie> filtered =
          await fetchMovies(Endpoints.getMoviesForGenre(genre.id!, 1));
      if (!mounted) return;
      setState(() {
        genreMovies = filtered;
        isLoadingGenre = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        genreMovies = [];
        isLoadingGenre = false;
      });
      _showSnackBar('Could not load $genreName', Icons.error);
    }
  }

  /// Below this width the layout is too cramped for a permanent sidebar, so the
  /// sidebar is replaced by a bottom navigation bar.
  static const double _drawerBreakpoint = 900;

  /// The right sidebar is a third column, so it needs real room to sit beside
  /// the main content rather than under it.
  static const double _rightSidebarBreakpoint = 1180;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isNarrow = constraints.maxWidth < _drawerBreakpoint;
        final bool showRightSidebar =
            constraints.maxWidth >= _rightSidebarBreakpoint;

        final Widget content = isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppPalette.brand),
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                      child: _buildMainContent(
                          showRightSidebar: showRightSidebar)),
                  if (showRightSidebar) _buildRightSidebar(),
                ],
              );

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppPalette.background,
          body: Row(
            children: <Widget>[
              if (!isNarrow) _buildLeftSidebar(),
              Expanded(
                child: isNarrow
                    ? Column(
                        children: <Widget>[
                          _buildMobileAppBar(),
                          Expanded(child: content),
                        ],
                      )
                    : content,
              ),
            ],
          ),
          bottomNavigationBar: isNarrow ? _buildBottomNavBar() : null,
        );
      },
    );
  }

  /// The bottom destinations on narrow screens. These mirror the permanent
  /// sidebar so both layouts reach the same pages.
  static const List<({String page, IconData icon, IconData activeIcon})>
      _navDestinations = <({String page, IconData icon, IconData activeIcon})>[
    (page: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    (
      page: 'Discovery',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore
    ),
    (
      page: 'Downloaded',
      icon: Icons.download_outlined,
      activeIcon: Icons.download_done
    ),
    (
      page: 'Bookmarked',
      icon: Icons.bookmark_border,
      activeIcon: Icons.bookmark
    ),
  ];

  /// The bottom navigation bar that replaces the sidebar on phones.
  ///
  /// "More" opens a sheet with the destinations that do not fit, so nothing
  /// from the sidebar is unreachable without a drawer.
  Widget _buildBottomNavBar() {
    final int selected = _navDestinations.indexWhere(
      (({String page, IconData icon, IconData activeIcon}) d) => d.page == currentPage,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: <Widget>[
              for (final ({String page, IconData icon, IconData activeIcon}) d
                  in _navDestinations)
                Expanded(
                  child: _NavButton(
                    label: d.page,
                    icon: selected == _navDestinations.indexOf(d)
                        ? d.activeIcon
                        : d.icon,
                    isActive: selected == _navDestinations.indexOf(d),
                    onPressed: () => _navigateToPage(d.page),
                  ),
                ),
              Expanded(
                child: _NavButton(
                  label: 'More',
                  icon: Icons.more_horiz,
                  isActive: _isMoreActive,
                  onPressed: _openMoreSheet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// True when the active page is one of the destinations behind the More
  /// sheet, so the sheet's trigger shows as selected.
  bool get _isMoreActive => <String>{
        'Community',
        'Recent',
        'Top rated',
        'Coming soon',
        'Settings',
        'Help',
        'Logout',
      }.contains(currentPage);

  /// The destinations that do not fit in the bottom bar.
  static const List<({String page, IconData icon})> _moreDestinations =
      <({String page, IconData icon})>[
    (page: 'Community', icon: Icons.people_outline),
    (page: 'Recent', icon: Icons.access_time),
    (page: 'Top rated', icon: Icons.star_border),
    (page: 'Coming soon', icon: Icons.calendar_today_outlined),
    (page: 'Settings', icon: Icons.settings_outlined),
    (page: 'Help', icon: Icons.help_outline),
    (page: 'Logout', icon: Icons.logout),
  ];

  /// Opens the sheet holding the remaining destinations.
  Future<void> _openMoreSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    'More',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final ({String page, IconData icon}) d in _moreDestinations)
                  ListTile(
                    leading: Icon(
                      d.icon,
                      color: currentPage == d.page
                          ? AppPalette.brand
                          : AppPalette.textSecondary,
                    ),
                    title: Text(
                      d.page,
                      style: TextStyle(
                        color: currentPage == d.page
                            ? AppPalette.brand
                            : Colors.white70,
                        fontWeight: currentPage == d.page
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _navigateToPage(d.page);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Top bar for narrow screens. Carries the wordmark and quick access to
  /// search, which the permanent sidebar would otherwise provide.
  Widget _buildMobileAppBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: AppPalette.surface,
        child: Row(
          children: <Widget>[
            const _BrandMark(compact: true),
            const SizedBox(width: 10),
            Semantics(
              label: 'Play It',
              excludeSemantics: true,
              child: const Text(
                'Play It',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: _focusSearch,
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined, color: Colors.white70),
              onPressed: () => _navigateToPage('Settings'),
            ),
          ],
        ),
      ),
    );
  }

  /// The permanent sidebar shown on wide screens.
  Widget _buildLeftSidebar() {
    return Container(
      width: 200,
      color: AppPalette.surface,
      child: Column(
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Semantics(
              label: 'Play It',
              excludeSemantics: true,
              child: Row(
                children: <Widget>[
                  _BrandMark(),
                  SizedBox(width: 10),
                  Text(
                    'Play It',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 40),

          // Menu Section
          Padding(
            padding: EdgeInsets.only(left: 20, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MENU',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _buildMenuItem(Icons.home, 'Home', currentPage == 'Home'),
          _buildMenuItem(
              Icons.explore_outlined, 'Discovery', currentPage == 'Discovery'),
          _buildMenuItem(
              Icons.people_outline, 'Community', currentPage == 'Community'),
          _buildMenuItemWithNotif(
              Icons.calendar_today_outlined, 'Coming soon', false, true),

          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.only(left: 20, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'LIBRARY',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _buildMenuItem(Icons.access_time, 'Recent', currentPage == 'Recent'),
          _buildMenuItem(
              Icons.bookmark_border, 'Bookmarked', currentPage == 'Bookmarked'),
          _buildMenuItem(
              Icons.star_border, 'Top rated', currentPage == 'Top rated'),
          _buildMenuItem(Icons.download_outlined, 'Downloaded',
              currentPage == 'Downloaded'),

          Spacer(),
          _buildMenuItem(
              Icons.settings_outlined, 'Settings', currentPage == 'Settings'),
          _buildMenuItem(Icons.help_outline, 'Help', currentPage == 'Help'),
          _buildMenuItem(Icons.logout, 'Logout', currentPage == 'Logout'),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildServiceIcon(String asset, String text, Color color) {
    return InkWell(
      onTap: () => _showSnackBar('Filtering by $text content...', Icons.tv),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: text == 'tv+' ? Colors.black : Colors.white,
              fontSize:
                  text == 'N' ? 24 : (text == 'hulu' || text == 'tv+' ? 10 : 9),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, bool isActive) {
    return InkWell(
      onTap: () => _navigateToPage(label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? AppPalette.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isActive ? Colors.white : Colors.white60, size: 20),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white60,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemWithNotif(
      IconData icon, String label, bool isActive, bool hasNotif) {
    return InkWell(
      onTap: () => _navigateToPage(label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 15),
            Icon(icon, color: Colors.white60, size: 18),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
            if (hasNotif)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent({required bool showRightSidebar}) {
    return Container(
      color: const Color(0xFF0D0F1F),
      child: Column(
        children: <Widget>[
          _buildTopBar(),
          Expanded(child: _buildCurrentPageBody(showRightSidebar)),
        ],
      ),
    );
  }

  /// Routes the main content area to whichever sidebar page is active.
  Widget _buildCurrentPageBody(bool showRightSidebar) {
    // A search takes priority over the page underneath until it is cleared.
    final List<Movie>? results = searchResults;
    if (results != null) return _buildSearchResults(results);

    switch (currentPage) {
      case 'Discovery':
        return _buildDiscoveryPage();

      case 'Community':
        return BrowsePage(
          title: 'Community',
          subtitle:
              'What everyone is watching right now, ranked by TMDB popularity.',
          movies: trendingMovies ?? const <Movie>[],
          icon: Icons.people_outline,
          accent: const Color(0xFF7C5CFF),
          onTap: _watchMovie,
          onBookmark: _toggleBookmark,
          bookmarkedIds: bookmarkedIds,
        );

      case 'Recent':
        return BrowsePage(
          title: 'Recent',
          subtitle: 'Titles you have picked up recently.',
          movies: continueWatching ?? const <Movie>[],
          icon: Icons.access_time,
          accent: const Color(0xFF22D3EE),
          emptyTitle: 'Nothing recent yet',
          emptyMessage: 'Start watching something and it will show up here.',
          onTap: _watchMovie,
          onBookmark: _toggleBookmark,
          bookmarkedIds: bookmarkedIds,
        );

      case 'Top rated':
        return BrowsePage(
          title: 'Top rated',
          subtitle: 'The highest rated films on TMDB.',
          movies: topRated ?? const <Movie>[],
          icon: Icons.star_border,
          accent: AppPalette.brand,
          onTap: _watchMovie,
          onBookmark: _toggleBookmark,
          bookmarkedIds: bookmarkedIds,
        );

      case 'Downloaded':
        return DownloadedPage(
          // Only titles with a finished file belong here, rather than an
          // arbitrary slice of the popular feed.
          movies: _downloadedMovies,
          downloadService: _downloadService,
          bookmarkedIds: bookmarkedIds,
          onPlay: _watchMovie,
          onDetails: _watchMovie,
          onBookmark: _toggleBookmark,
          onRemove: _removeDownload,
          onDownloadMore: () => _navigateToPage('Discovery'),
        );

      case 'Home':
      default:
        return _buildHomePage(showRightSidebar);
    }
  }

  /// Results for the current search term, with a way to get back to the page
  /// that was open before searching.
  Widget _buildSearchResults(List<Movie> results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: <Widget>[
              Text(
                results.isEmpty
                    ? 'No matches'
                    : '${results.length} result${results.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                label: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BrowsePage(
            title: 'Search',
            subtitle: searchController.text.isEmpty
                ? 'Showing all titles.'
                : 'Matches for "${searchController.text}".',
            movies: results,
            icon: Icons.search,
            emptyTitle: 'No matches found',
            emptyMessage: 'Try a different title or keyword.',
            onTap: _watchMovie,
            onBookmark: _toggleBookmark,
            bookmarkedIds: bookmarkedIds,
          ),
        ),
      ],
    );
  }

  /// The default dashboard: a Recent movies row followed by one highlighted
  /// card per genre, each holding a scrollable row of titles. When the right
  /// sidebar has been moved below the fold (narrow screens) its content is
  /// appended instead of sitting beside.
  Widget _buildHomePage(bool showRightSidebar) {
    final List<Widget> sections = <Widget>[
      MovieRowSection(
        title: 'Recent movies',
        icon: Icons.new_releases_outlined,
        movies: recentMovies,
        isLoading: isLoadingRows,
        bookmarkedIds: bookmarkedIds,
        onTap: _watchMovie,
        onBookmark: _toggleBookmark,
      ),
      for (final _GenreRow row in _homeRows)
        MovieRowSection(
          title: row.label,
          icon: row.icon,
          movies: genreRows[row.label] ?? const <Movie>[],
          isLoading: isLoadingRows && !genreRows.containsKey(row.label),
          bookmarkedIds: bookmarkedIds,
          onTap: _watchMovie,
          onBookmark: _toggleBookmark,
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeroBanner(),
          const SizedBox(height: 26),
          RefreshIndicator(
            color: AppPalette.brand,
            backgroundColor: AppPalette.surface,
            onRefresh: _loadHomeRows,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                ...sections,
                if (!showRightSidebar) ...<Widget>[
                  const SizedBox(height: 8),
                  _buildRightSidebar(forStackedLayout: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Discovery is a genre browser rather than a plain list, so it gets its own
  /// layout with the genre chips above the results.
  Widget _buildDiscoveryPage() {
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              const Text(
                'Discovery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Browse the catalogue by genre.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: genres
                    .where((Genres genre) =>
                        genre.name != null && genre.name!.isNotEmpty)
                    .map(
                      (Genres genre) => _buildGenrePill(genre.name!),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              if (isLoadingGenre)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppPalette.brand),
                    ),
                  ),
                )
              else
                BrowsePage(
                  title: selectedGenre,
                  subtitle: 'Popular $selectedGenre titles on TMDB.',
                  movies: genreMovies,
                  icon: Icons.explore_outlined,
                  onTap: _watchMovie,
                  onBookmark: _toggleBookmark,
                  bookmarkedIds: bookmarkedIds,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenrePill(String genreName) {
    final bool isSelected = genreName == selectedGenre;
    return InkWell(
      onTap: () => _loadGenreMovies(genreName),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.brand : const Color(0xFF1B1F31),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          genreName,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 760;
        final Widget tabs = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _buildTabButton('Movie'),
              const SizedBox(width: 12),
              _buildTabButton('Series'),
              const SizedBox(width: 12),
              _buildTabButton('Anime'),
              const SizedBox(width: 12),
              _buildTabButton('TV Show'),
            ],
          ),
        );

        final Widget search = _buildSearchField(compact ? 180.0 : 250.0);
        final Widget avatar = InkWell(
          onTap: () => _navigateToPage('Settings'),
          child: CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(
                TMDB_BASE_IMAGE_URL + 'w185/aIecrmmYpqnyCWQArAueqD60qok.jpg'),
          ),
        );

        return Container(
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 16 : 30, vertical: 16),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    tabs,
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(child: search),
                        const SizedBox(width: 12),
                        avatar,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(child: tabs),
                    const SizedBox(width: 16),
                    search,
                    const SizedBox(width: 15),
                    avatar,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSearchField(double width) {
    return Container(
      key: _searchFieldKey,
      width: width,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.search,
        onSubmitted: (String value) => _searchMovies(value),
        decoration: const InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label) {
    bool isSelected = selectedTab == label;
    return TextButton(
      onPressed: () {
        setState(() => selectedTab = label);
        _loadData(); // Reload content for new tab
      },
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white54,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  /// The top banner: a self-advancing slideshow of the newest releases.
  ///
  /// Each slide fills the box with a [BoxFit.cover] backdrop, so nothing is
  /// stretched or letterboxed regardless of the source aspect ratio, and falls
  /// back to the poster when a title has no backdrop. Advancing is driven by a
  /// timer that pauses while the user is dragging and resumes afterwards.
  Widget _buildHeroBanner() {
    if (heroMovies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 350,
            child: Stack(
              children: <Widget>[
                // The timer is started from _loadData once the slides exist,
                // since PageView.builder has no creation callback.
                PageView.builder(
                  controller: _heroController,
                  itemCount: heroMovies.length,
                  onPageChanged: _onHeroPageChanged,
                  itemBuilder: (BuildContext context, int index) {
                    return _buildHeroSlide(heroMovies[index]);
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: _HeroDots(
                    count: heroMovies.length,
                    active: _heroPage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSlide(Movie movie) {
    final String? backdrop =
        tmdbImageUrl(movie.backdropPath, size: 'original');
    // A poster is 2:3, so stretching one across a 16:9 banner would distort
    // it badly. It is only used when there is no backdrop at all.
    final String? poster = tmdbImageUrl(movie.posterPath, size: 'w780');
    final String? image = backdrop ?? poster;
    final bool isBookmarked =
        movie.id != null && bookmarkedIds.contains(movie.id);

    return GestureDetector(
      onTap: () => _watchMovie(movie),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (image == null)
            Container(color: AppPalette.surface)
          else
            Image.network(
              image,
              fit: BoxFit.cover,
              // Anchored to the top so faces and titles in a backdrop are not
              // cropped by the banner's fixed height.
              alignment: Alignment.topCenter,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stack,
              ) => Container(color: AppPalette.surface),
              loadingBuilder: (
                BuildContext context,
                Widget child,
                ImageChunkEvent? progress,
              ) {
                if (progress == null) return child;
                return Container(color: AppPalette.surface);
              },
            ),
          // Scrim: strong at the bottom for the text, light at the top so the
          // artwork stays visible.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.88),
                ],
                stops: const <double>[0, 0.45, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _HeroChip(
                      label: 'Now playing',
                      color: AppPalette.brand,
                    ),
                    const SizedBox(width: 8),
                    _HeroChip(
                      label: isBookmarked ? 'Bookmarked' : 'Save',
                      color: Colors.white24,
                      icon: isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      onTap: () => _toggleBookmark(movie),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  movie.title ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _heroSubtitle(movie),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _watchMovie(movie),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.action,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Watch now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Rating and release year for a banner slide, skipping either when the
  /// underlying value is missing rather than printing a placeholder.
  String _heroSubtitle(Movie movie) {
    final double? rating = double.tryParse(movie.voteAverage ?? '');
    final String year = (movie.releaseDate ?? '').split('-').first;
    final bool hasYear = year.length == 4;

    if (rating == null && !hasYear) return 'Latest release';
    if (rating == null) return year;
    if (!hasYear) return 'Rated ${rating.toStringAsFixed(1)} / 10';
    return '${rating.toStringAsFixed(1)} / 10  ·  $year';
  }

  Widget _buildRightSidebar({bool forStackedLayout = false}) {
    final List<Widget> sections = <Widget>[
      _buildSidebarSection(
        title: 'Popular',
        movies: popular,
        expanded: showAllPopular,
        onToggle: () => setState(() => showAllPopular = !showAllPopular),
        emptyMessage: 'No popular titles yet.',
      ),
      const SizedBox(height: 30),
      _buildSidebarSection(
        title: 'Recommended',
        movies: recommended,
        expanded: showAllRecommended,
        onToggle: () =>
            setState(() => showAllRecommended = !showAllRecommended),
        emptyMessage: 'No recommendations yet.',
      ),
    ];

    if (forStackedLayout) {
      // Sits inside the page's scroll view on narrow screens, so it must not
      // claim a fixed width, carry its own background, or scroll itself.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections,
        ),
      );
    }

    return Container(
      width: 280,
      color: const Color(0xFF151827),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections,
        ),
      ),
    );
  }

  /// One titled block of the right sidebar, with a "See more" control that
  /// genuinely reveals the rest of the list instead of only showing a toast.
  Widget _buildSidebarSection({
    required String title,
    required List<Movie>? movies,
    required bool expanded,
    required VoidCallback onToggle,
    required String emptyMessage,
  }) {
    final List<Movie> items = movies ?? const <Movie>[];
    final int visible = expanded ? items.length : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        if (items.isEmpty)
          Text(emptyMessage,
              style: const TextStyle(color: Colors.white38, fontSize: 13))
        else
          ...items.take(visible).map(_buildSidebarCard),
        const SizedBox(height: 20),
        if (items.length > 3)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.action,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                expanded ? 'Show less' : 'See more',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSidebarCard(Movie movie) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Movie poster
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: _coverImage(movie.posterPath),
            ),
          ),
          SizedBox(width: 12),
          // Movie info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  movie.overview?.split('.').first ?? 'Action, Fantasy',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'PG-13',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    Icon(Icons.star, color: Colors.amber, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreChip(String label, bool isSelected) {
    return InkWell(
      onTap: () => _filterByGenre(label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.brand : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            if (!isSelected) ...[
              SizedBox(width: 4),
              Icon(Icons.add, color: Colors.white, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCard(Movie movie) {
    return InkWell(
      onTap: () => _watchMovie(movie),
      child: Container(
        height: 80,
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: _coverImage(movie.backdropPath ?? movie.posterPath),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie.title ?? '',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                movie.releaseDate?.split('-').first ?? '2021',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One genre row on the home page: a display label, the TMDB genre id and an
/// icon for its header. [isSeries] rows come from the TV endpoints instead.
/// A small pill used on the banner slide, for the "Now playing" badge and the
/// bookmark toggle.
class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, color: Colors.white, size: 15),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page indicator for the banner slideshow. The active dot is wider so the
/// current slide reads at a glance.
class _HeroDots extends StatelessWidget {
  const _HeroDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(count, (int index) {
        final bool isActive = index == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(left: 5),
          height: 7,
          width: isActive ? 20 : 7,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _GenreRow {
  const _GenreRow(this.label, this.genreId, this.icon, {this.isSeries = false});

  final String label;
  final int genreId;
  final IconData icon;
  final bool isSeries;
}

/// The Play It logo: a film icon in a rounded gradient tile.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 30 : 32;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppPalette.logoGreen, AppPalette.logoGreenDark],
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(Icons.movie, color: Colors.white, size: compact ? 18 : 20),
    );
  }
}

/// One destination in the mobile bottom navigation bar.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AppPalette.brand : AppPalette.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppPalette.brand.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
