import 'package:flutter/material.dart';
import 'package:movies/constants/api_constants.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/modal_class/genres.dart';
import 'package:movies/screens/movie_detail.dart';

/// Shows the movies the user has bookmarked.
///
/// The dashboard passes the resolved bookmark list in via [movies]; when it is
/// null the page renders its empty state, which is what it did before it was
/// wired up to the sidebar.
class FavoritesPage extends StatefulWidget {
  final List<Genres> genres;
  final List<Movie>? movies;

  FavoritesPage({Key? key, required this.genres, this.movies})
      : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  int _columnsFor(double width) {
    if (width < 480) return 2;
    if (width < 720) return 3;
    if (width < 1000) return 4;
    if (width < 1300) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final List<Movie> movies = widget.movies ?? const <Movie>[];
    final double padding = MediaQuery.of(context).size.width < 480 ? 16 : 24;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151827),
        foregroundColor: Colors.white,
        title: const Text('Bookmarked', style: TextStyle(fontSize: 18)),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(padding, 24, padding, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${movies.length} bookmarked title${movies.length == 1 ? '' : 's'}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    if (movies.isEmpty)
                      _buildEmpty()
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _columnsFor(constraints.maxWidth),
                          childAspectRatio: 0.56,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: movies.length,
                        itemBuilder: (BuildContext context, int index) {
                          return _buildMovieCard(movies[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.bookmark_border, size: 56, color: Colors.white24),
          const SizedBox(height: 18),
          const Text(
            'No bookmarks yet',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the bookmark icon on any poster to save it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => MovieDetailPage(
              movie: movie,
              themeData: Theme.of(context),
              heroId: '${movie.id}fav',
              genres: widget.genres,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (movie.posterPath == null || movie.posterPath!.isEmpty)
                  ? Container(color: const Color(0xFF1B1F31))
                  : Image.network(
                      TMDB_BASE_IMAGE_URL + 'w500' + movie.posterPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext context, Object error,
                              StackTrace? st) =>
                          Container(color: const Color(0xFF1B1F31)),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
