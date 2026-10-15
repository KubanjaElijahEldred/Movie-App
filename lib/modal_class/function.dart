import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:movies/api/endpoints.dart';
import 'package:movies/modal_class/credits.dart';
import 'package:movies/modal_class/genres.dart';
import 'package:movies/modal_class/movie.dart';
import 'package:movies/modal_class/video.dart';

Future<List<Movie>> fetchMovies(String api) async {
  MovieList movieList;
  var res = await http.get(Uri.parse(api));
  var decodeRes = jsonDecode(res.body);
  movieList = MovieList.fromJson(decodeRes);
  return movieList.movies ?? [];
}

Future<Credits> fetchCredits(String api) async {
  Credits credits;
  var res = await http.get(Uri.parse(api));
  var decodeRes = jsonDecode(res.body);
  credits = Credits.fromJson(decodeRes);
  return credits;
}

Future<GenresList> fetchGenres() async {
  GenresList genresList;
  var res = await http.get(Uri.parse(Endpoints.genresUrl()));
  var decodeRes = jsonDecode(res.body);
  genresList = GenresList.fromJson(decodeRes);
  return genresList;
}

/// The TV genre list. TV genre ids differ from the movie ones, so a TV or anime
/// view has to load these to name the genres on its cards and detail pages.
Future<GenresList> fetchTVGenres() async {
  GenresList genresList;
  var res = await http.get(Uri.parse(Endpoints.getTVGenres()));
  var decodeRes = jsonDecode(res.body);
  genresList = GenresList.fromJson(decodeRes);
  return genresList;
}

Future<VideoList> fetchVideos(int movieId) async {
  VideoList videoList;
  var res = await http.get(Uri.parse(Endpoints.getMovieVideos(movieId)));
  var decodeRes = jsonDecode(res.body);
  videoList = VideoList.fromJson(decodeRes);
  return videoList;
}
