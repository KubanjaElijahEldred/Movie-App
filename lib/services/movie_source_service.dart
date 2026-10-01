import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:movies/constants/api_constants.dart';
import 'package:movies/api/endpoints.dart';
import 'package:movies/models/movie_source.dart';

/// Resolves where a title can be watched, and which files may be saved.
///
/// Three real sources, in priority order:
///
/// 1. **Watch providers** from TMDB's `/watch/providers` endpoint. JustWatch
///    data, so these are genuine legal streaming/retail links per country.
/// 2. **Open films** from a short, hard-coded catalogue of feature films whose
///    creators published them for free download (Blender open movies and
///    public-domain titles). These are the only titles the app will actually
///    download, because their licence permits it.
/// 3. A configurable self-hosted CDN, so a studio or K.E.E can point the app
///    at their own library without a code change.
class MovieSourceService {
  MovieSourceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Base URL of an optional self-hosted library.
  ///
  /// Set [customLibraryBaseUrl] to a server that exposes
  /// `GET /catalogue.json` shaped like [CustomLibraryEntry]. Left null by
  /// default, so the app never assumes a host it was not pointed at.
  static String? customLibraryBaseUrl;

  /// Films published for free download, matched by TMDB title.
  ///
  /// Each entry is a complete short film released by its creators under a
  /// licence that permits redistribution (Blender's open movies are CC BY).
  /// The files are served by the Internet Archive with `Access-Control-Allow-
  /// Origin: *`, which is what lets the web build fetch them at all.
  ///
  /// These are the only titles the app offers as a file. A commercial title
  /// resolves to watch providers instead, because no licence permits
  /// redistributing it.
  static const List<OpenFilm> openFilms = <OpenFilm>[
    OpenFilm(
      tmdbId: 86644,
      title: 'Big Buck Bunny',
      year: '2008',
      runtime: '9 min',
      url: 'https://archive.org/download/BigBuckBunny_124/Content/'
          'big_buck_bunny_720p_surround.mp4',
      fileName: 'Big_Buck_Bunny_720p.mp4',
      sizeBytes: 61878609,
      license: 'CC BY 3.0 — Blender Foundation',
    ),
    OpenFilm(
      tmdbId: 531428,
      title: 'Spring',
      year: '2019',
      runtime: '8 min',
      url: 'https://archive.org/download/springopenmovie/springopenmovie.mp4',
      fileName: 'Spring_Open_Movie.mp4',
      sizeBytes: 90190341,
      license: 'CC BY 4.0 — Blender Studio',
    ),
    OpenFilm(
      tmdbId: 653734,
      title: 'Sprite Fright',
      year: '2022',
      runtime: '5 min',
      url: 'https://archive.org/download/sprite-fright/'
          'Sprite%20Fright%20-%20Open%20Movie%20by%20Blender%20Studio-804p.mp4',
      fileName: 'Sprite_Fright_1080p.mp4',
      sizeBytes: 110581245,
      license: 'CC BY 4.0 — Blender Studio',
    ),
  ];

