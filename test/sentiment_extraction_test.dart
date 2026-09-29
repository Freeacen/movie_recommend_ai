import 'package:flutter_test/flutter_test.dart';
import 'package:movie_recommend_ai/data/models/movie.dart';
import 'package:movie_recommend_ai/data/models/user_taste_profile.dart';
import 'package:movie_recommend_ai/data/repositories/movie_repository.dart';
import 'package:movie_recommend_ai/data/services/backend_ai_service.dart';
import 'package:movie_recommend_ai/data/services/dynamic_explanation_assembler.dart';
import 'package:movie_recommend_ai/data/services/gemini_ai_service.dart';
import 'package:movie_recommend_ai/domain/enums/movie_status.dart';
import 'package:movie_recommend_ai/core/utils/date_formatter.dart';

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

    test('Fresh recommendation ("başka bir şey öner") exits recent franchise context cleanly', () async {
      final backendService = BackendAiService();
      const spiderMan = Movie(
        id: 557,
        title: 'Örümcek-Adam',
        genres: 'Aksiyon, Macera, Fantastik',
        overview: 'Peter Parker örümcek tarafından ısırılır.',
      );
      const interstellar = Movie(
        id: 157336,
        title: 'Yıldızlararası (Interstellar)',
        genres: 'Bilim Kurgu, Dram',
        overview: 'Solucan deliğinden geçerek yeni bir yaşanabilir gezegen arayan astronotlar.',
      );

      final result = await backendService.getRecommendation(
        userPrompt: 'başka bir şey öner',
        tasteProfile: const UserTasteProfile(
          preferredGenres: ['Bilim Kurgu', 'Dram'],
          likedThemes: ['uzay', 'derin bilim kurgu'],
          lastUpdated: '2026-01-01',
        ),
        watchedMovies: [],
        candidateCatalog: [spiderMan, interstellar],
        recentContext: 'Son önerilen film: Örümcek-Adam (2002)',
      );

      expect(result, isNotNull);
      final title = result['recommended_title']?.toString() ?? '';
      expect(title, isNotEmpty);
      expect(title.toLowerCase(), isNot(contains('örümcek')));
      expect(title.toLowerCase(), isNot(contains('spider')));
    });

    test('Natural library prompt ("bana bir film öner bakalım kütüphaneme bakıp") gets valid recommendation', () async {
      final backendService = BackendAiService();
      const inception = Movie(
        id: 27205,
        title: 'Başlangıç (Inception)',
        genres: 'Bilim Kurgu, Gerilim',
        overview: 'Rüyalara girip bilinçaltından sır çalan bir ekip.',
      );

      final result = await backendService.getRecommendation(
        userPrompt: 'bana bir film öner bakalım kütüphaneme bakıp',
        tasteProfile: const UserTasteProfile(
          preferredGenres: ['Bilim Kurgu', 'Gerilim'],
          likedThemes: ['akıl yakan kurgular', 'zaman'],
          lastUpdated: '2026-01-01',
        ),
        watchedMovies: [],
        candidateCatalog: [inception],
      );

      expect(result, isNotNull);
      final title = result['recommended_title']?.toString() ?? '';
      expect(title, isNotEmpty);
      expect(result['reason'], isNotNull);
    });

    test('classifyUserTurnWithContext identifies WATCHED_CONFIRMATION and infers date for "çıktığı tarihten bir veya 2 ay sonra izlemiştim"', () async {
      final backendService = BackendAiService();
      const tenet = Movie(
        id: 577922,
        title: 'Tenet',
        releaseDate: '2020-08-26',
        genres: 'Aksiyon, Gerilim, Bilim Kurgu',
      );

      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'bu filmi çıktığı tarihten bir veya 2 ay sonra izlemiştim',
        lastAssistantMessage: '1 hafta önce sana Tenet filmini önermiştim. İzleme fırsatın oldu mu?',
        activeMovie: tenet,
        now: DateTime(2026, 9, 27),
      );

      expect(result['intent'], equals('WATCHED_CONFIRMATION'));
      expect(result['watch_date'], isNotNull);
      // Date should be approx 2020-10
      expect(result['watch_date'].toString(), startsWith('2020-10'));
    });

    test('classifyUserTurnWithContext identifies START_EVALUATION for "değerlendirelim"', () async {
      final backendService = BackendAiService();
      const tenet = Movie(
        id: 577922,
        title: 'Tenet',
        releaseDate: '2020-08-26',
      );

      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'değerlendirelim',
        lastAssistantMessage: 'Bu filmi değerlendirip zevk profiline yeni tercihler eklemek ister misin?',
        activeMovie: tenet,
      );

      expect(result['intent'], equals('START_EVALUATION'));
    });

    test('classifyUserTurnWithContext identifies LIBRARY_QUERY for "kütüphaneye ekledin mi teneti"', () async {
      final backendService = BackendAiService();
      const tenet = Movie(
        id: 577922,
        title: 'Tenet',
        releaseDate: '2020-08-26',
      );

      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'kütüphaneye ekledin mi teneti',
        lastAssistantMessage: 'Tamamdır, istediğin zaman konuşabiliriz.',
        activeMovie: tenet,
      );

      expect(result['intent'], equals('LIBRARY_QUERY'));
    });

    test('classifyUserTurnWithContext identifies POSTPONE_OR_NOT_WATCHED for "henüz izlemedim sonra bakarım"', () async {
      final backendService = BackendAiService();
      const tenet = Movie(
        id: 577922,
        title: 'Tenet',
        releaseDate: '2020-08-26',
      );

      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'henüz izlemedim sonra bakarım',
        lastAssistantMessage: 'İzleme fırsatın oldu mu?',
        activeMovie: tenet,
      );

      expect(result['intent'], equals('POSTPONE_OR_NOT_WATCHED'));
    });

    test('classifyUserTurnWithContext identifies REMOVE_FROM_LIBRARY for "bu filmi yanlışlıkla ekledim kütüphanemden sil"', () async {
      final backendService = BackendAiService();
      const tenet = Movie(
        id: 577922,
        title: 'Tenet',
        releaseDate: '2020-08-26',
      );

      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'bu filmi yanlışlıkla ekledim kütüphanemden sil',
        lastAssistantMessage: 'Tenet filmini kütüphanene ekledim!',
        activeMovie: tenet,
      );

      expect(result['intent'], equals('REMOVE_FROM_LIBRARY'));
    });

    test('MovieRepository deleteMovie completely removes movie from catalog', () async {
      final repo = MovieRepository();
      const testMovie = Movie(
        id: 999999,
        title: 'Test Movie For Deletion',
        status: MovieStatus.watched,
      );

      await repo.saveMovie(testMovie);
      expect(await repo.getMovieById(999999), isNotNull);

      await repo.deleteMovie(999999);
      expect(await repo.getMovieById(999999), isNull);
    });

    test('classifyUserTurnWithContext correctly identifies RECOMMENDATION_REQUEST with is_rewatch_or_choice for franchise rewatch query', () async {
      final backendService = BackendAiService();
      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'fast and furious serisini diyorum izledim hepsini ama bir filmini tekrar izleyeceğim hangisini izleyeyim sen seç',
      );

      expect(result['intent'], equals('RECOMMENDATION_REQUEST'));
      expect(result['is_rewatch_or_choice'], isTrue);
    });

    test('classifyUserTurnWithContext correctly identifies RECOMMENDATION_REQUEST for "hızlı ve öfkeli hangisini izleyeyim"', () async {
      final backendService = BackendAiService();
      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'hızlı ve öfkeli izlemeyi düşünüyorum, her filmini birkaç kere izledim, sence bu gece hangisini izleyeyim',
      );

      expect(result['intent'], equals('RECOMMENDATION_REQUEST'));
      expect(result['is_rewatch_or_choice'], isTrue);
    });

    test('classifyUserTurnWithContext liberates user from interview question when user requests new recommendation', () async {
      final backendService = BackendAiService();
      const pendingMovie = Movie(id: 101, title: 'Inception', status: MovieStatus.watched);
      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'bana bir komedi filmi öner',
        lastAssistantMessage: 'Inception filminin en çok neresini sevdin? Puan verelim mi?',
        activeMovie: pendingMovie,
      );

      expect(result['intent'], equals('RECOMMENDATION_REQUEST'));
    });

    test('classifyUserTurnWithContext identifies postponement during review interview', () async {
      final backendService = BackendAiService();
      const pendingMovie = Movie(id: 101, title: 'Inception', status: MovieStatus.watched);
      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'sonra izlerim şimdi vaktim olmadı',
        lastAssistantMessage: 'Inception filminin en çok neresini sevdin? Puan verelim mi?',
        activeMovie: pendingMovie,
      );

      expect(result['intent'], equals('POSTPONE_OR_NOT_WATCHED'));
    });

    test('classifyUserTurnWithContext handles compound intent (watched + rating + recommendation request)', () async {
      final backendService = BackendAiService();
      final now = DateTime(2024, 10, 15);
      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: "Matrix'i dün izledim 9 verdim, şimdi bana Nolan'ın bir filmini öner",
        now: now,
      );

      expect(result['intent'], equals('COMPOUND_WATCHED_AND_RECOMMEND'));
      expect(result['movie_title'].toString().toLowerCase(), contains('matrix'));
      expect(result['rating'], equals(9.0));
      expect(result['watch_date'], equals('2024-10-14'));
    });

    test('classifyUserTurnWithContext identifies RECOMMENDATION_REQUEST for natural genre desires (e.g. "bilim kurgu istiyorum")', () async {
      final backendService = BackendAiService();
      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'bilim kurgu istiyorum',
      );

      expect(result['intent'], equals('RECOMMENDATION_REQUEST'));
    });

    test('classifyUserTurnWithContext identifies GENERAL_CHAT for user objection/mismatch query (e.g. "bilim kurgu demiştim ama bunda var mı")', () async {
      final backendService = BackendAiService();
      const activeMovie = Movie(id: 202, title: 'Son Bir Şans', genres: 'Aksiyon, Gerilim', status: MovieStatus.watchlist);
      final result = await backendService.classifyUserTurnWithContext(
        userPrompt: 'bilim kurgu demiştim ama bunda var mı bilim kurrgu',
        activeMovie: activeMovie,
      );

      expect(result['intent'], equals('GENERAL_CHAT'));
      expect(result['movie_title'], equals('Son Bir Şans'));
    });

    test('DynamicExplanationAssembler does not hallucinate unrelated themes onto a movie', () {
      const assembler = DynamicExplanationAssembler();
      const movie = Movie(id: 303, title: 'Son Bir Şans', genres: 'Aksiyon, Gerilim', overview: 'Deniz komandoları operasyonu.');
      const tasteProfile = UserTasteProfile(
        likedThemes: ['zamanda yolculuk ve paradokslar'],
        preferredGenres: ['Bilim Kurgu'],
        lastUpdated: '2024-10-15',
      );

      final pitch = assembler.assemble(movie: movie, tasteProfile: tasteProfile);
      expect(pitch.fullReason.contains('zamanda yolculuk'), isFalse);
    });

    test('DateFormatter.formatFriendly reliably returns pure Turkish month names across all environments', () {
      expect(DateFormatter.formatFriendly('2024-10-15'), equals('15 Ekim 2024'));
      expect(DateFormatter.formatFriendly('2023-01-01'), equals('1 Ocak 2023'));
      expect(DateFormatter.formatFriendly('2022-07-20'), equals('20 Temmuz 2022'));
    });
  });
}


