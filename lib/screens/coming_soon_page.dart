import 'package:flutter/material.dart';
import 'package:movies/api/endpoints.dart';
import 'package:movies/constants/api_constants.dart';
import 'package:movies/modal_class/function.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/modal_class/genres.dart';
import 'package:movies/screens/movie_detail.dart';

class ComingSoonPage extends StatefulWidget {
  final List<Genres> genres;

  ComingSoonPage({required this.genres});

  @override
  _ComingSoonPageState createState() => _ComingSoonPageState();
}

class _ComingSoonPageState extends State<ComingSoonPage> {
  List<Movie>? upcomingMovies;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpcomingMovies();
  }

  Future<void> _loadUpcomingMovies() async {
    try {
      final movies = await fetchMovies(Endpoints.upcomingMoviesUrl(1));
      setState(() {
        upcomingMovies = movies;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
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
              'Upcoming movies and releases',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            SizedBox(height: 24),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: Colors.amber))
                  : upcomingMovies == null || upcomingMovies!.isEmpty
                      ? Center(
                          child: Text(
                            'No upcoming movies found',
                            style: TextStyle(color: Colors.white60),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    _columnsFor(constraints.maxWidth),
                                childAspectRatio: 0.6,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: upcomingMovies!.length,
                              itemBuilder: (context, index) {
                                final movie = upcomingMovies![index];
                                return _buildMovieCard(movie);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailPage(
              movie: movie,
              themeData: Theme.of(context),
              heroId: '${movie.id}upcoming',
              genres: widget.genres,
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
                image: DecorationImage(
                  image: NetworkImage(
                      TMDB_BASE_IMAGE_URL + 'w500/' + (movie.posterPath ?? '')),
                  fit: BoxFit.cover,
                ),
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
                    margin: EdgeInsets.all(8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SOON',
                      style: TextStyle(
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
          SizedBox(height: 8),
          Text(
            movie.title ?? '',
            style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            movie.releaseDate ?? 'TBA',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
