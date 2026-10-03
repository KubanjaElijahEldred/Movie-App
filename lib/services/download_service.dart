import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:movies/models/movie_source.dart';
import 'package:movies/services/download_target.dart';

/// Where a download currently is.
enum DownloadStatus { queued, downloading, completed, failed, cancelled }

/// A single in-flight or finished download.
///
/// Exposed as a [ChangeNotifier] so a progress bar can rebuild without the
/// whole dashboard rebuilding on every chunk.
class DownloadTask extends ChangeNotifier {
  DownloadTask({
    required this.movieId,
    required this.title,
    required this.source,
  });

  final int? movieId;
  final String title;
  final DownloadSource source;

  DownloadStatus status = DownloadStatus.queued;

  /// Bytes written so far.
  int received = 0;

  /// Total bytes, or 0 while unknown.
  int total = 0;

  String? error;

  /// Where the finished file ended up: an absolute path on mobile and
  /// desktop, the file name on the web.
  String? location;

  /// True when a transfer failed but the browser can still be pointed straight
  /// at the file, so the UI can offer a manual route instead of a dead end.
  bool get canOpenInBrowser => source.url.startsWith('https://');

  /// Message shown when a failure was caused by the source refusing a
  /// cross-origin read, which is what stops the web build from buffering the
  /// file itself.
  bool get isCrossOriginBlocked =>
      status == DownloadStatus.failed &&
      (error ?? '').contains('CORS');

  double get progress {
    if (status == DownloadStatus.completed) return 1;
    if (total <= 0) return 0;
    return (received / total).clamp(0.0, 1.0);
  }

  /// Downloaded size formatted for the UI, e.g. "12.4 MB / 88.0 MB".
  String get progressLabel {
    final String done = formatBytes(received);
    if (total <= 0) return done;
    return '$done / ${formatBytes(total)}';
  }

  /// 1306 as "1.3 KB".
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
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

/// Streams a real file, with progress, cancellation and resume-from-scratch.
///
/// This is deliberately a plain HTTP downloader. It has no idea what a film
/// is: the caller supplies a [DownloadSource], and only licences that permit
/// redistribution are ever passed in. Point [MovieSourceService] at a studio's
/// own CDN and the same engine manages those files too.
class DownloadService extends ChangeNotifier {
  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Every task, keyed by the movie id string.
  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};

  /// Live network subscriptions, so a cancel can actually stop the transfer.
  final Map<String, StreamSubscription<List<int>>> _subscriptions =
      <String, StreamSubscription<List<int>>>{};

  /// Where each in-flight transfer is writing.
  final Map<String, DownloadTarget> _targets = <String, DownloadTarget>{};

  bool _disposed = false;

  /// Snapshot of every task, for a downloads screen.
  Map<String, DownloadTask> get tasks =>
      Map<String, DownloadTask>.unmodifiable(_tasks);

  /// The task for [movieId], or null when nothing has been started for it.
  DownloadTask? taskFor(int? movieId) {
    if (movieId == null) return null;
    return _tasks[movieId.toString()];
  }

  /// Whether a finished file exists for this title.
  bool isDownloaded(int? movieId) =>
      taskFor(movieId)?.status == DownloadStatus.completed;

  static String _key(int? movieId, String title) =>
      (movieId ?? title.hashCode).toString();

  /// Starts downloading [source] for [movieId].
  ///
  /// Returns the task immediately; progress arrives through [taskFor] and its
  /// [ChangeNotifier] notifications. A title that already finished is not
  /// fetched twice.
  Future<DownloadTask> start({
    required int? movieId,
    required String title,
    required DownloadSource source,
  }) async {
    if (_disposed) {
      throw StateError('DownloadService was used after dispose()');
    }

    final String key = _key(movieId, title);
    final DownloadTask? existing = _tasks[key];
    if (existing != null) {
      if (existing.status == DownloadStatus.completed ||
          existing.status == DownloadStatus.downloading) {
        return existing;
      }
      // A previous attempt failed or was cancelled, so start over.
      _tasks.remove(key);
    }

    final DownloadTask task = DownloadTask(
      movieId: movieId,
      title: title,
      source: source,
    )..total = source.sizeBytes;
    _tasks[key] = task;
    _transfer(key, task, source);
    return task;
  }

