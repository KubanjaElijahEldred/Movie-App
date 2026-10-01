import 'download_target_io.dart'
    if (dart.library.js_interop) 'download_target_web.dart' as impl;

/// Where a download's bytes are written.
///
/// Mobile and desktop write straight to a file, so a feature-length film never
/// has to fit in memory. The web has no writable filesystem, so bytes are
/// accumulated and handed to the browser's own download manager as a blob.
abstract class DownloadTarget {
  /// Appends a chunk of the file. May be called from the network callback.
  void addChunk(List<int> chunk);

  /// Flushes and closes, returning a human-readable location for the file.
  ///
  /// A path on mobile and desktop, the file name on the web.
  Future<String> finish();

  /// Abandons the transfer and discards whatever was written.
  Future<void> abort();
}

/// Creates a target that writes [fileName] for [movieId].
DownloadTarget createDownloadTarget({
  required int? movieId,
  required String fileName,
  required String mimeType,
}) =>
    impl.createDownloadTarget(
      movieId: movieId,
      fileName: fileName,
      mimeType: mimeType,
    );
