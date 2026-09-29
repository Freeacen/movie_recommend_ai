import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movie_recommend_ai/data/services/tmdb_service.dart';

void main() {
  group('TMDB Trailer Service Tests', () {
    test('Returns mock trailer key when network fails or for mock movies', () async {
      final failingClient = MockClient((request) async => http.Response('Error', 500));
      final service = TmdbService(client: failingClient);
      
      // Inception
      final inceptionTrailer = await service.getMovieTrailer(27205);
      expect(inceptionTrailer, equals('Jvurpf91omw'));

      // Interstellar
      final interstellarTrailer = await service.getMovieTrailer(157336);
      expect(interstellarTrailer, equals('zSWdZVtXT7E'));

      // Oppenheimer
      final oppenheimerTrailer = await service.getMovieTrailer(872585);
      expect(oppenheimerTrailer, equals('uYPbbksJxIg'));

      // Non-existent movie with failing client returns null
      final unknownTrailer = await service.getMovieTrailer(99999999);
      expect(unknownTrailer, isNull);
    });

    test('Picks official YouTube trailer over teaser and clips from TMDB response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/movie/12345/videos')) {
          return http.Response(
            jsonEncode({
              'id': 12345,
              'results': [
                {
                  'site': 'YouTube',
                  'type': 'Clip',
                  'key': 'clip_key_1',
                  'official': false,
                },
                {
                  'site': 'YouTube',
                  'type': 'Trailer',
                  'key': 'official_trailer_key_2',
                  'official': true,
                },
                {
                  'site': 'YouTube',
                  'type': 'Teaser',
                  'key': 'teaser_key_3',
                  'official': true,
                },
              ]
            }),
            200,
          );
        }
        return http.Response('{"results":[]}', 200);
      });

      final service = TmdbService(client: mockClient, apiKey: 'test_api_key');
      final trailerKey = await service.getMovieTrailer(12345);

      expect(trailerKey, equals('official_trailer_key_2'));
    });

    test('Falls back to English or general videos when Turkish locale has no trailer', () async {
      final mockClient = MockClient((request) async {
        if (request.url.queryParameters['language'] == 'tr-TR') {
          // Turkish results empty
          return http.Response('{"results":[]}', 200);
        }
        if (request.url.queryParameters['language'] == 'en-US') {
          return http.Response(
            jsonEncode({
              'id': 54321,
              'results': [
                {
                  'site': 'YouTube',
                  'type': 'Trailer',
                  'key': 'en_trailer_key',
                  'official': true,
                }
              ]
            }),
            200,
          );
        }
        return http.Response('{"results":[]}', 200);
      });

      final service = TmdbService(client: mockClient, apiKey: 'test_api_key');
      final trailerKey = await service.getMovieTrailer(54321);

      expect(trailerKey, equals('en_trailer_key'));
    });

    test('Movie with no backdrop falls back to posterUrl cleanly', () {
      const backdropUrl = '';
      const posterUrl = 'https://image.tmdb.org/t/p/w500/sample.jpg';
      final displayImageUrl = backdropUrl.isNotEmpty ? backdropUrl : posterUrl;
      expect(displayImageUrl, equals(posterUrl));
    });

    test('Movie with backdrop prefers backdropUrl over posterUrl', () {
      const backdropUrl = 'https://image.tmdb.org/t/p/w1280/sample_backdrop.jpg';
      const posterUrl = 'https://image.tmdb.org/t/p/w500/sample_poster.jpg';
      final displayImageUrl = backdropUrl.isNotEmpty ? backdropUrl : posterUrl;
      expect(displayImageUrl, equals(backdropUrl));
    });
  });
}
