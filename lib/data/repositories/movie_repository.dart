import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/local_storage.dart';
import '../../domain/enums/movie_status.dart';
import '../models/movie.dart';

class MovieRepository {
  final AppDatabase _appDb;

  // In-memory cache pre-seeded with Halil's 20 movies so it NEVER fails on Web or any platform
  static final List<Movie> _memoryMovies = [
    const Movie(
      id: 278,
      title: 'The Shawshank Redemption',
      overview: 'Andy Dufresne, haksız yere çarptırıldığı müebbet hapis cezasında umudunu ve zekasını korur.',
      posterPath: '/9cqNtx0Gag8bY19rSlGWKbImcq2.jpg',
      backdropPath: '/kXfqcdQKsToO0OUXHcrrNCHDBzO.jpg',
      releaseDate: '1994-09-23',
      voteAverage: 8.7,
      genres: 'Dram, Suç',
      status: MovieStatus.watched,
      initialProposedAt: '2025-10-29T00:00:00.000Z',
      recommendedAt: '2025-10-29T00:00:00.000Z',
      userRating: 8.5,
      ratingSource: 'manual',
      likedAspects: ['umut ve dostluk', 'efsanevi hapishane kaçışı'],
      reviewed: true,
    ),
    const Movie(
      id: 112233,
      title: 'Bring Her Back',
      overview: 'Kayıp bir yakınının ardından gerilimli bir yüzleşmeye sürüklenen ailenin hikayesi.',
      posterPath: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
      releaseDate: '2024-05-10',
      voteAverage: 6.0,
      genres: 'Korku, Gerilim',
      status: MovieStatus.watched,
      initialProposedAt: '2025-11-13T00:00:00.000Z',
      recommendedAt: '2025-11-13T00:00:00.000Z',
      userRating: 5.4,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 680,
      title: 'Pulp Fiction',
      overview: 'Los Angeles yeraltı dünyasından birbirinden ilginç karakterlerin kesişen maceraları.',
      posterPath: '/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg',
      backdropPath: '/suaEOtk1N1sgg2MTM7oZd2cfVp3.jpg',
      releaseDate: '1994-09-10',
      voteAverage: 8.5,
      genres: 'Gerilim, Suç',
      status: MovieStatus.watched,
      initialProposedAt: '2025-11-20T00:00:00.000Z',
      recommendedAt: '2025-11-20T00:00:00.000Z',
      userRating: 8.4,
      ratingSource: 'manual',
      likedAspects: ['Tarantino kurgusu', 'unutulmaz diyaloglar'],
      reviewed: true,
    ),
    const Movie(
      id: 264660,
      title: 'Ex Machina',
      overview: 'Yapay zekaya sahip Ava ile yapılan Turing testi derin psikolojik gerilime dönüşür.',
      posterPath: '/dmJW8vlVAFFRHeDAWGsrK9dfWgy.jpg',
      backdropPath: '/k2z5R5nK8m9N0p1Q2r3S4t5U6v7.jpg',
      releaseDate: '2014-12-16',
      voteAverage: 7.6,
      genres: 'Dram, Bilim Kurgu',
      status: MovieStatus.watched,
      initialProposedAt: '2025-11-25T00:00:00.000Z',
      recommendedAt: '2025-11-25T00:00:00.000Z',
      userRating: 7.2,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 105,
      title: 'Back to the Future',
      overview: 'Marty McFly, çılgın bilim insanı Doc Brown\'ın DeLorean zaman makinesiyle 1955 yılına gider.',
      posterPath: '/fNOH9f1aA7XRTzl1sAOx9iF553Q.jpg',
      backdropPath: '/533wjh6T8u7oO6J27v3G91G5jY0.jpg',
      releaseDate: '1985-07-03',
      voteAverage: 8.3,
      genres: 'Macera, Komedi, Bilim Kurgu',
      status: MovieStatus.watched,
      initialProposedAt: '2025-11-26T00:00:00.000Z',
      recommendedAt: '2025-11-26T00:00:00.000Z',
      userRating: 9.2,
      ratingSource: 'manual',
      likedAspects: ['zaman yolculuğu', 'DeLorean', 'mükemmel mizah'],
      reviewed: true,
    ),
    const Movie(
      id: 165,
      title: 'Back to the Future Part II',
      overview: 'Marty ve Doc, geleceği kurtarmak için 2015 yılına gidip zaman çizgisini korumaya çalışır.',
      posterPath: '/77587f7aA7XRTzl1sAOx9iF553Q.jpg',
      releaseDate: '1989-11-20',
      voteAverage: 7.8,
      genres: 'Macera, Komedi, Bilim Kurgu',
      status: MovieStatus.watched,
      initialProposedAt: '2025-12-01T00:00:00.000Z',
      recommendedAt: '2025-12-01T00:00:00.000Z',
      userRating: 7.8,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 196,
      title: 'Back to the Future Part III',
      overview: 'Doc Brown 1885 Vahşi Batı döneminde mahsur kalınca Marty onu kurtarmak için geçmişe gider.',
      posterPath: '/kv7587f7aA7XRTzl1sAOx9iF553Q.jpg',
      releaseDate: '1990-05-25',
      voteAverage: 7.5,
      genres: 'Macera, Komedi, Bilim Kurgu, Vahşi Batı',
      status: MovieStatus.watched,
      initialProposedAt: '2025-12-04T00:00:00.000Z',
      recommendedAt: '2025-12-04T00:00:00.000Z',
      userRating: 7.2,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 38,
      title: 'Eternal Sunshine of the Spotless Mind',
      overview: 'Birbirlerinin anılarını hafızalarından sildiren iki aşığın zihinsel ve duygusal yolculuğu.',
      posterPath: '/5MwkWH9tYHv3mV9OdYTMR5qreIz.jpg',
      backdropPath: '/7c93UnRwN446U17B57bBkl562pL.jpg',
      releaseDate: '2004-03-19',
      voteAverage: 8.1,
      genres: 'Bilim Kurgu, Dram, Romantik',
      status: MovieStatus.watched,
      initialProposedAt: '2025-11-04T00:00:00.000Z',
      recommendedAt: '2025-11-04T00:00:00.000Z',
      userRating: 8.2,
      ratingSource: 'manual',
      likedAspects: ['özgün hafıza kurgusu', 'Jim Carrey performansı'],
      reviewed: true,
    ),
    const Movie(
      id: 157336,
      title: 'Interstellar',
      overview: 'İnsanlığın geleceğini kurtarmak için solucan deliğinden geçip yeni gezegen arayan kaşifler.',
      posterPath: '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
      backdropPath: '/xJHokMbljvjADYdit5fK5VQsXEG.jpg',
      releaseDate: '2014-11-05',
      voteAverage: 8.4,
      genres: 'Macera, Dram, Bilim Kurgu',
      status: MovieStatus.watched,
      initialProposedAt: '2025-08-06T00:00:00.000Z',
      recommendedAt: '2025-08-06T00:00:00.000Z',
      userRating: 9.5,
      ratingSource: 'manual',
      likedAspects: ['Hans Zimmer müzikleri', 'kara delik fiziği', 'zamansal görelilik'],
      reviewed: true,
    ),
    const Movie(
      id: 129,
      title: 'Spirited Away',
      overview: 'Chihiro, ailesiyle yeni kasabaya taşınırken ruhların ve büyülerin dünyasına adım atar.',
      posterPath: '/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg',
      backdropPath: '/mSDsSDwaP3E7dEfUPWy4J0djt4O.jpg',
      releaseDate: '2001-07-20',
      voteAverage: 8.5,
      genres: 'Animasyon, Aile, Fantastik',
      status: MovieStatus.watched,
      initialProposedAt: '2025-08-12T00:00:00.000Z',
      recommendedAt: '2025-08-12T00:00:00.000Z',
      userRating: 7.1,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 27205,
      title: 'Inception',
      overview: 'Rüyalar içinde zihin hırsızlığı ve fikir ekme operasyonunu konu alan başyapıt.',
      posterPath: '/edv5CZvWj09upOsy2Y6IwDhK8bt.jpg',
      backdropPath: '/s3TBrRGB1iav7gFOCNx3H31MoES.jpg',
      releaseDate: '2010-07-15',
      voteAverage: 8.4,
      genres: 'Bilim Kurgu, Aksiyon, Gerilim',
      status: MovieStatus.watched,
      initialProposedAt: '2025-08-16T00:00:00.000Z',
      recommendedAt: '2025-08-16T00:00:00.000Z',
      userRating: 9.3,
      ratingSource: 'manual',
      likedAspects: ['rüya katmanları', 'zihin bükücü final', 'derin atmosfer'],
      reviewed: true,
    ),
    const Movie(
      id: 220289,
      title: 'Coherence',
      overview: 'Bir kuyruklu yıldız geçişinde paralel evrenler arasında yaşanan klostrofobik kriz.',
      posterPath: '/5k33Yn4dCjV3Z35p3e4m8x9p2q0.jpg',
      releaseDate: '2013-09-19',
      voteAverage: 7.3,
      genres: 'Bilim Kurgu, Gizem, Gerilim',
      status: MovieStatus.watched,
      initialProposedAt: '2025-07-02T00:00:00.000Z',
      recommendedAt: '2025-07-02T00:00:00.000Z',
      userRating: 7.0,
      ratingSource: 'manual',
      likedAspects: ['paralel boyutlar', 'gerilim dozu'],
      reviewed: true,
    ),
    const Movie(
      id: 43539,
      title: 'I am Number Four',
      overview: 'Gezegenleri yok edilen ve Dünya\'ya saklanan dokuz uzaylı gençten dördüncüsünün mücadelesi.',
      posterPath: '/j6sQ55zS9aRk0x8L7e3M9p2q0Z1.jpg',
      releaseDate: '2011-02-18',
      voteAverage: 6.2,
      genres: 'Aksiyon, Bilim Kurgu, Gerilim',
      status: MovieStatus.watched,
      initialProposedAt: '2025-07-09T00:00:00.000Z',
      recommendedAt: '2025-07-09T00:00:00.000Z',
      userRating: 7.2,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 116745,
      title: 'The Secret Life of Walter Mitty',
      overview: 'Sıradan bir dergi editörünün hayallerinin peşinden İzlanda ve Grönland\'a uzanan yolculuğu.',
      posterPath: '/7mK5S8f4aA7XRTzl1sAOx9iF553.jpg',
      releaseDate: '2013-12-25',
      voteAverage: 7.2,
      genres: 'Macera, Komedi, Dram',
      status: MovieStatus.watched,
      initialProposedAt: '2025-07-16T00:00:00.000Z',
      recommendedAt: '2025-07-16T00:00:00.000Z',
      userRating: 7.5,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 152601,
      title: 'Her',
      overview: 'Yapay zekalı gelişmiş bir işletim sistemiyle derin bir duygusal bağ kuran yalnız yazar.',
      posterPath: '/lT5CjE3h9wR8Q5y2X8x8W9x0Y1z.jpg',
      releaseDate: '2013-12-18',
      voteAverage: 7.9,
      genres: 'Romantik, Bilim Kurgu, Dram',
      status: MovieStatus.watched,
      initialProposedAt: '2025-07-19T00:00:00.000Z',
      recommendedAt: '2025-07-19T00:00:00.000Z',
      userRating: 7.0,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 16428,
      title: 'The Amateurs',
      overview: 'Küçük bir kasabada yaşayan bir grup arkadaşın amatör film çekme macerası.',
      releaseDate: '2005-02-06',
      voteAverage: 6.1,
      genres: 'Komedi',
      status: MovieStatus.watched,
      initialProposedAt: '2025-07-23T00:00:00.000Z',
      recommendedAt: '2025-07-23T00:00:00.000Z',
      userRating: 7.6,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 1234821,
      title: 'Sinners',
      overview: 'Karanlık sırlarla örülü bir kasabada geçen gerilim dolu korku hikayesi.',
      releaseDate: '2025-03-07',
      voteAverage: 6.5,
      genres: 'Gerilim, Korku',
      status: MovieStatus.watched,
      initialProposedAt: '2025-07-30T00:00:00.000Z',
      recommendedAt: '2025-07-30T00:00:00.000Z',
      userRating: 6.7,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 227707,
      title: 'PROJECT ALMANAC',
      overview: 'Bir grup lise öğrencisi zamanda yolculuk yapmayı keşfeder ancak her müdahale geleceği bozar.',
      releaseDate: '2015-01-29',
      voteAverage: 6.7,
      genres: 'Bilim Kurgu, Gerilim',
      status: MovieStatus.watched,
      initialProposedAt: '2025-06-11T00:00:00.000Z',
      recommendedAt: '2025-06-11T00:00:00.000Z',
      userRating: 8.7,
      ratingSource: 'manual',
      likedAspects: ['zaman makinesi prototipi', 'kelebek etkisi'],
      reviewed: true,
    ),
    const Movie(
      id: 9654,
      title: 'Italian Job',
      overview: 'Venedik\'te altın külçelerini çalan profesyonel hırsızlar çetesinin Los Angeles\'taki intikamı.',
      releaseDate: '2003-05-30',
      voteAverage: 6.8,
      genres: 'Aksiyon, Suç',
      status: MovieStatus.watched,
      initialProposedAt: '2025-06-18T00:00:00.000Z',
      recommendedAt: '2025-06-18T00:00:00.000Z',
      userRating: 7.4,
      ratingSource: 'manual',
      reviewed: true,
    ),
    const Movie(
      id: 381289,
      title: 'A Dog\'s Purpose',
      overview: 'Farklı hayatlar boyunca reenkarne olarak sahibini arayan sadık bir köpeğin dokunaklı öyküsü.',
      releaseDate: '2017-01-19',
      voteAverage: 7.6,
      genres: 'Aile, Komedi, Dram',
      status: MovieStatus.watched,
      initialProposedAt: '2025-06-25T00:00:00.000Z',
      recommendedAt: '2025-06-25T00:00:00.000Z',
      userRating: 8.0,
      ratingSource: 'manual',
      likedAspects: ['dokunaklı dostluk', 'yaşam amacı'],
      reviewed: true,
    ),
  ];

