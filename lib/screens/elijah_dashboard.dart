import 'package:flutter/material.dart';
import 'package:movies/api/endpoints.dart';
import 'package:movies/constants/api_constants.dart';
import 'package:movies/modal_class/function.dart';
import 'package:movies/modal_class/genres.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/modal_class/video.dart';
import 'package:movies/screens/movie_detail.dart';
import 'package:movies/screens/trailer_player.dart';

class ElijahDashboard extends StatefulWidget {
  @override
  _ElijahDashboardState createState() => _ElijahDashboardState();
}

class _ElijahDashboardState extends State<ElijahDashboard> {
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
  String selectedTab = 'Movie';
  String selectedGenre = 'Action';
  String currentPage = 'Home';
  TextEditingController searchController = TextEditingController();
  List<Movie>? searchResults;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
    if (query.isEmpty) {
      setState(() => searchResults = null);
      return;
    }

    try {
      final results = await fetchMovies(Endpoints.movieSearchUrl(query));
      setState(() => searchResults = results);
    } catch (e) {
      _showSnackBar('Search failed', Icons.error);
    }
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

      final filtered = await fetchMovies(Endpoints.getMoviesForGenre(genre.id!, 1));
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
  void _navigateToPage(String page) {
    setState(() => currentPage = page);
    _showSnackBar('Navigated to $page', Icons.navigation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D0F1F),
      body: Row(
        children: [
          _buildLeftSidebar(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10D98D)),
                  ))
                : Row(
                    children: [
                      Expanded(child: _buildMainContent()),
                      _buildRightSidebar(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 200,
      color: Color(0xFF151827),
      child: Column(
        children: [
          SizedBox(height: 32),
          // App Logo
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF10D98D), Color(0xFF08B877)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ),
                SizedBox(width: 10),
                Text(
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
                style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _buildMenuItem(Icons.home, 'Home', currentPage == 'Home'),
          _buildMenuItem(Icons.explore_outlined, 'Discovery', currentPage == 'Discovery'),
          _buildMenuItem(Icons.people_outline, 'Community', currentPage == 'Community'),
          _buildMenuItemWithNotif(Icons.calendar_today_outlined, 'Coming soon', false, true),
          
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.only(left: 20, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'LIBRARY',
                style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _buildMenuItem(Icons.access_time, 'Recent', false),
          _buildMenuItem(Icons.bookmark_border, 'Bookmarked', false),
          _buildMenuItem(Icons.star_border, 'Top rated', false),
          _buildMenuItem(Icons.download_outlined, 'Downloaded', false),
          
          Spacer(),
          _buildMenuItem(Icons.settings_outlined, 'Settings', false),
          _buildMenuItem(Icons.help_outline, 'Help', false),
          _buildMenuItem(Icons.logout, 'Logout', false),
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
              fontSize: text == 'N' ? 24 : (text == 'hulu' || text == 'tv+' ? 10 : 9),
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
            Icon(icon, color: isActive ? Colors.white : Colors.white60, size: 20),
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

  Widget _buildMenuItemWithNotif(IconData icon, String label, bool isActive, bool hasNotif) {
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

  Widget _buildMainContent() {
    return Container(
      color: Color(0xFF0D0F1F),
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroBanner(),
                  SizedBox(height: 30),
                  _buildHotNewSection(),
                  SizedBox(height: 30),
                  _buildContinueWatchingSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Row(
        children: [
          _buildTabButton('Movie'),
          SizedBox(width: 20),
          _buildTabButton('Series'),
          SizedBox(width: 20),
          _buildTabButton('Anime'),
          SizedBox(width: 20),
          _buildTabButton('TV Show'),
          Spacer(),
          // Search bar
          Container(
            width: 250,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF1A1D2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: searchController,
              style: TextStyle(color: Colors.white),
              onSubmitted: (value) => _searchMovies(value),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          SizedBox(width: 15),
          InkWell(
            onTap: () => _showSnackBar('Profile settings...', Icons.account_circle),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(
                  TMDB_BASE_IMAGE_URL + 'w185/aIecrmmYpqnyCWQArAueqD60qok.jpg'),
            ),
          ),
        ],
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
    if (trendingMovies == null || trendingMovies!.isEmpty) return SizedBox.shrink();
    final movie = trendingMovies!.first;
    
    return Container(
      height: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(TMDB_BASE_IMAGE_URL + 'original/' + (movie.backdropPath ?? movie.posterPath ?? '')),
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
                  child: Icon(Icons.favorite_border, color: Colors.white, size: 18),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          children: topRated!.take(4).map((movie) => Expanded(
            child: _buildHotNewCard(movie),
          )).toList(),
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
                image: NetworkImage(TMDB_BASE_IMAGE_URL + 'w500/' + (movie.posterPath ?? '')),
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
                      child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
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
    if (continueWatching == null || continueWatching!.isEmpty) return SizedBox.shrink();
    
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
                image: NetworkImage(TMDB_BASE_IMAGE_URL + 'w500/' + (movie.backdropPath ?? movie.posterPath ?? '')),
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
                    child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
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
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.star, color: Colors.amber, size: 20),
              ],
            ),
            TextButton(
              onPressed: () => _showSnackBar('Loading top rated...', Icons.star),
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
                      image: NetworkImage(TMDB_BASE_IMAGE_URL + 'w500/' + (movie.posterPath ?? '')),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text('Watch', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      SizedBox(width: 4),
                      InkWell(
                        onTap: () => _toggleBookmark(movie),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: bookmarkedIds.contains(movie.id) ? Color(0xFF10D98D) : Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            bookmarkedIds.contains(movie.id) ? Icons.bookmark : Icons.add,
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
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
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

  Widget _buildRightSidebar() {
    return Container(
      width: 280,
      color: Color(0xFF151827),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Popular section
          Text(
            'Popular',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),
          if (popular != null)
            ...popular!.take(3).map((movie) => _buildSidebarCard(movie)).toList(),
          SizedBox(height: 20),
          // See more button
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showSnackBar('Loading more popular movies...', Icons.trending_up),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10D98D),
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'See more',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 30),
          // Recommended section
          Text(
            'Recommended',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),
          if (recommended != null)
            ...recommended!.take(3).map((movie) => _buildSidebarCard(movie)).toList(),
          SizedBox(height: 20),
          // See more button
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showSnackBar('Loading more recommendations...', Icons.recommend),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10D98D),
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'See more',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
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
                image: NetworkImage(TMDB_BASE_IMAGE_URL + 'w500/' + (movie.posterPath ?? '')),
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
            image: NetworkImage(TMDB_BASE_IMAGE_URL + 'w500/' + (movie.backdropPath ?? movie.posterPath ?? '')),
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
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
