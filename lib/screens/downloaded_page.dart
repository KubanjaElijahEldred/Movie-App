import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:movies/constants/app_theme.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/services/download_service.dart';

/// A red primary action button used across this page.
class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expanded = false,
    this.filled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 18, color: filled ? Colors.white : AppPalette.danger),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : AppPalette.dangerBright,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );

    final Widget button = Container(
      decoration: BoxDecoration(
        gradient: filled ? AppPalette.dangerGradient : null,
        color: filled ? null : AppPalette.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: content,
          ),
        ),
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// The Downloaded page: a red-accented library of saved titles.
///
/// Each card exposes three red actions: play the download, remove the file, and
/// open the TMDB details. Everything here is wired to a real callback so no
/// button on the page is inert.
class DownloadedPage extends StatelessWidget {
  const DownloadedPage({
    super.key,
    required this.movies,
    required this.onPlay,
    required this.onRemove,
    required this.onDetails,
    this.onDownloadMore,
    this.bookmarkedIds = const <int>[],
    this.onBookmark,
    this.downloadService,
  });

  final List<Movie> movies;
  final ValueChanged<Movie> onPlay;
  final ValueChanged<Movie> onRemove;
  final ValueChanged<Movie> onDetails;
  final VoidCallback? onDownloadMore;
  final List<int> bookmarkedIds;
  final ValueChanged<Movie>? onBookmark;

  /// Optional, so the page still builds without a running download session.
  final DownloadService? downloadService;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return _buildEmpty(context);

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(child: _buildHeader()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          sliver: SliverLayoutBuilder(
            builder: (BuildContext context, SliverConstraints constraints) {
              final int columns =
                  (constraints.crossAxisExtent / 300).floor().clamp(1, 4);
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 196,
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final Movie movie = movies[index];
                    return _DownloadedCard(
                      movie: movie,
                      isBookmarked: movie.id != null &&
                          bookmarkedIds.contains(movie.id),
                      onPlay: () => onPlay(movie),
                      onRemove: () => onRemove(movie),
                      onDetails: () => onDetails(movie),
                      onBookmark: onBookmark == null
                          ? null
                          : () => onBookmark!(movie),
                    );
                  },
                  childCount: movies.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final int total = movies.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0x33E11D48), Color(0x14F43F5E), Color(0x0AE11D48)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppPalette.danger.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppPalette.danger.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppPalette.danger.withValues(alpha: 0.6)),
            ),
            child: const Icon(Icons.download_done, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Downloaded',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  total == 1 ? '1 title ready to watch offline' : '$total titles ready to watch offline',
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (onDownloadMore != null)
            DangerButton(
              label: 'Add more',
              icon: Icons.add,
              onPressed: onDownloadMore,
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPalette.danger.withValues(alpha: 0.14),
                border: Border.all(
                  color: AppPalette.danger.withValues(alpha: 0.45),
                ),
              ),
              child: const Icon(
                Icons.download_outlined,
                color: AppPalette.dangerBright,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No downloads yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Titles you save for offline viewing are listed here, ready to play without a connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 22),
            DangerButton(
              label: 'Browse titles',
              icon: Icons.explore_outlined,
              expanded: true,
              onPressed: onDownloadMore,
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadedCard extends StatelessWidget {
  const _DownloadedCard({
    required this.movie,
    required this.isBookmarked,
    required this.onPlay,
    required this.onRemove,
    required this.onDetails,
    this.onBookmark,
  });

  final Movie movie;
  final bool isBookmarked;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  final VoidCallback onDetails;
  final VoidCallback? onBookmark;

  @override
  Widget build(BuildContext context) {
    final String? poster = movie.posterPath == null || movie.posterPath!.isEmpty
        ? null
        : 'https://image.tmdb.org/t/p/w342${movie.posterPath}';

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 108,
            height: double.infinity,
            child: poster == null
                ? Container(
                    color: AppPalette.surfaceHigh,
                    child: const Icon(
                      Icons.movie_outlined,
                      color: AppPalette.textMuted,
                    ),
                  )
                : Image.network(
                    poster,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stack,
                    ) => Container(
                      color: AppPalette.surfaceHigh,
                      child: const Icon(
                        Icons.movie_outlined,
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    movie.title ?? 'Untitled',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: <Widget>[
                      Icon(Icons.check_circle,
                          color: AppPalette.dangerBright, size: 13),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Saved offline',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DangerButton(
                          label: 'Play',
                          icon: Icons.play_arrow,
                          onPressed: onPlay,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _IconAction(
                        icon: Icons.info_outline,
                        tooltip: 'Details',
                        onPressed: onDetails,
                      ),
                      if (onBookmark != null) ...<Widget>[
                        const SizedBox(width: 6),
                        _IconAction(
                          icon: isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          tooltip: 'Bookmark',
                          color: isBookmarked ? AppPalette.brand : null,
                          onPressed: onBookmark,
                        ),
                      ],
                      const SizedBox(width: 6),
                      _IconAction(
                        icon: Icons.delete_outline,
                        tooltip: 'Remove download',
                        color: AppPalette.dangerBright,
                        onPressed: onRemove,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppPalette.surfaceHigh,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icon,
              size: 17,
              color: onPressed == null ? AppPalette.textMuted : (color ?? Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
