import 'package:flutter/material.dart';
import 'package:movies/api/endpoints.dart';
import 'package:movies/constants/api_constants.dart';
import 'package:movies/constants/app_theme.dart';
import 'package:movies/modal_class/credits.dart';
import 'package:movies/modal_class/genres.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/modal_class/video.dart';
import 'package:movies/modal_class/function.dart';
import 'package:movies/screens/widgets.dart';
import 'package:movies/screens/trailer_player.dart';
import 'package:movies/models/movie_source.dart';
import 'package:movies/screens/where_to_watch_sheet.dart';
import 'package:movies/services/download_service.dart';
import 'package:movies/services/movie_source_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MovieDetailPage extends StatefulWidget {
  final Movie movie;
  final ThemeData themeData;
  final String heroId;
  final List<Genres> genres;

  /// Shared across the app so a download started here is visible on the
  /// Downloaded page. Optional because a few older call sites predate the
  /// download feature; when null the page falls back to a private instance.
  final DownloadService? downloadService;

  MovieDetailPage(
      {required this.movie,
      required this.themeData,
      required this.heroId,
      required this.genres,
      this.downloadService});
  @override
  _MovieDetailPageState createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  List<Video>? trailers;
  bool isLoadingTrailers = false;

  /// The app-wide service when one was supplied, otherwise a local instance
  /// so this page still works from older call sites.
  late final DownloadService _downloads =
      widget.downloadService ?? DownloadService();

  /// True when this state created its own service and must dispose it.
  late final bool _ownsDownloads = widget.downloadService == null;

  @override
  void initState() {
    super.initState();
    _fetchTrailers();
  }

  @override
  void dispose() {
    if (_ownsDownloads) _downloads.dispose();
    super.dispose();
  }

  Future<void> _fetchTrailers() async {
    setState(() {
      isLoadingTrailers = true;
    });
    try {
      final videoList = await fetchVideos(widget.movie.id!);
      setState(() {
        trailers = videoList.results?.where((v) => 
          v.site == 'YouTube' && (v.type == 'Trailer' || v.type == 'Teaser')
        ).toList();
        isLoadingTrailers = false;
      });
    } catch (e) {
      setState(() {
        isLoadingTrailers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  children: <Widget>[
                    widget.movie.backdropPath == null
                        ? Image.asset(
                            'assets/images/na.jpg',
                            fit: BoxFit.cover,
                          )
                        : FadeInImage(
                            width: double.infinity,
                            height: double.infinity,
                            image: NetworkImage(TMDB_BASE_IMAGE_URL +
                                'original/' +
                                widget.movie.backdropPath!),
                            fit: BoxFit.cover,
                            placeholder:
                                AssetImage('assets/images/loading.gif'),
                          ),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          gradient: LinearGradient(
                              begin: FractionalOffset.bottomCenter,
                              end: FractionalOffset.topCenter,
                              colors: [
                                widget.themeData.colorScheme.secondary,
                                widget.themeData.colorScheme.secondary
                                    .withValues(alpha: .3),
                                widget.themeData.colorScheme.secondary
                                    .withValues(alpha: .2),
                                widget.themeData.colorScheme.secondary
                                    .withValues(alpha: .1),
                              ],
                              stops: [
                                0.0,
                                0.25,
                                0.5,
                                0.75
                              ])),
                    )
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: widget.themeData.colorScheme.secondary,
                ),
              )
            ],
          ),
          Column(
            children: <Widget>[
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: widget.themeData.colorScheme.secondary,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.transparent,
                  child: Stack(
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 75, 16, 16),
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            color: widget.themeData.primaryColor,
                            child: Column(
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(left: 120.0),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          widget.movie.title!,
                                          style: widget.themeData.textTheme
                                              .headlineSmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: <Widget>[
                                              Text(
                                                widget.movie.voteAverage!,
                                                style: widget.themeData
                                                    .textTheme.bodyLarge,
                                              ),
                                              Icon(
                                                Icons.star,
                                                color: Colors.green,
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                // Action Buttons
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildActionButton(
                                        icon: Icons.play_circle_fill,
                                        label: 'Play Trailer',
                                        onTap: _playTrailer,
                                        color: Colors.red,
                                      ),
                                      _buildActionButton(
                                        icon: Icons.movie,
                                        label: 'Play Movie',
                                        onTap: _playMovie,
                                        color: Colors.blue,
                                      ),
                                      _buildActionButton(
                                        icon: Icons.download,
                                        label: 'Download',
                                        onTap: _downloadMovie,
                                        color: AppPalette.action,
                                      ),
                                    ],
                                  ),
                                ),
                                _buildDownloadProgress(),
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: BouncingScrollPhysics(),
                                    child: Column(
                                      children: <Widget>[
                                        widget.genres.isEmpty
                                            ? Container()
                                            : GenreList(
                                                themeData: widget.themeData,
                                                genres:
                                                    widget.movie.genreIds ?? [],
                                                totalGenres: widget.genres,
                                              ),
                                        Row(
                                          children: <Widget>[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0),
                                              child: Text(
                                                'Overview',
                                                style: widget.themeData
                                                    .textTheme.bodyLarge,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            widget.movie.overview!,
                                            style: widget
                                                .themeData.textTheme.bodySmall,
                                          ),
                                        ),
                                        Row(
                                          children: <Widget>[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0, bottom: 4.0),
                                              child: Text(
                                                'Release date : ${widget.movie.releaseDate}',
                                                style: widget.themeData
                                                    .textTheme.bodyLarge,
                                              ),
                                            ),
                                          ],
                                        ),
                                        ScrollingArtists(
                                          api: Endpoints.getCreditsUrl(
                                              widget.movie.id!),
                                          title: 'Cast',
                                          tapButtonText: 'See full cast & crew',
                                          themeData: widget.themeData,
                                          onTap: (Cast cast) {
                                            modalBottomSheetMenu(cast);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 40,
                        child: Hero(
                          tag: widget.heroId,
                          child: SizedBox(
                            width: 100,
                            height: 150,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: widget.movie.posterPath == null
                                  ? Image.asset(
                                      'assets/images/na.jpg',
                                      fit: BoxFit.cover,
                                    )
                                  : FadeInImage(
                                      image: NetworkImage(TMDB_BASE_IMAGE_URL +
                                          'w500/' +
                                          widget.movie.posterPath!),
                                      fit: BoxFit.cover,
                                      placeholder: AssetImage(
                                          'assets/images/loading.gif'),
                                    ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  void modalBottomSheetMenu(Cast cast) {
    // double height = MediaQuery.of(context).size.height;
    showModalBottomSheet(
        context: context,
        builder: (builder) {
          return Container(
            // height: height / 2,
            color: Colors.transparent,
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Container(
                      padding: const EdgeInsets.only(top: 54),
                      decoration: BoxDecoration(
                          color: widget.themeData.primaryColor,
                          borderRadius: new BorderRadius.only(
                              topLeft: const Radius.circular(16.0),
                              topRight: const Radius.circular(16.0))),
                      child: Center(
                        child: ListView(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: <Widget>[
                                  Text(
                                    '${cast.name}',
                                    style:
                                        widget.themeData.textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'as',
                                    style:
                                        widget.themeData.textTheme.bodyMedium,
                                  ),
                                  Text(
                                    '${cast.character}',
                                    style:
                                        widget.themeData.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ),
                Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                            color: widget.themeData.primaryColor,
                            border: Border.all(
                                color: widget.themeData.colorScheme.secondary,
                                width: 3),
                            image: DecorationImage(
                                fit: BoxFit.cover,
                                image: (cast.profilePath == null
                                        ? AssetImage('assets/images/na.jpg')
                                        : NetworkImage(TMDB_BASE_IMAGE_URL +
                                            'w500/' +
                                            cast.profilePath!))
                                    as ImageProvider<Object>),
                            shape: BoxShape.circle),
                      ),
                    ))
              ],
            ),
          );
        });
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playTrailer() {
    if (isLoadingTrailers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading trailers...')),
      );
      return;
    }

    if (trailers == null || trailers!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trailer available for this movie')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrailerPlayer(
          videoKey: trailers!.first.key!,
          movieTitle: widget.movie.title!,
        ),
      ),
    );
  }

  /// Opens the legal viewing options for this title.
  ///
  /// The previous behaviour built a YouTube *search* URL, which never played
  /// the film. The sheet now shows TMDB's real watch providers and, when the
  /// title has a licence that permits it, a working file download.
  void _playMovie() {
    WhereToWatchSheet.show(
      context,
      title: widget.movie.title ?? 'This title',
      tmdbId: widget.movie.id,
      downloadService: _downloads,
    );
  }

  /// Starts a real file download for this title.
  ///
  /// A download is only offered when the title resolves to a source whose
  /// licence permits redistribution. Anything else opens the provider list
  /// instead, so the button never silently becomes a dead link.
  Future<void> _downloadMovie() async {
    final MovieSourceService sources = MovieSourceService();
    final DownloadSource? source = await sources.fetchDownloadSource(
      widget.movie.id,
      widget.movie.title,
    );
    sources.dispose();

    if (!mounted) return;

    if (source == null) {
      await WhereToWatchSheet.show(
        context,
        title: widget.movie.title ?? 'This title',
        tmdbId: widget.movie.id,
        downloadService: _downloads,
      );
      return;
    }

    await _downloads.start(
      movieId: widget.movie.id,
      title: widget.movie.title ?? 'Untitled',
      source: source,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${source.fileName}'),
        backgroundColor: AppPalette.danger,
      ),
    );
  }

  /// Hands a source URL to the browser or the OS.
  ///
  /// Used as the manual route when a download cannot be completed in-app, so
  /// the user still gets the file rather than an error with no way forward.
  Future<void> _openSourceFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the file')),
      );
    }
  }

  /// Live progress for this title's download, shown under the action row.
  Widget _buildDownloadProgress() {
    final DownloadTask? task = _downloads.taskFor(widget.movie.id);
    if (task == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: task,
      builder: (BuildContext context, Widget? child) {
        final bool active =
            task.status == DownloadStatus.downloading ||
                task.status == DownloadStatus.queued;
        final bool done = task.status == DownloadStatus.completed;
        // A source that refuses cross-origin reads cannot be buffered by a
        // browser, so the file is offered directly instead of a dead error.
        final bool manual = task.isCrossOriginBlocked;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    done
                        ? Icons.check_circle
                        : active
                            ? Icons.downloading
                            : Icons.error_outline,
                    color: done
                        ? AppPalette.brand
                        : active
                            ? AppPalette.dangerBright
                            : AppPalette.textMuted,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      switch (task.status) {
                        DownloadStatus.completed => 'Saved offline',
                        DownloadStatus.failed => manual
                            ? 'This source blocks browser downloads'
                            : 'Download failed: '
                                '${task.error ?? 'unknown error'}',
                        DownloadStatus.cancelled => 'Download cancelled',
                        _ => 'Downloading · ${task.progressLabel}',
                      },
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: done
                            ? AppPalette.brand
                            : AppPalette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (active)
                    TextButton(
                      onPressed: () => _downloads.cancel(
                        widget.movie.id,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppPalette.textSecondary,
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  else if (manual)
                    TextButton(
                      onPressed: () => _openSourceFile(task.source.url),
                      style: TextButton.styleFrom(
                        foregroundColor: AppPalette.brand,
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Open file',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () => _downloads.remove(
                        widget.movie.id,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppPalette.dangerBright,
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Remove',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
              if (active && task.total > 0) ...<Widget>[
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    minHeight: 4,
                    backgroundColor: AppPalette.surfaceHigh,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppPalette.danger),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
