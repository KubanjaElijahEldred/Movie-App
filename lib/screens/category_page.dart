import 'package:flutter/material.dart';
import 'package:movies/modal_class/function.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/screens/browse_page.dart';

/// Builds the request URL for one page of results.
typedef MoviePageUrlBuilder = String Function(int page);

/// A "view more" destination for a home row.
///
/// It starts from the same feed the row shows and then pages through the
/// rest of the collection, appending each batch as the reader scrolls or taps
/// "Load more" (see [BrowsePage.onLoadMore]). Titles are de-duplicated by id so
/// a repeated result across pages never shows twice.
class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.urlBuilder,
    required this.onTap,
    required this.onBookmark,
    required this.bookmarkedIds,
    this.icon = Icons.explore_outlined,
    this.accent = const Color(0xFFE11D48),
  });

  final String title;
  final String subtitle;
  final MoviePageUrlBuilder urlBuilder;
  final ValueChanged<Movie> onTap;
  final Future<void> Function(Movie) onBookmark;

  /// Read lazily on every build so a bookmark toggled on this page is reflected
  /// immediately instead of showing a stale list captured when it opened.
  final List<int> Function() bookmarkedIds;
  final IconData icon;
  final Color accent;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final List<Movie> _movies = <Movie>[];
  final Set<int> _seen = <int>{};
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    if (mounted) setState(() => _isLoading = true);
    final int next = _page + 1;
    try {
      final List<Movie> fetched = await fetchMovies(widget.urlBuilder(next));
      final List<Movie> fresh = fetched
          .where((Movie m) => m.id == null || _seen.add(m.id!))
          .toList();
      if (!mounted) return;
      setState(() {
        _page = next;
        _movies.addAll(fresh);
        _isLoading = false;
        // TMDB caps discover at page 500; an empty page also ends the feed.
        _hasMore = fetched.isNotEmpty && next < 500;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasMore = false;
        _failed = true;
      });
    }
  }

  Future<void> _toggleBookmark(Movie movie) async {
    await widget.onBookmark(movie);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_movies.isEmpty && _isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0F1F),
        appBar: _appBar(),
        body: Center(
          child: CircularProgressIndicator(color: widget.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1F),
      appBar: _appBar(),
      body: BrowsePage(
        title: widget.title,
        subtitle: widget.subtitle,
        movies: _movies,
        icon: widget.icon,
        accent: widget.accent,
        emptyTitle: _failed ? 'Could not load titles' : 'Nothing here yet',
        emptyMessage: _failed
            ? 'Check your connection and try again.'
            : 'No titles to show.',
        onTap: widget.onTap,
        onBookmark: _toggleBookmark,
        bookmarkedIds: widget.bookmarkedIds(),
        onLoadMore: _loadNextPage,
        hasMore: _hasMore,
        isLoadingMore: _isLoading,
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: const Color(0xFF151827),
      foregroundColor: Colors.white,
      title: Text(widget.title, style: const TextStyle(fontSize: 18)),
    );
  }
}