  void _transfer(String key, DownloadTask task, DownloadSource source) {
    task
      ..status = DownloadStatus.downloading
      ..received = 0
      ..error = null
      ..location = null;
    task.notifyListeners();

    final DownloadTarget target = createDownloadTarget(
      movieId: task.movieId,
      fileName: source.fileName,
      mimeType: source.mimeType,
    );
    _targets[key] = target;

    () async {
      try {
        // Streamed rather than .get() so a long film never sits in memory on
        // mobile or desktop.
        final http.StreamedResponse res = await _client
            .send(http.Request('GET', Uri.parse(source.url)))
            .timeout(const Duration(seconds: 45));

        if (res.statusCode != 200) {
          await target.abort();
          _targets.remove(key);
          task
            ..status = DownloadStatus.failed
            ..error = 'Server answered ${res.statusCode}';
          task.notifyListeners();
          return;
        }

        // The declared length is authoritative when present, because the
        // catalogue's size is a cached value that can drift.
        final int declared = res.contentLength ?? 0;
        if (declared > 0) task.total = declared;
        task.notifyListeners();

        _subscriptions[key] = res.stream.listen(
          (List<int> chunk) {
            target.addChunk(chunk);
            task.received += chunk.length;
            task.notifyListeners();
          },
          onDone: () async {
            _subscriptions.remove(key);
            _targets.remove(key);
            final String where = await target.finish();
            if (_disposed) return;
            task
              ..status = DownloadStatus.completed
              ..location = where;
            task.notifyListeners();
            notifyListeners();
          },
          onError: (Object error) async {
            _subscriptions.remove(key);
            _targets.remove(key);
            await target.abort();
            _fail(task, error);
          },
          cancelOnError: true,
        );
      } on Object catch (error) {
        _targets.remove(key);
        await target.abort();
        _fail(task, error);
      }
    }();
  }

  /// Records a failure, translating the browser's opaque network error into
  /// something the UI can act on.
  ///
  /// A cross-origin refusal surfaces as a bare `NetworkError` with no detail,
  /// so it is matched on the known shapes and relabelled: it is not a broken
  /// link, it is a source that will not let a browser read the bytes.
  void _fail(DownloadTask task, Object error) {
    if (_disposed) return;
    final String raw = error.toString();
    task
      ..status = DownloadStatus.failed
      ..error = _isCrossOriginRefusal(raw)
          ? 'CORS: the source does not allow browser downloads'
          : raw;
    task.notifyListeners();
  }

  static bool _isCrossOriginRefusal(String raw) {
    if (!kIsWeb) return false;
    return raw.contains('XMLHttpRequest') ||
        raw.contains('NetworkError') ||
        raw.contains('statusCode == 400') ||
        raw.contains('ClientException') ||
        // The browser refuses a cross-origin body without ever naming CORS,
        // surfacing only a bare fetch failure. Treat it the same way, otherwise
        // the UI shows a dead error instead of the direct-link fallback.
        raw.contains('TypeError') ||
        raw.contains('Failed to fetch');
  }

  /// Stops an in-flight download and throws away the partial file.
  Future<void> cancel(int? movieId) async {
    final String key = (movieId ?? 0).toString();
    final DownloadTask? task = _tasks[key];
    if (task == null) return;

    await _subscriptions.remove(key)?.cancel();
    final DownloadTarget? target = _targets.remove(key);
    if (target != null) await target.abort();

    if (_disposed) return;
    task
      ..status = DownloadStatus.cancelled
      ..error = null;
    task.notifyListeners();
  }

  /// Deletes a finished download and forgets the task.
  Future<void> remove(int? movieId) async {
    final String key = (movieId ?? 0).toString();
    final DownloadTask? task = _tasks.remove(key);
    if (task == null) return;
    final DownloadTarget? target = _targets.remove(key);
    if (target != null) await target.abort();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final StreamSubscription<List<int>> sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    for (final DownloadTarget target in _targets.values) {
      target.abort();
    }
    _targets.clear();
    _client.close();
    super.dispose();
  }
}
