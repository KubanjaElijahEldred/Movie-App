import 'dart:io';

import 'package:movies/services/download_target.dart';

DownloadTarget createDownloadTarget({
  required int? movieId,
  required String fileName,
  required String mimeType,
}) {
  final String safe = movieId == null
      ? fileName
      : '${movieId}_$fileName';
  return _FileTarget(File('${_downloadDirectory().path}/$safe'));
}

/// Directory the downloads are written to.
///
/// A subdirectory of the system temp folder keeps the app free of extra
/// platform plugins, and a name derived from the movie id stops two titles with
/// the same file name from overwriting each other.
final Directory _cache = Directory(
  '${Directory.systemTemp.path}/playit_downloads',
);

Directory _downloadDirectory() {
  if (!_cache.existsSync()) {
    _cache.createSync(recursive: true);
  }
  return _cache;
}

/// Writes chunks straight to disk as they arrive.
class _FileTarget implements DownloadTarget {
  _FileTarget(this._file);

  final File _file;
  IOSink? _sink;
  bool _aborted = false;

  @override
  void addChunk(List<int> chunk) {
    if (_aborted) return;
    _sink ??= _file.openWrite();
    _sink!.add(chunk);
  }

  @override
  Future<String> finish() async {
    final IOSink? sink = _sink;
    _sink = null;
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }
    return _file.path;
  }

  @override
  Future<void> abort() async {
    _aborted = true;
    final IOSink? sink = _sink;
    _sink = null;
    if (sink != null) {
      try {
        await sink.close();
      } on Object {
        // Already closed.
      }
    }
    if (_file.existsSync()) {
      try {
        await _file.delete();
      } on Object {
        // Leaving the partial file is better than throwing mid-teardown.
      }
    }
  }
}
