import 'package:flutter/material.dart';
import 'package:movies/api/endpoints.dart';
import 'package:movies/constants/api_constants.dart';
import 'package:movies/modal_class/function.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/modal_class/genres.dart';
import 'package:movies/modal_class/release_date.dart';
import 'package:movies/screens/movie_detail.dart';

/// The media a [Movie] result represents. TMDB has no "anime" list, so anime is
/// told apart from other series by its Japanese original language plus the
/// Animation genre.
enum _MediaKind {
  movie('Movies'),
  series('Series & TV'),
  anime('Anime');

  const _MediaKind(this.label);

  final String label;
}

/// One unreleased title paired with the media kind it belongs to. TMDB ids are
/// only unique within a type, so keeping the kind alongside the [Movie] makes
/// de-duplication and the card badge unambiguous.
class _UpcomingTitle {
  const _UpcomingTitle(this.movie, this.kind);

  final Movie movie;
  final _MediaKind kind;
}

class ComingSoonPage extends StatefulWidget {
  final List<Genres> genres;

  ComingSoonPage({required this.genres});

  @override
  _ComingSoonPageState createState() => _ComingSoonPageState();
}

class _ComingSoonPageState extends State<ComingSoonPage> {
  List<_UpcomingTitle>? upcoming;
  List<Genres> genres = const <Genres>[];
  bool isLoading = true;

  /// The active kind filter. Null means "show everything".
  _MediaKind? filter;

  @override
  void initState() {
    super.initState();
    genres = widget.genres;
    _loadUpcoming();
  }

