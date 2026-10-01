import 'package:flutter/material.dart';
import 'package:movies/constants/app_theme.dart';
import 'package:movies/models/movie_source.dart';
import 'package:movies/services/download_service.dart';
import 'package:movies/services/movie_source_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom sheet listing where a title can legally be watched, and offering a
/// real download when the title has a free-to-save release.
///
/// The sheet never claims a film can be downloaded unless
/// [MovieSourceService.fetchDownloadSource] returned a licence that permits
/// it, so the Download action is always honest about what it will do.
class WhereToWatchSheet extends StatefulWidget {
  const WhereToWatchSheet({
    super.key,
    required this.title,
    required this.tmdbId,
    required this.downloadService,
    this.movieSourceService,
  });

  final String title;
  final int? tmdbId;
  final DownloadService downloadService;
  final MovieSourceService? movieSourceService;

  /// Shows the sheet and resolves to true when a download was started.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required int? tmdbId,
    required DownloadService downloadService,
    MovieSourceService? movieSourceService,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext context) => WhereToWatchSheet(
        title: title,
        tmdbId: tmdbId,
        downloadService: downloadService,
        movieSourceService: movieSourceService,
      ),
    );
  }

  @override
  State<WhereToWatchSheet> createState() => _WhereToWatchSheetState();
}

class _WhereToWatchSheetState extends State<WhereToWatchSheet> {
  late final MovieSourceService _sources =
      widget.movieSourceService ?? MovieSourceService();

  List<WatchProvider> _providers = const <WatchProvider>[];
  DownloadSource? _download;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    // Only dispose the fallback instance; an injected one is owned by the
    // caller and may be reused.
    if (widget.movieSourceService == null) _sources.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    setState(() => _loading = true);

    final int? id = widget.tmdbId;
    final List<WatchProvider> providers =
        id == null ? <WatchProvider>[] : await _sources.fetchWatchProviders(id);
    final DownloadSource? source =
        await _sources.fetchDownloadSource(id, widget.title);

    if (!mounted) return;
    setState(() {
      _providers = providers;
      _download = source;
      _loading = false;
    });
  }

  Future<void> _open(WatchProvider provider) async {
    final Uri uri = Uri.parse(provider.webUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that link')),
      );
    }
  }

  Future<void> _startDownload() async {
    final DownloadSource? source = _download;
    if (source == null) return;

    // The messenger is captured before the pop: afterwards this State's context
    // is defunct and showing a SnackBar through it would throw.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    final DownloadTask task = await widget.downloadService.start(
      movieId: widget.tmdbId,
      title: widget.title,
      source: source,
    );

    if (!mounted) return;
    navigator.pop(true);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          task.status == DownloadStatus.completed
              ? '${source.fileName} saved'
              : 'Downloading ${source.fileName} '
                  '(${DownloadTask.formatBytes(source.sizeBytes)})',
        ),
        backgroundColor: AppPalette.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Where to watch',
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 56),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppPalette.brand,
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: <Widget>[
                        if (_download != null) ...<Widget>[
                          _DownloadTile(
                            source: _download!,
                            onPressed: _startDownload,
                          ),
                          const SizedBox(height: 22),
                        ] else ...<Widget>[
                          const _NoDownloadNote(),
                          const SizedBox(height: 22),
                        ],
                        if (_providers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No streaming providers are listed for this '
                              'title in your region.',
                              style: TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else ...<Widget>[
                          const Text(
                            'Available in your region',
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              for (final WatchProvider provider in _providers)
                                _ProviderChip(provider: provider),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // TMDB publishes one watch page per title and region
                          // rather than a deep link per provider, so there is
                          // a single honest call to action instead of several
                          // buttons that all opened the same place.
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _open(_providers.first),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('See where to watch'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppPalette.brand,
                                foregroundColor: AppPalette.background,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Opens the official TMDB watch page, which links '
                            'straight to each provider.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.source, required this.onPressed});

  final DownloadSource source;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppPalette.danger.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.danger.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.download,
                  color: AppPalette.dangerBright,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Download film',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      source.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source.sizeBytes > 0
                          ? '${_format(source.sizeBytes)} · ${source.license}'
                          : source.license,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppPalette.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(int bytes) {
    if (bytes <= 0) return '';
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(1)} ${units[unit]}';
  }
}

/// One streaming service, shown as a logo-and-name chip.
///
/// TMDB gives a single watch page per title and region rather than a link per
/// provider, so these are informational and the sheet carries one button that
/// opens the page.
class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.provider});

  final WatchProvider provider;

  @override
  Widget build(BuildContext context) {
    final String? logo = provider.logoUrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppPalette.textMuted.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: logo == null
                ? const _FallbackLogo()
                : Image.network(
                    logo,
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stack,
                    ) => const _FallbackLogo(),
                  ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              provider.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (provider.isFree) ...<Widget>[
            const SizedBox(width: 7),
            const _Badge(
              label: 'FREE',
              color: AppPalette.brand,
              background: Color(0x2E10D98D),
            ),
          ] else if (provider.isPaid) ...<Widget>[
            const SizedBox(width: 7),
            _Badge(
              label:
                  provider.type == WatchProviderType.buy ? 'BUY' : 'RENT',
              color: AppPalette.textSecondary,
              background: Colors.transparent,
            ),
          ],
        ],
      ),
    );
  }
}

/// Stands in for a provider logo that fails to load, which happens whenever
/// TMDB has not uploaded one yet.
class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Icon(
        Icons.play_circle_outline,
        color: AppPalette.textMuted,
        size: 20,
      ),
    );
  }
}

/// A small pill describing what a provider charges.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NoDownloadNote extends StatelessWidget {
  const _NoDownloadNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline,
            color: AppPalette.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This title has no free-to-download release, so it is not '
              'offered as a file. The providers below are the legal ways to '
              'watch it.',
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
