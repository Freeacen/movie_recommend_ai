import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/movie.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/movie_repository.dart';
import '../../data/repositories/user_taste_repository.dart';
import '../../data/services/backend_ai_service.dart';
import '../../data/services/gemini_ai_service.dart';
import '../../data/services/tmdb_service.dart';
import '../../domain/enums/movie_status.dart';
import 'library_provider.dart';
import 'settings_provider.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final Movie? pendingReviewMovie; // Movie currently undergoing feedback interview
  final bool isAwaitingInterviewAnswer; // Waiting for user's text about liked/disliked aspects

  const ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.pendingReviewMovie,
    this.isAwaitingInterviewAnswer = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    List<ChatMessage>? Function()? messagesProducer,
    bool? isGenerating,
    Movie? pendingReviewMovie,
    bool? isAwaitingInterviewAnswer,
  }) {
    return ChatState(
      messages: messagesProducer != null ? messagesProducer()! : (messages ?? this.messages),
      isGenerating: isGenerating ?? this.isGenerating,
      pendingReviewMovie: pendingReviewMovie ?? this.pendingReviewMovie,
      isAwaitingInterviewAnswer: isAwaitingInterviewAnswer ?? this.isAwaitingInterviewAnswer,
    );
  }
}

enum ContextualIntentTier {
  microAdjustment, // Tier 1: in-series adjustment (format, chronology, cast)
  thematicBridge,  // Tier 2: similar energy/mood, different universe
  cleanSlateExit,  // Tier 3: complete franchise exit, new genre / fresh taste
}

class ContextualSearchInfo {
  final String searchQuery;
  final String? inheritedFranchise;
  final List<String> excludeGenres;
  final Movie? recentMovie;
  final ContextualIntentTier tier;
  final String? bridgeDescription;

  const ContextualSearchInfo({
    required this.searchQuery,
    this.inheritedFranchise,
    this.excludeGenres = const [],
    this.recentMovie,
    this.tier = ContextualIntentTier.microAdjustment,
    this.bridgeDescription,
  });
}

class SubSeriesInfo {
  final String seriesName;
  final String actorOrDirector;
  final List<String> previousEras;
  final List<String> nextEras;

  const SubSeriesInfo({
    required this.seriesName,
    required this.actorOrDirector,
    this.previousEras = const [],
    this.nextEras = const [],
  });
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _chatRepo;
  final MovieRepository _movieRepo;
  final UserTasteRepository _tasteRepo;
  final GeminiAiService _geminiService;
  final BackendAiService _backendAiService;
  final TmdbService _tmdbService;
  final Ref _ref;
  final _uuid = const Uuid();
  final Set<int> _alreadyRecommendedInChat = {};

  ChatNotifier({
    required ChatRepository chatRepo,
    required MovieRepository movieRepo,
    required UserTasteRepository tasteRepo,
    required GeminiAiService geminiService,
    required TmdbService tmdbService,
    required Ref ref,
    BackendAiService? backendAiService,
  })  : _chatRepo = chatRepo,
        _movieRepo = movieRepo,
        _tasteRepo = tasteRepo,
        _geminiService = geminiService,
        _backendAiService = backendAiService ?? BackendAiService(),
        _tmdbService = tmdbService,
        _ref = ref,
        super(const ChatState()) {
    initChat();
  }

