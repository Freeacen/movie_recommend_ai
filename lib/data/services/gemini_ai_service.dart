import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/utils/local_storage.dart';
import '../models/movie.dart';
import '../models/user_taste_profile.dart';
import '../../domain/enums/movie_status.dart';

class AspectAnalysisResult {
  final double score; // 1.0 - 10.0 scale
  final List<String> likedAspects;
  final List<String> dislikedAspects;
  final String summary;

  const AspectAnalysisResult({
    required this.score,
    required this.likedAspects,
    required this.dislikedAspects,
    required this.summary,
  });
}

class MovieReviewChatResponse {
  final String reply;
  final double score; // 1.0 - 10.0 scale
  final List<String> likedAspects;
  final List<String> dislikedAspects;
  final String summary;

  const MovieReviewChatResponse({
    required this.reply,
    required this.score,
    required this.likedAspects,
    required this.dislikedAspects,
    required this.summary,
  });
}

class GeminiAiService {
  final http.Client _client;
  String? _apiKey;

  GeminiAiService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey;

  String? get apiKey {
    if (_apiKey != null && _apiKey!.trim().isNotEmpty) {
      return _apiKey;
    }
    return LocalStorageHelper.getItem(LocalStorageHelper.keyGeminiApiKey);
  }

  set apiKey(String? value) {
    _apiKey = value;
  }

  /// Helper to post generateContent with automatic model fallback
  Future<({int statusCode, String? reasonPhrase, String body, String modelUsed})> _postGenerateContent({
    required String activeKey,
    required String prompt,
    Map<String, dynamic>? generationConfig,
  }) async {
    final models = [ApiConstants.geminiModel, ApiConstants.geminiModelFallback];

    for (final model in models) {
      final uri = Uri.parse(
        '${ApiConstants.geminiBaseUrl}/$model:generateContent?key=$activeKey',
      );

      final payload = <String, dynamic>{
        'contents': [
          {
            'parts': [{'text': prompt}]
          }
        ],
      };
      if (generationConfig != null) {
        payload['generationConfig'] = generationConfig;
      }

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return (
          statusCode: 200,
          reasonPhrase: response.reasonPhrase,
          body: response.body,
          modelUsed: model,
        );
      } else if (response.statusCode == 404 && model != models.last) {
        // Try next fallback model
        continue;
      } else {
        return (
          statusCode: response.statusCode,
          reasonPhrase: response.reasonPhrase,
          body: response.body,
          modelUsed: model,
        );
      }
    }

