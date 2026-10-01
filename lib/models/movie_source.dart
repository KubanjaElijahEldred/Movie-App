/// Where a title can legally be watched, streamed or downloaded.
///
/// The app cannot ship or fetch full-length commercial films: TMDB is a
/// metadata service and does not host video files, and its trailer data is
/// only YouTube keys uploaded by the studios. So every entry here points at
/// something the rights holder publishes for public consumption, and the
/// download button only ever points at a file that is genuinely free to
/// fetch.
class WatchProvider {
  const WatchProvider({
    required this.name,
    required this.webUrl,
    this.logoUrl,
    this.type = WatchProviderType.stream,
    this.isFree = false,
  });

  final String name;

  /// Opens the provider's own page for this title.
  final String webUrl;

  final String? logoUrl;
  final WatchProviderType type;

  /// True when the provider does not charge for this title.
  final bool isFree;

  /// Whether the title has to be paid for before it can be watched.
  bool get isPaid => type == WatchProviderType.rent || type == WatchProviderType.buy;
}

/// What a provider offers for a given title.
///
/// The four values mirror the list names TMDB nests under each region.
enum WatchProviderType {
  /// Part of a subscription: `flatrate`.
  stream,

  /// Advertised as free to watch: `free`.
  free,

  /// Rented for a fixed period: `rent`.
  rent,

  /// Bought outright: `buy`.
  buy,
}

/// A downloadable file for a title.
class DownloadSource {
  const DownloadSource({
    required this.url,
    required this.fileName,
    required this.sizeBytes,
    required this.license,
    this.mimeType = 'video/mp4',
  });

  /// Direct, CORS-readable file URL.
  final String url;

  /// Suggested file name, extension included.
  final String fileName;

  /// Size in bytes, or 0 when the server does not report it.
  final int sizeBytes;

  /// Human-readable licence, shown in the UI so the source is never a
  /// surprise.
  final String license;

  final String mimeType;
}

/// A film published for free download, with the licence that permits it.
class OpenFilm {
  const OpenFilm({
    required this.tmdbId,
    required this.title,
    required this.year,
    required this.runtime,
    required this.url,
    required this.fileName,
    required this.sizeBytes,
    required this.license,
  });

  /// TMDB listing, so a catalogue card can deep-link to the title.
  final int tmdbId;

  final String title;
  final String year;
  final String runtime;

  /// Direct, CORS-readable file URL.
  final String url;

  final String fileName;
  final int sizeBytes;
  final String license;

  DownloadSource get source => DownloadSource(
        url: url,
        fileName: fileName,
        sizeBytes: sizeBytes,
        license: license,
      );
}
