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
    final topLikedThemes = tasteProfile.likedThemes.take(3).toList();
    final topPreferredGenres = tasteProfile.preferredGenres.take(2).toList();
    final favoriteGenres = (movie.genres ?? '').split(',').map((g) => g.trim()).take(2).toList();

    // 2. Resolve matching aspects
    final matched = <String>[];
    if (targetAspects != null && targetAspects.isNotEmpty) {
      matched.addAll(targetAspects);
    } else {
      matched.addAll(topLikedThemes.isNotEmpty ? topLikedThemes : ['ters köşe kurgu', 'akıl almaz kurgu']);
    }

    // 3. Construct modular personalized hook
    String personalizedHook = '';
    if (topLikedThemes.isNotEmpty && templateHookGenre != null && templateHookGenre.isNotEmpty) {
      personalizedHook = '$templateHookGenre ve profilindeki "${topLikedThemes.first}" gibi unsurlara tutkun bir sinemasever olarak;';
    } else if (topPreferredGenres.isNotEmpty) {
      personalizedHook = 'Favorilerin arasında yer alan ${topPreferredGenres.first} sinemasına ve zihin bükücü anlatılara ilgi duyan biri olarak;';
    } else if (templateHookGenre != null && templateHookGenre.isNotEmpty) {
      personalizedHook = '$templateHookGenre;';
    } else {
      final genreStr = favoriteGenres.isNotEmpty ? favoriteGenres.join(' ve ') : 'nitelikli sinema';
      personalizedHook = '$genreStr türündeki derin hikayeleri ve akıl almaz ters köşeleri seven biri olarak;';
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
