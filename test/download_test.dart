import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movies/api/endpoints.dart';
import 'package:movies/models/movie_source.dart';
import 'package:movies/services/download_service.dart';
import 'package:movies/services/movie_source_service.dart';

/// A licensed source pointing at a host the tests never contact.
const DownloadSource mp4Source = DownloadSource(
  url: 'https://example.invalid/movie.mp4',
  fileName: 'Big_Buck_Bunny.mp4',
  sizeBytes: 0,
  license: 'CC BY 3.0 — Blender Foundation',
);

/// A stand-in stream failure, so the service's catch path is exercised.
class SocketishError implements Exception {
  const SocketishError();
}

void main() {
  group('open film catalogue', () {
    test('every entry is a complete file with a licence', () {
      expect(MovieSourceService.openFilms, isNotEmpty);
      for (final OpenFilm film in MovieSourceService.openFilms) {
        expect(film.url, startsWith('https://'), reason: film.title);
        expect(film.url, endsWith('.mp4'), reason: film.title);
        expect(film.sizeBytes, greaterThan(1 << 20), reason: film.title);
        expect(film.license, isNotEmpty, reason: film.title);
      }
    });

    test('tmdb ids and titles are unique', () {
      final Set<int> ids = MovieSourceService.openFilms
          .map((OpenFilm f) => f.tmdbId)
          .toSet();
      final Set<String> titles = MovieSourceService.openFilms
          .map((OpenFilm f) => f.title.toLowerCase())
          .toSet();
      expect(ids.length, MovieSourceService.openFilms.length);
      expect(titles.length, MovieSourceService.openFilms.length);
    });

    test('resolves a downloadable source by id and by title', () async {
      final MovieSourceService service = MovieSourceService();
      addTearDown(service.dispose);

      final OpenFilm film = MovieSourceService.openFilms.first;
      expect(
        (await service.fetchDownloadSource(film.tmdbId, null))?.url,
        film.url,
      );
      expect(
        (await service.fetchDownloadSource(null, film.title))?.url,
        film.url,
      );
    });

    test('returns null for a title with no free release', () async {
      final MovieSourceService service = MovieSourceService();
      addTearDown(service.dispose);

      expect(await service.fetchDownloadSource(27205, 'Inception'), isNull);
    });
  });

  group('watch providers', () {
    test('reads the offers from the region key, not from results', () async {
      // This is the real payload shape from /movie/27205/watch/providers: the
      // offer entries carry no `link`, only the region object does. Reading
      // results['flatrate'] or entry['link'] both yield a silent empty list.
      final MovieSourceService service = MovieSourceService(
        client: MockClient((http.Request request) async {
          expect(request.url.path, '/3/movie/27205/watch/providers');
          expect(request.url.queryParameters['watch_region'], 'US');
          return http.Response(
            '{"id":27205,"results":{'
            '"GB":{"link":""},'
            '"US":{"link":"https://www.themoviedb.org/movie/27205-inception'
            '/watch?locale=US",'
            '"flatrate":[{"logo_path":"/a.png","provider_id":1866,'
            '"provider_name":"ViX Premium","display_priority":153},'
            '{"logo_path":"/b.png","provider_id":8,'
            '"provider_name":"Netflix","display_priority":1}],'
            '"rent":[{"logo_path":"/c.png","provider_id":10,'
            '"provider_name":"Amazon Video","display_priority":8}]}}}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final List<WatchProvider> providers =
          await service.fetchWatchProviders(27205);
      expect(
        providers.map((WatchProvider p) => p.name).toList(),
        <String>['ViX Premium', 'Netflix', 'Amazon Video'],
      );
      // Every provider points at the single watch page the region advertises.
      for (final WatchProvider p in providers) {
        expect(p.webUrl, contains('/watch?locale=US'));
      }
      expect(providers[0].type, WatchProviderType.stream);
      expect(providers[0].isFree, isFalse);
      expect(providers[0].logoUrl, endsWith('/a.png'));
      expect(providers[2].type, WatchProviderType.rent);
      expect(providers[2].isPaid, isTrue);
    });

    test('marks an ad-supported provider as free', () async {
      final MovieSourceService service = MovieSourceService(
        client: MockClient((http.Request request) async => http.Response(
              '{"results":{"US":{"link":"https://x/watch",'
              '"free":[{"provider_id":613,"provider_name":"Freevee"}]}}}',
              200,
            )),
      );
      addTearDown(service.dispose);

      final List<WatchProvider> providers = await service.fetchWatchProviders(1);
      expect(providers.single.type, WatchProviderType.free);
      expect(providers.single.isFree, isTrue);
      expect(providers.single.isPaid, isFalse);
    });

    test('de-duplicates a provider listed in two offer types', () async {
      final MovieSourceService service = MovieSourceService(
        client: MockClient((http.Request request) async => http.Response(
              '{"results":{"US":{"link":"https://x/watch",'
              '"flatrate":[{"provider_id":8,"provider_name":"Netflix"}],'
              '"buy":[{"provider_id":8,"provider_name":"Netflix"}]}}}',
              200,
            )),
      );
      addTearDown(service.dispose);

      expect(await service.fetchWatchProviders(1), hasLength(1));
    });

    test('falls back to any known market when the region is absent', () async {
      final MovieSourceService service = MovieSourceService(
        client: MockClient((http.Request request) async => http.Response(
              '{"results":{"GH":{"link":"https://x/watch?locale=GH",'
              '"flatrate":[{"provider_id":8,"provider_name":"Showmax"}]}}}',
              200,
            )),
      );
      addTearDown(service.dispose);

      final List<WatchProvider> providers =
          await service.fetchWatchProviders(1, region: 'US');
      expect(providers.single.name, 'Showmax');
      expect(providers.single.webUrl, contains('locale=GH'));
    });

    test('returns an empty list when no market has a watch page', () async {
      final MovieSourceService service = MovieSourceService(
        client: MockClient((http.Request request) async => http.Response(
              '{"results":{"US":{"link":"","flatrate":[]}}}',
              200,
            )),
      );
      addTearDown(service.dispose);

      expect(await service.fetchWatchProviders(1), isEmpty);
    });

    test('returns an empty list when the endpoint fails', () async {
      final MovieSourceService service = MovieSourceService(
        client: MockClient(
            (http.Request request) async => http.Response('', 500)),
      );
      addTearDown(service.dispose);

      expect(await service.fetchWatchProviders(27205), isEmpty);
    });

    test('returns an empty list when the request throws', () async {
      final MovieSourceService service = MovieSourceService(
        client: MockClient(
          (http.Request request) async => throw const SocketishError(),
        ),
      );
      addTearDown(service.dispose);

      expect(await service.fetchWatchProviders(27205), isEmpty);
    });
  });

  group('watch provider url', () {
    test('carries the api key and the region', () {
      final String url = Endpoints.watchProvidersUrl(27205, 'gb');
      expect(url, contains('/movie/27205/watch/providers'));
      expect(url, contains('watch_region=GB'));
      expect(url, contains('api_key='));
    });
  });

  group('download service', () {
    test('streams the whole file and reports the finished path', () async {
      const String payload = 'a real mp4 payload, streamed in chunks';
      final List<List<int>> chunks = <List<int>>[];
      for (int i = 0; i < payload.length; i += 8) {
        final int end = i + 8 > payload.length ? payload.length : i + 8;
        chunks.add(payload.substring(i, end).codeUnits.toList());
      }

      final DownloadService service = DownloadService(
        client: MockClient.streaming(
          (http.BaseRequest request, http.ByteStream body) async {
            return http.StreamedResponse(
              Stream<List<int>>.fromIterable(chunks),
              200,
              contentLength: payload.length,
            );
          },
        ),
      );
      addTearDown(service.dispose);

      final DownloadTask task = await service.start(
        movieId: 1,
        title: 'Big Buck Bunny',
        source: mp4Source,
      );
      await _settle(service, task);

      expect(task.status, DownloadStatus.completed, reason: task.error);
      expect(task.received, payload.length);
      expect(task.total, payload.length);
      expect(task.progress, 1);
      expect(task.location, isNotNull);
      expect(task.location, contains('1_Big_Buck_Bunny.mp4'));
      expect(service.isDownloaded(1), isTrue);
    });

    test('does not start the same title twice', () async {
      int requests = 0;
      final DownloadService service = DownloadService(
        client: MockClient.streaming(
          (http.BaseRequest request, http.ByteStream body) async {
            requests++;
            return http.StreamedResponse(
              Stream<List<int>>.value(<int>[1, 2, 3]),
              200,
            );
          },
        ),
      );
      addTearDown(service.dispose);

      final DownloadTask first = await service.start(
        movieId: 7,
        title: 'Spring',
        source: mp4Source,
      );
      await _settle(service, first);
      final DownloadTask second = await service.start(
        movieId: 7,
        title: 'Spring',
        source: mp4Source,
      );
      await _settle(service, second);

      expect(identical(first, second), isTrue);
      expect(requests, 1);
    });

    test('fails loudly on a non-200 response', () async {
      final DownloadService service = DownloadService(
        client: MockClient.streaming(
          (http.BaseRequest request, http.ByteStream body) async =>
              http.StreamedResponse(const Stream<List<int>>.empty(), 404),
        ),
      );
      addTearDown(service.dispose);

      final DownloadTask task = await service.start(
        movieId: 2,
        title: 'Sprite Fright',
        source: mp4Source,
      );
      await _settle(service, task);

      expect(task.status, DownloadStatus.failed);
      expect(task.error, contains('404'));
      expect(service.isDownloaded(2), isFalse);
    });

    test('cancel stops a transfer and marks the task cancelled', () async {
      final StreamController<List<int>> controller =
          StreamController<List<int>>();
      addTearDown(controller.close);

      final DownloadService service = DownloadService(
        client: MockClient.streaming(
          (http.BaseRequest request, http.ByteStream body) async =>
              http.StreamedResponse(controller.stream, 200),
        ),
      );
      addTearDown(service.dispose);

      final DownloadTask task = await service.start(
        movieId: 3,
        title: 'Big Buck Bunny',
        source: mp4Source,
      );
      controller.add(<int>[1, 2, 3]);
      await _waitFor(() => task.received == 3);
      expect(task.status, DownloadStatus.downloading);

      await service.cancel(3);
      expect(task.status, DownloadStatus.cancelled);

      // Anything the server sends after the cancel must be ignored.
      controller.add(<int>[4, 5, 6]);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(task.received, 3);
    });

    test('remove forgets a finished download', () async {
      final DownloadService service = DownloadService(
        client: MockClient.streaming(
          (http.BaseRequest request, http.ByteStream body) async =>
              http.StreamedResponse(
                Stream<List<int>>.value(<int>[9, 9]),
                200,
              ),
        ),
      );
      addTearDown(service.dispose);

      final DownloadTask task = await service.start(
        movieId: 4,
        title: 'Spring',
        source: mp4Source,
      );
      await _settle(service, task);
      expect(service.isDownloaded(4), isTrue);

      await service.remove(4);
      expect(service.isDownloaded(4), isFalse);
      expect(service.taskFor(4), isNull);
    });

    test('progress label formats bytes', () {
      expect(DownloadTask.formatBytes(0), '0 B');
      expect(DownloadTask.formatBytes(999), '999 B');
      expect(DownloadTask.formatBytes(1536), '1.5 KB');
      expect(DownloadTask.formatBytes(61878609), '59.0 MB');
    });
  });
}

/// Polls until [task] leaves an in-flight state, so the test does not depend
/// on how many microtasks the network layer happens to need.
Future<void> _settle(DownloadService service, DownloadTask task) async {
  await _waitFor(() =>
      task.status != DownloadStatus.downloading &&
      task.status != DownloadStatus.queued);
  // One more turn so any post-completion bookkeeping has run.
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

/// Polls until [done] returns true, or fails the test.
Future<void> _waitFor(bool Function() done) async {
  for (int i = 0; i < 300; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition was never true');
}
