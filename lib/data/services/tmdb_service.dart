import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/utils/local_storage.dart';
import '../models/movie.dart';
import 'gemini_ai_service.dart';

class TmdbService {
  final http.Client _client;
  String? _apiKey;
  GeminiAiService? _geminiService;

  TmdbService({http.Client? client, String? apiKey, GeminiAiService? geminiService})
      : _client = client ?? http.Client(),
        _apiKey = apiKey,
        _geminiService = geminiService;

  void setGeminiService(GeminiAiService service) {
    _geminiService = service;
  }

  String? get apiKey {
    if (_apiKey != null && _apiKey!.trim().isNotEmpty) {
      return _apiKey;
    }
    final stored = LocalStorageHelper.getItem(LocalStorageHelper.keyTmdbApiKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored;
    }
    return ApiConstants.defaultTmdbApiKey;
  }

  set apiKey(String? value) {
    _apiKey = value;
  }

  static const Map<int, String> genreMap = {
    28: 'Aksiyon',
    12: 'Macera',
    16: 'Animasyon',
    35: 'Komedi',
    80: 'Suç',
    99: 'Belgesel',
    18: 'Dram',
    10751: 'Aile',
    14: 'Fantastik',
    36: 'Tarih',
    27: 'Korku',
    10402: 'Müzik',
    9648: 'Gizem',
    10749: 'Romantik',
    878: 'Bilim Kurgu',
    10770: 'TV Filmi',
    53: 'Gerilim',
    10752: 'Savaş',
    37: 'Vahşi Batı',
  };