  /// Fetches TMDB's watch providers for [tmdbId] in [region].
  ///
  /// TMDB nests the payload two levels deep: `results` is keyed by country,
  /// and each country holds a `link` plus the `flatrate`, `free`, `rent` and
  /// `buy` lists. Two mistakes are easy here and both produce a silently
  /// empty sheet, so they are worth stating:
  ///
  /// * the offer lists live under the country key, not directly under
  ///   `results`, and
  /// * only the country object carries a `link` — an individual provider entry
  ///   has just a logo, id, name and priority. Every provider therefore shares
  ///   the one watch page for the region.
  ///
  /// Returns an empty list when the request fails, so a detail page still
  /// renders when the endpoint is unreachable.
  Future<List<WatchProvider>> fetchWatchProviders(
    int tmdbId, {
    String region = 'US',
  }) async {
    try {
      final http.Response res = await _client
          .get(Uri.parse(Endpoints.watchProvidersUrl(tmdbId, region)))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const <WatchProvider>[];

      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      final Map<String, dynamic> byRegion =
          (body['results'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final String wanted = region.toUpperCase();
      final Map<String, dynamic>? offers =
          byRegion[wanted] as Map<String, dynamic>? ??
              // TMDB answers with the requested region when it knows the
              // title, but otherwise with whichever market it does know about.
              byRegion.values
                  .whereType<Map<String, dynamic>>()
                  .cast<Map<String, dynamic>?>()
                  .firstWhere(
                    (Map<String, dynamic>? e) =>
                        (e?['link'] as String? ?? '').isNotEmpty,
                    orElse: () => null,
                  );
      if (offers == null) return const <WatchProvider>[];

      final String watchPage = offers['link'] as String? ?? '';

      // Only a small set is carried through, because TMDB returns many
      // providers per title and the sheet has no room for them all.
      const int maxProviders = 8;
      final List<WatchProvider> providers = <WatchProvider>[];
      final Set<String> seen = <String>{};

      void collect(WatchProviderType type, Object? raw) {
        if (providers.length >= maxProviders || raw == null) return;
        final Map<String, dynamic> entry = raw as Map<String, dynamic>;
        final int id = entry['provider_id'] as int? ?? 0;
        final String name = entry['provider_name'] as String? ?? '';
        if (name.isEmpty || watchPage.isEmpty || !seen.add(name)) return;

        providers.add(WatchProvider(
          name: name,
          webUrl: watchPage,
          logoUrl: entry['logo_path'] == null
              ? (id == 0 ? null : tmdbLogoUrl(id))
              : tmdbImageUrl(entry['logo_path'] as String?, size: 'w92'),
          type: type,
          isFree: type == WatchProviderType.free,
        ));
      }

      for (final Object? entry
          in (offers['flatrate'] as List<Object?>? ?? const <Object?>[])) {
        collect(WatchProviderType.stream, entry);
      }
      for (final Object? entry
          in (offers['free'] as List<Object?>? ?? const <Object?>[])) {
        collect(WatchProviderType.free, entry);
      }
      for (final Object? entry
          in (offers['rent'] as List<Object?>? ?? const <Object?>[])) {
        collect(WatchProviderType.rent, entry);
      }
      for (final Object? entry
          in (offers['buy'] as List<Object?>? ?? const <Object?>[])) {
        collect(WatchProviderType.buy, entry);
      }

      return providers;
    } catch (_) {
      return const <WatchProvider>[];
    }
  }

  /// TMDB serves provider logos from a separate image path.
  static const String _providerLogoPrefix = '/providers/';

  static String tmdbLogoUrl(int providerId) =>
      'https://image.tmdb.org/t/p/w92$_providerLogoPrefix$providerId.png';

  /// The downloadable file for [tmdbId], or null when the title has no
  /// free-to-download release.
  ///
  /// Matching is by TMDB id first and title second, so an entry still resolves
  /// when TMDB's id for the film changes.
  Future<DownloadSource?> fetchDownloadSource(
    int? tmdbId,
    String? title,
  ) async {
    for (final OpenFilm film in openFilms) {
      if (tmdbId != null && film.tmdbId == tmdbId) return film.source;
    }
    if (title != null) {
      final String needle = title.trim().toLowerCase();
      for (final OpenFilm film in openFilms) {
        if (film.title.toLowerCase() == needle) return film.source;
      }
    }

    // A configured self-hosted library can widen this to the studio's own
    // catalogue, but it is only consulted when a host was set.
    if (customLibraryBaseUrl != null) {
      try {
        final Uri base = Uri.parse(customLibraryBaseUrl!);
        final http.Response res = await _client
            .get(base.resolve('catalogue.json'))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) return null;

        final dynamic decoded = jsonDecode(res.body);
        final List<Object?> entries = decoded is List
            ? decoded
            : ((decoded as Map<String, dynamic>)['titles'] as List<Object?>? ??
                const <Object?>[]);

        for (final Object? raw in entries) {
          final Map<String, dynamic> entry = raw as Map<String, dynamic>;
          final int id = entry['tmdbId'] as int? ?? 0;
          final String name = (entry['title'] as String? ?? '').toLowerCase();
          if ((tmdbId != null && id == tmdbId) ||
              (title != null && name == title.trim().toLowerCase())) {
            final String? url = entry['url'] as String?;
            if (url == null || url.isEmpty) return null;
            return DownloadSource(
              url: url,
              fileName: entry['fileName'] as String? ?? '$name.mp4',
              sizeBytes: entry['sizeBytes'] as int? ?? 0,
              license: entry['license'] as String? ?? 'Licensed',
            );
          }
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void dispose() => _client.close();
}