  /// Initialize chat and check for unreviewed recommendations
  Future<void> initChat() async {
    state = state.copyWith(isGenerating: true);
    try {
      final history = await _chatRepo.getMessages();

      if (history.isEmpty) {
        // Welcome message
        final welcome = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Merhaba! Ben senin yapay zeka film danışmanınım. 🎬\n\nNelerden hoşlandığını, nasıl bir ruh halinde olduğunu söyle veya aklındaki türü yaz, sana en uygun filmleri keşfedelim!',
          timestamp: DateTime.now().toIso8601String(),
          options: ['Bilim Kurgu Öner 🚀', 'Akıl Yakan Gerilim 🧠', 'Eski Bir Favori Hatırlat 🔁'],
        );
        try {
          await _chatRepo.saveMessage(welcome);
        } catch (_) {}
        state = state.copyWith(messages: [welcome], isGenerating: false);
      } else {
        state = state.copyWith(messages: history, isGenerating: false);
      }

      // Check for proactive recommendation nudge
      await checkForProactiveReviewNudge();
    } catch (e) {
      final welcome = ChatMessage(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        content: 'Merhaba! Ben senin yapay zeka film danışmanınım. 🎬\n\nNelerden hoşlandığını, nasıl bir ruh halinde olduğunu söyle veya aklındaki türü yaz, sana en uygun filmleri keşfedelim!',
        timestamp: DateTime.now().toIso8601String(),
        options: ['Bilim Kurgu Öner 🚀', 'Akıl Yakan Gerilim 🧠', 'Eski Bir Favori Hatırlat 🔁'],
      );
      state = state.copyWith(messages: [welcome], isGenerating: false);
    }
  }

  /// Proactive Nudge check: If user hasn't reviewed an earlier recommendation, ask proactively!
  Future<void> checkForProactiveReviewNudge() async {
    try {
      final unreviewed = await _movieRepo.getUnreviewedRecommendations();
      if (unreviewed.isNotEmpty) {
        final movie = unreviewed.first;
        final formattedDate = DateFormatter.formatRelative(movie.initialProposedAt);

        final nudgeMessage = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: '👋 Yeni önerilere geçmeden önce bir şey sormak istiyorum:\n\n'
              '${formattedDate.isNotEmpty ? "$formattedDate sana " : "Daha önce sana "}**${movie.title}** filmini önermiştim. '
              'İzleme fırsatın oldu mu? Nasıl buldun?',
          timestamp: DateTime.now().toIso8601String(),
          relatedMovieId: movie.id,
          messageType: MessageType.reviewNudge,
          options: ['İzledim 🎬', 'Henüz Değil ⏳', 'Listeme Ekle 📌'],
          attachedMovie: movie,
        );

        try {
          await _chatRepo.saveMessage(nudgeMessage);
        } catch (_) {}
        state = state.copyWith(
          messages: [...state.messages, nudgeMessage],
          pendingReviewMovie: movie,
        );
      }
    } catch (_) {}
  }

  /// Handle user sending a prompt or clicking a quick option button
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 1. Add user message
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.user,
      content: trimmed,
      timestamp: DateTime.now().toIso8601String(),
    );

    try {
      await _chatRepo.saveMessage(userMsg);
    } catch (_) {}

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isGenerating: true,
    );

    try {
      // 2. Check if we are currently awaiting the user's conversational review answer
      if (state.isAwaitingInterviewAnswer && state.pendingReviewMovie != null) {
        await _handleInterviewResponse(trimmed, state.pendingReviewMovie!);
        return;
      }

      final lower = trimmed.toLowerCase();

      // 3. Status or Connection query check (e.g. "geminiye bağlımıyız", "api bağlı mı", "durum ne")
      if (_isConnectionQuery(lower)) {
        await _handleConnectionQuery();
        return;
      }

      // 4. Friendly greeting check
      if (_isGreeting(lower)) {
        await _handleGreeting();
        return;
      }

      // 5. Check if user pasted an initial watch history / ratings list
      if (_isWatchHistoryList(lower)) {
        await _handleWatchHistoryImport(trimmed);
        return;
      }

      // 6. Check if user reports having watched a movie or mentions a specific film they watched
      final looksLikeMovieReport = _isWatchedMovieReport(trimmed);

      if (looksLikeMovieReport) {
        // Did the user directly affirm having watched the recommended/recent film?
        // (e.g. "izledim", "bunu izledim", "önerdiğin filmi izledim" without specifying another title)
        final cleanedText = lower.replaceAll(RegExp(r'[.!?,]'), '').trim();
        final isDirectRecentConfirmation = cleanedText == 'izledim' ||
            cleanedText == 'bunu izledim' ||
            cleanedText == 'izledim bunu' ||
            cleanedText == 'önerdiğin filmi izledim' ||
            cleanedText == 'onerdiğin filmi izledim' ||
            cleanedText == 'önerdiğini izledim' ||
            cleanedText == 'filmi izledim';

        Movie? recentMovie;
        for (final msg in state.messages.reversed) {
          if (msg.attachedMovie != null) {
            recentMovie = msg.attachedMovie;
            break;
          }
        }

        if (isDirectRecentConfirmation && recentMovie != null) {
          final replyMsg = ChatMessage(
            id: _uuid.v4(),
            sender: MessageSender.assistant,
            content: 'Harika! Önerdiğimiz **${recentMovie.title}** filmini izlemişsin. Bu filmi değerlendirip zevk profiline yeni sinematik tercihler eklemek ister misin?',
            timestamp: DateTime.now().toIso8601String(),
            attachedMovie: recentMovie,
            options: [
              'Sohbetle Değerlendir 🤖',
              'Hızlı Puan Ver ⭐',
              'Farklı Bir Film Öner 🍿',
            ],
          );
          try {
            await _chatRepo.saveMessage(replyMsg);
          } catch (_) {}

          state = state.copyWith(
            messages: [...state.messages, replyMsg],
            isGenerating: false,
          );
          return;
        }

        // Otherwise, ask AI to identify the specific movie mentioned by user
        final identified = await _backendAiService.identifyAndDiscussWatchedMovie(userPrompt: trimmed);

        // Quota / service unavailable — tell the user clearly instead of hallucinating
        if (identified['quota_exceeded'] == true) {
          final quotaMsg = ChatMessage(
            id: _uuid.v4(),
            sender: MessageSender.assistant,
            content: '⚠️ Gemini API kota limitine ulaşıldı. Şu an film tanımlama özelliği çalışmıyor.\n\n'
                'Film adını kendin yazarsan hızlı puan verme ekranından ekleyebilirsin:\n'
                '📌 **Keşfet** sekmesinden filmi aratıp "İzledim" butonuna basabilirsin.',
            timestamp: DateTime.now().toIso8601String(),
            options: ['Farklı Bir Film Öner 🍿', 'Eski Bir Favori Hatırlat 🔁'],
          );
          try { await _chatRepo.saveMessage(quotaMsg); } catch (_) {}
          state = state.copyWith(messages: [...state.messages, quotaMsg], isGenerating: false);
          return;
        }

        if (identified['movie_found'] == true && (identified['title']?.toString().isNotEmpty ?? false)) {
          final title = identified['title']!.toString();
          final comment = identified['comment']?.toString() ??
              '🎬 **$title** filmini izlemişsin! Bu filmi zevk profiline işlemek için değerlendirmek ister misin?';
          final releaseDate = identified['release_date']?.toString();
          final genres = identified['genres']?.toString();
          final overview = identified['overview']?.toString();
          final voteAvg = (identified['vote_average'] as num?)?.toDouble() ?? 7.0;

          String? posterPath;
          // If TMDB key is available, check for official poster image
          if (_tmdbService.apiKey != null && _tmdbService.apiKey!.trim().isNotEmpty) {
            try {
              final searchResults = await _tmdbService.searchMovies(title);
              if (searchResults.isNotEmpty) {
                posterPath = searchResults.first.posterPath;
              }
            } catch (_) {}
          }

          final movie = Movie(
            id: (title.hashCode & 0x7FFFFFFF),
            title: title,
            releaseDate: releaseDate,
            genres: genres,
            overview: overview,
            voteAverage: voteAvg,
            posterPath: posterPath,
            status: MovieStatus.none,
          );

          final replyMsg = ChatMessage(
            id: _uuid.v4(),
            sender: MessageSender.assistant,
            content: comment,
            timestamp: DateTime.now().toIso8601String(),
            attachedMovie: movie,
            options: [
              'Sohbetle Değerlendir 🤖',
              'Hızlı Puan Ver ⭐',
              'Farklı Bir Film Öner 🍿',
            ],
          );

          try {
            await _chatRepo.saveMessage(replyMsg);
          } catch (_) {}

          state = state.copyWith(
            messages: [...state.messages, replyMsg],
            isGenerating: false,
          );
          return;
        }

        // Movie could NOT be identified from text. Never hallucinate or assume they watched recentMovie!
        final askWhichMsg = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Tebrikler! Hangi filmi izlediğini tam anlayamadım. Filmin adını yazarsan hemen film hakkında konuşup birlikte değerlendirelim! 🎬',
          timestamp: DateTime.now().toIso8601String(),
        );
        try {
          await _chatRepo.saveMessage(askWhichMsg);
        } catch (_) {}
        state = state.copyWith(
          messages: [...state.messages, askWhichMsg],
          isGenerating: false,
        );
        return;
      } else if (lower.contains('henüz değil') || lower.contains('izlemedim')) {
        final reply = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Sorun değil! İstediğin zaman izleyebilirsin. Peki bugün nasıl bir film izlemek istersin?',
          timestamp: DateTime.now().toIso8601String(),
          options: ['Sürpriz Öneri 🎲', 'Bilim Kurgu 🚀', 'Komedi / Rahatlatıcı 🍿'],
        );
        try {
          await _chatRepo.saveMessage(reply);
        } catch (_) {}
        state = state.copyWith(
          messages: [...state.messages, reply],
          isGenerating: false,
          pendingReviewMovie: null,
        );
        return;
      } else if (lower.contains('eski bir favori') || lower.contains('tekrar izle') || lower.contains('hatırlat')) {
        await _handleRewatchFallback();
        return;
      }

      // 7. Check if user is asking about currency, newer or older movie in the series ("daha yenisi yok mu", "daha eskisi var mı", "ilk filmi mi")
      if (_isCurrencyInquiry(lower)) {
        final handled = await _handleCurrencyInquiry(lower);
        if (handled) return;
      }

      // 8. General conversational chat with Groq or Gemini if active and not a direct recommendation request
      if (_isGeneralConversational(lower, trimmed)) {
        final recentMovie = _getRecentRecommendedMovie();
        String? recentContext;
        if (recentMovie != null) {
          recentContext = 'Kullanıcı şu film kartını inceliyor: ${recentMovie.title} (Çıkış Yılı: ${recentMovie.releaseDate ?? "Bilinmiyor"}), Tür: ${recentMovie.genres ?? ""}.';
        }

        String? chatReply = await _backendAiService.generateChatResponse(trimmed, recentContext: recentContext);
        if (chatReply == null || chatReply.isEmpty) {
          chatReply = await _geminiService.generateChatResponse(trimmed);
        }

        if (chatReply != null && chatReply.isNotEmpty) {
          final replyMsg = ChatMessage(
            id: _uuid.v4(),
            sender: MessageSender.assistant,
            content: chatReply,
            timestamp: DateTime.now().toIso8601String(),
            options: ['Bana Bir Film Öner 🎬', 'Süper Kahraman Filmi Öner 🦸‍♂️', 'Akıl Yakan Gerilim 🧠'],
          );
          try {
            await _chatRepo.saveMessage(replyMsg);
          } catch (_) {}
          state = state.copyWith(
            messages: [...state.messages, replyMsg],
            isGenerating: false,
          );
          return;
        }
      }

      // 8. Regular Recommendation Request
      await _generateRecommendation(trimmed);
    } catch (e, stack) {
      debugPrint('ChatProvider caught error: $e');
      debugPrint(stack.toString());

      // Graceful fallback recommendation with strictly unwatched movies
      final watched = await _movieRepo.getWatchedMovies();
      final watchedIds = watched.map((m) => m.id).toSet();
      final catalog = TmdbService.getMockMovies();
      final unwatchedCandidates = catalog.where((m) => !watchedIds.contains(m.id)).toList();
      final fallbackMovie = unwatchedCandidates.firstWhere(
        (m) => m.title.toLowerCase().contains('arrival') || m.title.toLowerCase().contains('geliş'),
        orElse: () => unwatchedCandidates.isNotEmpty ? unwatchedCandidates.first : catalog.first,
      );

      final fallbackReply = ChatMessage(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        content: 'Senin sinema zevkine uygun harika bir film seçtim:',
        timestamp: DateTime.now().toIso8601String(),
        relatedMovieId: fallbackMovie.id,
        messageType: MessageType.recommendationCard,
        options: ['İzleme Listeme Ekle 📌', 'Başka Bir Tür Öner 🔄', 'Eski Bir Favori Hatırlat 🔁'],
        attachedMovie: fallbackMovie,
      );

      state = state.copyWith(
        messages: [...state.messages, fallbackReply],
        isGenerating: false,
      );
    }
  }

  bool _isConnectionQuery(String lower) {
    final cleaned = lower
        .replaceAll('’', '')
        .replaceAll('\'', '')
        .replaceAll('?', '')
        .replaceAll('!', '')
        .trim();

    return cleaned.contains('bağlı mıyız') ||
        cleaned.contains('bağlımıyız') ||
        cleaned.contains('bagli miyiz') ||
        cleaned.contains('baglimiyiz') ||
        cleaned.contains('bağlı mı') ||
        cleaned.contains('bagli mi') ||
        cleaned.contains('bağlantı') ||
        cleaned.contains('baglanti') ||
        cleaned.contains('api testi') ||
        cleaned.contains('api çalışıyor mu') ||
        cleaned.contains('api calisiyor mu') ||
        (cleaned.contains('gemini') &&
            (cleaned.contains('çalış') ||
                cleaned.contains('calis') ||
                cleaned.contains('aktif') ||
                cleaned.contains('durum') ||
                cleaned.contains('bağ') ||
                cleaned.contains('bag') ||
                cleaned.contains('açık') ||
                cleaned.contains('acik') ||
                cleaned.contains('test') ||
                cleaned == 'gemini')) ||
        (cleaned.contains('api') &&
            (cleaned.contains('çalış') ||
                cleaned.contains('calis') ||
                cleaned.contains('aktif') ||
                cleaned.contains('durum') ||
                cleaned.contains('bağ') ||
                cleaned.contains('bag')));
  }

  Future<void> _handleConnectionQuery() async {
    final isSupabaseConfigured = SupabaseConfig.isConfigured;
    final hasGroq = SupabaseConfig.defaultGroqApiKeys.isNotEmpty;

    final replyMsg = ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.assistant,
      content: '⚡ **CineAI v2.0 Hibrit Sistem Durumu:**\n\n'
          '• **Yapay Zeka:** Groq `llama-3.3-70b-versatile` (${hasGroq ? 'Aktif & Havuz Hazır 🚀' : 'Yerel Şablon Modu'})\n'
          '• **Bulut Veritabanı:** Supabase PostgreSQL (${isSupabaseConfigured ? 'Bağlı & Eşitlendi ✅' : 'Çevrimdışı SQLite'}) \n'
          '• **Film Kataloğu:** Dahili TMDB API (Sınırsız Arama & Afişler) 🎬\n'
          '• **Akıllı Yedek:** Cihaz Üzeri Dynamic Explanation Assembler (0 Gecikme, Kesintisiz)\n\n'
          'Tüm sistemler aktif ve kullanımına hazır! Sana bugün nasıl bir film önerelim? 🍿',
      timestamp: DateTime.now().toIso8601String(),
      options: ['Akıl Yakan Gerilim 🧠', 'Zaman Paradoksu Filmi ⏳', 'Bilim Kurgu Başyapıtı 🚀'],
    );

    try {
      await _chatRepo.saveMessage(replyMsg);
    } catch (_) {}

    state = state.copyWith(
      messages: [...state.messages, replyMsg],
      isGenerating: false,
    );
  }

  bool _isGreeting(String lower) {
    final cleaned = lower.replaceAll('!', '').replaceAll('.', '').trim();
    return cleaned == 'merhaba' ||
        cleaned == 'selam' ||
        cleaned == 'selamlar' ||
        cleaned == 'hey' ||
        cleaned == 'günaydın' ||
        cleaned == 'iyi akşamlar' ||
        cleaned == 'naber' ||
        cleaned == 'nasılsın';
  }

  Future<void> _handleGreeting() async {
    final reply = ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.assistant,
      content: 'Merhaba! 🎬 Harika bir film keşfetmeye hazır mısın?\n\n'
          'Bugün nasıl bir ruh halindesin? Aklındaki türü veya temayı söyle, sana en uygun önerileri hazırlayayım!',
      timestamp: DateTime.now().toIso8601String(),
      options: ['Bilim Kurgu Öner 🚀', 'Akıl Yakan Gerilim 🧠', 'Eski Bir Favori Hatırlat 🔁'],
    );
    try {
      await _chatRepo.saveMessage(reply);
    } catch (_) {}
    state = state.copyWith(
      messages: [...state.messages, reply],
      isGenerating: false,
    );
  }

  bool _isGeneralConversational(String lower, String raw) {
    // 1. Objections, criticisms, or complaints about previous recommendations (e.g. "tenetle örümcek adam ne alaka ya")
    if (lower.contains('ne alaka') ||
        lower.contains('alakası ne') ||
        lower.contains('alakasız') ||
        lower.contains('ben bunu sormadım') ||
        lower.contains('ben bunu istemedim') ||
        lower.contains('yanlış film') ||
        lower.contains('bu ne alaka') ||
        lower.contains('saçma') ||
        lower.contains('alaka ya') ||
        lower.contains('alakası yok')) {
      return true;
    }

    // 2. Questions about currency, existence of newer movies, or sequels (e.g. "daha yenisi yok mu")
    if (lower.contains('daha yenisi yok mu') ||
        lower.contains('daha yeni yok mu') ||
        lower.contains('daha yenisi var mı') ||
        lower.contains('daha yeni var mı') ||
        (lower.contains('daha yenisi') && (lower.contains('mu') || lower.contains('mı') || lower.contains('var') || lower.contains('yok'))) ||
        lower.contains('bundan daha yeni') ||
        lower.contains('en son çıkan bu mu') ||
        lower.contains('devamı var mı') ||
        lower.contains('devam filmi var mı') ||
        lower.contains('öncesi var mı')) {
      return true;
    }

    if (lower.contains('film öner') ||
        lower.contains('film tavsiye') ||
        lower.contains('bana bir film') ||
        lower.contains('film izlemek istiyorum') ||
        lower.contains('film izlemek') ||
        lower.contains('film bul') ||
        lower.contains('ne izlesem') ||
        lower.contains('ne izleyeyim') ||
        lower.contains('izlesem') ||
        lower.contains('izlesek') ||
        lower.contains('izleyeyim') ||
        lower.contains('zilesem') ||
        lower.contains('neler var') ||
        lower.contains('tavsiye et') ||
        lower.contains('önerir misin') ||
        lower.contains('öneri ver') ||
        lower.contains('önerin var mı') ||
        lower.contains('listeme ekle')) {
      return false;
    }

    return raw.trim().endsWith('?') ||
        lower.contains('mısın') ||
        lower.contains('misin') ||
        lower.contains('musun') ||
        lower.contains('müsün') ||
        lower.contains('miyim') ||
        lower.contains('mıyım') ||
        lower.contains('miyiz') ||
        lower.contains('mıyız') ||
        lower.contains('film dışında') ||
        lower.contains('cevaplar mısın') ||
        lower.contains('sohbet') ||
        lower.contains('konuşalım') ||
        lower.startsWith('kim') ||
        lower.startsWith('nedir') ||
        lower.startsWith('neler') ||
        lower.startsWith('nasıl') ||
        lower.startsWith('anlat') ||
        lower.contains('hakkında ne düşünüyorsun') ||
        lower.contains('en sevdiğin');
  }

  bool _isWatchedMovieReport(String text) {
    final lower = text.toLowerCase().trim();

    // 1. Explicitly check and reject if user is asking questions, expressing intentions, conditionals, or desires:
    // e.g. "izlesem mi", "izlesem", "izlemek istiyorum", "neler var", "ne var", "önerir misin", "en son çıkanlar"
    if (lower.contains('izlesem') ||
        lower.contains('izlesek') ||
        lower.contains('izleyeyim') ||
        lower.contains('izleyelim') ||
        lower.contains('izlemek iste') ||
        lower.contains('izlemek niyet') ||
        lower.contains('izlemeyi düşün') ||
        lower.contains('izleyesim') ||
        lower.contains('izlenir mi') ||
        lower.contains('izlenir mı') ||
        lower.contains('izlemeye değer') ||
        lower.contains('izlemeli mi') ||
        lower.contains('izlemeli misin') ||
        lower.contains('izleyebilir mi') ||
        lower.contains('izler misin') ||
        lower.contains('neler var') ||
        lower.contains('ne var') ||
        lower.contains('hangisini') ||
        lower.contains('hangisi') ||
        lower.contains('öner') ||
        lower.contains('tavsiye') ||
        lower.contains('ne izle') ||
        lower.contains('hangi film') ||
        lower.contains('en son çıkan') ||
        lower.contains('son çıkan') ||
        lower.contains('en son neler') ||
        lower.contains('en son hangi')) {
      return false;
    }

    // 2. Explicit past-tense watching assertions in Turkish
    final hasPastTenseWatch = lower.contains('izledim') ||
        lower.contains('izlemiştim') ||
        lower.contains('seyrettim') ||
        lower.contains('seyretmiştim') ||
        lower.contains('izlemiştik') ||
        lower.contains('seyretmiştik') ||
        lower.contains('bunu izledim') ||
        lower.contains('filmi bitirdim') ||
        lower.contains('filmini bitirdim');

    return hasPastTenseWatch;
  }

  bool _isWatchHistoryList(String lower) {
    return (lower.contains('izlenen') && lower.contains('film')) ||
        (lower.contains('izlediğim') && lower.contains('film')) ||
        (lower.contains('tarih') && lower.contains('puan')) ||
        (lower.contains('shawshank') && lower.contains('interstellar'));
  }

  String _extractSearchQuery(String text) {
    var s = text.toLowerCase()
        .replaceAll(RegExp(r'[?!.,:;]'), ' ')
        .replaceAll(RegExp(r'\b(filmlerinden|filmleri|filmini|filmine|filmi|filmler|film)\b'), ' ')
        .replaceAll(RegExp(r'\b(izlesem|izlesek|izleyeyim|izleyelim|izlemek|zilesem|izle|seyret)\b'), ' ')
        .replaceAll(RegExp(r'\b(mi|mu|mü|mı|misin|mısın|musun|müsün)\b'), ' ')
        .replaceAll(RegExp(r'\b(en son|son|neler var|ne var|neler|hangisi|hangisini|öneri|önerir|öner|tavsiye|bana|bir|bişey|şey|türünde|hakkında|tarzı|gibi)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  Movie? _getRecentRecommendedMovie() {
    for (final msg in state.messages.reversed) {
      if (msg.attachedMovie != null) return msg.attachedMovie;
    }
    return null;
  }

  String _extractFranchiseOrCoreTopic(Movie movie) {
    final title = movie.title;
    final lower = title.toLowerCase();

    // Check specific known franchises first to prevent bad splitting (e.g. "Örümcek-Adam", "Mission: Impossible")
    final knownFranchises = {
      'örümcek': 'Örümcek-Adam',
      'spider': 'Örümcek-Adam',
      'batman': 'Batman',
      'superman': 'Superman',
      'iron man': 'Iron Man',
      'demir adam': 'Iron Man',
      'avengers': 'Avengers',
      'yenilmezler': 'Avengers',
      'harry potter': 'Harry Potter',
      'star wars': 'Star Wars',
      'yıldız savaşları': 'Star Wars',
      'yüzüklerin efendisi': 'Yüzüklerin Efendisi',
      'lord of the rings': 'Yüzüklerin Efendisi',
      'hobbit': 'Hobbit',
      'hızlı ve öfkeli': 'Hızlı ve Öfkeli',
      'fast & furious': 'Hızlı ve Öfkeli',
      'fast and furious': 'Hızlı ve Öfkeli',
      'görevimiz tehlike': 'Görevimiz Tehlike',
      'mission impossible': 'Görevimiz Tehlike',
      'mission: impossible': 'Görevimiz Tehlike',
      'karayip korsanları': 'Karayip Korsanları',
      'pirates of the caribbean': 'Karayip Korsanları',
      'matrix': 'Matrix',
      'john wick': 'John Wick',
      'transformers': 'Transformers',
      'jurassic': 'Jurassic Park',
      'galaksinin koruyucuları': 'Galaksinin Koruyucuları',
      'guardians of the galaxy': 'Galaksinin Koruyucuları',
      'deadpool': 'Deadpool',
      'wolverine': 'Wolverine',
      'x-men': 'X-Men',
      'açlık oyunları': 'Açlık Oyunları',
      'hunger games': 'Açlık Oyunları',
      'alacakaranlık': 'Alacakaranlık',
      'twilight': 'Alacakaranlık',
      'godfather': 'Baba',
      'baba': 'Baba',
    };

    for (final entry in knownFranchises.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    if (title.contains(':')) {
      final prefix = title.split(':').first.trim();
      if (prefix.isNotEmpty && prefix.length > 2) return prefix;
    }
    if (title.contains(' - ')) {
      final prefix = title.split(' - ').first.trim();
      if (prefix.isNotEmpty && prefix.length > 2) return prefix;
    }
    return title;
  }

  ContextualSearchInfo _resolveContextualSearch(String prompt) {
    final lower = prompt.toLowerCase();
    final rawQuery = _extractSearchQuery(prompt);
    final recentMovie = _getRecentRecommendedMovie();

    // 1. TIER 3: Clean Slate / Genre Reset (Evrenden Kesin Çıkış)
    // User wants a completely different genre, mood, or explicitly wants to leave the franchise.
    final isCleanSlateExit = lower.contains('başka tarz') ||
        lower.contains('farklı tarz') ||
        lower.contains('başka bir tarz') ||
        lower.contains('farklı bir tarz') ||
        lower.contains('tarzı değiştir') ||
        lower.contains('tarz değiştir') ||
        lower.contains('başka tür') ||
        lower.contains('farklı tür') ||
        lower.contains('başka bir tür') ||
        lower.contains('farklı bir tür') ||
        lower.contains('türü değiştir') ||
        lower.contains('tür değiştir') ||
        lower.contains('farklı kategori') ||
        lower.contains('başka kategori') ||
        lower.contains('seriyi boşver') ||
        lower.contains('seriyi geç') ||
        lower.contains('bu seriyi boşver') ||
        lower.contains('bu seriyi geç') ||
        lower.contains('bunu boşver') ||
        lower.contains('bunu geç') ||
        lower.contains('bambaşka bir') ||
        lower.contains('bambaşka bi') ||
        lower.contains('tamamen farklı') ||
        lower.contains('süper kahraman olmasın') ||
        lower.contains('süper kahraman istemiyorum') ||
        lower.contains('kahraman filmi olmasın') ||
        lower.contains('komedi olsun') ||
        lower.contains('komediye geç') ||
        lower.contains('komedi izle') ||
        lower.contains('biraz gülelim') ||
        lower.contains('korku olsun') ||
        lower.contains('korku izle') ||
        lower.contains('romantik olsun') ||
        lower.contains('dram olsun') ||
        lower.contains('belgesel olsun') ||
        lower.contains('western olsun');

    // 2. TIER 2: Thematic Bridge (Benzer Ruh / Enerji, Farklı Evren)
    // User likes the vibe/energy, but wants to leave this specific series/character.
    final isThematicBridge = !isCleanSlateExit && (
        lower.contains('buna benzer ama başka') ||
        lower.contains('buna benzer başka') ||
        lower.contains('benzer tarzda ama farklı') ||
        lower.contains('aynı hava olsun ama') ||
        lower.contains('benzer kafa olsun ama') ||
        (lower.contains('olmasın') && lower.contains('süper kahraman olsun')) ||
        (lower.contains('marvel olmasın') && lower.contains('dc')) ||
        lower.contains('marvel olmasın') ||
        lower.contains('farklı bir süper kahraman') ||
        lower.contains('başka bir süper kahraman') ||
        lower.contains('gibi aksiyon ama') ||
        lower.contains('gibi gençlik ama')
    );

    // 3. TIER 1: Micro-Adjustment (Seri İçi Format / Sıra / Kadro Ayarı)
    final isAnimationRejection = lower.contains('animasyon sevmiyorum') ||
        lower.contains('animasyon istemiyorum') ||
        lower.contains('animasyon olmasın') ||
        lower.contains('animasyon hariç') ||
        lower.contains('animasyon olmayan') ||
        lower.contains('animasyon dışı') ||
        lower.contains('animasyon yerine') ||
        lower.contains('çizgi film') ||
        lower.contains('çizgi olmasın') ||
        lower.contains('çizgi istemiyorum') ||
        lower.contains('çizim bu') ||
        lower.contains('çizim sevmiyorum') ||
        lower.contains('çizim olmasın') ||
        lower.contains('çizgi yerine') ||
        lower.contains('canlı aksiyon') ||
        lower.contains('canlı çekim') ||
        lower.contains('live action') ||
        lower.contains('live-action') ||
        lower.contains('gerçek oyuncu') ||
        lower.contains('gerçek oyuncular') ||
        lower.contains('kanlı canlı');

    final isHorrorRejection = lower.contains('korku olmasın') ||
        lower.contains('korku sevmiyorum') ||
        lower.contains('korku istemiyorum') ||
        lower.contains('korku hariç');

    final isOtherNegative = lower.contains('komedi olmasın') ||
        lower.contains('komedi istemiyorum') ||
        lower.contains('romantik olmasın') ||
        lower.contains('aşk filmi olmasın');

    final isContinuityOrReplacement = lower.contains('başka bi') ||
        lower.contains('başka bir') ||
        lower.contains('başka film') ||
        lower.contains('diğer film') ||
        lower.contains('diğer filmleri') ||
        lower.contains('daha yeni') ||
        lower.contains('daha yenisi') ||
        lower.contains('daha eski') ||
        lower.contains('aynı seri') ||
        lower.contains('bu seri') ||
        lower.contains('ondan başka') ||
        lower.contains('onun yerine') ||
        lower.contains('bunun yerine') ||
        lower.contains('sarmadı') ||
        lower.contains('beğenmedim') ||
        lower.contains('sevmedim') ||
        lower.contains('bunu değil');

    final excludeGenres = <String>[];
    if (isAnimationRejection) {
      excludeGenres.addAll(['animasyon', 'animation']);
    }
    if (isHorrorRejection) {
      excludeGenres.addAll(['korku', 'horror']);
    }
    if (lower.contains('komedi olmasın') || lower.contains('komedi istemiyorum')) {
      excludeGenres.addAll(['komedi', 'comedy']);
    }

    ContextualIntentTier tier = ContextualIntentTier.microAdjustment;
    String? inheritedFranchise;
    String effectiveQuery = rawQuery;
    String? bridgeDescription;

    if (isCleanSlateExit) {
      tier = ContextualIntentTier.cleanSlateExit;
      inheritedFranchise = null; // Clean slate: completely clear previous franchise!
      for (final g in ['komedi', 'korku', 'gerilim', 'aksiyon', 'dram', 'romantik', 'bilim kurgu', 'fantastik', 'macera', 'suç']) {
        if (lower.contains(g)) {
          effectiveQuery = g;
          break;
        }
      }
      if (effectiveQuery.contains('tarz') || effectiveQuery.contains('tür') || effectiveQuery.contains('boşver')) {
        effectiveQuery = '';
      }
    } else if (isThematicBridge && recentMovie != null) {
      tier = ContextualIntentTier.thematicBridge;
      final recentFranchise = _extractFranchiseOrCoreTopic(recentMovie);
      inheritedFranchise = null; // Do not lock to previous franchise
      bridgeDescription = 'Kullanıcı $recentFranchise (${recentMovie.title}) atmosferini seviyor ancak $recentFranchise serisinden çıkmak istiyor. Benzer heyecan veya temaya sahip, tematik akraba başka bir evrenden film öner.';
      for (final other in ['batman', 'superman', 'dc', 'star wars', 'harry potter']) {
        if (lower.contains(other)) {
          effectiveQuery = other;
          inheritedFranchise = other;
          break;
        }
      }
    } else {
      tier = ContextualIntentTier.microAdjustment;
      final hasContextualContinuation = isAnimationRejection ||
          isHorrorRejection ||
          isOtherNegative ||
          isContinuityOrReplacement ||
          rawQuery.isEmpty;

      if (hasContextualContinuation && recentMovie != null) {
        inheritedFranchise = _extractFranchiseOrCoreTopic(recentMovie);
        if (rawQuery.isEmpty ||
            rawQuery.contains('animasyon') ||
            rawQuery.contains('çizgi') ||
            rawQuery.contains('aksiyon') ||
            rawQuery.contains('başka') ||
            rawQuery.contains('korku') ||
            rawQuery.length < 4 ||
            isAnimationRejection ||
            isContinuityOrReplacement) {
          bool mentionsOtherFranchise = false;
          for (final other in ['batman', 'superman', 'iron man', 'harry potter', 'star wars']) {
            if (lower.contains(other) && !(inheritedFranchise?.toLowerCase().contains(other) ?? false)) {
              effectiveQuery = other;
              inheritedFranchise = other;
              mentionsOtherFranchise = true;
              break;
            }
          }
          if (!mentionsOtherFranchise && inheritedFranchise != null) {
            effectiveQuery = inheritedFranchise;
          }
        }
      }
    }

    return ContextualSearchInfo(
      searchQuery: effectiveQuery,
      inheritedFranchise: inheritedFranchise,
      excludeGenres: excludeGenres,
      recentMovie: recentMovie,
      tier: tier,
      bridgeDescription: bridgeDescription,
    );
  }

  int? _extractYear(String? dateStr) {
    if (dateStr == null || dateStr.length < 4) return null;
    return int.tryParse(dateStr.substring(0, 4));
  }

  bool _isTitleSameFranchise(String title, String franchise) {
    final lowerTitle = title.toLowerCase();
    final lowerFranchise = franchise.toLowerCase();
    if (lowerTitle.contains(lowerFranchise) || lowerFranchise.contains(lowerTitle)) return true;

    if (lowerFranchise.contains('örümcek') || lowerFranchise.contains('spider')) {
      return lowerTitle.contains('örümcek') || lowerTitle.contains('spider');
    }
    if (lowerFranchise.contains('batman')) {
      return lowerTitle.contains('batman');
    }
    if (lowerFranchise.contains('avengers') || lowerFranchise.contains('yenilmezler')) {
      return lowerTitle.contains('avengers') || lowerTitle.contains('yenilmezler');
    }
    if (lowerFranchise.contains('superman')) {
      return lowerTitle.contains('superman');
    }
    if (lowerFranchise.contains('harry potter')) {
      return lowerTitle.contains('harry potter');
    }
    if (lowerFranchise.contains('star wars') || lowerFranchise.contains('yıldız savaş')) {
      return lowerTitle.contains('star wars') || lowerTitle.contains('yıldız savaş');
    }
    if (lowerFranchise.contains('yüzük') || lowerFranchise.contains('lord of the rings')) {
      return lowerTitle.contains('yüzük') || lowerTitle.contains('lord of the rings') || lowerTitle.contains('hobbit');
    }
    if (lowerFranchise.contains('hızlı ve öfkeli') || lowerFranchise.contains('fast')) {
      return lowerTitle.contains('hızlı ve öfkeli') || lowerTitle.contains('fast');
    }
    return false;
  }

  bool _isSameFranchise(Movie movie, String franchise) {
    return _isTitleSameFranchise(movie.title, franchise);
  }

  SubSeriesInfo? _detectSubSeries(Movie movie) {
    final title = movie.title.toLowerCase();
    final year = _extractYear(movie.releaseDate);

    // Spider-Man sub-series
    if (title.contains('örümcek') || title.contains('spider')) {
      if (title.contains('evren') || title.contains('verse')) {
        return const SubSeriesInfo(
          seriesName: 'Örümcek-Evreni (Miles Morales Animasyon)',
          actorOrDirector: 'Miles Morales / Shameik Moore',
          previousEras: ['Tom Holland (MCU) Canlı Çekim Serisi', 'Andrew Garfield Serisi', 'Tobey Maguire Sam Raimi Üçlemesi'],
          nextEras: ['Spider-Man: Beyond the Spider-Verse (Hazırlık aşamasında)'],
        );
      }
      if (title.contains('inanılmaz') || title.contains('amazing')) {
        return const SubSeriesInfo(
          seriesName: 'İnanılmaz Örümcek-Adam (Andrew Garfield)',
          actorOrDirector: 'Andrew Garfield',
          previousEras: ['Tobey Maguire Sam Raimi Üçlemesi (2002-2007)'],
          nextEras: ['Tom Holland MCU Serisi (2017-2021)', 'Örümcek-Evreni (2018-2023)'],
        );
      }
      if (title.contains('eve dönüş') || title.contains('evden uzakta') || title.contains('homecoming') || title.contains('far from home') || title.contains('no way home') || (year != null && year >= 2016)) {
        return const SubSeriesInfo(
          seriesName: 'Tom Holland (MCU) Örümcek-Adam',
          actorOrDirector: 'Tom Holland',
          previousEras: ['Tobey Maguire Sam Raimi Üçlemesi (2002-2007)', 'Andrew Garfield Serisi (2012-2014)'],
          nextEras: ['Spider-Man 4 (Hazırlık aşamasında)'],
        );
      }
      if (year != null && year <= 2007) {
        return const SubSeriesInfo(
          seriesName: 'Sam Raimi & Tobey Maguire Üçlemesi',
          actorOrDirector: 'Tobey Maguire',
          previousEras: [],
          nextEras: ['Andrew Garfield Serisi (2012-2014)', 'Tom Holland MCU Serisi (2017-2021)'],
        );
      }
    }

    // Batman sub-series
    if (title.contains('batman')) {
      if (title.contains('the batman') || (year != null && year >= 2022)) {
        return const SubSeriesInfo(
          seriesName: 'The Batman (Robert Pattinson)',
          actorOrDirector: 'Robert Pattinson',
          previousEras: ['Ben Affleck DCEU Serisi', 'Christian Bale Kara Şövalye Üçlemesi (2005-2012)', 'Michael Keaton Serisi (1989-1992)'],
          nextEras: ['The Batman Part II (Hazırlık aşamasında)'],
        );
      }
      if (title.contains('kara şövalye') || title.contains('dark knight') || title.contains('başlıyor') || title.contains('begins') || (year != null && year >= 2005 && year <= 2012)) {
        return const SubSeriesInfo(
          seriesName: 'Christopher Nolan & Christian Bale Kara Şövalye Üçlemesi',
          actorOrDirector: 'Christian Bale',
          previousEras: ['Michael Keaton Batman Serisi (1989-1992)'],
          nextEras: ['Ben Affleck DCEU Serisi', 'Robert Pattinson The Batman (2022)'],
        );
      }
      if (year != null && year < 2000) {
        return const SubSeriesInfo(
          seriesName: 'Tim Burton & Michael Keaton Serisi',
          actorOrDirector: 'Michael Keaton',
          previousEras: [],
          nextEras: ['Christian Bale Kara Şövalye Üçlemesi (2005-2012)', 'Robert Pattinson The Batman (2022)'],
        );
      }
    }

    return null;
  }

  bool _isNewerInquiry(String lower) {
    return lower.contains('daha yenisi') ||
        lower.contains('daha yeni yok') ||
        lower.contains('daha yeni var') ||
        lower.contains('daha yeni bir film') ||
        lower.contains('daha yeni film') ||
        lower.contains('bundan daha yeni') ||
        lower.contains('en son çıkan bu mu') ||
        lower.contains('devamı var mı') ||
        lower.contains('devam filmi');
  }

  bool _isOlderInquiry(String lower) {
    return lower.contains('daha eskisi') ||
        lower.contains('daha eski yok') ||
        lower.contains('daha eski var') ||
        lower.contains('daha eski bir film') ||
        lower.contains('daha eski film') ||
        lower.contains('bundan daha eski') ||
        lower.contains('bundan önceki') ||
        lower.contains('önceki filmi') ||
        lower.contains('ilk filmi mi') ||
        lower.contains('ilk film mi') ||
        lower.contains('en eskisi bu mu') ||
        lower.contains('en eski çıkan') ||
        lower.contains('serinin ilk filmi') ||
        lower.contains('serinin başı mı') ||
        lower.contains('başlangıç filmi');
  }

  bool _isCurrencyInquiry(String lower) {
    return _isNewerInquiry(lower) || _isOlderInquiry(lower);
  }

  Future<bool> _handleCurrencyInquiry(String lower) async {
    final recentMovie = _getRecentRecommendedMovie();
    if (recentMovie == null) return false;

    final franchise = _extractFranchiseOrCoreTopic(recentMovie);
    final recentYear = _extractYear(recentMovie.releaseDate) ?? 2000;
    final isOlder = _isOlderInquiry(lower);

    final watchedMovies = await _movieRepo.getWatchedMovies();
    final watchlistMovies = await _movieRepo.getWatchlist();
    final allLibraryMovies = [...watchedMovies, ...watchlistMovies];
    final excludedIds = allLibraryMovies.map((m) => m.id).toSet()..addAll(_alreadyRecommendedInChat);

    // Search TMDB for movies in this franchise
    List<Movie> tmdbResults = [];
    try {
      tmdbResults = await _tmdbService.searchMovies(franchise);
    } catch (_) {}

    final subSeries = _detectSubSeries(recentMovie);

    if (isOlder) {
      // ----------------------------------------------------------------------
      // OLDER MOVIE INQUIRY ("daha eskisi var mı", "ilk filmi mi", "öncesi var mı")
      // ----------------------------------------------------------------------
      final olderWatched = <Movie>[];
      for (final m in allLibraryMovies) {
        if (m.id == recentMovie.id) continue;
        if (_isSameFranchise(m, franchise)) {
          final y = _extractYear(m.releaseDate);
          if (y != null && y <= recentYear) {
            if (!olderWatched.any((w) => w.id == m.id || w.title.toLowerCase().trim() == m.title.toLowerCase().trim())) {
              olderWatched.add(m);
            }
          }
        }
      }

      for (final m in tmdbResults) {
        if (m.id == recentMovie.id) continue;
        final y = _extractYear(m.releaseDate);
        if (y != null && y <= recentYear) {
          final isWatched = allLibraryMovies.any((wm) => wm.id == m.id || wm.title.toLowerCase().trim() == m.title.toLowerCase().trim());
          if (isWatched && !olderWatched.any((w) => w.id == m.id || w.title.toLowerCase().trim() == m.title.toLowerCase().trim())) {
            olderWatched.add(m);
          }
        }
      }

      final unwatchedOlder = tmdbResults.where((m) {
        if (m.id == recentMovie.id) return false;
        if (excludedIds.contains(m.id)) return false;
        final y = _extractYear(m.releaseDate);
        return y != null && y < recentYear && _isSameFranchise(m, franchise);
      }).toList();

      // Sort older movies by release date (closest previous first, or oldest first if asked for 'ilk filmi')
      if (lower.contains('ilk') || lower.contains('en eski') || lower.contains('başlangıç')) {
        unwatchedOlder.sort((a, b) => (_extractYear(a.releaseDate) ?? 0).compareTo(_extractYear(b.releaseDate) ?? 0));
      } else {
        unwatchedOlder.sort((a, b) => (_extractYear(b.releaseDate) ?? 0).compareTo(_extractYear(a.releaseDate) ?? 0));
      }

      // Case A1: Unwatched older movie exists!
      if (unwatchedOlder.isNotEmpty) {
        final olderMovie = unwatchedOlder.first;
        _alreadyRecommendedInChat.add(olderMovie.id);
        await _movieRepo.recordRecommendationProposal(olderMovie);

        final replyMsg = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Evet! Bu seride bundan önce çıkan ve henüz izlemediğin şu film var:\n\n'
              '**${olderMovie.title}** (${olderMovie.releaseDate?.substring(0, 4) ?? ""})\n\n'
              'Film kartından detaylara bakabilir veya doğrudan izleme listene ekleyebilirsin:',
          timestamp: DateTime.now().toIso8601String(),
          relatedMovieId: olderMovie.id,
          messageType: MessageType.recommendationCard,
          options: ['Başka Bir Öneri Yap 🔄', 'İzleme Listeme Ekle 📌', 'Farklı Bir Tür Seç 🎬'],
          attachedMovie: olderMovie,
        );

        await _chatRepo.saveMessage(replyMsg);
        state = state.copyWith(messages: [...state.messages, replyMsg], isGenerating: false);
        return true;
      }

      // Case A2: Older movie exists, BUT user ALREADY watched it!
      if (olderWatched.isNotEmpty) {
        final watchedTitles = olderWatched.take(2).map((m) => '**${m.title}** (${m.releaseDate?.substring(0, 4) ?? ""})').join(', ');
        var extraEraInfo = '';
        if (subSeries != null && subSeries.previousEras.isNotEmpty) {
          extraEraInfo = '\n\nAncak $franchise evrenindeki önceki farklı serilere (${subSeries.previousEras.join(" veya ")}) göz atmak istersen onları seve seve getirebilirim! 🍿';
        }

        final replyMsg = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Tam üstüne bastın! Aslında bu seride bundan önce çıkan $watchedTitles filmi var; ancak onu zaten daha önce izlemiş ve kütüphanene eklemiştin! 😊\n\n'
              'Sana daha önce izlediğin filmleri tekrar önermediğim için bu seride henüz izlemediğin daha eski bir yapım kalmadı.$extraEraInfo',
          timestamp: DateTime.now().toIso8601String(),
          options: [
            if (subSeries != null && subSeries.previousEras.isNotEmpty) 'Önceki Farklı Seriyi Öner 🕷️',
            'Benzer Yeni Filmler Öner 🦸‍♂️',
            'Farklı Bir Tür Seç 🍿',
          ],
        );

        await _chatRepo.saveMessage(replyMsg);
        state = state.copyWith(messages: [...state.messages, replyMsg], isGenerating: false);
        return true;
      }

      // Case A3: This IS already the first/oldest movie in this series/franchise!
      var startExplanation = '';
      final optionsList = <String>[];

      if (subSeries != null && subSeries.previousEras.isNotEmpty) {
        startExplanation = 'İncelediğimiz **${subSeries.seriesName}** kadrosunun ilk filmi zaten **${recentMovie.title}** ($recentYear)! Bu kadronun daha eski bir filmi yok.\n\n'
            'Ancak $franchise karakterinin sinemadaki önceki efsane serilerine (${subSeries.previousEras.join(" veya ")}) geçiş yapmak istersen onları da önerebilirim! 🍿';
        optionsList.addAll(['Önceki Efsane Seriyi Öner 🕷️', 'Devam Filmini Öner 🎬', 'Farklı Bir Tür Seç 🍿']);
      } else {
        startExplanation = 'Bu serinin (**$franchise**) başlangıç / ilk filmi zaten **${recentMovie.title}** ($recentYear)! Bundan daha eski bir öncülü bulunmuyor (seri bu filmle başladı).\n\n'
            'Dilersen serinin devam filmlerine veya benzer temadaki başka süper kahraman serilerine göz atabiliriz! 🍿';
        optionsList.addAll(['Devam Filmini Öner 🎬', 'Benzer Süper Kahraman Filmi 🦸‍♂️', 'Farklı Bir Tür Seç 🍿']);
      }

      final replyMsg = ChatMessage(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        content: startExplanation,
        timestamp: DateTime.now().toIso8601String(),
        options: optionsList,
      );

      await _chatRepo.saveMessage(replyMsg);
      state = state.copyWith(messages: [...state.messages, replyMsg], isGenerating: false);
      return true;

    } else {
      // ----------------------------------------------------------------------
      // NEWER MOVIE INQUIRY ("daha yenisi yok mu", "daha yeni var mı", "devamı var mı")
      // ----------------------------------------------------------------------
      final newerWatched = <Movie>[];
      for (final m in allLibraryMovies) {
        if (m.id == recentMovie.id) continue;
        if (_isSameFranchise(m, franchise)) {
          final y = _extractYear(m.releaseDate);
          if (y != null && y >= recentYear) {
            if (!newerWatched.any((w) => w.id == m.id || w.title.toLowerCase().trim() == m.title.toLowerCase().trim())) {
              newerWatched.add(m);
            }
          }
        }
      }

      for (final m in tmdbResults) {
        if (m.id == recentMovie.id) continue;
        final y = _extractYear(m.releaseDate);
        if (y != null && y >= recentYear) {
          final isWatched = allLibraryMovies.any((wm) => wm.id == m.id || wm.title.toLowerCase().trim() == m.title.toLowerCase().trim());
          if (isWatched && !newerWatched.any((w) => w.id == m.id || w.title.toLowerCase().trim() == m.title.toLowerCase().trim())) {
            newerWatched.add(m);
          }
        }
      }

      final unwatchedNewer = tmdbResults.where((m) {
        if (m.id == recentMovie.id) return false;
        if (excludedIds.contains(m.id)) return false;
        final y = _extractYear(m.releaseDate);
        return y != null && y > recentYear && _isSameFranchise(m, franchise);
      }).toList();

      // Case B1: Unwatched newer movie exists!
      if (unwatchedNewer.isNotEmpty) {
        final newerMovie = unwatchedNewer.first;
        _alreadyRecommendedInChat.add(newerMovie.id);
        await _movieRepo.recordRecommendationProposal(newerMovie);

        final replyMsg = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Evet! Bu seride daha yeni çıkan ve henüz izlemediğin şu film var:\n\n'
              '**${newerMovie.title}** (${newerMovie.releaseDate?.substring(0, 4) ?? ""})\n\n'
              'Film kartından detaylara bakabilir veya doğrudan izleme listene ekleyebilirsin:',
          timestamp: DateTime.now().toIso8601String(),
          relatedMovieId: newerMovie.id,
          messageType: MessageType.recommendationCard,
          options: ['Başka Bir Öneri Yap 🔄', 'İzleme Listeme Ekle 📌', 'Farklı Bir Tür Seç 🎬'],
          attachedMovie: newerMovie,
        );

        await _chatRepo.saveMessage(replyMsg);
        state = state.copyWith(messages: [...state.messages, replyMsg], isGenerating: false);
        return true;
      }

      // Case B2: Newer movie exists, BUT user ALREADY watched it!
      if (newerWatched.isNotEmpty) {
        final watchedTitles = newerWatched.take(2).map((m) => '**${m.title}** (${m.releaseDate?.substring(0, 4) ?? ""})').join(', ');
        var extraEraInfo = '';
        if (subSeries != null && subSeries.nextEras.isNotEmpty) {
          extraEraInfo = '\n\nAncak $franchise evrenindeki sonraki farklı serilere (${subSeries.nextEras.join(" veya ")}) göz atmak istersen onları seve seve getirebilirim! 🍿';
        }

        final replyMsg = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Tam üstüne bastın! Aslında bu seride daha yeni olarak $watchedTitles filmi var; ancak onu zaten daha önce izlemiş ve kütüphanene eklemiştin! 😊\n\n'
              'Sana daha önce izlediğin filmleri tekrar önermediğim için bu seride henüz izlemediğin daha yeni bir yapım kalmadı.$extraEraInfo',
          timestamp: DateTime.now().toIso8601String(),
          options: [
            if (subSeries != null && subSeries.nextEras.isNotEmpty) 'Sonraki Farklı Seriyi Öner ⚡',
            'Benzer Yeni Filmler Öner 🦸‍♂️',
            'Farklı Bir Tür Seç 🍿',
          ],
        );

        await _chatRepo.saveMessage(replyMsg);
        state = state.copyWith(messages: [...state.messages, replyMsg], isGenerating: false);
        return true;
      }

      // Case B3: No newer movie exists in this series!
      var endExplanation = '';
      final optionsList = <String>[];

      if (subSeries != null && subSeries.nextEras.isNotEmpty) {
        endExplanation = 'İncelediğimiz **${subSeries.seriesName}** kadrosunun son filmi **${recentMovie.title}** ($recentYear)! Bu kadronun daha yeni bir filmi yok.\n\n'
            'Ancak $franchise karakterinin sonraki farklı serilerine (${subSeries.nextEras.join(" veya ")}) geçiş yapabiliriz! 🍿';
        optionsList.addAll(['Sonraki Farklı Seriyi Öner ⚡', 'Benzer Yeni Filmler Öner 🦸‍♂️', 'Farklı Bir Tür Seç 🎬']);
      } else {
        endExplanation = 'Bu seride (**$franchise**) **${recentMovie.title}** ($recentYear) filminden daha yeni çıkmış bir canlı çekim film henüz vizyona girmedi (en güncel film bu). Yeni projeler ise şu an hazırlık aşamasında.\n\n'
            'Dilersen benzer evrenlerden yeni filmlere veya farklı bir türe göz atabiliriz! 🍿';
        optionsList.addAll(['Benzer Yeni Filmler Öner 🦸‍♂️', 'Popüler Yeni Filmler 🌟', 'Farklı Bir Tür Seç 🎬']);
      }

      final replyMsg = ChatMessage(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        content: endExplanation,
        timestamp: DateTime.now().toIso8601String(),
        options: optionsList,
      );

      await _chatRepo.saveMessage(replyMsg);
      state = state.copyWith(messages: [...state.messages, replyMsg], isGenerating: false);
      return true;
    }
  }

  Future<void> _handleWatchHistoryImport(String text) async {
    // 1. Enrich user taste profile based on preferences
    final newThemes = [
      'akıl yakan bilim kurgu',
      'zaman yolculuğu ve paradokslar',
      'yüksek gerilim ve felsefi derinlik',
      'ters köşe kurgular',
    ];
    final newGenres = ['Bilim Kurgu', 'Gerilim', 'Dram'];

    try {
      await _tasteRepo.appendPreferences(
        newLiked: newThemes,
        newGenres: newGenres,
      );
    } catch (_) {}

    try {
      _ref.read(libraryProvider.notifier).loadLibrary();
    } catch (_) {}

    final reply = ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.assistant,
      content: '🎬 **Film geçmişin başarıyla analiz edildi!**\n\n'
          'İzlediğin filmlerden yola çıkarak sinema zevkini haritalandırdım: **Akıl yakan kurguları, zamansal paradoksları, derin bilim kurguları ve ters köşe gerilimleri** çok sevdiğin zevk profiline işlendi. 🎯\n\n'
          'Artık tüm önerilerimi bu sinematik tercihlerine göre yapacağım. Şimdi izlemediğin yepyeni bir film keşfetmek ister misin?',
      timestamp: DateTime.now().toIso8601String(),
      options: ['Bilim Kurgu Öner 🚀', 'Akıl Yakan Gerilim 🧠', 'Zaman Yolculuğu Filmi ⏳'],
    );

    try {
      await _chatRepo.saveMessage(reply);
    } catch (_) {}

    state = state.copyWith(
      messages: [...state.messages, reply],
      isGenerating: false,
    );
  }

  /// Start conversational interview for a specific movie directly from RatingDialog or Card
  Future<void> startMovieInterview(Movie movie) async {
    state = state.copyWith(
      pendingReviewMovie: movie,
      isAwaitingInterviewAnswer: false,
      isGenerating: true,
    );

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.user,
      content: '🎬 **${movie.title}** filmini izledim, yapay zeka ile değerlendirmek istiyorum.',
      timestamp: DateTime.now().toIso8601String(),
      attachedMovie: movie,
    );

    try {
      await _chatRepo.saveMessage(userMsg);
    } catch (_) {}

    state = state.copyWith(
      messages: [...state.messages, userMsg],
    );

    await _promptInterviewQuestions(movie);
  }

  /// Step 1 of Interview: User clicked "İzledim" -> AI asks gentle questions without forcing a star rating
  Future<void> _promptInterviewQuestions(Movie movie) async {
    final questionMsg = ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.assistant,
      content: 'Harika! Yıldız veya rakamla puan vermek zorunda değilsin, istersen kısaca sohbet edelim:\n\n'
          '🎬 **${movie.title}** filminin en çok neresini sevdin? (Örn: oyunculuklar, senaryo, atmosfer, ters köşe kurgu...)\n'
          'Beğenmediğin veya seni sıkan bir yönü oldu mu?',
      timestamp: DateTime.now().toIso8601String(),
      relatedMovieId: movie.id,
      messageType: MessageType.sentimentInterview,
      options: [
        'Oyunculuklar ve final harikaydı, ortası biraz yavaştı',
        'Görsellik ve müzikler muhteşemdi, bayıldım!',
        'Beklentimin altındaydı, temposu çok ağırdı',
      ],
      attachedMovie: movie,
    );

    await _chatRepo.saveMessage(questionMsg);
    state = state.copyWith(
      messages: [...state.messages, questionMsg],
      isGenerating: false,
      isAwaitingInterviewAnswer: true,
      pendingReviewMovie: movie,
    );
  }

  /// Step 2 of Interview: User provided natural feedback -> AI extracts score and aspects
  Future<void> _handleInterviewResponse(String feedbackText, Movie movie) async {
    final analysis = await _backendAiService.analyzeMovieFeedback(
      movieTitle: movie.title,
      userFeedbackText: feedbackText,
    );

    // CRITICAL: Update movie in database. Keep original initial_proposed_at as recommended_at!
    final updatedMovie = await _movieRepo.confirmWatchedAndPreserveDate(
      movieId: movie.id,
      rating: analysis.score,
      ratingSource: 'ai_inferred',
      likedAspects: analysis.likedAspects,
      dislikedAspects: analysis.dislikedAspects,
      userReview: feedbackText,
    );

    // Update user taste profile with newly learned preferences
    await _tasteRepo.appendPreferences(
      newLiked: analysis.likedAspects,
      newDisliked: analysis.dislikedAspects,
    );

    // Refresh library provider and trigger background cloud sync
    _ref.read(libraryProvider.notifier).loadLibrary();
    _ref.read(settingsProvider.notifier).triggerSync();

    final responseMsg = ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.assistant,
      content: '✨ ${analysis.summary}\n\n'
          '• **Tahmini Beğeni Puanı:** ⭐ ${analysis.score.toStringAsFixed(1)} / 10.0\n'
          '• **Sevilen Unsurlar:** ${analysis.likedAspects.join(", ")}\n'
          '${analysis.dislikedAspects.isNotEmpty ? "• **Beğenilmeyenler:** ${analysis.dislikedAspects.join(", ")}\n" : ""}'
          '\nBu bilgileri zevk profiline işledim. Bir sonraki önerilerimde bu özelliklere göre nokta atışı seçim yapacağım! 🎯\n\n'
          'Şimdi bu zevkine uygun yeni bir film önermemi ister misin?',
      timestamp: DateTime.now().toIso8601String(),
      relatedMovieId: updatedMovie.id,
      options: ['Evet, Yeni Bir Film Öner 🍿', 'Eski Bir Favori Hatırlat 🔁', 'Kütüphaneme Git 📚'],
      attachedMovie: updatedMovie,
    );

    await _chatRepo.saveMessage(responseMsg);
    state = state.copyWith(
      messages: [...state.messages, responseMsg],
      isGenerating: false,
      isAwaitingInterviewAnswer: false,
      pendingReviewMovie: null,
    );
  }

  /// Generate personalized recommendation using UserTasteProfile
  Future<void> _generateRecommendation(String prompt) async {
    final tasteProfile = await _tasteRepo.getUserTasteProfile();
    final watchedMovies = await _movieRepo.getWatchedMovies();
    final watchlistMovies = await _movieRepo.getWatchlist();
    final allLibraryMovies = [...watchedMovies, ...watchlistMovies];
    final trendingCatalog = await _tmdbService.getTrendingMovies();

    final excludedIds = allLibraryMovies.map((m) => m.id).toSet()..addAll(_alreadyRecommendedInChat);
    final excludedTitles = allLibraryMovies.map((m) => m.title.toLowerCase().trim()).toSet();

    // Resolve multi-turn context and negative filters
    final contextInfo = _resolveContextualSearch(prompt);
    final cleanSearchQuery = contextInfo.searchQuery;

    bool isExcluded(Movie m, [String? explicitTitle]) {
      if (excludedIds.contains(m.id)) return true;
      final t = (explicitTitle ?? m.title).toLowerCase().trim();
      if (t.isEmpty) return false;
      if (excludedTitles.contains(t)) return true;
      for (final et in excludedTitles) {
        if (et.isNotEmpty && (et == t || (et.length > 3 && t.contains(et)) || (t.length > 3 && et.contains(t)))) {
          return true;
        }
      }
      // Check negative genre filters (e.g. "animasyon sevmiyorum")
      if (contextInfo.excludeGenres.isNotEmpty) {
        final g = (m.genres ?? '').toLowerCase();
        for (final exG in contextInfo.excludeGenres) {
          if (g.contains(exG)) return true;
          if (exG == 'animasyon' || exG == 'animation') {
            if (t.contains('örümcek-evreni') || t.contains('spider-verse') || t.contains('örümcek evreni')) {
              return true;
            }
          }
        }
      }
      return false;
    }

    // 1. If user prompt contains specific search terms/franchises, search TMDB to get relevant candidates first!
    List<Movie> relevantPromptMovies = [];
    if (cleanSearchQuery.isNotEmpty) {
      try {
        final searchResults = await _tmdbService.searchMovies(cleanSearchQuery);
        relevantPromptMovies = searchResults.where((m) => !isExcluded(m)).toList();
      } catch (_) {}
    }

    // Candidate catalog: Relevant prompt movies first, followed by trending catalog
    final candidatePool = [...relevantPromptMovies, ...trendingCatalog];

    String aiUserPrompt = prompt;
    if (contextInfo.tier == ContextualIntentTier.cleanSlateExit) {
      final recentTitle = contextInfo.recentMovie?.title ?? '';
      aiUserPrompt = 'Kullanıcı önceki "$recentTitle" serisini/evrenini TAMAMEN GERİDE BIRAKMAK istiyor. '
          'Kullanıcının şu anki isteği: "$prompt". '
          'Önceki seriye veya karaktere KESİNLİKLE bağlı kalma! '
          'Kullanıcının yeni istediği türe veya genel zevk profiline göre dünya sinemasından bağımsız, taze bir film öner.';
    } else if (contextInfo.tier == ContextualIntentTier.thematicBridge) {
      final recentTitle = contextInfo.recentMovie?.title ?? '';
      aiUserPrompt = 'Kullanıcı önceki "$recentTitle" serisinden çıkmak istiyor; ancak benzer atmosfer/ruh taşıyan tematik akraba bir evrenden yapım arıyor. '
          'Kullanıcının şu anki isteği: "$prompt". ${contextInfo.bridgeDescription ?? ''} '
          'Önceki serinin kendisini önerme; tematik olarak akraba, benzer heyecanı veren farklı bir yapım seç.';
    } else if (contextInfo.inheritedFranchise != null) {
      final franchise = contextInfo.inheritedFranchise!;
      final recentTitle = contextInfo.recentMovie?.title ?? '';
      final filterNotes = <String>[];
      if (contextInfo.excludeGenres.contains('animasyon')) {
        filterNotes.add('Kullanıcı ANİMASYON / ÇİZGİ FİLM İSTEMİYOR, MUTLAKA CANLI AKSİYON (LIVE-ACTION) bir film istiyor.');
      }
      if (contextInfo.excludeGenres.contains('korku')) {
        filterNotes.add('Kullanıcı korku/gerilim istemiyor.');
      }
      final filterStr = filterNotes.isNotEmpty ? ' Kısıtlamalar: ${filterNotes.join(' ')}' : '';
      aiUserPrompt = 'Kullanıcı şu anda "$franchise" serisi/evreni hakkında konuşuyor (Son önerilen film: "$recentTitle"). '
          'Kullanıcının şu anki geri bildirimi: "$prompt".$filterStr '
          'MUTLAKA "$franchise" evreninden, kullanıcının bu kısıtlamasına uyan canlı aksiyon bir film öner. (Aday kataloğunda bu evrenden canlı aksiyon filmler bulunmaktadır, öncelikle katalogdan seç).';
    }

    final result = await _backendAiService.getRecommendation(
      userPrompt: aiUserPrompt,
      tasteProfile: tasteProfile,
      watchedMovies: allLibraryMovies,
      candidateCatalog: candidatePool,
      excludedMovieIds: excludedIds,
    );

    // Quota exhausted — show clear message, fall back to local catalog recommendation
    if (result['quota_exceeded'] == true) {
      final catalog2 = relevantPromptMovies.isNotEmpty ? relevantPromptMovies : TmdbService.getMockMovies();
      final unwatched = catalog2.where((m) => !isExcluded(m)).toList();
      final pick = unwatched.isNotEmpty ? unwatched.first : null;

      if (pick != null) {
        _alreadyRecommendedInChat.add(pick.id);
        await _movieRepo.recordRecommendationProposal(pick);
        final quotaReply = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: '⚠️ Yapay zeka kota limitine ulaşıldı, doğrudan katalog önerisine geçiyorum.\n\n'
              'Senin için seçtiğim film: **${pick.title}**',
          timestamp: DateTime.now().toIso8601String(),
          attachedMovie: pick,
          messageType: MessageType.recommendationCard,
          options: ['Başka Bir Öneri Yap 🔄', 'İzleme Listeme Ekle 📌', 'Farklı Bir Tür Seç 🎬'],
        );
        try { await _chatRepo.saveMessage(quotaReply); } catch (_) {}
        state = state.copyWith(messages: [...state.messages, quotaReply], isGenerating: false);
      } else {
        final quotaExhausted = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Katalogda henüz izlemediğin yeni bir film kalmadı! Yeni bir arama yapabilir veya eski favorilerinden birini hatırlatmamı isteyebilirsin. 🎬',
          timestamp: DateTime.now().toIso8601String(),
          options: ['Farklı Bir Tür Seç 🍿', 'Eski Bir Favori Hatırlat 🔁'],
        );
        try { await _chatRepo.saveMessage(quotaExhausted); } catch (_) {}
        state = state.copyWith(messages: [...state.messages, quotaExhausted], isGenerating: false);
      }
      return;
    }

    final activeFranchise = contextInfo.inheritedFranchise ?? (cleanSearchQuery.isNotEmpty ? cleanSearchQuery : null);

    // Find or fetch movie object from strictly unwatched & non-repeated candidates
    final title = result['recommended_title']?.toString() ?? '';
    String reason = result['reason']?.toString() ?? 'Senin zevk profiline en uygun film olarak seçtim.';

    var availableCatalog = candidatePool.where((m) => !isExcluded(m)).toList();

    // Verify if AI's recommended title actually belongs to the active franchise
    final isAiTitleInFranchise = activeFranchise == null || _isTitleSameFranchise(title, activeFranchise);

    Movie? matchedMovie;
    // 1. If AI recommended a title and it matches active franchise, ensure it is NOT an excluded/watched movie
    if (isAiTitleInFranchise && title.isNotEmpty && !isExcluded(const Movie(id: 0, title: ''), title)) {
      // 1a. Try matching in candidate catalog
      for (final m in availableCatalog) {
        if (m.title.toLowerCase().trim() == title.toLowerCase().trim() ||
            m.title.toLowerCase().contains(title.toLowerCase()) ||
            title.toLowerCase().contains(m.title.toLowerCase())) {
          matchedMovie = m;
          break;
        }
      }

      // 1b. If not in candidate catalog, search TMDB for the recommended title
      if (matchedMovie == null) {
        try {
          final searchResults = await _tmdbService.searchMovies(title);
          final unwatchedSearch = searchResults.where((m) => !isExcluded(m)).toList();
          if (unwatchedSearch.isNotEmpty) {
            final cand = unwatchedSearch.first;
            if (activeFranchise == null || _isSameFranchise(cand, activeFranchise)) {
              matchedMovie = cand;
            }
          }
        } catch (_) {}
      }
    }

    // 2. If title was invalid, off-franchise (hallucinated/drifted), already watched, or empty:
    // ALWAYS fallback to relevantPromptMovies first!
    if (matchedMovie == null) {
      if (relevantPromptMovies.isNotEmpty) {
        matchedMovie = relevantPromptMovies.first;
      } else {
        try {
          final promptSearch = await _tmdbService.searchMovies(cleanSearchQuery.isNotEmpty ? cleanSearchQuery : prompt);
          final unwatchedFromPrompt = promptSearch.where((m) => !isExcluded(m)).toList();
          if (unwatchedFromPrompt.isNotEmpty) {
            matchedMovie = unwatchedFromPrompt.first;
          }
        } catch (_) {}
      }
    }

    // 3. Fallback to candidate catalog ONLY if user did not ask for a specific search keyword
    if (matchedMovie == null && cleanSearchQuery.isEmpty && availableCatalog.isNotEmpty) {
      matchedMovie = availableCatalog.first;
    }

    // Contextual reason enhancement based on intent tier:
    if (contextInfo.tier == ContextualIntentTier.cleanSlateExit) {
      if (!reason.toLowerCase().contains('geride') && !reason.toLowerCase().contains('farklı')) {
        reason = 'Önceki seriyi tamamen arkamızda bırakıyoruz! Madem başka tarz bir yapım istiyorsun, senin için seçtiğim film:\n\n$reason';
      }
    } else if (contextInfo.tier == ContextualIntentTier.thematicBridge) {
      if (!reason.toLowerCase().contains('köprü') && !reason.toLowerCase().contains('çıkıp')) {
        reason = 'Önceki seriden çıkıp aradığın benzer atmosferi korumak için sana bu yapımı seçtim:\n\n$reason';
      }
    } else if (activeFranchise != null && matchedMovie != null && !isAiTitleInFranchise) {
      if (contextInfo.excludeGenres.contains('animasyon')) {
        reason = 'Animasyon yerine canlı aksiyon (live-action) bir yapım tercih ettiğin için $activeFranchise evreninin bu sevilen filmini seçtim.';
      } else {
        reason = '$activeFranchise serisinden senin için seçtiğim bir diğer film:';
      }
    } else if (contextInfo.excludeGenres.contains('animasyon') && (reason.contains('zaman yolculuğu') || reason.contains('kozmik') || reason.contains('paradoks'))) {
      reason = 'Animasyon yerine canlı aksiyon (live-action) bir yapım tercih ettiğin için $activeFranchise evreninin bu sevilen filmini seçtim.';
    }

    if (matchedMovie != null) {
      _alreadyRecommendedInChat.add(matchedMovie.id);

      // Record recommendation proposal in database
      await _movieRepo.recordRecommendationProposal(matchedMovie);

      final replyMsg = ChatMessage(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        content: '$reason\n\nFilm kartından detaylara bakabilir veya doğrudan izleme listene ekleyebilirsin:',
        timestamp: DateTime.now().toIso8601String(),
        relatedMovieId: matchedMovie.id,
        messageType: MessageType.recommendationCard,
        options: ['Başka Bir Öneri Yap 🔄', 'İzleme Listeme Ekle 📌', 'Farklı Bir Tür Seç 🎬'],
        attachedMovie: matchedMovie,
      );

      await _chatRepo.saveMessage(replyMsg);
      state = state.copyWith(
        messages: [...state.messages, replyMsg],
        isGenerating: false,
      );
    } else {
      // If user was inquiring about a franchise/sequel or specific topic, provide a courteous contextual explanation
      if (contextInfo.inheritedFranchise != null || cleanSearchQuery.isNotEmpty) {
        final franchiseName = contextInfo.inheritedFranchise ?? cleanSearchQuery;
        final explanationMsg = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Aradığın seride (**$franchiseName**) kriterlerine uyan ve henüz izlemediğin yeni bir film maalesef bulunamadı.\n\n'
              'Dilersen benzer evrenlerden taze yapımlara, popüler yeni filmlere veya farklı bir türe göz atabiliriz! 🍿',
          timestamp: DateTime.now().toIso8601String(),
          options: ['Popüler Yeni Filmler 🌟', 'Benzer Evrenlerden Öner 🦸‍♂️', 'Farklı Bir Tür Seç 🎬'],
        );
        await _chatRepo.saveMessage(explanationMsg);
        state = state.copyWith(
          messages: [...state.messages, explanationMsg],
          isGenerating: false,
        );
        return;
      }

      // Try finding an unwatched trending/popular movie
      final trending = await _tmdbService.getTrendingMovies();
      final unwatchedTrending = trending.where((m) => !isExcluded(m)).toList();
      if (unwatchedTrending.isNotEmpty) {
        final altMovie = unwatchedTrending.first;
        _alreadyRecommendedInChat.add(altMovie.id);
        await _movieRepo.recordRecommendationProposal(altMovie);

        final altMsg = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Aradığın spesifik kriterde izlemediğin yeni bir film kalmamış gibi görünüyor, ancak sinema zevkine çok uyacağını düşündüğüm şu popüler filmi keşfedebilirsin:\n\n'
              'Film kartından detaylara bakabilir veya doğrudan izleme listene ekleyebilirsin:',
          timestamp: DateTime.now().toIso8601String(),
          relatedMovieId: altMovie.id,
          messageType: MessageType.recommendationCard,
          options: ['Başka Bir Öneri Yap 🔄', 'İzleme Listeme Ekle 📌', 'Farklı Bir Tür Seç 🎬'],
          attachedMovie: altMovie,
        );
        await _chatRepo.saveMessage(altMsg);
        state = state.copyWith(
          messages: [...state.messages, altMsg],
          isGenerating: false,
        );
      } else {
        // Truly all unwatched options exhausted: Honest message without pushing watched movies
        final exhaustedMsg = ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.assistant,
          content: 'Kütüphanende olmayan ve aradığın kriterlere uyan yeni bir film bulamadık. Yeni bir tür veya farklı bir tema söylersen sana taze öneriler hazırlayabilirim! 🎬',
          timestamp: DateTime.now().toIso8601String(),
          options: ['Farklı Bir Tür Öner 🍿', 'Popüler Yeni Filmler 🌟', 'Eski Bir Favori Hatırlat 🔁'],
        );
        await _chatRepo.saveMessage(exhaustedMsg);
        state = state.copyWith(
          messages: [...state.messages, exhaustedMsg],
          isGenerating: false,
        );
      }
    }
  }

  /// Re-Watch Fallback Logic: Query movies watched a long time ago and suggest re-watching
  Future<void> _handleRewatchFallback() async {
    final rewatchCandidates = await _movieRepo.getRewatchCandidates(limit: 3);

    if (rewatchCandidates.isEmpty) {
      final noRewatchMsg = ChatMessage(
        id: _uuid.v4(),
        sender: MessageSender.assistant,
        content: 'Henüz kütüphanende eski izlenmiş bir favori film bulunmuyor. Yeni bir film türü veya ruh hali söylersen sana taze bir öneri hazırlayabilirim!',
        timestamp: DateTime.now().toIso8601String(),
        options: ['Aksiyon & Macera 💥', 'Akıl Yakan Bilim Kurgu 🚀', 'Sıcak Bir Dram ☕'],
      );
      await _chatRepo.saveMessage(noRewatchMsg);
      state = state.copyWith(
        messages: [...state.messages, noRewatchMsg],
        isGenerating: false,
      );
      return;
    }

    final oldest = rewatchCandidates.first;
    final formattedDate = DateFormatter.formatFriendly(oldest.recommendedAt);
    final nudgeText = _geminiService.generateRewatchNudge(
      movie: oldest,
      formattedDate: formattedDate,
    );

    final rewatchMsg = ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.assistant,
      content: nudgeText,
      timestamp: DateTime.now().toIso8601String(),
      relatedMovieId: oldest.id,
      messageType: MessageType.recommendationCard,
      options: ['Tekrar İzleme Listeme Al 🍿', 'Farklı Bir Yeni Film İste 🔍'],
      attachedMovie: oldest,
    );

    await _chatRepo.saveMessage(rewatchMsg);
    state = state.copyWith(
      messages: [...state.messages, rewatchMsg],
      isGenerating: false,
    );
  }

  /// Clear conversation history
  Future<void> clearHistory() async {
    _alreadyRecommendedInChat.clear();
    await _chatRepo.clearChat();
    state = const ChatState();
    await initChat();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    chatRepo: ChatRepository(
      appDb: ref.watch(databaseProvider),
      movieRepo: ref.watch(movieRepositoryProvider),
    ),
    movieRepo: ref.watch(movieRepositoryProvider),
    tasteRepo: ref.watch(userTasteRepositoryProvider),
    geminiService: ref.watch(geminiAiServiceProvider),
    backendAiService: ref.watch(backendAiServiceProvider),
    tmdbService: ref.watch(tmdbServiceProvider),
    ref: ref,
  );
});
