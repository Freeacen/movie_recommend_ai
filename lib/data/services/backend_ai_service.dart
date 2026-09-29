import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/supabase_config.dart';
import '../../domain/enums/movie_status.dart';
import '../models/movie.dart';
import '../models/user_taste_profile.dart';
import 'dynamic_explanation_assembler.dart';
import 'gemini_ai_service.dart';

/// Backend AI Proxy Service
/// Handles communication with Supabase Edge Functions backed by the Groq API key rotation pool.
/// Integrates seamless offline degradation via DynamicExplanationAssembler and local heuristic analyzers.
class BackendAiService {
  final http.Client _client;
  final DynamicExplanationAssembler _assembler;

  BackendAiService({
    http.Client? client,
    DynamicExplanationAssembler? assembler,
  })  : _client = client ?? http.Client(),
        _assembler = assembler ?? const DynamicExplanationAssembler();

  /// Request personalized recommendation from Backend Proxy (Groq llama-3.3-70b pool)
  /// Automatically degrades to DynamicExplanationAssembler on rate limits or offline mode.
  Future<Map<String, dynamic>> getRecommendation({
    required String userPrompt,
    required UserTasteProfile tasteProfile,
    required List<Movie> watchedMovies,
    required List<Movie> candidateCatalog,
    Set<int> excludedMovieIds = const {},
    String? recentContext,
  }) async {
    // 1. Try Supabase Edge Function Groq Proxy if configured
    if (SupabaseConfig.isConfigured) {
      try {
        final uri = Uri.parse(SupabaseConfig.edgeFunctionProxyUrl);
        final payload = {
          'action': 'recommend',
          'payload': {
            'prompt': userPrompt,
            'tasteProfile': tasteProfile.toMap(),
            'watchedTitles': watchedMovies.map((m) => m.title).toList(),
            'excludedIds': excludedMovieIds.toList(),
            if (recentContext != null && recentContext.isNotEmpty)
              'recentContext': recentContext,
          },
        };

        final response = await _client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.defaultSupabaseAnonKey,
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            return data['data'] as Map<String, dynamic>;
          }
        }
      } catch (_) {
        // Fallback to direct Groq or local assembler
      }
    }

    // 2. Try Direct Groq API Pool (llama-3.3-70b-versatile)
    try {
      final groqResult = await _getRecommendationFromGroq(
        userPrompt: userPrompt,
        tasteProfile: tasteProfile,
        watchedMovies: watchedMovies,
        candidateCatalog: candidateCatalog,
        excludedMovieIds: excludedMovieIds,
        recentContext: recentContext,
      );
      if (groqResult != null) {
        return groqResult;
      }
    } catch (_) {}

    // 3. Offline / Graceful Degradation: Dynamic Explanation Assembler
    return _localAssembledRecommendation(
      userPrompt: userPrompt,
      tasteProfile: tasteProfile,
      watchedMovies: watchedMovies,
      candidateCatalog: candidateCatalog,
      excludedMovieIds: excludedMovieIds,
      recentContext: recentContext,
    );
  }

  /// Multi-turn conversational movie review on 1.0 - 10.0 scale
  Future<MovieReviewChatResponse> chatMovieFeedback({
    required String movieTitle,
    required List<Map<String, String>> conversationHistory,
    double? currentScore,
  }) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final uri = Uri.parse(SupabaseConfig.edgeFunctionProxyUrl);
        final payload = {
          'action': 'chat_feedback',
          'payload': {
            'movieTitle': movieTitle,
            'conversationHistory': conversationHistory,
            'currentScore': currentScore,
          },
        };

        final response = await _client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.defaultSupabaseAnonKey,
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final map = data['data'];
            return MovieReviewChatResponse(
              reply: map['reply']?.toString() ?? 'Görüşlerin başarıyla kaydedildi!',
              score: ((map['score'] as num?)?.toDouble() ?? (currentScore ?? 7.5)).clamp(0.0, 10.0),
              likedAspects: (map['liked_aspects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
              dislikedAspects: (map['disliked_aspects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
              summary: map['summary']?.toString() ?? '$movieTitle filmi değerlendirildi.',
            );
          }
        }
      } catch (_) {}
    }

    // 2. Try Direct Groq API Pool (llama-3.3-70b-versatile)
    try {
      final groqChatRes = await _chatMovieFeedbackFromGroq(
        movieTitle: movieTitle,
        conversationHistory: conversationHistory,
        currentScore: currentScore,
      );
      if (groqChatRes != null) return groqChatRes;
    } catch (_) {}

    // 3. Local offline review fallback
    return _localChatMovieFeedback(
      movieTitle: movieTitle,
      conversationHistory: conversationHistory,
      currentScore: currentScore,
    );
  }

  /// Identify watched movie from natural language (e.g. "the wolf of wall street izlemiştim")
  Future<Map<String, dynamic>> identifyAndDiscussWatchedMovie({
    required String userPrompt,
  }) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final uri = Uri.parse(SupabaseConfig.edgeFunctionProxyUrl);
        final payload = {
          'action': 'identify_movie',
          'payload': {'userPrompt': userPrompt},
        };

        final response = await _client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.defaultSupabaseAnonKey,
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 7));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            return data['data'] as Map<String, dynamic>;
          }
        }
      } catch (_) {}
    }

    // 2. Try Direct Groq API Pool (llama-3.3-70b-versatile)
    try {
      final groqIdentified = await _identifyMovieFromGroq(userPrompt: userPrompt);
      if (groqIdentified != null) return groqIdentified;
    } catch (_) {}

    // 3. Local offline fallback
    return _localIdentifyWatchedMovie(userPrompt);
  }

  /// Single-turn feedback analysis
  Future<AspectAnalysisResult> analyzeMovieFeedback({
    required String movieTitle,
    required String userFeedbackText,
  }) async {
    final chatRes = await chatMovieFeedback(
      movieTitle: movieTitle,
      conversationHistory: [
        {'role': 'user', 'content': userFeedbackText}
      ],
    );

    return AspectAnalysisResult(
      score: chatRes.score,
      likedAspects: chatRes.likedAspects,
      dislikedAspects: chatRes.dislikedAspects,
      summary: chatRes.summary,
    );
  }

  /// Classify user intent using conversation context (Last Assistant Message + Active Movie + User Message)
  Future<Map<String, dynamic>> classifyUserTurnWithContext({
    required String userPrompt,
    String? lastAssistantMessage,
    Movie? activeMovie,
    DateTime? now,
  }) async {
    final currentDate = now ?? DateTime.now();
    final systemPrompt = '''
Sen CineAI akıllı film asistanının bağlamsal niyet (intent) ve detay çıkarıcısısın.
Kullanıcının son mesajını, önceki asistan mesajını ve konuşulan film bağlamını analiz ederek kullanıcının niyetini ve parametrelerini çıkar.

Şu anki gerçek tarih: ${currentDate.toIso8601String().substring(0, 10)}
Önceki Asistan Mesajı: "${lastAssistantMessage ?? 'Yok'}"
Konuşulan / Önerilen Film: "${activeMovie?.title ?? 'Yok'}" (Çıkış Tarihi: ${activeMovie?.releaseDate ?? 'Bilinmiyor'})

Kullanıcının Olası Niyetleri (intent):
1. "WATCHED_CONFIRMATION": Kullanıcı önerilen filmi veya tek bir filmi daha önce izlediğini, seyrettiğini veya bitirdiğini kütüphaneye eklemek/puanlamak amacıyla doğal dille ifade ettiğinde. (DİKKAT: Kullanıcı bir seriden 'hangisini izleyeyim', 'sen seç', 'hangisini tekrar izleyeyim', 'hangisine başlayayım' gibi bir seçim veya tavsiye istiyorsa intent RECOMMENDATION_REQUEST olmalıdır, WATCHED_CONFIRMATION DEĞİL!)
2. "POSTPONE_OR_NOT_WATCHED": Kullanıcı filmi henüz izlemediğini, şu an izleme fırsatı bulamadığını veya daha sonra izleyeceğini ifade ettiğinde.
3. "START_EVALUATION": Asistanın filmi değerlendirme, puanlama veya konuşma teklifine herhangi bir olumlu yanıt verdiğinde, onayladığında ya da film hakkındaki fikirlerini paylaşmaya istekli olduğunu belirttiğinde.
4. "LIBRARY_QUERY": Kullanıcı filmin kütüphanesine veya izleme listesine eklenip eklenmediğini, durumunu veya kütüphanesinde nelerin olduğunu sorduğunda.
5. "REMOVE_FROM_LIBRARY": Kullanıcı filmi kütüphanesinden, izlediklerinden veya izleme listesinden silmek, çıkarmak, kaldırmak veya yanlışlıkla eklendiğini belirtip kütüphaneden temizlemek istediğinde.
6. "RECOMMENDATION_REQUEST": Kullanıcı AÇIKÇA yeni bir film önerisi veya tavsiyesi istediğinde ("bana film öner", "ne izlesem", "tavsiye et", "izleyecek film bul"), bir seriden hangisini izlemesi gerektiğini sorduğunda ("hangisini izleyeyim", "sen seç") veya seriden seçim yapmanı istediğinde.
DİKKAT 1 (OLUMSUZLUK / İSTEMEME): Eğer kullanıcı olumsuz bir ifade kullanıyorsa (örneğin "film önerme", "tavsiye istemiyorum", "öneri yapma", "don't recommend", "no recommendations", "sadece konuşalım", "film istemiyorum"), intent KESİNLİKLE RECOMMENDATION_REQUEST DEĞİLDİR, intent KESİNLİKLE "GENERAL_CHAT" olmalıdır!
7. "GENERAL_CHAT": Kullanıcı sinema, belirli bir film veya yönetmen hakkında soru sorduğunda, filmleri kıyasladığında, film önermeni istemediğini belirttiğinde ("film önerme", "sadece sohbet edelim"), film dışı konularda sohbet ettiğinde veya selamlaştığında.
8. "COMPOUND_WATCHED_AND_RECOMMEND": Kullanıcı tek bir mesajda hem bir filmi daha önce izlediğini/puanladığını belirtip hem de yeni bir film önerisi veya tavsiyesi istediğinde (Örn: "Matrix'i dün izledim 9 verdim, bana Nolan'dan film öner", "Interstellar'ı bitirdim harikaydı buna benzer ne izlesem").

movie_title Çıkarım Kuralları:
- Kullanıcı mesajında adı geçen filmi, seriyi veya yapımı tespit et ve "movie_title" alanına yaz. Kullanıcı yeni bir filmden bahsetmiyorsa ve mevcut aktif filmden konuşuluyorsa aktif filmi koru ("${activeMovie?.title ?? ''}").
- ÇİFT FİLM KURALI: Eğer kullanıcı aynı cümlede hem izlediği hem de henüz izlemediği birden fazla filmden bahsediyorsa (örneğin "A'yı izledim ama B'yi izlemedim"), "movie_title" alanına KESİNLİKLE İZLEDİĞİNİ belirttiği filmi (A) yaz!
- SERİ VE SAYI NORMALİZASYONU: Kullanıcı bir serinin ilk filmini belirtmek için gayriresmi takılar kullandıysa (örneğin "Matrix 1", "Hızlı ve Öfkeli 1", "Iron Man 1"), "movie_title" alanına filmin resmi ve bilinen adını ("The Matrix", "The Fast and the Furious", "Iron Man") yaz. Ancak filmin gerçek adında sayı varsa ("Air Force One", "F1", "1917", "Ocean's 11", "Se7en"), filmin öz adını koru.

Zaman & Tarih Çıkarım Kuralı (watch_date):
- Kullanıcı izleme zamanını herhangi bir şekilde belirttiyse (örneğin filmin vizyonuna göre "çıktığı tarihten sonra", "geçen yaz", "dün", "yıllar önce", "2021 sonbaharında"), bunu yaklaşık YYYY-MM-DD ISO formatında hesapla.
- Örneğin film çıkış tarihi 2020-08 ise ve kullanıcı "çıktığı tarihten 1-2 ay sonra izlemiştim" dediyse watch_date: "2020-10-15" olmalıdır.
- "çıktığında izlemiştim" dediyse filmin çıkış tarihi (${activeMovie?.releaseDate ?? '2020-01-01'}) olmalıdır.
- Kullanıcı zaman belirtmediyse ve sadece izlediğini söylediyse null döndür.

Puan & Değerlendirme Çıkarımı:
- Kullanıcı herhangi bir puan ifadesi kullandıysa (örneğin 10 üzerinden puan, yıldız veya skor), bunu 1.0 - 10.0 arasında double sayı olarak "rating" alanına koy. Yoksa null.
- Kullanıcı beğendiği veya beğenmediği yönlerden bahsettiyse "liked_aspects" ve "disliked_aspects" listelerine ekle.
- Kullanıcı aynı mesajda film hakkında detaylı görüş veya eleştiri paylaştıysa "has_detailed_review": true yap.
- is_rewatch_or_choice: Kullanıcı bir seriden hangisini izleyeceğini soruyorsa ("hangisini izleyeyim", "sen seç"), izlediği bir seriden tekrar izlemek için öneri istiyorsa ("birini tekrar izleyeceğim hangisi olsun") veya seriden seçim yapmanı istiyorsa true yap, aksi halde false.

JSON Şeması (SADECE GEÇERLİ JSON DÖNDÜR):
{
  "intent": "WATCHED_CONFIRMATION" | "POSTPONE_OR_NOT_WATCHED" | "START_EVALUATION" | "LIBRARY_QUERY" | "REMOVE_FROM_LIBRARY" | "RECOMMENDATION_REQUEST" | "GENERAL_CHAT" | "COMPOUND_WATCHED_AND_RECOMMEND",
  "movie_title": "${activeMovie?.title ?? ''}",
  "is_rewatch_or_choice": false,
  "watch_date": "YYYY-MM-DD" veya null,
  "rating": null veya double,
  "liked_aspects": [],
  "disliked_aspects": [],
  "has_detailed_review": false,
  "review_summary": null
}
''';

    final result = await _callGroqChat(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      expectJson: true,
    );

    if (result != null && result['intent'] != null) {
      return result;
    }

    return _localClassifyUserTurn(userPrompt, activeMovie, currentDate);
  }

  Map<String, dynamic> _localClassifyUserTurn(String userPrompt, Movie? activeMovie, DateTime now) {
    final lower = userPrompt.toLowerCase().trim();

    // 0. Remove from library
    if (lower.contains('kütüphaneden sil') ||
        lower.contains('kutuphaneden sil') ||
        lower.contains('kütüphaneden çıkar') ||
        lower.contains('kutuphaneden cikar') ||
        lower.contains('kütüphanemden çıkar') ||
        lower.contains('kütüphanemden sil') ||
        lower.contains('listeden çıkar') ||
        lower.contains('listeden cikar') ||
        lower.contains('listemden kaldır') ||
        lower.contains('yanlışlıkla ekle') ||
        lower.contains('yanlislikla ekle')) {
      return {
        'intent': 'REMOVE_FROM_LIBRARY',
        'movie_title': activeMovie?.title ?? '',
        'watch_date': null,
        'rating': null,
        'liked_aspects': <String>[],
        'disliked_aspects': <String>[],
        'has_detailed_review': false,
      };
    }

    // 1. Library check query
    if (lower.contains('kütüphaneye ekle') ||
        lower.contains('kütüphanede var mı') ||
        lower.contains('kutuphanede var mi') ||
        lower.contains('ekledin mi') ||
        lower.contains('eklendi mi') ||
        lower.contains('listemde var mı')) {
      return {
        'intent': 'LIBRARY_QUERY',
        'movie_title': activeMovie?.title ?? '',
        'watch_date': null,
        'rating': null,
        'liked_aspects': <String>[],
        'disliked_aspects': <String>[],
        'has_detailed_review': false,
      };
    }

    // 2. Evaluation confirmation
    if (lower == 'değerlendirelim' ||
        lower == 'degerlendirelim' ||
        lower.contains('sohbetle değerlendir') ||
        lower.contains('puan verelim') ||
        lower == 'olur' ||
        lower == 'konuşalım') {
      return {
        'intent': 'START_EVALUATION',
        'movie_title': activeMovie?.title ?? '',
        'watch_date': null,
        'rating': null,
        'liked_aspects': <String>[],
        'disliked_aspects': <String>[],
        'has_detailed_review': false,
      };
    }

    // 3. Postpone or not watched
    if (lower.contains('henüz değil') ||
        lower.contains('henuz degil') ||
        lower.contains('henüz izlemedim') ||
        lower.contains('daha izlemedim') ||
        lower.contains('sonra izlerim') ||
        lower.contains('sonra izleyeceğim') ||
        lower.contains('fırsatım olmadı') ||
        lower.contains('vaktim olmadı')) {
      return {
        'intent': 'POSTPONE_OR_NOT_WATCHED',
        'movie_title': activeMovie?.title ?? '',
        'watch_date': null,
        'rating': null,
        'liked_aspects': <String>[],
        'disliked_aspects': <String>[],
        'has_detailed_review': false,
      };
    }

    // 4. Inquiries about a specific movie or comparisons ("duydun mu", "biliyor musun", "benzer mi")
    final isSpecificMovieInquiry = lower.contains('duydun mu') ||
        lower.contains('biliyor musun') ||
        lower.contains('biliyor mu') ||
        lower.contains('gördün mü') ||
        lower.contains('benzer mi') ||
        lower.contains('nasıl bir film') ||
        lower.contains('hakkında ne düşünüyorsun') ||
        lower.contains('konusu ne') ||
        lower.contains('çıktı mı') ||
        lower.contains('vizyonda mı') ||
        lower.contains('demiştim') ||
        lower.contains('bunda var mı') ||
        lower.contains('bunda o var mı') ||
        lower.contains('bunda yok') ||
        lower.contains('bunda o yok') ||
        lower.contains('bu o değil') ||
        lower.contains('ne alaka') ||
        lower.contains('alakası ne');

    if (isSpecificMovieInquiry) {
      String candidateTitle = activeMovie?.title ?? '';
      final match = RegExp(r'([A-Za-z0-9ÇĞİÖŞÜçğıöşü\s\-]+?)\s+filmi', caseSensitive: false).firstMatch(userPrompt);
      if (match != null) {
        candidateTitle = match.group(1)?.trim() ?? candidateTitle;
      }
      return {
        'intent': 'GENERAL_CHAT',
        'movie_title': candidateTitle,
        'watch_date': null,
        'rating': null,
        'liked_aspects': <String>[],
        'disliked_aspects': <String>[],
        'has_detailed_review': false,
      };
    }

    // Negation check: if user explicitly says NOT to recommend (e.g. "önerme", "tavsiye etme", "istemiyorum", "don't recommend")
    final isRecommendationNegated = lower.contains('önerme') ||
        lower.contains('onerme') ||
        lower.contains('tavsiye etme') ||
        lower.contains('tavsiye verme') ||
        lower.contains('öneri yapma') ||
        lower.contains('oneri yapma') ||
        lower.contains('don\'t recommend') ||
        lower.contains('no recommend') ||
        (lower.contains('istemiyorum') && (lower.contains('öner') || lower.contains('tavsiye') || lower.contains('film önerme'))) ||
        (lower.contains('istemem') && (lower.contains('öner') || lower.contains('tavsiye') || lower.contains('film önerme')));

    final hasGenreMention = lower.contains('bilim kurgu') ||
        lower.contains('bilimkurgu') ||
        lower.contains('korku') ||
        lower.contains('gerilim') ||
        lower.contains('komedi') ||
        lower.contains('aksiyon') ||
        lower.contains('dram') ||
        lower.contains('romantik') ||
        lower.contains('macera') ||
        lower.contains('animasyon') ||
        lower.contains('suç') ||
        lower.contains('suc') ||
        lower.contains('fantastik') ||
        lower.contains('gizem') ||
        lower.contains('western') ||
        lower.contains('belgesel') ||
        lower.contains('anime') ||
        lower.contains('süper kahraman') ||
        lower.contains('super kahraman');

    final hasDesireOrSearchExpression = lower.contains('istiyorum') ||
        lower.contains('istiyom') ||
        lower.contains('istiyoruz') ||
        lower.contains('bakarım') ||
        lower.contains('baksam') ||
        lower.contains('bakalım') ||
        lower.contains('gelsin') ||
        lower.contains('ver') ||
        lower.contains('bul') ||
        lower.contains('arıyorum') ||
        lower.contains('ariyorum') ||
        lower.contains('lazım') ||
        lower.contains('lazim') ||
        lower.contains('var mı') ||
        lower.contains('var mi') ||
        lower.contains('ne izle') ||
        lower.contains('izlesem') ||
        lower.contains('izlesek') ||
        lower.contains('izlemek') ||
        lower.contains('izleyesim') ||
        lower.contains('canım');

    // 5. Check if asking for recommendation
    final isAskingRecommendationOrChoice = !isRecommendationNegated && (
        lower.contains('öner') ||
        lower.contains('oneri') ||
        lower.contains('tavsiye') ||
        lower.contains('hangisi') ||
        lower.contains('hangisine') ||
        lower.contains('seç') ||
        lower.contains('sec') ||
        lower.contains('izleyeyim') ||
        lower.contains('izleyelim') ||
        lower.contains('başlayayım') ||
        lower.contains('which') ||
        lower.contains('choose') ||
        lower.contains('film öner') ||
        lower.contains('başka bir') ||
        lower.contains('farklı bir') ||
        lower.contains('yeni bir') ||
        hasDesireOrSearchExpression ||
        hasGenreMention);

    // 5a. Compound watched confirmation + recommendation request (e.g. "Matrix'i dün izledim 9 verdim, bana Nolan'dan film öner")
    final isRewatchOrChoice = (lower.contains('hangisi') ||
        lower.contains('seç') ||
        lower.contains('sec') ||
        lower.contains('tekrar') ||
        lower.contains('which') ||
        lower.contains('choose'));

    final hasWatchedConfirmation = lower.contains('izledim') ||
        lower.contains('izlemiştim') ||
        lower.contains('seyrettim') ||
        lower.contains('seyretmiştim') ||
        lower.contains('bitirdim');

    if (!isRewatchOrChoice && hasWatchedConfirmation && isAskingRecommendationOrChoice) {
      String? inferredDate;
      if (lower.contains('dün') || lower.contains('dun')) {
        inferredDate = now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
      } else if (lower.contains('geçen hafta') || lower.contains('gecen hafta')) {
        inferredDate = now.subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
      } else if (lower.contains('çıktığında') || lower.contains('vizyonda')) {
        inferredDate = activeMovie?.releaseDate;
      } else if (lower.contains('bugün') || lower.contains('az önce') || lower.contains('yeni bitirdim') || lower.contains('şimdi bitirdim') || lower.contains('şimdi izledim')) {
        inferredDate = now.toIso8601String().substring(0, 10);
      }

      String identifiedTitle = '';
      final watchedMatch = RegExp(r"([A-Za-z0-9ÇĞİÖŞÜçğıöşü\s\-':]+?)(?:'i|'ı|'u|'ü|'yi|'yı|'yu|'yü|\s)\s*(?:dün|bugün|yeni|az önce)?\s*(?:izledim|izlemiştim|seyrettim|bitirdim)", caseSensitive: false).firstMatch(userPrompt);
      if (watchedMatch != null) {
        identifiedTitle = watchedMatch.group(1)?.trim() ?? '';
      }
      if (identifiedTitle.isEmpty) {
        identifiedTitle = activeMovie?.title ?? '';
      }

      final explicitRating = _extractExplicitRating(userPrompt);

      return {
        'intent': 'COMPOUND_WATCHED_AND_RECOMMEND',
        'movie_title': identifiedTitle,
        'is_rewatch_or_choice': false,
        'watch_date': inferredDate,
        'rating': explicitRating,
        'liked_aspects': <String>[],
        'disliked_aspects': <String>[],
        'has_detailed_review': explicitRating != null,
      };
    }

    // 6. Recommendation request or franchise selection (checks this BEFORE watched confirmation)
    if (isAskingRecommendationOrChoice) {
      return {
        'intent': 'RECOMMENDATION_REQUEST',
        'movie_title': activeMovie?.title ?? '',
        'is_rewatch_or_choice': isRewatchOrChoice,
        'watch_date': null,
        'rating': null,
        'liked_aspects': <String>[],
        'disliked_aspects': <String>[],
        'has_detailed_review': false,
      };
    }

    // 6. Watched confirmation
    if (lower.contains('izledim') ||
        lower.contains('izlemiştim') ||
        lower.contains('seyrettim') ||
        lower.contains('seyretmiştim') ||
        lower.contains('bitirdim')) {
      String? inferredDate;
      if (lower.contains('dün') || lower.contains('dun')) {
        inferredDate = now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
      } else if (lower.contains('geçen hafta') || lower.contains('gecen hafta')) {
        inferredDate = now.subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
      } else if (lower.contains('çıktığında') || lower.contains('vizyonda')) {
        inferredDate = activeMovie?.releaseDate;
      } else if (lower.contains('bugün') || lower.contains('az önce') || lower.contains('yeni bitirdim') || lower.contains('şimdi bitirdim') || lower.contains('şimdi izledim')) {
        inferredDate = now.toIso8601String().substring(0, 10);
      } else if (lower.contains('sonra') && activeMovie?.releaseDate != null) {
        // e.g. "çıktığı tarihten bir veya 2 ay sonra"
        final relDate = DateTime.tryParse(activeMovie!.releaseDate!);
        if (relDate != null) {
          inferredDate = relDate.add(const Duration(days: 60)).toIso8601String().substring(0, 10);
        }
      }

      return {
        'intent': 'WATCHED_CONFIRMATION',
        'movie_title': activeMovie?.title ?? '',
        'watch_date': inferredDate,
        'rating': null,
        'liked_aspects': <String>[],
        'disliked_aspects': <String>[],
        'has_detailed_review': false,
      };
    }

    return {
      'intent': 'GENERAL_CHAT',
      'movie_title': activeMovie?.title ?? '',
      'watch_date': null,
      'rating': null,
      'liked_aspects': <String>[],
      'disliked_aspects': <String>[],
      'has_detailed_review': false,
    };
  }

  /// Free-form conversational chat response using Groq
  Future<String?> generateChatResponse(String userPrompt, {String? recentContext}) async {
    final systemPrompt = '''
Sen CineAI adlı zeki, samimi, kültürlü ve tutkulu bir yapay zeka sinema danışmanısın.
Uzmanlık alanın: Sinema, filmler, yönetmenler, oyuncular, senaryolar, film incelemeleri ve önerilerdir.
${recentContext != null && recentContext.isNotEmpty ? '\nBağlam ve Doğrulanmış Film Bilgileri:\n$recentContext\n' : ''}

KİMLİK VE ALAN SINIRLARI (DOMAIN GUARDRAILS):
1. Sen yalnızca bir sinema ve film asistanısın. Sohbetin odağını her zaman sinemada tut.
2. Eğer kullanıcı tamamen sinema dışı konulardan (hava durumu, yemek tarifleri, siyaset, günlük dertler, okul/iş, matematik vb.) bahsederse, kullanıcıyı kesinlikle terslemeden, esprili ve sıcak bir dille konuyu tekrar sinemaya bağla:
   Örnek: "Ben CineAI, senin sinema ve film danışmanınım! Film dünyasının büyüsünden çok uzaklaşmayalım; ama istersen bu havaya veya bu ruh haline mükemmel gidecek harika bir film önerisiyle devam edebiliriz! 🍿"

BAĞLAM VE REFERANS FİLM GÜVENCESİ (FALSE-POSITIVE ÖNLEYİCİ):
1. Sana yukarıda verilen "Bağlam ve Doğrulanmış Film Bilgileri" yalnızca olası bir arka plan referansıdır.
2. Eğer kullanıcının mesajı bariz bir şekilde bu film hakkında değilse (kullanıcı sadece genel bir sohbet, duygu durumu, günlük bir konu veya başka bir şeyden bahsediyorsa ve bu filmi bizzat sormamışsa), bu filmi ZORLA konuşmaya dahil etme, kullanıcı bu filmi sormuş gibi davranma.
3. Yalnızca kullanıcının mesajı gerçekten o filmle, o evrenle veya kıyaslamayla ilgiliyse bu bilgiyi kullan.

HALÜSİNASYON VE UYDURMA YASAKTIR:
1. Bilmediğin veya sana bilgisi verilmeyen bir film adı geçerse, adını motamot Türkçeye çevirip hayali hayvan veya çocukça uydurma konular (örneğin "kuyruklu fare gizli ajan animasyonu" gibi) KESİNLİKLE uydurma!
2. Eğer bir film hakkında doğrulanmış bilgin yoksa veya film çok yeniyse/yapım aşamasındaysa, dürüstçe "Bu yapım hakkında elimdeki bilgiler sınırlı veya henüz yapım aşamasında olabilir" diyerek kullanıcının ne bildiğini sor.

SPOILER (SÜRPRİZ BOZAN) KESİNLİKLE YASAKTIR:
1. Film önerilerinde, film analizlerinde ve sohbetlerde filmlerin sonunu, kilit ters köşe (twist) sürprizlerini veya katilin/gizin kim olduğunu ASLA açık etme!
2. Merak uyandırıcı, atmosferi ve çatışmayı anlatan ama sürprizi kullanıcıya saklayan bir sinematik anlatım kullan.

FORMAT VE METİN KURALLARI:
1. KESİNLİKLE Markdown tablosu (| Sütun | Sütun |) KULLANMA. Mobil ve dar ekranlarda tablolar bozulur.
2. KESİNLİKLE HTML etiketleri (<br>, <p> vb.) KULLANMA.
3. Kıyaslama veya anlatımları akıcı paragraflar, kalın vurgular (**film adı**) ve şık madde işaretleri (•) kullanarak yap.
4. Dil her zaman sıcak, akıcı ve samimi Türkçe olsun.
''';

    final result = await _callGroqChat(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      expectJson: false,
    );

    if (result != null && result['content'] != null) {
      return result['content'].toString();
    }
    return _localChatResponse(userPrompt, recentContext);
  }

  String _localChatResponse(String userPrompt, [String? recentContext]) {
    final lower = userPrompt.toLowerCase();
    if (lower.contains('daha yeni') || lower.contains('daha yenisi') || lower.contains('en yenisi') || lower.contains('yok mu')) {
      return 'İncelediğimiz film serisinde bundan daha yeni çıkmış bir canlı çekim film henüz vizyona girmedi (yeni projeler hazırlık aşamasında). Dilersen aynı evrendeki diğer filmlere veya benzer tonda yeni maceralara göz atabiliriz! 🍿';
    }
    if (lower.contains('demiştim') ||
        lower.contains('bunda var mı') ||
        lower.contains('bunda o var mı') ||
        lower.contains('bunda yok') ||
        lower.contains('bunda o yok') ||
        lower.contains('bu o değil') ||
        lower.contains('ne alaka') ||
        lower.contains('alakası ne') ||
        lower.contains('alakasız') ||
        lower.contains('uyuşmuyor') ||
        lower.contains('değil ki')) {
      final movieName = (recentContext != null && recentContext.contains('Kullanıcının daha önce incelediği / konuşulan film: '))
          ? recentContext.split('Kullanıcının daha önce incelediği / konuşulan film: ')[1].split('(')[0].trim()
          : '';
      if (movieName.isNotEmpty) {
        return 'Haklısın, **$movieName** tam olarak aradığın türle veya istediğinle örtüşmedi, kusura bakma! 🎬 Şimdi doğrudan istediğin türden harika bir yapım önerelim. Nasıl bir film istersin?';
      }
      return 'Haklısın, bir önceki önerim tam olarak istediğinle örtüşmedi, kusura bakma! Şimdi doğrudan istediğin seriden veya türden harika bir öneri hazırlayalım. Aklındaki detayları söylemen yeterli. 🎬';
    }
    if (lower.contains('hava') || lower.contains('yemek') || lower.contains('tarif') || lower.contains('matematik') || lower.contains('siyaset')) {
      return 'Ben CineAI, senin sinema ve film danışmanınım! 🎬 Film dünyasının büyüsünden uzaklaşmayalım; ama istersen bu ruh haline mükemmel gidecek harika bir film önerisi yapabilirim! 🍿';
    }
    return 'Sinema konusunda her zaman yanındayım! İstediğin türe, yönetmene veya karaktere göre en uygun filmleri keşfetmek için buradayım. 🎬';
  }

  /// Generate warm re-watch nudge message for an older favorite
  String generateRewatchNudge({
    required Movie movie,
    required String formattedDate,
  }) {
    final aspectsInfo = movie.likedAspects.isNotEmpty
        ? ' Özellikle ${movie.likedAspects.take(2).join(" ve ")} yönünü çok beğenmiştin.'
        : '';

    return 'Aradığın kriterlere uygun yepyeni bir film yerine sana **${movie.title}** filmini hatırlatmak istedim.$aspectsInfo\n\nBu unutulmaz favorini yeniden izleyerek nostaljik bir sinema gecesi yapmaya ne dersin? 🍿';
  }

  /// Reinforce or reject cached recommendation based on real user actions
  /// Positive signals: User adds to watchlist, rates >= 7.0
  /// Negative signals: User objects ("ne alaka", "alakasız"), rates < 5.0
  Future<void> updateRecommendationFeedback({
    required int movieId,
    required bool positive,
    String? signal,
  }) async {
    if (!SupabaseConfig.isConfigured || movieId == 0) return;

    try {
      final uri = Uri.parse(SupabaseConfig.edgeFunctionProxyUrl);
      final payload = {
        'action': 'update_feedback',
        'payload': {
          'movieId': movieId,
          'positive': positive,
          'signal': signal ?? '',
        },
      };

      await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.defaultSupabaseAnonKey,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Cache high quality verified movie pitch into Supabase
  Future<void> recordRecommendationInCache({
    required Movie movie,
    required String reason,
    required List<String> matchingAspects,
  }) async {
    if (!SupabaseConfig.isConfigured || movie.id == 0) return;

    try {
      final uri = Uri.parse('${SupabaseConfig.defaultSupabaseUrl}/rest/v1/cached_recommendations');
      await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.defaultSupabaseAnonKey,
          'Authorization': 'Bearer ${SupabaseConfig.defaultSupabaseAnonKey}',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode([
          {
            'movie_id': movie.id,
            'movie_title': movie.title,
            'hook_genre': 'Sinema zevkine tam uyan bir yapım olarak',
            'hook_mood': 'Sürükleyici temposuyla',
            'core_summary': reason,
            'target_aspects': matchingAspects,
            'quality_score': 1,
            'is_verified': false,
            'is_rejected': false,
          }
        ]),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Local Assembler & Heuristic Analyzers (Zero-Latency Offline Mode)
  // --------------------------------------------------------------------------
  Map<String, dynamic> _localAssembledRecommendation({
    required String userPrompt,
    required UserTasteProfile tasteProfile,
    required List<Movie> watchedMovies,
    required List<Movie> candidateCatalog,
    required Set<int> excludedMovieIds,
    String? recentContext,
  }) {
    final watchedIds = watchedMovies.map((m) => m.id).toSet();
    final watchedTitles = watchedMovies.map((m) => m.title.toLowerCase().trim()).toSet();
    var available = candidateCatalog.where((m) {
      if (watchedIds.contains(m.id)) return false;
      final t = m.title.toLowerCase().trim();
      if (watchedTitles.contains(t)) return false;
      for (final wt in watchedTitles) {
        if (wt.isNotEmpty && (t == wt || (wt.length > 3 && t.contains(wt)) || (t.length > 3 && wt.contains(t)))) {
          return false;
        }
      }
      return true;
    }).toList();

    if (available.isEmpty) {
      return {
        'recommended_title': '',
        'reason': 'Katalogdaki tüm filmleri zaten izlemişsin!',
        'matching_aspects': <String>[],
        'is_fallback': true,
      };
    }

    final lowerPrompt = userPrompt.toLowerCase();
    final rejectAnimation = lowerPrompt.contains('animasyon sevmiyorum') ||
        lowerPrompt.contains('animasyon istemiyorum') ||
        lowerPrompt.contains('animasyon olmasın') ||
        lowerPrompt.contains('animasyon hariç') ||
        lowerPrompt.contains('çizgi film') ||
        lowerPrompt.contains('çizgi olmasın') ||
        lowerPrompt.contains('canlı aksiyon') ||
        lowerPrompt.contains('live action') ||
        lowerPrompt.contains('live-action');

    var unproposed = available.where((m) => !excludedMovieIds.contains(m.id)).toList();
    var candidates = unproposed.isNotEmpty ? unproposed : available;

    final isDifferentRequest = lowerPrompt.contains('başka') ||
        lowerPrompt.contains('farklı') ||
        lowerPrompt.contains('değiştir') ||
        lowerPrompt.contains('boşver') ||
        lowerPrompt.contains('çıkmak istiyor') ||
        lowerPrompt.contains('önceki serinin kendisini önerme') ||
        lowerPrompt.contains('kesinlikle bağlı kalma') ||
        lowerPrompt.contains('geçelim');

    // Extract previous movie if mentioned in system context: e.g. 'Kullanıcı önceki "Örümcek-Adam" serisinden çıkmak istiyor'
    String? previousMentioned;
    if (lowerPrompt.contains('kullanıcı önceki "')) {
      final parts = lowerPrompt.split('kullanıcı önceki "');
      if (parts.length > 1) {
        previousMentioned = parts[1].split('"').first.toLowerCase().trim();
      }
    }

    if (previousMentioned != null && previousMentioned.isNotEmpty) {
      final filteredOutPrev = candidates.where((m) {
        final t = m.title.toLowerCase();
        return !t.contains(previousMentioned!) && !previousMentioned!.contains(t);
      }).toList();
      if (filteredOutPrev.isNotEmpty) {
        candidates = filteredOutPrev;
      }
    }

    if (isDifferentRequest && recentContext != null && recentContext.isNotEmpty) {
      final recentLower = recentContext.toLowerCase();
      final filteredOutRecent = candidates.where((m) {
        final t = m.title.toLowerCase();
        return !recentLower.contains(t) && !t.contains(recentLower);
      }).toList();
      if (filteredOutRecent.isNotEmpty) {
        candidates = filteredOutRecent;
      }
    }

    if (lowerPrompt.contains('örümcek adam olmasın') || lowerPrompt.contains('örümcek-adam olmasın')) {
      final noSpider = candidates.where((m) => !m.title.toLowerCase().contains('örümcek') && !m.title.toLowerCase().contains('spider')).toList();
      if (noSpider.isNotEmpty) {
        candidates = noSpider;
      }
    }

    if (lowerPrompt.contains('batman olmasın')) {
      final noBatman = candidates.where((m) => !m.title.toLowerCase().contains('batman')).toList();
      if (noBatman.isNotEmpty) {
        candidates = noBatman;
      }
    }

    if (rejectAnimation) {
      candidates = candidates.where((m) {
        final g = (m.genres ?? '').toLowerCase();
        final t = m.title.toLowerCase();
        return !g.contains('animasyon') && !g.contains('animation') && !t.contains('örümcek-evreni') && !t.contains('spider-verse');
      }).toList();
    }

    // Search for movies matching keywords in userPrompt
    final promptWords = userPrompt.toLowerCase()
        .replaceAll(RegExp(r'[?!.,:;]'), ' ')
        .split(' ')
        .where((w) => w.length > 2 && !['film', 'filmi', 'filmleri', 'öner', 'izle', 'bana', 'gibi', 'neler', 'bişey', 'animasyon', 'sevmiyorum', 'istemiyorum', 'olmasın', 'canlı', 'aksiyon', 'başka', 'farklı', 'tane', 'şey', 'bunu', 'şunu', 'öneri', 'yap'].contains(w))
        .toList();

    Movie? chosen;
    if (promptWords.isNotEmpty) {
      int highestScore = 0;
      for (final m in candidates) {
        int score = 0;
        final t = m.title.toLowerCase();
        final g = (m.genres ?? '').toLowerCase();
        final o = (m.overview ?? '').toLowerCase();
        for (final word in promptWords) {
          if (t.contains(word)) score += 6;
          if (g.contains(word)) score += 3;
          if (o.contains(word)) score += 1;
        }
        if (score > highestScore) {
          highestScore = score;
          chosen = m;
        }
      }
    }

    // If user prompt had specific words but local catalog has no match, return empty so TMDB handles it!
    if (chosen == null) {
      if (promptWords.length >= 2) {
        return {
          'recommended_title': '',
          'reason': 'Aradığın kriterlere uygun filmleri arıyorum...',
          'matching_aspects': <String>[],
          'is_fallback': false,
        };
      }
      chosen = candidates.first;
    }

    final genreDesc = (chosen.genres != null && chosen.genres!.isNotEmpty)
        ? '${chosen.genres} türündeki sinematik tercihlerine uygun'
        : 'Sinema zevkine uygun';
    final assembled = _assembler.assemble(
      movie: chosen,
      tasteProfile: tasteProfile,
      templateHookGenre: '$genreDesc bir yapım olarak',
      templateHookMood: 'Etkileyici temposu ve atmosferiyle',
      templateCoreSummary: chosen.overview,
    );

    return {
      'recommended_title': chosen.title,
      'movie_id': chosen.id,
      'reason': assembled.fullReason,
      'matching_aspects': assembled.matchingAspects,
      'is_fallback': false,
      'is_template': true,
    };
  }

  MovieReviewChatResponse _localChatMovieFeedback({
    required String movieTitle,
    required List<Map<String, String>> conversationHistory,
    double? currentScore,
  }) {
    final latestUserMsg = conversationHistory.reversed
        .firstWhere((m) => m['role'] == 'user', orElse: () => {'content': ''})['content'] ?? '';

    final explicit = _extractExplicitRating(latestUserMsg);
    final score = (explicit ?? (currentScore ?? 7.5)).clamp(0.0, 10.0);

    return MovieReviewChatResponse(
      reply: 'Kesinlikle katılıyorum! $movieTitle hakkında belirttiğin tespitler çok yerinde. Bu görüşleri zevk profiline işledim.',
      score: score,
      likedAspects: ['etkileyici atmosfer', 'ters köşe kurgu'],
      dislikedAspects: [],
      summary: '$movieTitle filmini $score/10 olarak değerlendirdin. Atmosferi ve kurgusu öne çıktı.',
    );
  }

  Map<String, dynamic> _localIdentifyWatchedMovie(String prompt) {
    final lower = prompt.toLowerCase();
    final hasWatch = lower.contains('izledim') || lower.contains('seyrettim') || lower.contains('bitirdim');
    if (!hasWatch) return {'movie_found': false};

    final title = prompt
        .replaceAll(RegExp(r'izledim|seyrettim|bitirdim|en son|bunu|filmini|filmi|arşive|ekleyelim', caseSensitive: false), '')
        .trim();

    if (title.length < 2) return {'movie_found': false};

    return {
      'movie_found': true,
      'title': title,
      'release_date': '2024-01-01',
      'genres': 'Sinema',
      'overview': '$title, sinemaseverler tarafından ilgiyle takip edilen sürükleyici bir yapımdır. Filmin kurgusu ve anlatımı izleyicide derin izler bırakır.',
      'vote_average': 7.5,
      'comment': '**$title** filmini izlemişsin! Sinema zevkini haritalandırmak için bu film hakkındaki düşüncelerini duymayı çok isterim. Değerlendirmek ister misin?',
    };
  }

  double? _extractExplicitRating(String text) {
    final regex = RegExp(r'(\d{1,2}(?:[.,]\d)?)');
    final match = regex.firstMatch(text);
    if (match != null) {
      final val = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      if (val != null && val >= 0.0 && val <= 10.0) return val;
    }
    return null;
  }

  static const List<String> supportedGroqModels = [
    'openai/gpt-oss-120b',
    'llama-3.3-70b-versatile',
    'openai/gpt-oss-20b',
    'llama-3.1-8b-instant',
    'qwen/qwen3.8-27b',
    'llama3-70b-8192',
    'llama3-8b-8192',
    'mixtral-8x7b-32768',
    'gemma2-9b-it',
  ];

  static String? _lastWorkingGroqModel;

  // --------------------------------------------------------------------------
  // Groq API Key Rotation Pool & Fast Inference
  // --------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _callGroqChat({
    required String systemPrompt,
    required String userPrompt,
    bool expectJson = true,
  }) async {
    if (SupabaseConfig.defaultGroqApiKeys.isEmpty) return null;

    final modelList = <String>[];
    if (_lastWorkingGroqModel != null && supportedGroqModels.contains(_lastWorkingGroqModel)) {
      modelList.add(_lastWorkingGroqModel!);
    }
    for (final m in supportedGroqModels) {
      if (!modelList.contains(m)) {
        modelList.add(m);
      }
    }

    for (final apiKey in SupabaseConfig.defaultGroqApiKeys) {
      if (apiKey.isEmpty || apiKey.contains('YOUR_GROQ')) continue;

      for (final model in modelList) {
        try {
          final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
          final body = {
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.6,
            if (expectJson) 'response_format': {'type': 'json_object'},
          };

          final response = await _client.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'User-Agent': 'CineAI/1.0',
            },
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            _lastWorkingGroqModel = model;
            final decoded = jsonDecode(response.body);
            final content = decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
            if (expectJson) {
              String cleaned = content.trim();
              if (cleaned.startsWith('```json')) {
                cleaned = cleaned.substring(7);
              } else if (cleaned.startsWith('```')) {
                cleaned = cleaned.substring(3);
              }
              if (cleaned.endsWith('```')) {
                cleaned = cleaned.substring(0, cleaned.length - 3);
              }
              cleaned = cleaned.trim();
              return jsonDecode(cleaned) as Map<String, dynamic>;
            }
            return {'content': content};
          }
        } catch (_) {
          continue; // Try next model or next API key
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getRecommendationFromGroq({
    required String userPrompt,
    required UserTasteProfile tasteProfile,
    required List<Movie> watchedMovies,
    required List<Movie> candidateCatalog,
    Set<int> excludedMovieIds = const {},
    String? recentContext,
  }) async {
    final candidatesList = candidateCatalog
        .where((m) => !excludedMovieIds.contains(m.id))
        .take(15)
        .map((m) => {'id': m.id, 'title': m.title, 'genres': m.genres, 'overview': m.overview})
        .toList();

    final watchedTitlesList = watchedMovies.map((m) => m.title).toList();

    const systemPrompt = '''
Sen uzman bir sinema eleştirmeni ve yapay zeka film öneri asistanısın.

🚨 1 NUMARALI VE EN KATI KURAL (KULLANICI İSTEĞİNE %100 SADAKAT):
1. Kullanıcının mesajında belirttiği AÇIK İSTEK (belirli bir karakter, franchise, yönetmen, tür, tema veya duygu durumu; örneğin "örümcek adam", "batman", "korku", "zombi", "kore gerilim", "animasyon", "dinozor") MUTLAK BİRİNCİ ÖNCELİKTİR.
2. Kullanıcının genel profilindeki diğer türler veya sevdiği temalar, kullanıcının o anki spesifik isteğini ASLA ezemez veya değiştiremez! Örneğin kullanıcı "örümcek adam" diyorsa MUTLAKA ve KESİNLİKLE Örümcek Adam evreninden bir film önerilmelidir (örn: Spider-Man: Across the Spider-Verse, Spider-Man 2 vb.). Alakasız başka bir film (Tenet vb.) önermek KESİNLİKLE YASAKTIR.
3. Eğer Aday Filmler Kataloğunda kullanıcının aradığı türe/isteğe uyan bir film varsa onu seç. Eğer katalogdaki filmler kullanıcının isteğiyle ALAKASIZSA, katalogdan alakasız bir film seçme; dünya sinemasından kullanıcının isteğine tam uyan gerçek bir filmi doğrudan öner.
4. ÇOK KADEMELİ BAĞLAM VE GEÇİŞ KURALI (MİKRO DÜZELTME / TEMATİK KÖPRÜ / TAM SIFIRLAMA):
A) Kademe 1 - Mikro Düzeltme (Seri İçi Format/Sıra Değişimi):
Kullanıcı sadece mevcut serinin formatına (örn: "animasyon olmasın", "çizim bu", "canlı aksiyon olsun", "daha eskisi") itiraz ediyorsa: Konuşulan seriden KESİNLİKLE çıkma! Seriden kullanıcının format isteğine uyan (örn: animasyon yerine canlı aksiyon Spider-Man) bir film öner.
B) Kademe 2 - Tematik Akraba / Köprü (Benzer Ruh, Farklı Evren):
Kullanıcı "buna benzer ama başka seri", "örümcek adam olmasın ama süper kahraman olsun", "bunun gibi aksiyon ama Marvel olmasın" diyorsa: Mevcut seriden çık, ancak benzer tematik ruhtaki akraba evrene (örn: The Batman, Kick-Ass, Watchmen) köprü kur.
C) Kademe 3 - Tam Sıfırlama / Başka Tarz / Yeni Öneri (Evrenden Kesin Çıkış):
Kullanıcı "başka tarz bir şey", "farklı bir tür", "bu seriyi boşver", "bunu geçelim", "komedi olsun", "korku izleyelim", "başka bir şey öner", "başka bir film", "farklı bir yapım", "başka öneri yap" diyorsa veya genel bir film istiyorsa: Önceki seriyi ve evreni KESİNLİKLE UNUT VE BIRAK! Kullanıcının yeni istediği türe veya genel zevk profiline göre dünya sinemasından bağımsız taze bir film öner. Asla eski seriye saplanıp kalma!

🚨 2 NUMARALI KURAL (İZLENEN FİLMLER VE TEKRAR İZLEME):
- Kullanıcı genel bir öneri istiyorsa, daha önce izlediği filmleri KESİNLİKLE önerme; yeni, taze bir film öner.
- ANCAK kullanıcı açıkça belirli bir seriyi daha önce izlediğini belirtip o seriden "hangisini tekrar izleyeyim", "hangisini seçeyim", "bu seriden hangisini önerirsin" gibi bir SEÇİM istiyorsa; o serideki en iyi, en keyifli filmi seç ve neden bu bölümü izlemesi gerektiğini gerekçesiyle açıkla!

🚨 3 NUMARALI KURAL (SPOILER KESİNLİKLE YASAKTIR):
- Öneri gerekçesinde ("reason") filmin kilit sürprizlerini, ters köşelerini (plot twists) veya finalini KESİNLİKLE AÇIK ETME!
- İzleyicide merak uyandıran, atmosferi, temayı ve çatışmayı öne çıkaran bir dille yaz.

Cevabını SADECE geçerli bir JSON nesnesi olarak döndür:
{
  "selected_id": 12345, // Katalogdan seçildiyse ID'si, dışarıdan ise 0
  "title": "Film Adı",
  "reason": "Kullanıcının o anki spesifik isteğine özel, samimi, neden bu filmi seçtiğini açıklayan 2-3 cümlelik öneri gerekçesi (asla spoiler içermez).",
  "matching_aspects": ["sevilen tema 1", "sevilen tema 2"]
}
''';

    final userContent = '''
${recentContext != null && recentContext.isNotEmpty ? 'Son Önerilen / İncelenen Film Bağlamı: $recentContext\n' : ''}Kullanıcı İsteği: "$userPrompt"
Beğendiği Temalar: ${tasteProfile.likedThemes.join(', ')}
Sevdiği Türler: ${tasteProfile.preferredGenres.join(', ')}

⛔ KULLANICININ ZATEN İZLEDİĞİ YASAKLI FİLMLER (KESİNLİKLE BUNLARDAN BİRİNİ ÖNERME - Kullanıcı tekrar izlemek istemediyse):
${watchedTitlesList.join(', ')}

Aday Filmler Kataloğu (Öncelikli):
${jsonEncode(candidatesList)}
''';

    final json = await _callGroqChat(
      systemPrompt: systemPrompt,
      userPrompt: userContent,
      expectJson: true,
    );

    if (json != null && json['title'] != null && json['title'].toString().isNotEmpty) {
      final title = json['title'].toString();
      final titleNorm = title.toLowerCase().trim();

      // Check if user explicitly asked for rewatch, choice, or selection in a franchise
      final lowerPrompt = userPrompt.toLowerCase();
      final isRewatchOrChoice = lowerPrompt.contains('tekrar') ||
          lowerPrompt.contains('rewatch') ||
          lowerPrompt.contains('hangisini') ||
          lowerPrompt.contains('sen seç') ||
          lowerPrompt.contains('hangisi') ||
          lowerPrompt.contains('seç') ||
          lowerPrompt.contains('sec') ||
          lowerPrompt.contains('which one') ||
          lowerPrompt.contains('choose');

      if (!isRewatchOrChoice) {
        final isAlreadyWatched = watchedMovies.any((m) {
          final mt = m.title.toLowerCase().trim();
          return mt == titleNorm || (mt.length > 3 && titleNorm.contains(mt)) || (titleNorm.length > 3 && mt.contains(titleNorm));
        });
        if (isAlreadyWatched) {
          return null; // Force fallback to unwatched candidate search
        }
      }

      final selectedId = (json['selected_id'] as num?)?.toInt() ?? 0;

      Movie? movie;
      if (selectedId != 0) {
        for (final m in candidateCatalog) {
          if (m.id == selectedId) {
            movie = m;
            break;
          }
        }
      }
      if (movie == null) {
        for (final m in candidateCatalog) {
          if (m.title.toLowerCase() == title.toLowerCase() ||
              m.title.toLowerCase().contains(title.toLowerCase()) ||
              title.toLowerCase().contains(m.title.toLowerCase())) {
            movie = m;
            break;
          }
        }
      }

      final matching = (json['matching_aspects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['sinematik anlatım'];

      return {
        'recommended_title': title,
        'movie_id': movie?.id ?? (title.hashCode & 0x7FFFFFFF),
        if (movie != null)
          'movie': movie.copyWith(
            status: MovieStatus.recommended,
            initialProposedAt: DateTime.now().toIso8601String(),
            recommendedAt: DateTime.now().toIso8601String(),
            ratingSource: 'ai_inferred',
          ),
        'reason': json['reason']?.toString() ?? '$title zevk profiline mükemmel uyuyor.',
        'matching_aspects': matching,
        'is_fallback': false,
      };
    }
    return null;
  }

  Future<MovieReviewChatResponse?> _chatMovieFeedbackFromGroq({
    required String movieTitle,
    required List<Map<String, String>> conversationHistory,
    double? currentScore,
  }) async {
    const systemPrompt = '''
Sen samimi ve zeki bir sinema arkadaşısın.
Kullanıcı film hakkında düşüncelerini paylaşıyor.
Görevin kullanıcının yazdıklarını analiz edip KESİNLİKLE 1.0 ile 10.0 arasında tek ondalıklı bir puan tahmin etmek (örn: 7.8, 8.5, 4.0), beğendiği ve beğenmediği yönleri çıkarmak ve sıcak, zeki bir sohbet cevabı üretmek.
Cevabını SADECE şu JSON şablonunda ver:
{
  "reply": "Kullanıcıya samimi yanıtın (1-2 cümle)",
  "score": 8.0,
  "liked_aspects": ["harika atmosfer", "güçlü oyunculuk"],
  "disliked_aspects": ["ağır tempo"],
  "summary": "1 cümlelik özet değerlendirme"
}
''';

    final userContent = '''
Film: $movieTitle
Önceki Puan Tahmini: ${currentScore ?? 'Henüz yok'}
Sohbet Geçmişi:
${conversationHistory.map((m) => '${m['role']}: ${m['content']}').join('\n')}
''';

    final json = await _callGroqChat(
      systemPrompt: systemPrompt,
      userPrompt: userContent,
      expectJson: true,
    );

    if (json != null && json['score'] != null) {
      final scoreVal = ((json['score'] as num).toDouble()).clamp(0.0, 10.0);
      return MovieReviewChatResponse(
        reply: json['reply']?.toString() ?? 'Görüşlerin başarıyla analiz edildi!',
        score: scoreVal,
        likedAspects: (json['liked_aspects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        dislikedAspects: (json['disliked_aspects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        summary: json['summary']?.toString() ?? '$movieTitle filmi değerlendirildi.',
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> _identifyMovieFromGroq({
    required String userPrompt,
  }) async {
    const systemPrompt = '''
Kullanıcının mesajından daha önce İZLEDİĞİNİ veya BİTİRDİĞİNİ açıkça belirttiği filmi tespit et.
Cevabını SADECE geçerli bir JSON olarak döndür:
{
  "found": true,
  "movie_title": "The Wolf of Wall Street",
  "overview": "2-3 cümlelik akıcı, atmosferi ve çatışmayı anlatan detaylı film özeti.",
  "discussion": "Filmle ilgili sohbet başlatacak samimi bir soru veya yorum."
}
ÖNEMLİ KURAL:
Kullanıcı bir filmi izlediğini AÇIKÇA BELİRTMİYORSA (örneğin film önerisi/tavsiyesi istiyorsa, "ne izlesem", "izlesem mi", "en son neler var", "hangi filmi izleyeyim" gibi sorular soruyorsa veya film arıyorsa) KESİNLİKLE {"found": false} döndür. Asla varsayım yapma veya film uydurma.
''';

    final json = await _callGroqChat(
      systemPrompt: systemPrompt,
      userPrompt: 'Kullanıcı mesajı: "$userPrompt"',
      expectJson: true,
    );

    if (json != null && json['found'] == true && json['movie_title'] != null) {
      final title = json['movie_title'].toString();
      return {
        'movie_found': true,
        'title': title,
        'overview': json['overview']?.toString() ?? '',
        'comment': json['discussion']?.toString() ?? '**$title** filmini izlemişsin! Bu yapım hakkındaki düşüncelerini duymayı çok isterim.',
        'genres': 'Sinema',
        'vote_average': 7.5,
      };
    }
    return null;
  }
}