  /// Loads everything opening in the current calendar month, across film and TV.
  ///
  /// The queries are date-bounded (see [Endpoints.upcomingMoviesThisMonthUrl]
  /// and [Endpoints.upcomingTVThisMonthUrl]), so a call made today only returns
  /// titles still to come this month. Anything whose release date has arrived is
  /// excluded both by the query and by the local [ReleaseDate.isUpcoming] check,
  /// which is what makes a title drop off the moment it is released.
  Future<void> _loadUpcoming() async {
    try {
      // Two pages per medium. The second page is a bonus, so a failure there
      // still leaves a usable board instead of blanking the screen.
      final List<List<Movie>> pages = await Future.wait<List<Movie>>(
        <Future<List<Movie>>>[
          _safeFetch(Endpoints.upcomingMoviesThisMonthUrl(1)),
          _safeFetch(Endpoints.upcomingTVThisMonthUrl(1)),
          _safeFetch(Endpoints.upcomingMoviesThisMonthUrl(2)),
          _safeFetch(Endpoints.upcomingTVThisMonthUrl(2)),
        ],
      );

      final List<_UpcomingTitle> titles = _merge(
        movies: <Movie>[...pages[0], ...pages[2]],
        tv: <Movie>[...pages[1], ...pages[3]],
      );

      // TV genres are loaded as well so a series or anime card can have its
      // genre ids named on the detail page; movie genre ids do not cover them.
      List<Genres> mergedGenres = widget.genres;
      try {
        final GenresList tv = await fetchTVGenres();
        mergedGenres =
            _mergeGenres(widget.genres, tv.genres ?? const <Genres>[]);
      } catch (_) {
        // Keep the movie-only list; the board still works.
      }

      if (!mounted) return;
      setState(() {
        upcoming = titles;
        genres = mergedGenres;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<Movie>> _safeFetch(String url) async {
    try {
      return await fetchMovies(url);
    } catch (_) {
      return <Movie>[];
    }
  }

  /// Filters to unreleased, in-month, illustrated titles, tags each with its
  /// media kind, de-duplicates them and orders them by how soon they arrive.
  List<_UpcomingTitle> _merge({
    required List<Movie> movies,
    required List<Movie> tv,
  }) {
    final DateTime now = DateTime.now();
    final Set<String> seen = <String>{};
    final List<_UpcomingTitle> titles = <_UpcomingTitle>[];

    void add(Movie movie, bool isTv) {
      if (movie.id == null) return;
      if (!_hasArtwork(movie)) return;
      if (!ReleaseDate.isUpcoming(movie.releaseDate)) return;

      final DateTime? date = ReleaseDate.parse(movie.releaseDate);
      if (date == null || date.month != now.month || date.year != now.year) {
        return;
      }

      final _MediaKind kind = !isTv
          ? _MediaKind.movie
          : _isAnime(movie)
              ? _MediaKind.anime
              : _MediaKind.series;
      if (!seen.add('${isTv ? 'tv' : 'movie'}-${movie.id}')) return;
      titles.add(_UpcomingTitle(movie, kind));
    }

    movies.forEach((Movie m) => add(m, false));
    tv.forEach((Movie m) => add(m, true));

    titles.sort((_UpcomingTitle a, _UpcomingTitle b) =>
        ReleaseDate.parse(a.movie.releaseDate)!
            .compareTo(ReleaseDate.parse(b.movie.releaseDate)!));
    return titles;
  }

  bool _hasArtwork(Movie movie) =>
      (movie.posterPath != null && movie.posterPath!.isNotEmpty) ||
      (movie.backdropPath != null && movie.backdropPath!.isNotEmpty);

  bool _isAnime(Movie movie) =>
      movie.originalLanguage == 'ja' && (movie.genreIds?.contains(16) ?? false);

  List<Genres> _mergeGenres(List<Genres> a, List<Genres> b) {
    final Map<int, Genres> byId = <int, Genres>{};
    for (final Genres genre in <Genres>[...a, ...b]) {
      if (genre.id != null) byId.putIfAbsent(genre.id!, () => genre);
    }
    return byId.values.toList();
  }

  /// The titles currently shown, honouring the kind filter if one is set.
  List<_UpcomingTitle> get _visible {
    final List<_UpcomingTitle> all = upcoming ?? const <_UpcomingTitle>[];
    if (filter == null) return all;
    return all.where((_UpcomingTitle t) => t.kind == filter).toList();
  }

  /// Scales the poster grid with the available width so the page stays usable
  /// on a phone instead of squeezing five columns into a narrow viewport.
  int _columnsFor(double width) {
    if (width < 480) return 2;
    if (width < 720) return 3;
    if (width < 1000) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    // This screen used to return a bare Container, which left it with no
    // Scaffold and therefore no way back except the browser's back button.
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151827),
        foregroundColor: Colors.white,
        title: const Text('Coming Soon', style: TextStyle(fontSize: 18)),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Releasing in ${ReleaseDate.monthYear(DateTime.now())}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Movies, series and anime due this month. Titles drop off once '
              'they are released.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildFilterRow(),
            const SizedBox(height: 20),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.amber))
                  : _visible.isEmpty
                      ? _buildEmpty()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final List<_UpcomingTitle> titles = _visible;
                            return RefreshIndicator(
                              color: Colors.amber,
                              backgroundColor: const Color(0xFF151827),
                              onRefresh: _loadUpcoming,
                              child: GridView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      _columnsFor(constraints.maxWidth),
                                  childAspectRatio: 0.48,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: titles.length,
                                itemBuilder: (context, index) {
                                  final _UpcomingTitle title = titles[index];
                                  return _buildMovieCard(title);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final List<_UpcomingTitle> all = upcoming ?? const <_UpcomingTitle>[];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _buildFilterChip(null, 'All', all.length),
          for (final _MediaKind kind in _MediaKind.values)
            _buildFilterChip(
              kind,
              kind.label,
              all.where((_UpcomingTitle t) => t.kind == kind).length,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(_MediaKind? kind, String label, int count) {
    final bool selected = filter == kind;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => filter = kind),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.amber : const Color(0xFF1B1F31),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final String message = filter == null
        ? 'Nothing else is scheduled this month'
        : 'No ${filter!.label.toLowerCase()} left this month';
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.white60),
      ),
    );
  }

  /// Accent used for the media-kind badge on a card.
  Color _kindColor(_MediaKind kind) {
    switch (kind) {
      case _MediaKind.movie:
        return Colors.amber;
      case _MediaKind.series:
        return const Color(0xFF4F8CFF);
      case _MediaKind.anime:
        return const Color(0xFFFF5C8A);
    }
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

  Widget _buildMovieCard(_UpcomingTitle entry) {
    final Movie movie = entry.movie;
    final Color kindColor = _kindColor(entry.kind);
    final String releaseLabel = ReleaseDate.format(movie.releaseDate);
    final String? countdown = ReleaseDate.timeUntil(movie.releaseDate);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailPage(
              movie: movie,
              themeData: Theme.of(context),
              heroId: '${movie.id}upcoming',
              genres: genres,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: _coverImage(movie.posterPath ?? movie.backdropPath),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kindColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.kind.label.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title ?? '',
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  color: Colors.white60, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  releaseLabel,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (countdown != null) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      countdown,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
