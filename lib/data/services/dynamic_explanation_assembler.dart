import '../models/movie.dart';
import '../models/user_taste_profile.dart';

class AssembledPitch {
  final String fullReason;
  final List<String> matchingAspects;
  final String hook;
  final String coreSummary;

  const AssembledPitch({
    required this.fullReason,
    required this.matchingAspects,
    required this.hook,
    required this.coreSummary,
  });
}

/// Dynamic Explanation Assembler
/// Constructs personalized movie pitches on-device with zero network latency and zero AI tokens.
/// Seamlessly blends cloud recommendation templates (hooks + summaries) with local SQLite taste signals.
class DynamicExplanationAssembler {
  const DynamicExplanationAssembler();

  /// Assembles an engaging, human-like recommendation pitch tailored specifically
  /// to the user's local taste profile using modular template components.
  AssembledPitch assemble({
    required Movie movie,
    required UserTasteProfile tasteProfile,
    String? templateHookGenre,
    String? templateHookMood,
    String? templateCoreSummary,
    List<String>? targetAspects,
  }) {
    // 1. Extract user's strongest local taste signals
    final topLikedThemes = tasteProfile.likedThemes.take(5).toList();
    final topPreferredGenres = tasteProfile.preferredGenres.take(3).toList();
    final favoriteGenres = (movie.genres ?? '').split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).take(2).toList();

    // 2. Only consider themes that genuinely align with the movie's content/genres
    final movieGenreLower = (movie.genres ?? '').toLowerCase();
    final movieOverviewLower = (movie.overview ?? '').toLowerCase();
    final movieTitleLower = movie.title.toLowerCase();

    final matchingThemes = topLikedThemes.where((theme) {
      final t = theme.toLowerCase();
      if (movieGenreLower.contains(t) || movieOverviewLower.contains(t) || movieTitleLower.contains(t)) {
        return true;
      }
      final words = t.split(' ').where((w) => w.length > 3);
      return words.any((w) => movieGenreLower.contains(w) || movieOverviewLower.contains(w));
    }).toList();

    // 3. Resolve matching aspects
    final matched = <String>[];
    if (targetAspects != null && targetAspects.isNotEmpty) {
      matched.addAll(targetAspects);
    } else if (matchingThemes.isNotEmpty) {
      matched.addAll(matchingThemes);
    } else if (favoriteGenres.isNotEmpty) {
      matched.addAll(favoriteGenres);
    } else {
      matched.add('nitelikli sinema');
    }

    // 4. Construct modular personalized hook without hallucinating unrelated themes
    String personalizedHook = '';
    if (matchingThemes.isNotEmpty && templateHookGenre != null && templateHookGenre.isNotEmpty) {
      personalizedHook = '$templateHookGenre ve profilindeki "${matchingThemes.first}" gibi unsurlara tutkun bir sinemasever olarak;';
    } else if (matchingThemes.isNotEmpty) {
      personalizedHook = 'Profilindeki "${matchingThemes.first}" gibi unsurlara ve kaliteli sinema anlatılarına tutkun biri olarak;';
    } else if (templateHookGenre != null && templateHookGenre.isNotEmpty) {
      personalizedHook = '$templateHookGenre;';
    } else if (favoriteGenres.isNotEmpty) {
      personalizedHook = 'Favori türlerinden olan ${favoriteGenres.join(" ve ")} sinemasına ilgi duyan biri olarak;';
    } else {
      personalizedHook = 'Sinema zevkine ve kaliteli anlatılara önem veren bir izleyici olarak;';
    }

    // 4. Resolve core summary and mood accent
    final core = (templateCoreSummary != null && templateCoreSummary.isNotEmpty)
        ? templateCoreSummary
        : (movie.overview != null && movie.overview!.isNotEmpty
            ? movie.overview!
            : '${movie.title}, güçlü atmosferi ve derin karakterleriyle seni derinden etkileyecek bir yapım.');

    final moodAccent = (templateHookMood != null && templateHookMood.isNotEmpty)
        ? ' $templateHookMood "${movie.title}" tam sana göre.'
        : ' "${movie.title}" zevk profiline nokta atışı uyacak.';

    // 5. Assemble final pitch
    final fullReason = '$personalizedHook $core$moodAccent';

    return AssembledPitch(
      fullReason: fullReason,
      matchingAspects: matched,
      hook: personalizedHook,
      coreSummary: core,
    );
  }
}
