import 'package:flutter/material.dart';
import 'package:movies/constants/api_constants.dart';
import 'package:movies/constants/app_theme.dart';
import 'package:movies/modal_class/movie.dart';

/// A responsive, reusable browse screen for a list of movies.
///
/// Used by the sidebar destinations that show a collection rather than the
/// dashboard layout (Discovery, Community, Recent, Top rated, Downloaded and
/// Bookmarked). It adapts its column count to the available width so the same
/// widget works on a phone, a tablet and a desktop browser.
class BrowsePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Movie> movies;
  final IconData icon;
  final Color accent;
  final String emptyTitle;
  final String emptyMessage;
  final void Function(Movie movie) onTap;
  final void Function(Movie movie)? onBookmark;
  final List<int> bookmarkedIds;

  const BrowsePage({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.movies,
    required this.icon,
    required this.onTap,
    this.accent = const Color(0xFFE11D48),
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage = 'No titles to show.',
    this.onBookmark,
    this.bookmarkedIds = const [],
  }) : super(key: key);

  /// Keeps cards a sensible size on very wide screens instead of stretching
  /// a handful of giant cards across a desktop monitor.
  static const double _maxContentWidth = 1400;

  int _columnsFor(double width) {
    if (width < 480) return 2;
    if (width < 720) return 3;
    if (width < 1000) return 4;
    if (width < 1300) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = _columnsFor(constraints.maxWidth);
        final double horizontalPadding = constraints.maxWidth < 480
            ? 16
            : (constraints.maxWidth < 1000 ? 24 : 32);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 28),
                  if (movies.isEmpty)
                    _buildEmpty(context)
                  else
                    _buildGrid(context, columns),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Text(
          '${movies.length} title${movies.length == 1 ? '' : 's'}',
          style: TextStyle(
              color: accent, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context, int columns) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 20,
        crossAxisSpacing: 18,
        childAspectRatio: 0.56,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final Movie movie = movies[index];
        return _PosterCard(
          movie: movie,
          accent: accent,
          isBookmarked: bookmarkedIds.contains(movie.id),
          onTap: () => onTap(movie),
          onBookmark: onBookmark == null ? null : () => onBookmark!(movie),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.white24),
          const SizedBox(height: 18),
          Text(
            emptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final Movie movie;
  final Color accent;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback? onBookmark;

  const _PosterCard({
    Key? key,
    required this.movie,
    required this.accent,
    required this.isBookmarked,
    required this.onTap,
    this.onBookmark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? poster = movie.posterPath;
    final double rating = double.tryParse(movie.voteAverage ?? '') ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: poster == null || poster.isEmpty
                      ? Container(color: const Color(0xFF1B1F31))
                      : Image.network(
                          TMDB_BASE_IMAGE_URL + 'w500' + poster,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: const Color(0xFF1B1F31)),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFF1B1F31),
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFE11D48),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (rating > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (onBookmark != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onBookmark,
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: isBookmarked ? accent : Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title ?? 'Untitled',
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