  /// Fetch trending movies (Day or Week)
  Future<List<Movie>> getTrendingMovies() async {
    final key = apiKey;
    if (key == null || key.trim().isEmpty) {
      return getMockMovies();
    }

    try {
      final uri = Uri.parse('${ApiConstants.tmdbBaseUrl}/trending/movie/week?api_key=$key&language=tr-TR');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>;
        return results.map((item) => Movie.fromTmdbJson(item, genreMap: genreMap)).toList();
      } else {
        return getMockMovies();
      }
    } catch (_) {
      return getMockMovies();
    }
  }

  /// Search movies via TMDB API (fast, reliable, 0 Gemini tokens).
  Future<List<Movie>> searchMovies(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final key = apiKey;
    if (key != null && key.trim().isNotEmpty) {
      try {
        final uri = Uri.parse('${ApiConstants.tmdbBaseUrl}/search/movie?api_key=$key&query=${Uri.encodeComponent(cleanQuery)}&language=tr-TR');
        final response = await _client.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List<dynamic>;
          if (results.isNotEmpty) {
            return results.map((item) => Movie.fromTmdbJson(item, genreMap: genreMap)).toList();
          }
        }
      } catch (_) {}
    }

    // Fallback to local catalog if offline
    final mock = getMockMovies();
    final localMatches = mock.where((m) =>
        m.title.toLowerCase().contains(cleanQuery.toLowerCase()) ||
        (m.genres ?? '').toLowerCase().contains(cleanQuery.toLowerCase())).toList();
    return localMatches;
  }

  /// Dedicated method to search with Gemini AI when TMDB has no results and user explicitly requests it
  Future<List<Movie>> searchMoviesWithAi(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || _geminiService == null) return [];

    try {
      return await _geminiService!.searchMoviesWithAi(cleanQuery);
    } catch (_) {
      return [];
    }
  }

  /// Get movie details by ID
  Future<Movie?> getMovieDetails(int id) async {
    if (apiKey == null || apiKey!.trim().isEmpty) {
      final match = getMockMovies().where((m) => m.id == id);
      return match.isNotEmpty ? match.first : null;
    }

    try {
      final uri = Uri.parse('${ApiConstants.tmdbBaseUrl}/movie/$id?api_key=$apiKey&language=tr-TR');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Movie.fromTmdbJson(data, genreMap: genreMap);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// High quality mock catalog with real TMDB paths for instant out-of-the-box demo
  static List<Movie> getMockMovies() {
    return [
      const Movie(
        id: 27205,
        title: 'Inception (Başlangıç)',
        overview: 'Dom Cobb, zihnin en savunmasız olduğu rüya anında insanların bilinçaltından en derin sırları çalma konusunda uzmanlaşmış yetenekli bir hırsızdır. Cobb\'a hayatını geri kazanması için imkansız bir görev teklif edilir: fikir çalmak yerine zihne yeni bir fikir yerleştirmek. Tehlikeli bir ekiple zihnin katmanlarına daldıkça geçmişinin hayaletleriyle yüzleşmek zorunda kalır.',
        posterPath: '/edv5CZvWj09upOsy2Y6IwDhK8bt.jpg',
        backdropPath: '/s3TBrRGB1iav7gFOCNx3H31MoES.jpg',
        releaseDate: '2010-07-15',
        voteAverage: 8.4,
        genres: 'Bilim Kurgu, Aksiyon, Macera',
      ),
      const Movie(
        id: 157336,
        title: 'Interstellar (Yıldızlararası)',
        overview: 'Dünya üzerindeki yaşam kaynakları tükenirken, insanlığın hayatta kalabilmesi için bir grup kaşif solucan deliğinden geçerek uzayın derinliklerine doğru tehlikeli bir yolculuğa çıkar. Eski NASA pilotu Cooper, geride bıraktığı ailesiyle insanlığın geleceği arasında zorlu bir seçim yapmak zorundadır. Zamanın göreceli aktığı bu destansı yolculuk, sevginin ve bilimin sınırlarını sorgulatır.',
        posterPath: '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
        backdropPath: '/xJHokMbljvjADYdit5fK5VQsXEG.jpg',
        releaseDate: '2014-11-05',
        voteAverage: 8.4,
        genres: 'Macera, Dram, Bilim Kurgu',
      ),
      const Movie(
        id: 693134,
        title: 'Dune: Çöl Gezegeni Bölüm 2',
        overview: 'Paul Atreides, ailesini yok eden komploculara karşı intikam arayışındayken Chani ve Fremen halkıyla güçlerini birleştirir. Evrenin kaderini belirleyecek devasa bir savaş yaklaşırken, hayatının aşkı ile bildiği evrenin geleceği arasında bir seçim yapmak zorunda kalır. Çöl gezegeninin kadim sırları, Paul\'ü kehanetin merkezindeki liderliğe taşır.',
        posterPath: '/8b8R8l88Qje9dn9OE8PY05Nxl1X.jpg',
        backdropPath: '/xOMo8BRK7PfcJv9JCnx7s520DRq.jpg',
        releaseDate: '2024-02-27',
        voteAverage: 8.2,
        genres: 'Bilim Kurgu, Macera',
      ),
      const Movie(
        id: 872585,
        title: 'Oppenheimer',
        overview: 'J. Robert Oppenheimer\'ın İkinci Dünya Savaşı sırasında Manhattan Projesi ile ilk nükleer silahı geliştirmesini ve sonrasındaki dramatik süreçleri konu alır. Bilimin sınırlarını zorlayarak savaşı bitiren bombayı üreten fizikçi, yarattığı gücün vicdani yüküyle sarsılır. Savaş sonrası dönemde siyasi çekişmeler ve güvenlik soruşturmalarıyla yüzleşen bilim insanının çalkantılı hayatı gözler önüne serilir.',
        posterPath: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
        backdropPath: '/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg',
        releaseDate: '2023-07-19',
        voteAverage: 8.1,
        genres: 'Dram, Tarih',
      ),
      const Movie(
        id: 496243,
        title: 'Parasite (Parazit)',
        overview: 'Yoksul Kim ailesinin fertleri, zengin Park ailesinin evinde farklı işlerde çalışmak üzere kurnazca planlar yapar ve aralarında beklenmedik bir bağ kurulur. İki aile arasındaki sınıf farkı ve sırlar zamanla karanlık bir gerilime evrilir. Evin bodrumunda gizlenen sırlar açığa çıktıkça trajikomik bir hayatta kalma mücadelesi başlar.',
        posterPath: '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg',
        backdropPath: '/hiKmp9Sm99viY8W095ArVIq7zy8.jpg',
        releaseDate: '2019-05-30',
        voteAverage: 8.5,
        genres: 'Komedi, Gerilim, Dram',
      ),
      const Movie(
        id: 155,
        title: 'The Dark Knight (Kara Şövalye)',
        overview: 'Batman, Teğmen Jim Gordon ve Savcı Harvey Dent ile iş birliği yaparak Gotham sokaklarını suçtan arındırmaya çalışırken Joker isimli kaos mimarıyla yüzleşir. Joker\'in kural tanımaz anarşist planları Gotham halkını ve Batman\'in ahlaki sınırlarını sonuna kadar sınar. Adaletin simgesi olmak için neleri feda etmek gerektiğinin sarsıcı hikayesidir.',
        posterPath: '/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
        backdropPath: '/dqK9Hag1054tghRQSqLSfrkvQnA.jpg',
        releaseDate: '2008-07-16',
        voteAverage: 8.5,
        genres: 'Dram, Aksiyon, Suç, Gerilim',
      ),
      const Movie(
        id: 129,
        title: 'Spirited Away (Ruhların Kaçışı)',
        overview: 'On yaşındaki Chihiro, ailesiyle yeni bir kasabaya taşınırken kendisini tanrıların, cadıların ve ruhların hüküm sürdüğü gizemli bir dünyada bulur. Anne ve babası domuza dönüşen küçük kız, onları kurtarmak için dev bir hamamda çalışmaya başlar. Korkularıyla yüzleşen Chihiro, gerçek adını unutmadan insan dünyasına geri dönmeye çalışır.',
        posterPath: '/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg',
        backdropPath: '/mSDsSDwaP3E7dEfUPWy4J0djt4O.jpg',
        releaseDate: '2001-07-20',
        voteAverage: 8.5,
        genres: 'Animasyon, Aile, Fantastik',
      ),
      const Movie(
        id: 278,
        title: 'The Shawshank Redemption (Esaretin Bedeli)',
        overview: 'İşlemediği bir çifte cinayetten hüküm giyen bankacı Andy Dufresne, Shawshank Cezaevi\'nde geçirdiği yirmi yılı aşkın sürede umudunu asla kaybetmez. Zekası, sabrı ve gardiyanlara sunduğu finansal yardımlarla cezaevinde kendine özel bir yer edinir. Red ile kurduğu derin dostluk ve özgürlüğe duyduğu inanç, sinema tarihinin en unutulmaz kaçış hikayesine dönüşür.',
        posterPath: '/9cqNtx0Gag8bY19rSlGWKbImcq2.jpg',
        backdropPath: '/kXfqcdQKsToO0OUXHcrrNCHDBzO.jpg',
        releaseDate: '1994-09-23',
        voteAverage: 8.7,
        genres: 'Dram, Suç',
      ),
      const Movie(
        id: 329865,
        title: 'Arrival (Geliş)',
        overview: 'Dünyaya inen gizemli uzay gemileriyle iletişim kurması için görevlendirilen uzman dilbilimci Dr. Louise Banks, insanlığın kaderini ve zaman algısını değiştirecek bir keşif yapar. Küresel bir nükleer kriz eşiğindeyken uzaylı varlıkların diliyle düşünmeyi öğrenen Louise, geleceğini ve geçmişini aynı anda görmeye başlar. Zamansal algı ve dil felsefesini birleştiren duygusal bir bilim kurgu başyapıtıdır.',
        posterPath: '/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg',
        backdropPath: '/h3jYanWMEwK61qHDq8x0Yt1rWvA.jpg',
        releaseDate: '2016-11-10',
        voteAverage: 7.9,
        genres: 'Bilim Kurgu, Gizem, Dram',
      ),
      const Movie(
        id: 206487,
        title: 'Predestination (Zamanın Ötesinde)',
        overview: 'Zamanda yolculuk yaparak gelecekte işlenecek suçları önlemekle görevli bir Zamansal Ajan, kariyerinin en karmaşık ve zihin bükücü son görevine çıkar. New York\'ta binlerce kişinin ölümüne yol açan Fiyasko Bombacısı\'nı yakalamaya çalışırken geçmişin derinliklerindeki gizemli bir yabancıyla karşılaşır. Kimlik, kader ve zaman paradokslarını son ana kadar soluksuz işleyen akıl yakan bir kurgu sunar.',
        posterPath: '/sE0lF00g4UaA88o7NqK24W2rC27.jpg',
        backdropPath: '/7c93UnRwN446U17B57bBkl562pL.jpg',
        releaseDate: '2014-08-28',
        voteAverage: 7.5,
        genres: 'Bilim Kurgu, Gerilim, Gizem',
      ),
      const Movie(
        id: 335984,
        title: 'Blade Runner 2049',
        overview: 'Los Angeles Polis Departmanı memuru K, toplumdan geriye kalanı kaosa sürükleme potansiyeline sahip, uzun süredir gömülü bir sırrı açığa çıkarır. Bu keşif onu otuz yıldır kayıp olan eski polis Rick Deckard\'ı bulmaya yöneltir. İnsanlık, yapay zeka ve varoluş üzerine görsel ve işitsel bir şölen sunan derin bir distopya hikayesidir.',
        posterPath: '/gajva2L0rPYkEWjzgFlBXCAVBE5.jpg',
        backdropPath: '/ilRyASDvt7v57UyuJp0J7e6Kkrq.jpg',
        releaseDate: '2017-10-04',
        voteAverage: 8.0,
        genres: 'Bilim Kurgu, Dram, Gizem',
      ),
      const Movie(
        id: 1124,
        title: 'The Prestige (Prestij)',
        overview: '19. yüzyıl sonlarında Londra\'da iki sihirbaz arasındaki rekabet, en üstün ilüzyonu yaratma takıntısıyla tehlikeli bir savaşa dönüşür. Robert Angier ve Alfred Borden, Işınlanan Adam numarasının sırrını çözmek için bilim ve fedakarlığın sınırlarını zorlar. Takıntı, kıskançlık ve ters köşelerle dolu kurgusuyla Christopher Nolan imzalı unutulmaz bir başyapıttır.',
        posterPath: '/tRNlZbgNCNOpLpbPEz5L8G8A0JN.jpg',
        backdropPath: '/2tUNJ4zY84C6bU689W87u44p85y.jpg',
        releaseDate: '2006-10-19',
        voteAverage: 8.2,
        genres: 'Dram, Gizem, Bilim Kurgu',
      ),
      const Movie(
        id: 603,
        title: 'The Matrix',
        overview: 'Gündüzleri yazılımcı geceleri hacker olan Thomas Anderson (Neo), yaşadığı dünyanın devasa bir simülasyon olduğunu keşfeder. Morpheus ve Trinity rehberliğinde gerçek dünyaya uyanan Neo, insanlığı yapay zekaların köleliğinden kurtarmak için Seçilmiş Kişi rolünü üstlenir. Felsefe, aksiyon ve sinematik devrimi birleştiren bir başyapıttır.',
        posterPath: '/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg',
        backdropPath: '/7u3pxc0K1uhETH2EnTUtvHGapdn.jpg',
        releaseDate: '1999-03-30',
        voteAverage: 8.2,
        genres: 'Aksiyon, Bilim Kurgu',
      ),
      const Movie(
        id: 11324,
        title: 'Shutter Island (Zindan Adası)',
        overview: 'Adli tıp memuru Teddy Daniels, tehlikeli akıl hastalarının tutulduğu izole bir adadan kaçan bir katili soruşturmak üzere adaya gider. Kasvetli fırtına adayı dünyadan koparırken, Teddy hastanedeki hekimlerin ve sistemin karanlık sırlarını araştırmaya başlar. Gerçek ile delilik arasındaki çizginin giderek bulanıklaştığı şok edici bir psikolojik gerilimdir.',
        posterPath: '/kve20tXwUZpu4GUX8l6X7Z4aZ69.jpg',
        backdropPath: '/c5kF0Q34Z0a2Zk09h7Z8Z5Q6P3a.jpg',
        releaseDate: '2010-02-14',
        voteAverage: 8.2,
        genres: 'Dram, Gerilim, Gizem',
      ),
      const Movie(
        id: 220289,
        title: 'Coherence',
        overview: 'Bir kuyruklu yıldızın Dünya\'nın yakınından geçtiği gece, bir grup arkadaş akşam yemeğindeyken paralel evrenlerin kapıları aralanır. Elektriklerin kesilmesiyle birlikte yan sokakta kendilerinin tıpatıp aynı bir versiyonunun yaşadığını fark ederler. Güvensizlik ve paranoyanın tırmandığı bu mikrobütçeli başyapıt, kuantum fiziğini ustalıkla işler.',
        posterPath: '/5k33Yn4dCjV3Z35p3e4m8x9p2q0.jpg',
        backdropPath: '/6j33Yn4dCjV3Z35p3e4m8x9p2q1.jpg',
        releaseDate: '2013-09-19',
        voteAverage: 7.3,
        genres: 'Bilim Kurgu, Gizem, Gerilim',
      ),
      const Movie(
        id: 264660,
        title: 'Ex Machina',
        overview: 'Genç bir yazılımcı olan Caleb, gizemli teknoloji milyarderi Nathan\'ın izole dağ evinde geliştirdiği yapay zeka humanoid Ava\'yı Turing testine tabi tutmakla görevlendirilir. Ava ile yaptığı seanslar derinleştikçe, insanın mı makineyi yoksa makinenin mi insanı manipüle ettiği sorusu gündeme gelir. Zeka, bilinç ve insan doğası üzerine gerilim dolu bir yüzleşmedir.',
        posterPath: '/dmJW8vlVAFFRHeDAWGsrK9dfWgy.jpg',
        backdropPath: '/k2z5R5nK8m9N0p1Q2r3S4t5U6v7.jpg',
        releaseDate: '2014-12-16',
        voteAverage: 7.6,
        genres: 'Dram, Bilim Kurgu',
      ),
      const Movie(
        id: 152601,
        title: 'Her (Aşk)',
        overview: 'Yalnız bir yazar olan Theodore, tüm ihtiyaçlarına yanıt veren ve insan benzeri duygusal bir bilince sahip gelişmiş bir işletim sistemi (Samantha) ile tanışır. Zamanla aralarında derin, samimi ve sıra dışı bir aşk bağı filizlenir. Modern dünyada yabancılaşma, teknoloji ve sevginin doğasını dokunaklı bir dille sorgulayan bir başyapıttır.',
        posterPath: '/lT5CjE3h9wR8Q5y2X8x8W9x0Y1z.jpg',
        backdropPath: '/mN0p1Q2r3S4t5U6v7W8x9Y0Z1a2.jpg',
        releaseDate: '2013-12-18',
        voteAverage: 7.9,
        genres: 'Romantik, Bilim Kurgu, Dram',
      ),
      const Movie(
        id: 77,
        title: 'Memento (Akıl Defteri)',
        overview: 'Kısa süreli hafıza kaybı yaşayan Leonard Shelby, eşinin katilini bulmak için vücuduna dövmeler yaparak ve Polaroid fotoğraflarla ipuçlarını takip eder. Her 15 dakikada bir hafızası sıfırlanırken kime güvenebileceğini bilemez. Zamanın geriye doğru aktığı benzersiz kurgusuyla zihinleri zorlayan bir neo-noir gerilimdir.',
        posterPath: '/yuWyL6QjR6u64O0yBfAeVNfUvFf.jpg',
        backdropPath: '/7c93UnRwN446U17B57bBkl562pL.jpg',
        releaseDate: '2000-10-11',
        voteAverage: 8.4,
        genres: 'Gizem, Gerilim',
      ),
      const Movie(
        id: 577922,
        title: 'Tenet',
        overview: 'Üçüncü Dünya Savaşı\'nı önlemek için zamanın akışını tersine çeviren entropi teknolojisiyle uluslararası bir casusluk operasyonuna atılan İsimsiz Kahraman\'ın hikayesidir. Gelecekten gelen silahların ve tersine dönen fizik kurallarının ortasında küresel bir komployu engellemeye çalışır. Görsel efektleri ve kafa karıştıran zaman kurgusuyla yüksek tempolu bir aksiyon sunar.',
        posterPath: '/k68nPLbIST6NP96JmTxmZijEvCA.jpg',
        backdropPath: '/dqK9Hag1054tghRQSqLSfrkvQnA.jpg',
        releaseDate: '2020-08-26',
        voteAverage: 7.2,
        genres: 'Aksiyon, Bilim Kurgu, Gerilim',
      ),
      const Movie(
        id: 45612,
        title: 'Source Code (Yaşam Şifresi)',
        overview: 'Bir askeri simülasyon aracılığıyla banliyö trenindeki bir patlamadan önceki son 8 dakikayı tekrar tekrar yaşayan Yüzbaşı Colter Stevens\'ın zamana karşı yarışıdır. Bombacının kimliğini bulup ikinci bir büyük saldırıyı engellemek için her döngüde yeni ipuçları toplar. Paralel evrenler ve fedakarlık temalı sürükleyici bir bilim kurgu gerilimidir.',
        posterPath: '/tNG7zU6R1jWqB2f5a3Pq0W8t8J1.jpg',
        backdropPath: '/s3TBrRGB1iav7gFOCNx3H31MoES.jpg',
        releaseDate: '2011-03-30',
        voteAverage: 7.3,
        genres: 'Gerilim, Bilim Kurgu, Gizem',
      ),
      const Movie(
        id: 137113,
        title: 'Edge of Tomorrow (Yarının Sınırında)',
        overview: 'Uzaylı istilasına karşı savaşırken bir zaman döngüsüne hapsolan Binbaşı William Cage, her ölümünde aynı güne uyanarak hayatta kalmayı öğrenir. Efsanevi savaşçı Rita Vrataski ile iş birliği yaparak uzaylı zihnini alt etmeye çalışır. Yüksek mizahı, nefes kesen aksiyonu ve akıllı kurgusuyla türünün en başarılı örneklerindendir.',
        posterPath: '/xMwLqA1U2a8N7v2b2V3c4D5e6F7.jpg',
        backdropPath: '/xJHokMbljvjADYdit5fK5VQsXEG.jpg',
        releaseDate: '2014-05-27',
        voteAverage: 7.6,
        genres: 'Aksiyon, Bilim Kurgu',
      ),
    ];
  }
}