    return (
      statusCode: 500,
      reasonPhrase: 'Bağlantı kurulamadı',
      body: '',
      modelUsed: ApiConstants.geminiModel,
    );
  }

  /// Test whether current Gemini API key is valid and working
  Future<({bool success, String message})> testConnection() async {
    final activeKey = apiKey;
    if (activeKey == null || activeKey.trim().isEmpty) {
      return (
        success: false,
        message: 'Kayıtlı bir Gemini API anahtarı bulunmuyor.',
      );
    }

    if (activeKey.startsWith('...') || activeKey.length < 20) {
      return (
        success: false,
        message: 'Eksik anahtar girildi ("$activeKey"). Lütfen Google AI Studio\'daki tam anahtarı kopyalayın.',
      );
    }

    try {
      final res = await _postGenerateContent(
        activeKey: activeKey,
        prompt: 'Merhaba, bu bir test mesajı. Kısaca "Bağlantı başarılı" de.',
      );

      if (res.statusCode == 200) {
        return (
          success: true,
          message: 'Google Gemini API (${res.modelUsed}) bağlantısı başarılı! 🚀',
        );
      } else {
        String detail = res.reasonPhrase ?? 'Bilinmeyen hata';
        try {
          final errJson = jsonDecode(res.body);
          if (errJson['error']?['message'] != null) {
            detail = errJson['error']['message'];
          }
        } catch (_) {}
        return (
          success: false,
          message: 'Google yanıtı: $detail (Kod: ${res.statusCode})',
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Bağlantı hatası: $e',
      );
    }
  }

  /// Free-form conversational response via Gemini
  Future<String?> generateChatResponse(String userPrompt) async {
    final activeKey = apiKey;
    if (activeKey == null || activeKey.trim().isEmpty) return null;

    try {
      final prompt = 'Sen CineAI uygulamasının yapay zeka film danışmanısın. Kullanıcıyla samimi, zeki, sinemasever ve doğal bir dille Türkçe sohbet et. Eski puanlarını veya veritabanı kayıtlarını mekanik şekilde sayma.\nKullanıcı: $userPrompt';
      final res = await _postGenerateContent(
        activeKey: activeKey,
        prompt: prompt,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Analyze user feedback conversation about a watched movie.
  /// Extracts an inferred rating (1.0 - 10.0), liked elements, and disliked elements.
  Future<AspectAnalysisResult> analyzeMovieFeedback({
    required String movieTitle,
    required String userFeedbackText,
  }) async {
    final activeKey = apiKey;
    if (activeKey != null && activeKey.trim().isNotEmpty) {
      try {
        final prompt = '''
Sen uzman bir sinema ve duygu analizi yapay zekasısın.
Kullanıcı daha önce önerilen "$movieTitle" filmini izledi ve şu yorumu yaptı:
"$userFeedbackText"

Görevin:
1. Kullanıcının yorumundan filmi ne kadar beğendiğine dair 1.0 ile 10.0 arasında gerçekçi bir puan çıkar (Örn: 7.8, 8.5).
2. Filmin en çok beğendiği yönleri (oyunculuk, senaryo, ters köşe, atmosfer, müzik vb.) kısa etiketler halinde listele.
3. Filmin beğenmediği veya sıkıldığı yönleri varsa kısa etiketler halinde listele.
4. 2-3 cümlelik samimi ve kişisel bir özet oluştur. İlk cümle genel izlenimi yansıtsın, ikinci cümle beğenilen/beğenilmeyen detayları vurgulasın, üçüncü cümle (varsa) bu filmin kullanıcı için ne ifade ettiğini tamamlasın.

Lütfen SADECE geçerli bir JSON formatında yanıt ver, başka hiçbir metin ekleme:
{
  "score": 7.8,
  "liked_aspects": ["güçlü oyunculuk", "ters köşe final"],
  "disliked_aspects": ["ağır orta tempo"],
  "summary": "Genel olarak filmi beğendin ve tatmin edici bir izleme deneyimi yaşadın. Oyunculukları ve finali özellikle seni etkiledi, ancak orta kısımdaki tempo senin için biraz ağır geldi. Bu film, beklentilerin karşılayan türden sağlam bir yapım olarak aklında kalacak."
}
''';

        final res = await _postGenerateContent(
          activeKey: activeKey,
          prompt: prompt,
          generationConfig: {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
          },
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          final jsonMap = jsonDecode(_cleanJson(text));
          return AspectAnalysisResult(
            score: ((jsonMap['score'] as num?)?.toDouble() ?? 7.5).clamp(1.0, 10.0),
            likedAspects: (jsonMap['liked_aspects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
            dislikedAspects: (jsonMap['disliked_aspects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
            summary: jsonMap['summary']?.toString() ?? 'Değerlendirmen başarıyla kaydedildi.',
          );
        }
      } catch (_) {
        // Fallback to local heuristic analyzer
      }
    }

    // Heuristic rule-based local sentiment analyzer for fallback & offline mode
    return _localAnalyzeFeedback(userFeedbackText);
  }

  /// Interactive, multi-turn conversational review for a specific movie in a dedicated pop-up modal.
  /// Generates a cinematic assistant reply while continuously tracking user score (1.0 - 10.0) and aspects.
  Future<MovieReviewChatResponse> chatMovieFeedback({
    required String movieTitle,
    required List<Map<String, String>> conversationHistory,
    double? currentScore,
  }) async {
    final activeKey = apiKey;
    if (activeKey != null && activeKey.trim().isNotEmpty) {
      try {
        final historyText = conversationHistory.map((m) {
          final role = m['role'] == 'user' ? 'Kullanıcı' : 'AI Danışman';
          return '$role: ${m['content']}';
        }).join('\n');

        final prompt = '''
Sen CineAI uygulamasının zeki, tutkulu ve samimi film eleştirmeni yapay zekasısın.
Kullanıcı seninle "$movieTitle" filmini izledikten sonra filmi değerlendirmek için sohbet ediyor.

Şu ana kadarki sohbet geçmişi:
$historyText

Mevcut tahmini puan: ${currentScore != null ? "${currentScore.toStringAsFixed(1)} / 10.0" : "Henüz kesinleşmedi (başlangıç için 7.0 civarı baz al)"}

GÖREVLERİN:
1. Kullanıcının son mesajına doğrudan, samimi, zeki ve sinemasever bir dille cevap ver (reply).
   - Kullanıcının bahsettiği detayları (oyunculuk, senaryo, atmosfer, kurgu, tempo, final vb.) samimiyetle yorumla, film hakkındaki sinematik bilginle harmanla.
   - Sohbeti derinleştirecek, kullanıcının daha fazla hissini açığa çıkaracak sıcak bir soru veya tespit ekle.
2. Filmin beğeni puanını **1.0 ile 10.0 arasında** (ondalıklı, örneğin 7.2, 8.5) güncelle veya tahmin et (score).
   - DİKKAT: Eğer kullanıcı bir puan veya puan aralığı belirttiyse (örneğin "bence 7.5", "8 verelim", "6.8 değil de 7.2 ya da 7.8 arasında", "7.5 diyelim"), kullanıcının istediği puanı KESİNLİKLE 'score' olarak ata!
3. Kullanıcının filmde beğendiği unsurları (liked_aspects) ve beğenmediği/eleştirdiği unsurları (disliked_aspects) kısa etiketler halinde güncelle.
4. Bu ana kadar kullanıcının film hakkındaki hislerini özetleyen **2-3 cümlelik** kişisel ve samimi bir özet hazırla (summary). İlk cümle genel izlenimi, ikinci cümle öne çıkan beğeni/eleştiri detaylarını yansıtsın, üçüncü cümle (varsa) filmin kullanıcı için ne anlama geldiğini tamamlasın.

Lütfen cevabını SADECE geçerli bir JSON formatında döndür, başka hiçbir metin ekleme:
{
  "reply": "Cevabın buraya gelecek...",
  "score": 7.5,
  "liked_aspects": ["ters köşe kurgu", "etkileyici atmosfer"],
  "disliked_aspects": ["orta kısımdaki ağır tempo"],
  "summary": "Atmosferi ve ters köşeleri sayesinde "$movieTitle" seni derinden etkiledi. Özellikle kurgu yapısını ve yönetmenin tercihlerini çok beğendin, ancak orta kısımdaki tempo zaman zaman seni sarstı. Bu film, aklında iz bırakacak türden güçlü bir yapım."
}
''';

        final res = await _postGenerateContent(
          activeKey: activeKey,
          prompt: prompt,
          generationConfig: {
            'temperature': 0.3,
            'responseMimeType': 'application/json',
          },
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          final jsonMap = jsonDecode(_cleanJson(text));
          return MovieReviewChatResponse(
            reply: jsonMap['reply']?.toString() ?? 'Harika bir bakış açısı! Değerlendirmene devam edebilirsin.',
            score: ((jsonMap['score'] as num?)?.toDouble() ?? (currentScore ?? 7.0)).clamp(1.0, 10.0),
            likedAspects: (jsonMap['liked_aspects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
            dislikedAspects: (jsonMap['disliked_aspects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
            summary: jsonMap['summary']?.toString() ?? '',
          );
        }
      } catch (_) {
        // Fallback to local heuristic analyzer
      }
    }

    return _localChatMovieFeedback(
      movieTitle: movieTitle,
      conversationHistory: conversationHistory,
      currentScore: currentScore,
    );
  }

  /// Search for movies using Gemini's extensive knowledge when TMDB API key is not configured.
  Future<List<Movie>> searchMoviesWithAi(String query) async {
    final activeKey = apiKey;
    if (activeKey != null && activeKey.trim().isNotEmpty) {
      try {
        final prompt = '''
Sen CineAI uygulamasının film arama motorusun.
Kullanıcı "$query" araması yaptı.
Bu aramayla eşleşen en alakalı 1 ile 5 film bilgisini (özellikle sinema tarihindeki bilinen filmler veya yeni yapımlar) JSON array olarak listele.

Lütfen SADECE geçerli bir JSON array formatında yanıt ver, başka hiçbir metin ekleme:
[
  {
    "title": "Filmin Adı",
    "original_title": "Original Title",
    "release_date": "YYYY-MM-DD",
    "genres": "Bilim Kurgu, Gerilim",
    "overview": "Filmin Türkçe 2-3 cümlelik konusu, atmosferi ve temel çatışması.",
    "vote_average": 7.4
  }
]
''';

        final res = await _postGenerateContent(
          activeKey: activeKey,
          prompt: prompt,
          generationConfig: {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
          },
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          final dynamic parsed = jsonDecode(_cleanJson(text));
          final list = parsed is List ? parsed : (parsed['movies'] as List? ?? []);

          return list.map((item) {
            final title = item['title']?.toString() ?? query;
            final releaseDate = item['release_date']?.toString();
            final genres = item['genres']?.toString();
            final overview = item['overview']?.toString();
            final voteAvg = (item['vote_average'] as num?)?.toDouble() ?? 7.0;

            return Movie(
              id: (title.hashCode & 0x7FFFFFFF),
              title: title,
              releaseDate: releaseDate,
              genres: genres,
              overview: overview,
              voteAverage: voteAvg,
              status: MovieStatus.none,
            );
          }).toList();
        }
      } catch (_) {}
    }

    // No API key or API failed — don't fabricate fake movies, just return empty
    return [];
  }

  /// Analyze if the user's message is mentioning a watched movie (e.g. "en son end of the oak street izledim").
  /// Returns movie details, movie comment, and whether a movie was identified.
  Future<Map<String, dynamic>> identifyAndDiscussWatchedMovie({
    required String userPrompt,
  }) async {
    final activeKey = apiKey;
    if (activeKey != null && activeKey.trim().isNotEmpty) {
      try {
        final prompt = '''
Sen CineAI uygulamasının zeki ve tutkulu sinema danışmanısın.
Kullanıcının yazdığı mesajı analiz et:
"$userPrompt"

GÖREV:
1. Kullanıcı yakın zamanda veya daha önce izlediği bir filmden bahsediyor mu? (Örn: "en son end of the oak street izledim", "dün akşam inception izledim", "interstellar filmini bitirdim", "oppenheimer izledim süperdi", "end of the oak street").
   - DİKKAT: Eğer kullanıcı izlediği bir filmden BAHSETMİYORSA ve sadece genel film önerisi istiyorsa (örn: "film öner", "ne izlesem", "akıl yakan gerilim tavsiye et"), "movie_found": false döndür.
2. Eğer bir film tespit ettiysen:
   - "title": Filmin bilinen adı (Türkçe veya orijinal).
   - "release_date": Çıkış tarihi (YYYY-MM-DD veya en azından YYYY-01-01).
   - "genres": Türleri (örn: "Bilim Kurgu, Gerilim").
   - "overview": 2-3 cümlelik akıcı, atmosferi ve çatışmayı anlatan detaylı film özeti.
   - "vote_average": 1.0 - 10.0 arası genel beğeni puanı.
   - "comment": Bu film hakkında samimi, zeki, sinemasever bir dille 2-3 cümlelik harika bir yorum yap. Filmin konusuna, yönetmenine, atmosferine veya oyunculuklarına değin ve kullanıcının zevk profiline işlemek için değerlendirmek isteyip istemediğini sor.

Lütfen SADECE geçerli bir JSON formatında döndür:
{
  "movie_found": true,
  "title": "The End of Oak Street",
  "release_date": "2026-08-14",
  "genres": "Bilim Kurgu, Gerilim, Aksiyon",
  "overview": "1980'lerin banliyösünde yaşayan bir ailenin kendilerini aniden tarih öncesi dinozorlar çağında bulmasını konu alan bilim kurgu gerilim filmi. Zamansal anomalilerle parçalanan mahallede hayatta kalma mücadelesi verilirken, ailenin geçmişindeki gizemler de gün yüzüne çıkıyor.",
  "vote_average": 7.0,
  "comment": "David Robert Mitchell'ın 80'ler banliyö atmosferini dinozorların kol gezdiği tarih öncesi bir hayatta kalma mücadelesiyle birleştirdiği The End of Oak Street sahiden son dönemin en merak uyandıran bilim kurgu işlerinden biri! Özellikle sonundaki paralel gerçeklik tartışmaları ve temposu çok konuşuldu. Bu filmi zevk profiline işlemek ve puanlamak için değerlendirmek ister misin?"
}
''';

        final res = await _postGenerateContent(
          activeKey: activeKey,
          prompt: prompt,
          generationConfig: {
            'temperature': 0.3,
            'responseMimeType': 'application/json',
          },
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          final jsonMap = jsonDecode(_cleanJson(text)) as Map<String, dynamic>;
          return jsonMap;
        } else if (res.statusCode == 429 || res.statusCode == 503) {
          // Quota exhausted or service unavailable — signal caller clearly
          return {'movie_found': false, 'quota_exceeded': true};
        }
      } catch (_) {}
    }

    return _localIdentifyWatchedMovie(userPrompt);
  }

  /// Local fallback rule for offline mode
  Map<String, dynamic> _localIdentifyWatchedMovie(String prompt) {
    final lower = prompt.toLowerCase();
    final hasWatchKeyword = lower.contains('izledim') ||
        lower.contains('seyrettim') ||
        lower.contains('bitirdim') ||
        lower.contains('en son') ||
        lower.contains('bunu izledim');

    if (!hasWatchKeyword) {
      return {'movie_found': false};
    }

    String extractedTitle = prompt
        .replaceAll(RegExp(r'izledim|seyrettim|bitirdim|en son|bunu|filmini|filmi|🎬', caseSensitive: false), '')
        .replaceAll(':', '')
        .trim();

    if (extractedTitle.length < 2) {
      return {'movie_found': false};
    }

    return {
      'movie_found': true,
      'title': extractedTitle,
      'release_date': '2025-01-01',
      'genres': 'Sinema',
      'overview': '$extractedTitle, sinemaseverler tarafından ilgiyle takip edilen etkileyici bir yapımdır. Filmin kurgusu, atmosferi ve karakter gelişimi izleyicide derin izler bırakır.',
      'vote_average': 7.0,
      'comment': '**$extractedTitle** filmini izlemişsin! Sinema zevkini haritalandırmak için bu film hakkındaki düşüncelerini duymayı çok isterim. Bu filmi değerlendirmek ister misin?',
    };
  }

  /// Ask AI for a personalized movie recommendation tailored to user's taste profile
  Future<Map<String, dynamic>> getRecommendation({
    required String userPrompt,
    required UserTasteProfile tasteProfile,
    required List<Movie> watchedMovies,
    required List<Movie> candidateCatalog,
    Set<int> excludedMovieIds = const {},
  }) async {
    final tasteContext = tasteProfile.toContextPrompt();
    final watchedTitles = watchedMovies.map((m) => m.title).join(', ');
    final activeKey = apiKey;

    if (activeKey != null && activeKey.trim().isNotEmpty) {
      try {
        final prompt = '''
Sen kişiselleştirilmiş film danışmanı bir yapay zekasın.
Kullanıcının profil bilgileri:
$tasteContext
Daha önce izlediği filmler: [$watchedTitles]

Kullanıcının isteği:
"$userPrompt"

Kullanıcının zevk profilinde sevdiği unsurları (örn. ters köşe, derin atmosfer, müzik) dikkate alarak ve hoşlanmadığı şeylerden kaçınarak harika bir film öner.
Daha önce izlediklerini tekrar önerme.
Kullanıcının eski puanlarını veya veritabanı puanlarını kesinlikle mekanik olarak sayma; samimi, sıcak ve sinematik bir dille açıkla.

Yanıtını SADECE şu JSON formatında ver:
{
  "recommended_title": "Film Adı",
  "reason": "Neden önerdiğini ve kullanıcının sevdiği özelliklerle nasıl uyuştuğunu samimi şekilde anlatan 2-3 cümle.",
  "matching_aspects": ["ters köşe", "etkileyici müzikler"]
}
''';

        final res = await _postGenerateContent(
          activeKey: activeKey,
          prompt: prompt,
          generationConfig: {
            'temperature': 0.7,
            'responseMimeType': 'application/json',
          },
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          final jsonMap = jsonDecode(_cleanJson(text));
          return jsonMap;
        } else if (res.statusCode == 429 || res.statusCode == 503) {
          return {'recommended_title': '', 'quota_exceeded': true, 'reason': '', 'matching_aspects': []};
        }
      } catch (_) {
        // Fallback to local smart recommender on network errors
      }
    }

    // Local smart recommender (no API key, or network error)
    return _localRecommendMovie(userPrompt, tasteProfile, watchedMovies, candidateCatalog, excludedMovieIds);
  }

  /// Generate warm re-watch nudge message for an older favorite
  String generateRewatchNudge({
    required Movie movie,
    required String formattedDate,
  }) {
    final aspectsInfo = movie.likedAspects.isNotEmpty
        ? ' Özellikle ${movie.likedAspects.take(2).join(" ve ")} yönünü çok beğenmiştin.'
        : '';

    return 'Aradığın kriterlere uygun yepyeni bir film bulamadık ama **${movie.title}** filmini izleyeli epey zaman oldu.$aspectsInfo\n\nNostaljik bir sinema gecesi yapıp bu favorini yeniden izlemeye ne dersin? 🍿';
  }

  /// Local rule-based analyzer for sentiment and aspects on a 1.0 - 10.0 scale
  AspectAnalysisResult _localAnalyzeFeedback(String text) {
    final lower = text.toLowerCase();
    final liked = <String>[];
    final disliked = <String>[];

    // Check if user explicitly stated a rating (e.g. "bence 7.5", "7.2 yada 7.8", "8/10", "10 üzerinden 7")
    final explicitRating = _extractExplicitRating(text);
    double baseScore = explicitRating ?? 7.0;

    if (explicitRating == null) {
      // Positive indicators
      if (lower.contains('harika') || lower.contains('efsane') || lower.contains('mükemmel') || lower.contains('bayıldım') || lower.contains('muhteşem')) {
        baseScore += 1.8;
      }
      if (lower.contains('iyi') || lower.contains('güzel') || lower.contains('beğendim') || lower.contains('etkileyici') || lower.contains('başarılı')) {
        baseScore += 0.8;
      }

      // Negative indicators
      if (lower.contains('berbat') || lower.contains('kötü') || lower.contains('sıkıldım') || lower.contains('beğenmedim') || lower.contains('zaman kaybı') || lower.contains('rezalet')) {
        baseScore -= 2.5;
      }
      if (lower.contains('yavaş') || lower.contains('tempo') || lower.contains('uzun') || lower.contains('klişe') || lower.contains('beklentimin altında')) {
        baseScore -= 0.8;
      }
    }

    // Liked aspects detection
    if (lower.contains('oyunculuk') || lower.contains('oyuncu')) liked.add('etkileyici oyunculuk');
    if (lower.contains('ters köşe') || lower.contains('sürpriz') || lower.contains('final')) liked.add('ters köşe kurgu');
    if (lower.contains('müzik') || lower.contains('soundtrack')) liked.add('atmosferik müzikler');
    if (lower.contains('görsel') || lower.contains('efekt') || lower.contains('sinematografi')) liked.add('etkileyici görsellik');
    if (lower.contains('senaryo') || lower.contains('hikaye') || lower.contains('konu')) liked.add('sürükleyici senaryo');
    if (lower.contains('gerilim') || lower.contains('heyecan')) liked.add('yüksek gerilim');
    if (lower.contains('derin') || lower.contains('felsefe') || lower.contains('psikoloji')) liked.add('derin felsefi / psikolojik tema');

    // Disliked aspects detection
    if (lower.contains('tempo') || lower.contains('yavaş') || lower.contains('ağır') || lower.contains('sıkıcı')) {
      disliked.add('ağır orta tempo');
    }
    if (lower.contains('klişe') || lower.contains('tahmin edilebilir')) disliked.add('klişe diyaloglar');
    if (lower.contains('uzun') || lower.contains('gereksiz uzatılmış')) disliked.add('gereksiz uzun sahneler');
    if (lower.contains('mantık hatası') || lower.contains('saçma') || lower.contains('kopuk')) disliked.add('senaryo boşlukları');

    // Default fallbacks if empty
    if (liked.isEmpty && baseScore >= 6.5) liked.add('genel anlatım ve atmosfer');
    if (disliked.isEmpty && baseScore < 7.0) disliked.add('tempo dengesizliği');

    // Clamp score between 1.0 and 10.0 with 1 decimal place
    final finalScore = (baseScore.clamp(1.0, 10.0) * 10).roundToDouble() / 10.0;

    return AspectAnalysisResult(
      score: finalScore,
      likedAspects: liked,
      dislikedAspects: disliked,
      summary: 'Görüşlerin analiz edildi, zevk profiline yeni sinematik tercihler işlendi!',
    );
  }

  /// Helper to extract explicit scores from user text (e.g. "7.2 yada 7.8", "bence puanı 8.2", "10 üzerinden 7")
  double? _extractExplicitRating(String text) {
    // 1. Range match: "7.2 yada 7.8", "7 ile 8 arası", "7 - 8"
    final rangeRegex = RegExp(
      r'(\d{1,2}(?:[.,]\d)?)\s*(?:ile|yada|ya da|veya|-)\s*(\d{1,2}(?:[.,]\d)?)',
      caseSensitive: false,
    );
    final rangeMatch = rangeRegex.firstMatch(text);
    if (rangeMatch != null) {
      final v1 = double.tryParse(rangeMatch.group(1)!.replaceAll(',', '.'));
      final v2 = double.tryParse(rangeMatch.group(2)!.replaceAll(',', '.'));
      if (v1 != null && v2 != null && v1 <= 10 && v2 <= 10) {
        return ((v1 + v2) / 2 * 10).roundToDouble() / 10.0;
      }
    }

    // 2. Explicit patterns: "10 üzerinden 7.5", "7.5 / 10", "bence puanı 8.2", "puanım 8", "8 verelim", "bence 7.5"
    final explicitRegex = RegExp(
      r'(?:10\s*üzerinden\s*(\d{1,2}(?:[.,]\d)?))|(?:(\d{1,2}(?:[.,]\d)?)\s*\/\s*10)|(?:(?:puan\w*|bence|verelim|olsun|diyelim)(?:\s+\w+)?\s+(\d{1,2}(?:[.,]\d)?))',
      caseSensitive: false,
    );
    final match = explicitRegex.firstMatch(text);
    if (match != null) {
      for (int i = 1; i <= match.groupCount; i++) {
        final g = match.group(i);
        if (g != null) {
          final val = double.tryParse(g.replaceAll(',', '.'));
          if (val != null && val >= 1.0 && val <= 10.0) {
            return val;
          }
        }
      }
    }

    // 3. Fallback: Any decimal or integer between 1.0 and 10.0 in text if score keywords are present
    if (text.contains('puan') || text.contains('bence') || text.contains('ver') || text.contains('olsun') || text.contains('değil')) {
      final numRegex = RegExp(r'(?<!\d)(\d{1,2}(?:[.,]\d)?)(?!\d)');
      for (final m in numRegex.allMatches(text)) {
        final val = double.tryParse(m.group(1)!.replaceAll(',', '.'));
        if (val != null && val >= 1.0 && val <= 10.0) {
          return val;
        }
      }
    }

    return null;
  }

  /// Local fallback for conversational review when offline
  MovieReviewChatResponse _localChatMovieFeedback({
    required String movieTitle,
    required List<Map<String, String>> conversationHistory,
    double? currentScore,
  }) {
    final latestUserMsg = conversationHistory.reversed
        .firstWhere((m) => m['role'] == 'user', orElse: () => {'content': ''})['content'] ?? '';

    final analysis = _localAnalyzeFeedback(latestUserMsg);
    final newScore = analysis.score;

    final likedStr = analysis.likedAspects.isNotEmpty
        ? analysis.likedAspects.join(' ve ')
        : 'atmosfer';

    String reply;
    if (latestUserMsg.toLowerCase().contains('puan') || latestUserMsg.contains('7') || latestUserMsg.contains('8') || latestUserMsg.contains('9') || latestUserMsg.contains('6')) {
      reply = 'Filme dair puanını **${newScore.toStringAsFixed(1)} / 10.0** olarak not aldım! $movieTitle filminin özellikle $likedStr yönüne yaptığın vurgu çok yerinde. Finali veya oyunculuk performansı hakkında aklında kalan başka bir detay var mı?';
    } else {
      reply = 'Kesinlikle katılıyorum! $movieTitle için belirttiğin $likedStr konusundaki tespitlerin çok isabetli. ${newScore >= 7.5 ? "Genel olarak filmin sende bıraktığı etki oldukça yüksek görünüyor." : "Belli ki beklentilerini tam olarak karşılayamayan bazı yönler olmuş."} Bu filmi sinemasever bir arkadaşına önerir miydin?';
    }

    return MovieReviewChatResponse(
      reply: reply,
      score: newScore,
      likedAspects: analysis.likedAspects,
      dislikedAspects: analysis.dislikedAspects,
      summary: '$movieTitle filmini $newScore/10 olarak değerlendirdin. $likedStr yönleri öne çıktı.',
    );
  }

  /// Local rule-based recommender with smart cycling and theme matching
  Map<String, dynamic> _localRecommendMovie(
    String userPrompt,
    UserTasteProfile tasteProfile,
    List<Movie> watchedMovies,
    List<Movie> candidateCatalog, [
    Set<int> excludedMovieIds = const {},
  ]) {
    final watchedIds = watchedMovies.map((m) => m.id).toSet();
    final watchedTitles = watchedMovies.map((m) => m.title.toLowerCase().trim()).toList();

    bool isWatched(Movie m) {
      if (watchedIds.contains(m.id)) return true;
      final mTitle = m.title.toLowerCase().trim();
      final pureTitle = mTitle.split('(').first.trim();
      for (final wt in watchedTitles) {
        final pureWt = wt.split('(').first.trim();
        if (mTitle == wt || pureTitle == pureWt) return true;
        if (pureTitle.isNotEmpty && pureWt.isNotEmpty) {
          if (pureTitle.contains(pureWt) || pureWt.contains(pureTitle)) return true;
        }
      }
      return false;
    }

    // Filter out all watched movies
    var unwatched = candidateCatalog.where((m) => !isWatched(m)).toList();

    if (unwatched.isEmpty) {
      return {
        'recommended_title': '',
        'reason': 'Katalogdaki tüm filmleri zaten izlemişsin!',
        'matching_aspects': [],
        'is_fallback': true,
      };
    }

    // Filter out movies already proposed in the current chat session if possible
    var candidates = unwatched.where((m) => !excludedMovieIds.contains(m.id)).toList();
    if (candidates.isEmpty) {
      // If all candidates have been shown once, reset the rotation
      candidates = unwatched;
    }

    final lowerPrompt = userPrompt.toLowerCase();
    Movie? chosen;
    String customReason = '';
    final matching = <String>[];

    // Check specific themes in user prompt
    if (lowerPrompt.contains('zaman') || lowerPrompt.contains('paradoks') || lowerPrompt.contains('döngü') || lowerPrompt.contains('loop')) {
      chosen = candidates.firstWhere(
        (m) => m.title.toLowerCase().contains('predestination') ||
            m.title.toLowerCase().contains('source code') ||
            m.title.toLowerCase().contains('edge of tomorrow') ||
            m.title.toLowerCase().contains('tenet'),
        orElse: () => candidates.first,
      );
      matching.addAll(['zaman yolculuğu', 'zamansal paradokslar', 'ters köşe kurgu']);
      customReason = 'Zamanda yolculuk ve akıl almaz zamansal paradoksları seven bir sinemasever olarak **${chosen.title}**, seni soluksuz bırakacak!';
    } else if (lowerPrompt.contains('nolan') || lowerPrompt.contains('prestij') || lowerPrompt.contains('hafıza') || lowerPrompt.contains('memento')) {
      chosen = candidates.firstWhere(
        (m) => m.title.toLowerCase().contains('prestige') ||
            m.title.toLowerCase().contains('memento') ||
            m.title.toLowerCase().contains('tenet'),
        orElse: () => candidates.first,
      );
      matching.addAll(['Christopher Nolan dehası', 'ters köşe kurgu', 'derin gizem']);
      customReason = 'Christopher Nolan\'ın akıl yakan kurgu, derin gizem ve sürükleyici anlatım tarzına sahip **${chosen.title}** yapımını senin için seçtim.';
    } else if (lowerPrompt.contains('akıl yakan') || lowerPrompt.contains('ters köşe') || lowerPrompt.contains('beyin')) {
      chosen = candidates.firstWhere(
        (m) => m.title.toLowerCase().contains('prestige') ||
            m.title.toLowerCase().contains('predestination') ||
            m.title.toLowerCase().contains('shutter') ||
            m.title.toLowerCase().contains('memento'),
        orElse: () => candidates.first,
      );
      matching.addAll(['ters köşe final', 'derin gizem', 'zihin bükücü senaryo']);
      customReason = 'Son saniyesine kadar ters köşelerle dolu, zihni zorlayan akıl yakan bir başyapıt: **${chosen.title}**!';
    } else if (lowerPrompt.contains('uzay') || lowerPrompt.contains('uzaylı') || lowerPrompt.contains('dil') || lowerPrompt.contains('geliş')) {
      chosen = candidates.firstWhere(
        (m) => m.title.toLowerCase().contains('arrival') || m.title.toLowerCase().contains('geliş') || m.title.toLowerCase().contains('dune'),
        orElse: () => candidates.first,
      );
      matching.addAll(['felsefi bilim kurgu', 'zamansal algı', 'etkileyici atmosfer']);
      customReason = 'O derin bilim kurgu atmosferini ve insan algısını sarsan felsefi temaları hissettirecek bir başyapıt: Denis Villeneuve imzalı **${chosen.title}**!';
    } else if (lowerPrompt.contains('yapay zeka') || lowerPrompt.contains('distopya') || lowerPrompt.contains('cyberpunk') || lowerPrompt.contains('blade')) {
      chosen = candidates.firstWhere(
        (m) => m.title.toLowerCase().contains('blade runner'),
        orElse: () => candidates.first,
      );
      matching.addAll(['distopik atmosfer', 'yapay zeka felsefesi', 'görsel şölen']);
      customReason = 'Yapay zeka felsefesi ve büyüleyici atmosferiyle sinema tarihinin görsel şaheseri **${chosen.title}** tam sana göre.';
    } else if (lowerPrompt.contains('gerilim') || lowerPrompt.contains('ada') || lowerPrompt.contains('shutter')) {
      chosen = candidates.firstWhere(
        (m) => m.title.toLowerCase().contains('shutter') || m.title.toLowerCase().contains('zindan'),
        orElse: () => candidates.first,
      );
      matching.addAll(['psikolojik gerilim', 'şok edici son', 'kasvetli atmosfer']);
      customReason = 'Sinir uçlarına dokunan psikolojik gerilim ve unutulmaz bir ters köşe sunduğu için Leonardo DiCaprio\'nun devleştiği **${chosen.title}** filmini seçtim.';
    } else if (lowerPrompt.contains('simülasyon') || lowerPrompt.contains('matrix') || lowerPrompt.contains('gerçek')) {
      chosen = candidates.firstWhere(
        (m) => m.title.toLowerCase().contains('matrix'),
        orElse: () => candidates.first,
      );
      matching.addAll(['simülasyon teorisi', 'felsefi aksiyon', 'zihin açıcı']);
      customReason = 'Gerçeklik algını sorgulatacak ve akıl yakan kurgusuyla seni büyüleyecek efsanevi bilim kurgu klasiği **${chosen.title}**.';
    } else if (lowerPrompt.contains('aksiyon') || lowerPrompt.contains('savaş') || lowerPrompt.contains('dövüş')) {
      chosen = candidates.firstWhere(
        (m) => m.title.toLowerCase().contains('edge of tomorrow') ||
            m.title.toLowerCase().contains('dark knight') ||
            m.title.toLowerCase().contains('matrix'),
        orElse: () => candidates.first,
      );
      matching.addAll(['yüksek tempo', 'akıllı aksiyon', 'zaman döngüsü']);
      customReason = 'Hem nefes kesen bir aksiyon temposu hem de zekice işlenmiş bir kurgu sunduğu için **${chosen.title}** filmini seçtim.';
    }

    // If "başka", "farklı" or no specific keyword, pick the next available candidate from rotation
    if (chosen == null) {
      chosen = candidates.first;
      matching.addAll(tasteProfile.likedThemes.take(2));
      if (matching.isEmpty) {
        matching.addAll(['akıl yakan kurgu', 'zamansal derinlik']);
      }
      customReason = 'Sinema zevkine ve profilindeki "${matching.join(" ve ")}" gibi unsurlara tam oturan harika bir film seçtim: **${chosen.title}**!';
    }

    return {
      'recommended_title': chosen.title,
      'movie_id': chosen.id,
      'reason': customReason,
      'matching_aspects': matching,
      'is_fallback': false,
    };
  }

  String _cleanJson(String text) {
    String cleaned = text.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }
}
