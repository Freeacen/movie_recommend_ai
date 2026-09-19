import 'dart:convert';

class UserTasteProfile {
  final int id;
  final List<String> likedThemes;
  final List<String> dislikedThemes;
  final List<String> preferredGenres;
  final String lastUpdated;

  const UserTasteProfile({
    this.id = 1,
    this.likedThemes = const [],
    this.dislikedThemes = const [],
    this.preferredGenres = const [],
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'liked_themes': jsonEncode(likedThemes),
      'disliked_themes': jsonEncode(dislikedThemes),
      'preferred_genres': jsonEncode(preferredGenres),
      'last_updated': lastUpdated,
    };
  }

  factory UserTasteProfile.fromMap(Map<String, dynamic> map) {
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

    return UserTasteProfile(
      id: map['id'] as int? ?? 1,
      likedThemes: parseJsonList(map['liked_themes']),
      dislikedThemes: parseJsonList(map['disliked_themes']),
      preferredGenres: parseJsonList(map['preferred_genres']),
      lastUpdated: map['last_updated'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  UserTasteProfile copyWith({
    int? id,
    List<String>? likedThemes,
    List<String>? dislikedThemes,
    List<String>? preferredGenres,
    String? lastUpdated,
  }) {
    return UserTasteProfile(
      id: id ?? this.id,
      likedThemes: likedThemes ?? this.likedThemes,
      dislikedThemes: dislikedThemes ?? this.dislikedThemes,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  String toContextPrompt() {
    final buffer = StringBuffer();
    if (likedThemes.isNotEmpty) {
      buffer.writeln('- Kullanıcının çok sevdiği unsurlar: ${likedThemes.join(', ')}');
    }
    if (dislikedThemes.isNotEmpty) {
      buffer.writeln('- Kullanıcının sevmediği / sıkıldığı unsurlar: ${dislikedThemes.join(', ')}');
    }
    if (preferredGenres.isNotEmpty) {
      buffer.writeln('- Favori türleri: ${preferredGenres.join(', ')}');
    }
    return buffer.toString().trim();
  }
}
