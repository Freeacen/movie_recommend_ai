import 'dart:convert';
import '../../core/constants/api_constants.dart';
import '../../domain/enums/movie_status.dart';

class Movie {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double? voteAverage;
  final String? genres; // comma separated genres e.g. "Sci-Fi, Thriller"
  final MovieStatus status;
  final String? initialProposedAt; // temporary proposal timestamp
  final String? recommendedAt; // permanent watch/recommendation anchor timestamp
  final double? userRating;
  final String? ratingSource; // 'manual' or 'ai_inferred'
  final List<String> likedAspects;
  final List<String> dislikedAspects;
  final String? userReview;
  final bool reviewed;

  const Movie({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage,
    this.genres,
    this.status = MovieStatus.none,
    this.initialProposedAt,
    this.recommendedAt,
    this.userRating,
    this.ratingSource,
    this.likedAspects = const [],
    this.dislikedAspects = const [],
    this.userReview,
    this.reviewed = false,
  });

  String get posterUrl {
    if (posterPath == null || posterPath!.isEmpty) {
      return '';
    }
    if (posterPath!.startsWith('http')) {
      return posterPath!;
    }
    return '${ApiConstants.tmdbImageBaseUrlW500}$posterPath';
  }

  String get backdropUrl {
    if (backdropPath == null || backdropPath!.isEmpty) {
      return '';
    }
    if (backdropPath!.startsWith('http')) {
      return backdropPath!;
    }
    return '${ApiConstants.tmdbImageBaseUrlOriginal}$backdropPath';
  }

  String get releaseYear {
    if (releaseDate == null || releaseDate!.isEmpty) {
      return '';
    }
    return releaseDate!.split('-').first;
  }

  Movie copyWith({
    int? id,
    String? title,
    String? overview,
    String? posterPath,
    String? backdropPath,
    String? releaseDate,
    double? voteAverage,
    String? genres,
    MovieStatus? status,
    String? initialProposedAt,
    String? recommendedAt,
    double? userRating,
    String? ratingSource,
    List<String>? likedAspects,
    List<String>? dislikedAspects,
    String? userReview,
    bool? reviewed,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      voteAverage: voteAverage ?? this.voteAverage,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      initialProposedAt: initialProposedAt ?? this.initialProposedAt,
      recommendedAt: recommendedAt ?? this.recommendedAt,
      userRating: userRating ?? this.userRating,
      ratingSource: ratingSource ?? this.ratingSource,
      likedAspects: likedAspects ?? this.likedAspects,
      dislikedAspects: dislikedAspects ?? this.dislikedAspects,
      userReview: userReview ?? this.userReview,
      reviewed: reviewed ?? this.reviewed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'release_date': releaseDate,
      'vote_average': voteAverage,
      'genres': genres,
      'status': status.toDbString(),
      'initial_proposed_at': initialProposedAt,
      'recommended_at': recommendedAt,
      'user_rating': userRating,
      'rating_source': ratingSource,
      'liked_aspects': jsonEncode(likedAspects),
      'disliked_aspects': jsonEncode(dislikedAspects),
      'user_review': userReview,
      'reviewed': reviewed ? 1 : 0,
    };
  }

  factory Movie.fromMap(Map<String, dynamic> map) {
    List<String> parseJsonList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(value.toString());
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
      return [];
    }

    return Movie(
      id: map['id'] as int,
      title: map['title'] as String,
      overview: map['overview'] as String?,
      posterPath: map['poster_path'] as String?,
      backdropPath: map['backdrop_path'] as String?,
      releaseDate: map['release_date'] as String?,
      voteAverage: (map['vote_average'] as num?)?.toDouble(),
      genres: map['genres'] as String?,
      status: MovieStatus.fromDbString(map['status'] as String?),
      initialProposedAt: map['initial_proposed_at'] as String?,
      recommendedAt: map['recommended_at'] as String?,
      userRating: (map['user_rating'] as num?)?.toDouble(),
      ratingSource: map['rating_source'] as String?,
      likedAspects: parseJsonList(map['liked_aspects']),
      dislikedAspects: parseJsonList(map['disliked_aspects']),
      userReview: map['user_review'] as String?,
      reviewed: (map['reviewed'] as int? ?? 0) == 1,
    );
  }

  factory Movie.fromTmdbJson(Map<String, dynamic> json, {Map<int, String>? genreMap}) {
    String? genreString;
    if (json['genres'] is List) {
      genreString = (json['genres'] as List)
          .map((g) => g['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join(', ');
    } else if (json['genre_ids'] is List && genreMap != null) {
      genreString = (json['genre_ids'] as List)
          .map((id) => genreMap[id] ?? '')
          .where((s) => s.isNotEmpty)
          .join(', ');
    }

    return Movie(
      id: json['id'] as int,
      title: json['title'] as String? ?? json['name'] as String? ?? 'Untitled',
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: json['release_date'] as String? ?? json['first_air_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      genres: genreString,
      status: MovieStatus.none,
    );
  }
}
