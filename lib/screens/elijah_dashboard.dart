import 'package:flutter/material.dart';
import 'package:movies/api/endpoints.dart';
import 'package:movies/constants/api_constants.dart';
import 'package:movies/modal_class/function.dart';
import 'package:movies/modal_class/genres.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/modal_class/video.dart';
import 'package:movies/screens/browse_page.dart';
import 'package:movies/screens/coming_soon_page.dart';
import 'package:movies/screens/favorites_page.dart';
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

  /// Movies for the Discovery page, loaded per genre.
  List<Movie> genreMovies = [];

  /// Whether the right sidebar sections are showing all their titles.
  bool showAllPopular = false;
  bool showAllRecommended = false;

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
  }

  @override
  void dispose() {
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

      setState(() {
        genres = genresList.genres ?? [];
        trendingMovies = trending;
        topRated = rated;
        continueWatching = trending.take(4).toList();
        recentDownloads = popular.take(4).toList();
        bookmarked = rated.take(4).toList();
        this.popular = rated.take(3).toList();
        this.recommended = popular.take(3).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
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
        backgroundColor: Color(0xFF10D98D),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
                style: TextStyle(color: Color(0xFF10D98D)),
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

  /// Below this width the layout is too cramped for a permanent sidebar, so it
  /// moves into a drawer.
  static const double _drawerBreakpoint = 900;

  /// The right sidebar is a third column, so it needs real room to sit beside
  /// the main content rather than under it.
  static const double _rightSidebarBreakpoint = 1180;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useDrawer = constraints.maxWidth < _drawerBreakpoint;
        final bool showRightSidebar =
            constraints.maxWidth >= _rightSidebarBreakpoint;

        final Widget content = isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10D98D)),
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
          backgroundColor: const Color(0xFF0D0F1F),
          drawer: useDrawer ? _buildDrawer() : null,
          body: Row(
            children: <Widget>[
              if (!useDrawer) _buildLeftSidebar(),
              Expanded(
                child: useDrawer
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
        );
      },
    );
  }

  /// Top bar for narrow screens. Carries the drawer button, the wordmark and a
  /// way into Settings, which the permanent sidebar would otherwise provide.
  Widget _buildMobileAppBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: const Color(0xFF151827),
        child: Row(
          children: <Widget>[
            Builder(
              builder: (BuildContext context) => IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'PlayMo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
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

  /// The sidebar rendered inside a drawer on narrow screens. Reuses the same
  /// items and active-state logic as the permanent sidebar so both stay in sync.
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF151827),
      child: SafeArea(
        child: _buildLeftSidebar(inDrawer: true),
      ),
    );
  }

  Widget _buildLeftSidebar({bool inDrawer = false}) {
    return Container(
      width: 200,
      color: const Color(0xFF151827),
      child: Column(
        children: [
          SizedBox(height: 32),
          // App Logo. Inside a drawer the wordmark already sits in the app bar
          // on narrow screens, so it is skipped there to save vertical space.
          if (!inDrawer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10D98D), Color(0xFF08B877)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'PlayMo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
          color: isActive ? Color(0xFF10D98D) : Colors.transparent,
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
          accent: const Color(0xFFFACC15),
          onTap: _watchMovie,
          onBookmark: _toggleBookmark,
          bookmarkedIds: bookmarkedIds,
        );

      case 'Downloaded':
        return BrowsePage(
          title: 'Downloaded',
          subtitle: 'Titles saved for offline viewing.',
          movies: recentDownloads ?? const <Movie>[],
          icon: Icons.download_outlined,
          accent: const Color(0xFF34D399),
          emptyTitle: 'No downloads',
          emptyMessage: 'Films you download will be listed here.',
          onTap: _watchMovie,
          onBookmark: _toggleBookmark,
          bookmarkedIds: bookmarkedIds,
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

  /// The default dashboard. When the right sidebar has been moved below the
  /// fold (narrow screens) its content is appended instead of sitting beside.
  Widget _buildHomePage(bool showRightSidebar) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeroBanner(),
          const SizedBox(height: 30),
          _buildHotNewSection(),
          const SizedBox(height: 30),
          _buildContinueWatchingSection(),
          if (!showRightSidebar) ...<Widget>[
            const SizedBox(height: 30),
            _buildRightSidebar(forStackedLayout: true),
          ],
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
                          AlwaysStoppedAnimation<Color>(Color(0xFF10D98D)),
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
          color: isSelected ? const Color(0xFF10D98D) : const Color(0xFF1B1F31),
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

  Widget _buildHeroBanner() {
    if (trendingMovies == null || trendingMovies!.isEmpty)
      return SizedBox.shrink();
    final movie = trendingMovies!.first;

    return Container(
      height: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(TMDB_BASE_IMAGE_URL +
              'original/' +
              (movie.backdropPath ?? movie.posterPath ?? '')),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
          ),
        ),
        padding: EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bookmark and Favorite icons at top
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF10D98D),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.bookmark, color: Colors.white, size: 18),
                ),
                SizedBox(width: 10),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.favorite_border,
                      color: Colors.white, size: 18),
                ),
              ],
            ),
            Spacer(),
            // Movie title
            Text(
              movie.title ?? '',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
            ),
            SizedBox(height: 8),
            // Genres
            Text(
              'Action, Adventure, Fantasy',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 15),
            // Watch now button
            ElevatedButton(
              onPressed: () => _watchMovie(movie),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10D98D),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Watch now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotNewSection() {
    if (topRated == null || topRated!.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hot New',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 15),
        Row(
          children: topRated!
              .take(4)
              .map((movie) => Expanded(
                    child: _buildHotNewCard(movie),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildHotNewCard(Movie movie) {
    return Container(
      margin: EdgeInsets.only(right: 15),
      child: Stack(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(
                    TMDB_BASE_IMAGE_URL + 'w500/' + (movie.posterPath ?? '')),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Rating badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 12),
                  SizedBox(width: 3),
                  Text(
                    movie.voteAverage?.toString().substring(0, 3) ?? '0',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          // Play button overlay
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _watchMovie(movie),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withOpacity(0.0),
                  ),
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Color(0xFF10D98D).withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.play_arrow, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Movie title at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie.title ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueWatchingSection() {
    if (continueWatching == null || continueWatching!.isEmpty)
      return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Continue Watching',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 15),
        Row(
          children: continueWatching!.take(2).map((movie) {
            final index = continueWatching!.indexOf(movie);
            return Expanded(
              child: _buildContinueCard(movie, (index + 1) * 35),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildContinueCard(Movie movie, int progress) {
    // Generate fake timestamps
    final totalMinutes = 150 + (progress * 2);
    final watchedMinutes = (totalMinutes * progress / 100).round();
    final watchedHours = watchedMinutes ~/ 60;
    final watchedMins = watchedMinutes % 60;
    final totalHours = totalMinutes ~/ 60;
    final totalMins = totalMinutes % 60;

    return Container(
      margin: EdgeInsets.only(right: 15),
      child: Stack(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(TMDB_BASE_IMAGE_URL +
                    'w500/' +
                    (movie.backdropPath ?? movie.posterPath ?? '')),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
          ),
          // Play button center
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _watchMovie(movie),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(0xFF10D98D).withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.play_arrow, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),
          // Movie info at bottom
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  movie.title ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      movie.voteAverage?.toString().substring(0, 3) ?? '0',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Timestamp
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${watchedHours.toString().padLeft(2, '0')}:${watchedMins.toString().padLeft(2, '0')} / ${totalHours.toString().padLeft(2, '0')}:${totalMins.toString().padLeft(2, '0')}:13',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRatedSection() {
    if (topRated == null || topRated!.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Top rated',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.star, color: Colors.amber, size: 20),
              ],
            ),
            TextButton(
              onPressed: () =>
                  _showSnackBar('Loading top rated...', Icons.star),
              child: Text('See all >', style: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: topRated!.take(6).length,
            itemBuilder: (context, index) {
              return _buildTopRatedCard(topRated![index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopRatedCard(Movie movie) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(TMDB_BASE_IMAGE_URL +
                          'w500/' +
                          (movie.posterPath ?? '')),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 12),
                        SizedBox(width: 2),
                        Text(
                          movie.voteAverage ?? '0',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _watchMovie(movie),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF10D98D),
                            padding: EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text('Watch',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      SizedBox(width: 4),
                      InkWell(
                        onTap: () => _toggleBookmark(movie),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: bookmarkedIds.contains(movie.id)
                                ? Color(0xFF10D98D)
                                : Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            bookmarkedIds.contains(movie.id)
                                ? Icons.bookmark
                                : Icons.add,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            movie.title ?? '',
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            movie.releaseDate?.split('-').first ?? '2021',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
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
                backgroundColor: const Color(0xFF10D98D),
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
              image: DecorationImage(
                image: NetworkImage(
                    TMDB_BASE_IMAGE_URL + 'w500/' + (movie.posterPath ?? '')),
                fit: BoxFit.cover,
              ),
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
          color: isSelected ? Color(0xFF10D98D) : Colors.white10,
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
          image: DecorationImage(
            image: NetworkImage(TMDB_BASE_IMAGE_URL +
                'w500/' +
                (movie.backdropPath ?? movie.posterPath ?? '')),
            fit: BoxFit.cover,
          ),
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
