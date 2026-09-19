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

  /// Free-form conversational chat response using Groq
  Future<String?> generateChatResponse(String userPrompt, {String? recentContext}) async {
    final systemPrompt = '''
Sen CineAI adlı zeki, samimi ve kültürlü bir yapay zeka sinema danışmanısın.
Kullanıcı seninle sohbet ediyor veya sinema, yönetmenler, film önerileri hakkında konuşuyor ya da önceki önerilerin hakkında sitem/eleştiri yöneltiyor.
${recentContext != null && recentContext.isNotEmpty ? 'Önceki Konuşma ve İncelenen Film Bağlamı: $recentContext\n' : ''}
Eğer kullanıcı önceki önerinin alakasız olduğunu söylerse (örneğin "ne alaka ya", "ben bunu sormadım", "alakasız oldu") hatanı samimiyetle kabul et, tatlı bir dille özür dile ve hemen kullanıcının gerçekte istediği konuya dönerek en iyi seçenekleri sun.
Eğer kullanıcı incelenen bir filmin devamını veya daha yenisini ("daha yenisi yok mu", "daha yeni var mı") soruyorsa ve o seride daha yeni film çıkmamışsa, bunu sinema kültürüyle dürüstçe açıkla (örn: "Örümcek-Adam serisinde Eve Dönüş Yok 2021 yapımıdır ve şu anki en yeni canlı çekim filmidir, sonraki film henüz yapım aşamasında"). Ardından evrendeki diğer filmleri veya benzer alternatifleri öner.
Kullanıcının sorusuna akıcı, samimi, yardımsever ve bilgili bir Türkçe ile yanıt ver.
Cevabını Markdown formatında, sıcak ve net bir tonla yaz.
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
      return 'İncelediğimiz film serisinde bundan daha yeni çıkmış bir canlı çekim film henüz vizyona girmedi (yeni projeler hazırlık aşamasında). Dilersen aynı evrendeki diğer filmlere veya benzer tonda yeni süper kahraman maceralarına göz atabiliriz! 🍿';
    }
    if (lower.contains('ne alaka') || lower.contains('alakası ne') || lower.contains('alakasız')) {
      return 'Haklısın, bir önceki önerim tam olarak istediğinle örtüşmedi, kusura bakma! Şimdi doğrudan istediğin seriden veya türden harika bir öneri hazırlayalım. Aklındaki detayları söylemen yeterli. 🎬';
    }
    return 'Sinema konusunda her zaman yanındayım! İstediğin türe, yönetmene veya karaktere göre en uygun filmleri keşfetmek için buradayım.';
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

  // --------------------------------------------------------------------------
  // Local Assembler & Heuristic Analyzers (Zero-Latency Offline Mode)
  // --------------------------------------------------------------------------
  Map<String, dynamic> _localAssembledRecommendation({
    required String userPrompt,
    required UserTasteProfile tasteProfile,
    required List<Movie> watchedMovies,
    required List<Movie> candidateCatalog,
    required Set<int> excludedMovieIds,
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
        .where((w) => w.length > 2 && !['film', 'filmi', 'filmleri', 'öner', 'izle', 'bana', 'gibi', 'neler', 'bişey', 'animasyon', 'sevmiyorum', 'istemiyorum', 'olmasın', 'canlı', 'aksiyon'].contains(w))
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

    final assembled = _assembler.assemble(
      movie: chosen,
      tasteProfile: tasteProfile,
      templateHookGenre: 'Sinema zevkine ve akıl yakan kurgu tercihlerine tam uyan bir başyapıt olarak',
      templateHookMood: 'Nefes kesici temposu ve derin atmosferiyle',
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
    'groq/compound-mini',
    'qwen/qwen3.8-27b',
    'openai/gpt-oss-20b',
    'groq/compound',
    'llama-3.3-70b-versatile',
  ];

  // --------------------------------------------------------------------------
  // Groq API Key Rotation Pool & Fast Inference
  // --------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _callGroqChat({
    required String systemPrompt,
    required String userPrompt,
    bool expectJson = true,
  }) async {
    if (SupabaseConfig.defaultGroqApiKeys.isEmpty) return null;

    for (final apiKey in SupabaseConfig.defaultGroqApiKeys) {
      if (apiKey.isEmpty || apiKey.contains('YOUR_GROQ')) continue;

      for (final model in supportedGroqModels) {
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
            },
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            final content = decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
            if (expectJson) {
              return jsonDecode(content) as Map<String, dynamic>;
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
C) Kademe 3 - Tam Sıfırlama / Başka Tarz (Evrenden Kesin Çıkış):
Kullanıcı "başka tarz bir şey", "farklı bir tür", "bu seriyi boşver", "bunu geçelim", "komedi olsun", "korku izleyelim" diyorsa: Önceki seriyi ve evreni KESİNLİKLE UNUT VE BIRAK! Kullanıcının yeni istediği türe veya genel zevk profiline göre dünya sinemasından bağımsız taze bir film öner. Asla eski seriye saplanıp kalma!

🚨 2 NUMARALI KURAL (YASAKLI / İZLENEN FİLMLER):
Kullanıcının daha önce izlediği veya kütüphanesinde olan filmleri ("YASAKLI / İZLENEN FİLMLER LİSTESİ") KESİNLİKLE VE ASLA ÖNERME!
Her zaman kullanıcının henüz izlemediği, YEPYENİ, taze bir film öner.

Cevabını SADECE geçerli bir JSON nesnesi olarak döndür:
{
  "selected_id": 12345, // Katalogdan seçildiyse ID'si, dışarıdan ise 0
  "title": "Film Adı",
  "reason": "Kullanıcının o anki spesifik isteğine özel, samimi, neden bu filmi seçtiğini açıklayan 2-3 cümlelik öneri gerekçesi.",
  "matching_aspects": ["sevilen tema 1", "sevilen tema 2"]
}
''';

    final userContent = '''
Kullanıcı İsteği: "$userPrompt"
Beğendiği Temalar: ${tasteProfile.likedThemes.join(', ')}
Sevdiği Türler: ${tasteProfile.preferredGenres.join(', ')}

⛔ KULLANICININ ZATEN İZLEDİĞİ YASAKLI FİLMLER (KESİNLİKLE BUNLARDAN BİRİNİ ÖNERME):
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

      // STRICT VALIDATION: If AI hallucinated and picked a movie from the watched list, REJECT IT!
      final isAlreadyWatched = watchedMovies.any((m) {
        final mt = m.title.toLowerCase().trim();
        return mt == titleNorm || (mt.length > 3 && titleNorm.contains(mt)) || (titleNorm.length > 3 && mt.contains(titleNorm));
      });
      if (isAlreadyWatched) {
        return null; // Force fallback to unwatched candidate search
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
