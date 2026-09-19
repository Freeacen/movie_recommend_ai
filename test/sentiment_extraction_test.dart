import 'package:flutter_test/flutter_test.dart';
import 'package:movie_recommend_ai/data/models/movie.dart';
import 'package:movie_recommend_ai/data/models/user_taste_profile.dart';
import 'package:movie_recommend_ai/data/services/backend_ai_service.dart';
import 'package:movie_recommend_ai/data/services/gemini_ai_service.dart';

void main() {
  group('Conversational Sentiment & Aspect Analysis Tests (1.0 - 10.0 scale)', () {
    late GeminiAiService geminiService;

    setUp(() {
      geminiService = GeminiAiService();
    });

    test('Positive review extracts high score (>= 7.5/10) and liked aspects', () async {
      const userFeedback = 'Oyunculuklar muhteşemdi ve senaryodaki ters köşe şahaneydi. Ancak ortasında tempo biraz yavaştı.';
      
      final result = await geminiService.analyzeMovieFeedback(
        movieTitle: 'Inception',
        userFeedbackText: userFeedback,
      );

      // Score should be high on 10-point scale
      expect(result.score, greaterThanOrEqualTo(7.5));
      expect(result.likedAspects, contains('etkileyici oyunculuk'));
      expect(result.likedAspects, contains('ters köşe kurgu'));
      expect(result.dislikedAspects, contains('ağır orta tempo'));
    });

    test('Critical review extracts low score (<= 5.0/10) and disliked aspects', () async {
      const userFeedback = 'Çok sıkıldım, klişe diyaloglar vardı ve film gereksiz uzatılmıştı. Zaman kaybı.';

      final result = await geminiService.analyzeMovieFeedback(
        movieTitle: 'Random Movie',
        userFeedbackText: userFeedback,
      );

      expect(result.score, lessThanOrEqualTo(5.0));
      expect(result.dislikedAspects, contains('klişe diyaloglar'));
      expect(result.dislikedAspects, contains('gereksiz uzun sahneler'));
    });

    test('Atmospheric audio and visual appreciation extracted correctly', () async {
      const userFeedback = 'Müzikler ve görsel efektler efsaneydi, sinematografisine bayıldım.';

      final result = await geminiService.analyzeMovieFeedback(
        movieTitle: 'Interstellar',
        userFeedbackText: userFeedback,
      );

      expect(result.score, greaterThanOrEqualTo(8.5));
      expect(result.likedAspects, contains('atmosferik müzikler'));
      expect(result.likedAspects, contains('etkileyici görsellik'));
    });

    test('Explicit score range extraction (e.g. "7.2 yada 7.8 arasında")', () async {
      const userFeedback = 'puanı 10 üzerinden 6.8 değil de 7.2 yada 7.8 arasında bişey diyebiliriz, ters köşesi harikaydı.';

      final result = await geminiService.analyzeMovieFeedback(
        movieTitle: 'Shutter Island',
        userFeedbackText: userFeedback,
      );

      expect(result.score, equals(7.5));
      expect(result.likedAspects, contains('ters köşe kurgu'));
    });

    test('Multi-turn chat feedback returns response on 1.0-10.0 scale', () async {
      final response = await geminiService.chatMovieFeedback(
        movieTitle: 'Shutter Island',
        conversationHistory: [
          {'role': 'assistant', 'content': 'Filmi nasıl buldun?'},
          {'role': 'user', 'content': 'Oyunculuklar muhteşemdi, DiCaprio döktürmüş ama ortası biraz yavaştı, bence puanı 8.2 olmalı.'},
        ],
        currentScore: 7.0,
      );

      expect(response.score, equals(8.2));
      expect(response.likedAspects, contains('etkileyici oyunculuk'));
      expect(response.reply, isNotEmpty);
    });

    test('identifyAndDiscussWatchedMovie detects movie from user message', () async {
      final result = await geminiService.identifyAndDiscussWatchedMovie(
        userPrompt: 'en son izledim bunu end of the oak street',
      );

      expect(result['movie_found'], isTrue);
      expect(result['title'].toString().toLowerCase(), contains('oak street'));
      expect(result['comment'], isNotNull);
      expect(result['comment'].toString().length, greaterThan(10));
    });

    test('searchMoviesWithAi returns empty list without API key (no fake movies)', () async {
      // Without a real API key, the service correctly returns an empty list
      // instead of fabricating fake movie data
      final results = await geminiService.searchMoviesWithAi('end of the oak street');
      expect(results, isEmpty); // No hallucinated movies — empty is the correct safe fallback
    });

    test('BackendAiService generateChatResponse returns friendly response for general questions', () async {
      final backendService = BackendAiService();
      final reply = await backendService.generateChatResponse('film dışında soru sorsam cevaplar mısın');
      expect(reply, isNotNull);
      expect(reply!.isNotEmpty, isTrue);
    });

    test('identifyAndDiscussWatchedMovie rejects recommendation questions and desires', () async {
      final backendService = BackendAiService();
      final queries = [
        'örümcek adam filmlerinden bişey mi izlesem en son neler var',
        'en son hangi filmler çıktı',
        'ne izlesem sence',
        'yeni bir bilim kurgu filmi izlemek istiyorum',
        'interstellar izlenir mi',
      ];

      for (final query in queries) {
        final result = await backendService.identifyAndDiscussWatchedMovie(userPrompt: query);
        expect(result['movie_found'], isFalse, reason: 'Failed for query: $query');
      }
    });

    test('generateChatResponse handles currency queries ("daha yenisi yok mu") with recent movie context', () async {
      final backendService = BackendAiService();
      final reply = await backendService.generateChatResponse(
        'daha yenisi yok mu',
        recentContext: 'Kullanıcı şu film kartını inceliyor: Örümcek-Adam: Eve Dönüş Yok (2021)',
      );
      expect(reply, isNotNull);
      expect(reply!.isNotEmpty, isTrue);
      // Ensures it does not throw or crash, and provides helpful guidance
      expect(reply.toLowerCase(), anyOf(contains('yeni'), contains('film'), contains('canlı çekim'), contains('seri')));
    });

    test('generateChatResponse handles older queries ("daha eskisi var mı", "ilk film mi")', () async {
      final backendService = BackendAiService();
      final reply = await backendService.generateChatResponse(
        'daha eskisi var mı serinin ilk filmi hangisi',
        recentContext: 'Kullanıcı şu film kartını inceliyor: Örümcek-Adam: Eve Dönüş (2017)',
      );
      expect(reply, isNotNull);
      expect(reply!.isNotEmpty, isTrue);
    });

    test('Negative genre filter ("animasyon sevmiyorum") rejects animation in candidates', () async {
      final backendService = BackendAiService();
      final spiderVerse = const Movie(
        id: 569094,
        title: 'Örümcek-Adam: Örümcek-Evrenine Geçiş',
        genres: 'Animasyon, Aksiyon, Macera',
        overview: 'Miles Morales çoklu evren macerasında.',
      );
      final spiderMan2002 = const Movie(
        id: 557,
        title: 'Örümcek-Adam',
        genres: 'Aksiyon, Macera, Fantastik',
        overview: 'Peter Parker örümcek tarafından ısırılır.',
      );

      final result = await backendService.getRecommendation(
        userPrompt: 'animasyon sevmiyorum ya',
        tasteProfile: const UserTasteProfile(
          preferredGenres: ['Bilim Kurgu'],
          likedThemes: ['zaman yolculuğu'],
          lastUpdated: '2026-01-01',
        ),
        watchedMovies: [],
        candidateCatalog: [spiderVerse, spiderMan2002],
      );

      expect(result, isNotNull);
      final recommendedTitle = result['recommended_title']?.toString() ?? '';
      expect(recommendedTitle, isNot(contains('Örümcek-Evreni')));
    });

    test('Clean slate exit ("başka tarz bir film öner") clears franchise and allows comedy recommendation', () async {
      final backendService = BackendAiService();
      const spiderMan = Movie(
        id: 557,
        title: 'Örümcek-Adam',
        genres: 'Aksiyon, Macera, Fantastik',
        overview: 'Peter Parker örümcek tarafından ısırılır.',
      );
      const superbad = Movie(
        id: 8363,
        title: 'Çok Fena (Superbad)',
        genres: 'Komedi',
        overview: 'İki lise öğrencisinin eğlenceli ve komik partiye gitme çabası.',
      );

      final result = await backendService.getRecommendation(
        userPrompt: 'Kullanıcı önceki "Örümcek-Adam" serisini/evrenini TAMAMEN GERİDE BIRAKMAK istiyor. Kullanıcının şu anki isteği: "başka tarz bir film öner komedi olsun". Önceki seriye veya karaktere KESİNLİKLE bağlı kalma! Kullanıcının yeni istediği türe veya genel zevk profiline göre dünya sinemasından bağımsız, taze bir film öner.',
        tasteProfile: const UserTasteProfile(
          preferredGenres: ['Komedi'],
          likedThemes: ['lise maceraları', 'arkadaşlık'],
          lastUpdated: '2026-01-01',
        ),
        watchedMovies: [],
        candidateCatalog: [spiderMan, superbad],
      );

      expect(result, isNotNull);
      final title = result['recommended_title']?.toString() ?? '';
      expect(title, isNot(contains('Örümcek-Adam')));
    });

    test('Thematic bridge ("benzer aksiyon olsun ama örümcek adam olmasın") bridges to another universe', () async {
      final backendService = BackendAiService();
      const spiderMan = Movie(
        id: 557,
        title: 'Örümcek-Adam',
        genres: 'Aksiyon, Macera, Fantastik',
        overview: 'Peter Parker örümcek tarafından ısırılır.',
      );
      const theBatman = Movie(
        id: 414906,
        title: 'The Batman',
        genres: 'Aksiyon, Suç, Dram',
        overview: 'Gotham sokaklarında adalet arayan Kara Şövalye.',
      );

      final result = await backendService.getRecommendation(
        userPrompt: 'Kullanıcı önceki "Örümcek-Adam" serisinden çıkmak istiyor; ancak benzer atmosfer/ruh taşıyan tematik akraba bir evrenden yapım arıyor. Kullanıcının şu anki isteği: "buna benzer aksiyon olsun ama örümcek adam olmasın". Önceki serinin kendisini önerme; tematik olarak akraba, benzer heyecanı veren farklı bir yapım seç.',
        tasteProfile: const UserTasteProfile(
          preferredGenres: ['Aksiyon'],
          likedThemes: ['kahramanlık', 'dedektiflik'],
          lastUpdated: '2026-01-01',
        ),
        watchedMovies: [],
        candidateCatalog: [spiderMan, theBatman],
      );

      expect(result, isNotNull);
      final title = result['recommended_title']?.toString() ?? '';
      expect(title, isNot(contains('Örümcek-Adam')));
    });
  });
}