  MovieRepository({AppDatabase? appDb}) : _appDb = appDb ?? AppDatabase.instance;

  static bool _hasLoadedFromStorage = false;

  void _loadFromStorageIfNeeded() {
    if (_hasLoadedFromStorage) return;
    _hasLoadedFromStorage = true;
    try {
      final jsonStr = LocalStorageHelper.getItem(LocalStorageHelper.keyWatchedMovies);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        for (final item in list) {
          final movie = Movie.fromMap(Map<String, dynamic>.from(item));
          _memoryMovies.removeWhere((m) => m.id == movie.id);
          _memoryMovies.add(movie);
        }
      }
    } catch (_) {}
  }

  void _saveToStorage() {
    try {
      final data = _memoryMovies.map((m) => m.toMap()).toList();
      LocalStorageHelper.setItem(LocalStorageHelper.keyWatchedMovies, jsonEncode(data));
    } catch (_) {}
  }

  Future<Database?> _getSafeDb() async {
    _loadFromStorageIfNeeded();
    if (kIsWeb) return null;
    try {
      return await _appDb.database.timeout(const Duration(milliseconds: 1500));
    } catch (e) {
      debugPrint('Warning: Database access failed ($e). Using in-memory store.');
      return null;
    }
  }

  /// Insert or update movie record
  Future<void> saveMovie(Movie movie) async {
    _loadFromStorageIfNeeded();
    _memoryMovies.removeWhere((m) => m.id == movie.id);
    _memoryMovies.add(movie);
    _saveToStorage();

    try {
      final db = await _getSafeDb();
      if (db != null) {
        await db.insert(
          'movies',
          movie.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('saveMovie SQLite error (safe in memory): $e');
    }
  }

  /// Get single movie by ID
  Future<Movie?> getMovieById(int id) async {
    _loadFromStorageIfNeeded();
    try {
      final db = await _getSafeDb();
      if (db != null) {
        final results = await db.query(
          'movies',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (results.isNotEmpty) {
          return Movie.fromMap(results.first);
        }
      }
    } catch (_) {}

    final match = _memoryMovies.where((m) => m.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  /// Get all movies across all statuses (watched, watchlist, recommended)
  Future<List<Movie>> getAllMovies() async {
    _loadFromStorageIfNeeded();
    try {
      final db = await _getSafeDb();
      if (db != null) {
        final results = await db.query('movies');
        if (results.isNotEmpty) {
          return results.map((m) => Movie.fromMap(m)).toList();
        }
      }
    } catch (_) {}
    return List.unmodifiable(_memoryMovies);
  }

  /// Propose a recommendation: records temporary initial_proposed_at
  Future<void> recordRecommendationProposal(Movie movie) async {
    final existing = await getMovieById(movie.id);
    final nowIso = DateTime.now().toIso8601String();

    final updatedMovie = (existing ?? movie).copyWith(
      status: MovieStatus.recommended,
      initialProposedAt: existing?.initialProposedAt ?? nowIso,
      reviewed: false,
    );

    await saveMovie(updatedMovie);
  }

  /// Get pending unreviewed recommendations that the AI should follow up on
  Future<List<Movie>> getUnreviewedRecommendations() async {
    try {
      final db = await _getSafeDb();
      if (db != null) {
        final results = await db.query(
          'movies',
          where: "status = 'recommended' AND reviewed = 0",
          orderBy: 'initial_proposed_at DESC',
        );
        if (results.isNotEmpty) {
          return results.map((m) => Movie.fromMap(m)).toList();
        }
      }
    } catch (_) {}

    return _memoryMovies.where((m) => m.status == MovieStatus.recommended && !m.reviewed).toList();
  }

  /// Confirm movie watched & STRICTLY keep the original recommendation date as the watched date!
  Future<Movie> confirmWatchedAndPreserveDate({
    required int movieId,
    double? rating,
    String? ratingSource,
    List<String>? likedAspects,
    List<String>? dislikedAspects,
    String? userReview,
    DateTime? explicitWatchDate,
  }) async {
    final existing = await getMovieById(movieId);
    if (existing == null) {
      throw Exception('Movie with ID $movieId not found in database');
    }

    final anchorDate = explicitWatchDate != null
        ? explicitWatchDate.toUtc().toIso8601String()
        : (existing.initialProposedAt ?? existing.recommendedAt ?? DateTime.now().toIso8601String());

    final updatedMovie = existing.copyWith(
      status: MovieStatus.watched,
      recommendedAt: anchorDate,
      userRating: rating ?? existing.userRating,
      ratingSource: ratingSource ?? existing.ratingSource ?? (rating != null ? 'manual' : null),
      likedAspects: likedAspects ?? existing.likedAspects,
      dislikedAspects: dislikedAspects ?? existing.dislikedAspects,
      userReview: userReview ?? existing.userReview,
      reviewed: true,
    );

    await saveMovie(updatedMovie);
    return updatedMovie;
  }

  /// Manually update watch date (recommended_at) for an existing movie
  Future<Movie?> updateWatchDate({
    required int movieId,
    required DateTime newWatchDate,
  }) async {
    final existing = await getMovieById(movieId);
    if (existing == null) return null;

    final updated = existing.copyWith(
      recommendedAt: newWatchDate.toUtc().toIso8601String(),
    );
    await saveMovie(updated);
    return updated;
  }

  /// Update movie status (e.g. toggle watchlist)
  Future<void> updateMovieStatus(int movieId, MovieStatus newStatus) async {
    final existing = await getMovieById(movieId);
    if (existing != null) {
      await saveMovie(existing.copyWith(status: newStatus));
    }
  }

  /// Get all movies currently on the user's Watchlist
  Future<List<Movie>> getWatchlist() async {
    try {
      final db = await _getSafeDb();
      if (db != null) {
        final results = await db.query(
          'movies',
          where: "status = 'watchlist'",
          orderBy: 'id DESC',
        );
        if (results.isNotEmpty) {
          return results.map((m) => Movie.fromMap(m)).toList();
        }
      }
    } catch (_) {}

    return _memoryMovies.where((m) => m.status == MovieStatus.watchlist).toList();
  }

  /// Get all movies confirmed as Watched
  Future<List<Movie>> getWatchedMovies() async {
    try {
      final db = await _getSafeDb();
      if (db != null) {
        final results = await db.query(
          'movies',
          where: "status = 'watched'",
          orderBy: 'recommended_at DESC',
        );
        if (results.isNotEmpty) {
          return results.map((m) => Movie.fromMap(m)).toList();
        }
      }
    } catch (_) {}

    final list = _memoryMovies.where((m) => m.status == MovieStatus.watched).toList();
    list.sort((a, b) => (b.recommendedAt ?? '').compareTo(a.recommendedAt ?? ''));
    return list;
  }

  /// Query movies watched a long time ago (oldest recommended_at) for Re-Watch / Fallback recommendation
  Future<List<Movie>> getRewatchCandidates({int limit = 5}) async {
    try {
      final db = await _getSafeDb();
      if (db != null) {
        final results = await db.query(
          'movies',
          where: "status = 'watched' AND (user_rating >= 3.5 OR user_rating IS NULL)",
          orderBy: 'recommended_at ASC',
          limit: limit,
        );
        if (results.isNotEmpty) {
          return results.map((m) => Movie.fromMap(m)).toList();
        }
      }
    } catch (_) {}

    final list = _memoryMovies.where((m) => m.status == MovieStatus.watched && (m.userRating == null || m.userRating! >= 7.0)).toList();
    list.sort((a, b) => (a.recommendedAt ?? '').compareTo(b.recommendedAt ?? ''));
    return list.take(limit).toList();
  }

  /// Seed Halil's 20 watched movies with their exact dates and ratings
  Future<void> seedDemoData() async {
    try {
      final db = await _getSafeDb();
      if (db != null) {
        for (final movie in _memoryMovies) {
          await db.insert('movies', movie.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      debugPrint('seedDemoData safe memory fallback: $e');
    }
    _saveToStorage();
  }
}
