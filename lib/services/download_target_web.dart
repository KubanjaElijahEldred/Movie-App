import 'dart:js_interop';
import 'dart:typed_data';

import 'package:movies/services/download_target.dart';
import 'package:web/web.dart' as web;

/// The web has no writable filesystem, so the bytes are buffered in memory and
/// handed to the browser's download manager as a blob once the transfer ends.
///
/// This is why every download source must send permissive CORS headers: the
/// browser will not expose the response body to this code otherwise.
DownloadTarget createDownloadTarget({
  required int? movieId,
  required String fileName,
  required String mimeType,
}) =>
    _BlobTarget(fileName: fileName, mimeType: mimeType);

class _BlobTarget implements DownloadTarget {
  _BlobTarget({required this.fileName, required this.mimeType});

  final String fileName;
  final String mimeType;

  /// Grows as chunks arrive, so a 90 MB film is held exactly once.
  final BytesBuilder _builder = BytesBuilder(copy: false);

  bool _aborted = false;
  bool _finished = false;

  @override
  void addChunk(List<int> chunk) {
    if (_aborted || _finished) return;
    _builder.add(chunk);
  }

  @override
  Future<String> finish() async {
    _finished = true;
    final Uint8List bytes = _builder.takeBytes();

    final web.Blob blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final String url = web.URL.createObjectURL(blob);

    final web.HTMLAnchorElement anchor =
        web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();

    // Revoking immediately can cancel the transfer in some browsers, so the
    // object URL is released a moment after the click is dispatched.
    Future<void>.delayed(const Duration(seconds: 30), () {
      web.URL.revokeObjectURL(url);
    });

    return fileName;
  }

  @override
  Future<void> abort() async {
    _aborted = true;
    _finished = true;
    _builder.clear();
  }
}
