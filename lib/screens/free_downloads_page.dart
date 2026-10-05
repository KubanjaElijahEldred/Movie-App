import 'package:flutter/material.dart';
import 'package:movies/constants/app_theme.dart';
import 'package:movies/models/movie_source.dart';
import 'package:movies/services/download_service.dart';
import 'package:movies/services/movie_source_service.dart';
import 'package:movies/screens/downloaded_page.dart';

/// A browsable shelf of films the app is allowed to hand a user as a file.
///
/// Every entry in [MovieSourceService.openFilms] is published by its creator
/// under a licence that permits redistribution, which is why the download
/// button here saves a real file to the device instead of opening a provider
/// link. Commercial titles deliberately do not appear: they resolve to "where
/// to watch" instead.
///
/// The catalogue is compiled in rather than fetched, because the only host that
/// serves these files with permissive CORS headers does not expose a searchable
/// API to a browser. Searching happens locally, over this list.
class FreeDownloadsPage extends StatefulWidget {
  const FreeDownloadsPage({super.key, required this.downloadService});

  final DownloadService downloadService;

  @override
  State<FreeDownloadsPage> createState() => _FreeDownloadsPageState();
}

class _FreeDownloadsPageState extends State<FreeDownloadsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filters the catalogue as the user types, so a title can be found without
  /// leaving the page.
  List<OpenFilm> get _visible {
    final String needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return MovieSourceService.openFilms;
    return MovieSourceService.openFilms
        .where(
          (OpenFilm f) =>
              f.title.toLowerCase().contains(needle) ||
              f.license.toLowerCase().contains(needle) ||
              f.year.contains(needle),
        )
        .toList();
  }

  void _startDownload(OpenFilm film) {
    widget.downloadService.start(
      movieId: film.tmdbId,
      title: film.title,
      source: film.source,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saving ${film.fileName}'),
        backgroundColor: AppPalette.brand,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<OpenFilm> films = _visible;
    final int totalBytes = films.fold<int>(
      0,
      (int sum, OpenFilm f) => sum + f.sizeBytes,
    );

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.textPrimary,
        title: const Text(
          'Free to download',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Short films released by their creators under a licence '
                  'that allows saving. Pick one and it downloads to this '
                  'device for offline viewing.',
                  style: TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (String value) => setState(() => _query = value),
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search these films',
                    hintStyle: const TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppPalette.textMuted,
                      size: 20,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: AppPalette.textMuted,
                            ),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: AppPalette.surfaceHigh,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  films.length == MovieSourceService.openFilms.length
                      ? '${films.length} films · '
                          '${_formatBytes(totalBytes)} available offline'
                      : '${films.length} of '
                          '${MovieSourceService.openFilms.length} films',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: films.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: films.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) => _FilmRow(
                      film: films[index],
                      downloadService: widget.downloadService,
                      onDownload: () => _startDownload(films[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}

/// One film: its licence, its real size, and a live progress row.
class _FilmRow extends StatelessWidget {
  const _FilmRow({
    required this.film,
    required this.downloadService,
    required this.onDownload,
  });

  final OpenFilm film;
  final DownloadService downloadService;
  final VoidCallback onDownload;

  /// Cancels by id when there is one, by title when there is not. Tasks are
  /// keyed the same way in `DownloadService`, so both paths reach the transfer
  /// that is actually running.
  static void _cancel(DownloadService service, OpenFilm film) {
    if (film.tmdbId != null) {
      service.cancel(film.tmdbId);
    } else {
      service.cancelByTitle(film.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: downloadService,
      builder: (BuildContext context, Widget? child) {
        final DownloadTask? task = film.tmdbId != null
            ? downloadService.taskFor(film.tmdbId)
            : downloadService.taskForTitle(film.title);
        final bool active = task?.status == DownloadStatus.downloading ||
            task?.status == DownloadStatus.queued;
        final bool done = task?.status == DownloadStatus.completed;
        final bool failed = task?.status == DownloadStatus.failed;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.surfaceHigh),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceHigh,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.movie_filter,
                      color: AppPalette.brand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          film.title,
                          style: const TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${film.year} · ${film.runtime} · '
                          '${DownloadTask.formatBytes(film.sizeBytes)}',
                          style: const TextStyle(
                            color: AppPalette.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            film.license,
                            style: const TextStyle(
                              color: AppPalette.dangerBright,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (task != null)
                _ProgressStrip(task: task, failed: failed)
              else
                Text(
                  'Saved as ${film.fileName}',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DangerButton(
                      label: done
                          ? 'Saved'
                          : active
                              ? 'Downloading'
                              : failed
                                  ? 'Retry'
                                  : 'Download',
                      icon: done
                          ? Icons.check
                          : active
                              ? Icons.downloading
                              : Icons.download,
                      onPressed: (done || active) ? null : onDownload,
                    ),
                  ),
                  if (active) ...<Widget>[
                    const SizedBox(width: 10),
                    DangerButton(
                      label: 'Cancel',
                      icon: Icons.close,
                      filled: false,
                      onPressed: () => _cancel(downloadService, film),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Progress, and the honest failure message, under a film's buttons.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.task, required this.failed});

  final DownloadTask task;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final bool done = task.status == DownloadStatus.completed;
    final String label = done
        ? 'Saved on this device'
        : failed
            ? (task.isCrossOriginBlocked
                ? 'This source blocks browser saves — open the file instead'
                : 'Failed: ${task.error ?? 'unknown error'}')
            : task.progressLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: done ? 1 : task.progress,
            minHeight: 5,
            backgroundColor: AppPalette.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(
              failed ? AppPalette.textMuted : AppPalette.brand,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: <Widget>[
            Icon(
              done
                  ? Icons.check_circle
                  : failed
                      ? Icons.error_outline
                      : Icons.downloading,
              size: 14,
              color: done
                  ? AppPalette.brand
                  : failed
                      ? AppPalette.textMuted
                      : AppPalette.dangerBright,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.search_off,
            color: AppPalette.textMuted,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            'No film matches that search',
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a title, a year, or a licence such as CC BY.',
            style: TextStyle(color: AppPalette.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
