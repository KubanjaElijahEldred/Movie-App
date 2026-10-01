// A one-off network check, run with `dart run`, that proves the open-film
// catalogue and the TMDB watch-provider endpoint both answer for real.
//
// Not part of the test suite, because it depends on the network and on a
// third party staying up.
import 'dart:io';

import 'package:movies/api/endpoints.dart';
import 'package:movies/models/movie_source.dart';
import 'package:movies/services/movie_source_service.dart';

Future<void> main() async {
  final MovieSourceService service = MovieSourceService();
  var failures = 0;

  for (final OpenFilm film in MovieSourceService.openFilms) {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest req = await client.getUrl(Uri.parse(film.url));
      final HttpClientResponse res = await req.close();

      // Only the head of the body is read: proving the file exists does not
      // mean pulling 100 MB over the wire three times.
      int read = 0;
      await for (final List<int> chunk in res) {
        read += chunk.length;
        if (read > 65536) break;
      }
      res.detachSocket().then((Socket s) => s.destroy());

      final bool ok = res.statusCode == 200 && read > 0;
      if (!ok) failures++;
      stdout.writeln(
        '${ok ? "OK  " : "FAIL"} ${film.title.padRight(18)} '
        'status=${res.statusCode} declared=${res.contentLength} read=$read '
        'cors=${res.headers.value("access-control-allow-origin")}',
      );
    } on Object catch (error) {
      failures++;
      stdout.writeln('FAIL ${film.title}: $error');
    } finally {
      client.close();
    }
  }

  // A title the app definitely renders, to confirm the endpoint shape.
  const int inception = 27205;
  final List<WatchProvider> providers =
      await service.fetchWatchProviders(inception, region: 'US');
  stdout.writeln('\n$inception (${Endpoints.watchProvidersUrl(inception, "US")})');
  stdout.writeln('  ${providers.length} provider(s)');
  for (final WatchProvider p in providers) {
    stdout.writeln('  - ${p.name} [${p.type.name}] free=${p.isFree}');
  }
  if (providers.isEmpty) failures++;

  service.dispose();
  stdout.writeln(failures == 0 ? '\nALL OK' : '\n$failures FAILURE(S)');
  exit(failures == 0 ? 0 : 1);
}
