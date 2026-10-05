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
  /// The files are served by Wikimedia Commons with `Access-Control-Allow-
  /// Origin: *`, which is what lets the web build fetch them at all.
  ///
  /// These are the only titles the app offers as a file. A commercial title
  /// resolves to watch providers instead, because no licence permits
  /// redistributing it.
  static const List<OpenFilm> openFilms = <OpenFilm>[
    // Served from Wikimedia Commons rather than archive.org: archive.org
    // redirects to a CDN that omits Access-Control-Allow-Origin, so a browser
    // can play the file but the app can never read the bytes to save them.
    //
    // Commons answers `access-control-allow-origin: *` on the file itself, which
    // is what makes the in-page save work. Sizes are the real content-length
    // values, so the progress bar is honest before the first chunk lands.
    //
    // Every entry is a complete short published by its creator under a licence
    // that permits redistribution. Blender's open movies are CC BY, which is
    // why this list exists at all: it is the only content the app may hand a
    // user as a file. Commercial titles resolve to watch providers instead.
    OpenFilm(
      tmdbId: 10378,
      title: 'Big Buck Bunny',
      year: '2008',
      runtime: '9 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/e/e7/'
          'Big_buck_bunny_720p_5mb.webm',
      fileName: 'Big_Buck_Bunny.webm',
      sizeBytes: 5709008,
      mimeType: 'video/webm',
      license: 'CC BY-SA 4.0 — Blender Foundation',
    ),
    OpenFilm(
      tmdbId: 253774,
      title: 'Caminandes: Gran Dillama',
      year: '2013',
      runtime: '2 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/8/8b/'
          'Caminandes%2C_Gran_Dillama_-_Blender_Foundation.webm',
      fileName: 'Caminandes_Gran_Dillama.webm',
      sizeBytes: 68626328,
      mimeType: 'video/webm',
      license: 'CC BY-SA 3.0 — Blender Foundation',
    ),
    OpenFilm(
      tmdbId: 1062079,
      title: 'Charge',
      year: '2022',
      runtime: '2 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/7/7a/'
          'Charge_-_Blender_Open_Movie-full_movie.webm',
      fileName: 'Charge.webm',
      sizeBytes: 223478979,
      mimeType: 'video/webm',
      license: 'CC BY 4.0 — Blender Studio',
    ),
    OpenFilm(
      tmdbId: 908389,
      title: 'Coffee Run',
      year: '2020',
      runtime: '3 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/3/3f/'
          'Coffee_Run_-_Blender_Open_Movie-full_movie.webm',
      fileName: 'Coffee_Run.webm',
      sizeBytes: 29260881,
      mimeType: 'video/webm',
      license: 'CC BY 4.0 — Blender Studio',
    ),
    OpenFilm(
      tmdbId: 738102,
      title: 'Glass Half',
      year: '2020',
      runtime: '3 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/0/02/'
          'Glass_Half_-_Blender_Open_Movie-full_movie.webm',
      fileName: 'Glass_Half.webm',
      sizeBytes: 175136749,
      mimeType: 'video/webm',
      license: 'CC BY 4.0 — Blender Studio',
    ),
    OpenFilm(
      tmdbId: null,
      title: 'HERO',
      year: '2016',
      runtime: '4 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/a/a9/'
          'HERO_-_Blender_Open_Movie-full_movie.webm',
      fileName: 'HERO.webm',
      sizeBytes: 60475168,
      mimeType: 'video/webm',
      license: 'CC BY 4.0 — Blender Studio',
    ),
    OpenFilm(
      tmdbId: 593048,
      title: 'Spring',
      year: '2019',
      runtime: '8 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/a/a5/'
          'Spring_-_Blender_Open_Movie.webm',
      fileName: 'Spring.webm',
      sizeBytes: 81781205,
      mimeType: 'video/webm',
      license: 'CC BY 4.0 — Blender Studio',
    ),
    OpenFilm(
      tmdbId: 891761,
      title: 'Sprite Fright',
      year: '2022',
      runtime: '5 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/7/76/'
          'Sprite_Fright_-_Blender_Open_Movie-full_movie.webm',
      fileName: 'Sprite_Fright.webm',
      sizeBytes: 158621642,
      mimeType: 'video/webm',
      license: 'CC BY 4.0 — Blender Studio',
    ),
    OpenFilm(
      tmdbId: 498482,
      title: 'The Daily Dweebs',
      year: '2020',
      runtime: '7 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/b/b2/'
          'The_Daily_Dweebs_-_Blender_Open_Movie-full_movie.webm',
      fileName: 'The_Daily_Dweebs.webm',
      sizeBytes: 147627996,
      mimeType: 'video/webm',
      license: 'CC BY 4.0 — Blender Studio',
    ),
    OpenFilm(
      tmdbId: 1177628,
      title: 'WING IT!',
      year: '2023',
      runtime: '3 min',
      url: 'https://upload.wikimedia.org/wikipedia/commons/3/38/'
          'WING_IT%21_-_Blender_Open_Movie-full_movie.webm',
      fileName: 'WING_IT!.webm',
      sizeBytes: 36196718,
      mimeType: 'video/webm',
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
      if (tmdbId != null && film.tmdbId != null && film.tmdbId == tmdbId) {
        return film.source;
      }
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
