import 'package:flutter/material.dart';
import 'package:movies/constants/app_theme.dart';
import 'package:movies/modal_class/movie.dart';

/// A single movie inside a [MovieRowSection].
///
/// Uses [Image.network] with an errorBuilder because a TMDB poster that fails
/// to load would otherwise be reported as an uncaught exception.
class MovieRowCard extends StatelessWidget {
  const MovieRowCard({
    super.key,
    required this.movie,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmark,
    this.width = 132,
  });

  final Movie movie;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;
  final double width;

  String get _year => (movie.releaseDate ?? '').split('-').first;

  @override
  Widget build(BuildContext context) {
    final String? poster =
        movie.posterPath == null || movie.posterPath!.isEmpty
            ? null
            : 'https://image.tmdb.org/t/p/w342${movie.posterPath}';

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Material(
                  color: AppPalette.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: poster == null
                        ? const _MissingPoster()
                        : Image.network(
                            poster,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              BuildContext context,
                              Object error,
                              StackTrace? stack,
                            ) => const _MissingPoster(),
                          ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _BookmarkChip(
                    isBookmarked: isBookmarked,
                    onPressed: onBookmark,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Colors.transparent, Color(0xE6000000)],
                      ),
                    ),
                    child: Text(
                      movie.title ?? 'Untitled',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(Icons.star, color: AppPalette.gold, size: 14),
              const SizedBox(width: 3),
              Text(
                _rating,
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 11,
                ),
              ),
              if (_year.isNotEmpty && _year.length == 4) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  _year,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String get _rating {
    final double? value = double.tryParse(movie.voteAverage ?? '');
    if (value == null) return '--';
    return value.toStringAsFixed(1);
  }
}

class _BookmarkChip extends StatelessWidget {
  const _BookmarkChip({required this.isBookmarked, required this.onPressed});

  final bool isBookmarked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            size: 16,
            color: isBookmarked ? AppPalette.gold : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MissingPoster extends StatelessWidget {
  const _MissingPoster();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppPalette.surfaceHigh,
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_outlined,
        color: AppPalette.textMuted,
        size: 28,
      ),
    );
  }
}

/// One genre section on the home page: a highlighted card with a yellow
/// gradient background and a highlighted border, holding a scrollable row of
/// more than ten movies.
class MovieRowSection extends StatefulWidget {
  const MovieRowSection({
    super.key,
    required this.title,
    required this.movies,
    required this.onTap,
    required this.onBookmark,
    required this.bookmarkedIds,
    this.icon = Icons.movie_filter_outlined,
    this.isLoading = false,
    this.accentLabel,
  });

  final String title;
  final List<Movie> movies;
  final ValueChanged<Movie> onTap;
  final ValueChanged<Movie> onBookmark;
  final List<int> bookmarkedIds;
  final IconData icon;
  final bool isLoading;
  final String? accentLabel;

  @override
  State<MovieRowSection> createState() => _MovieRowSectionState();
}

class _MovieRowSectionState extends State<MovieRowSection> {
  final ScrollController _controller = ScrollController();
  int _cardsPerPage = 6;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollBy(double amount) {
    if (!_controller.hasClients) return;
    final double target = (_controller.offset + amount).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return _skeleton();
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      decoration: BoxDecoration(
        gradient: AppPalette.goldGradient,
        borderRadius: BorderRadius.circular(18),
        border: AppPalette.goldBorder(),
        boxShadow: AppPalette.goldShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _header(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              _cardsPerPage = (constraints.maxWidth / 148).floor().clamp(1, 12);
              return SizedBox(
                height: 232,
                child: ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  itemCount: widget.movies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final Movie movie = widget.movies[index];
                    return MovieRowCard(
                      movie: movie,
                      isBookmarked:
                          movie.id != null && widget.bookmarkedIds.contains(movie.id),
                      onTap: () => widget.onTap(movie),
                      onBookmark: () => widget.onBookmark(movie),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final int count = widget.movies.length;
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppPalette.gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppPalette.gold.withValues(alpha: 0.5)),
          ),
          child: Icon(widget.icon, color: AppPalette.goldBright, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.accentLabel ?? '$count titles',
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _ArrowButton(
          icon: Icons.chevron_left,
          tooltip: 'Scroll ${widget.title} left',
          onPressed: () => _scrollBy(-_cardsPerPage * 148),
        ),
        const SizedBox(width: 6),
        _ArrowButton(
          icon: Icons.chevron_right,
          tooltip: 'Scroll ${widget.title} right',
          onPressed: () => _scrollBy(_cardsPerPage * 148),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return Container(
      height: 300,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppPalette.goldGradient,
        borderRadius: BorderRadius.circular(18),
        border: AppPalette.goldBorder(),
      ),
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(AppPalette.goldBright),
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppPalette.gold.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: AppPalette.goldBright, size: 20),
          ),
        ),
      ),
    );
  }
}
