import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/movie.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import 'movie_review_modal.dart';

class RatingDialog extends ConsumerStatefulWidget {
  final Movie movie;

  const RatingDialog({super.key, required this.movie});

  static Future<void> show(BuildContext context, Movie movie) {
    return showDialog(
      context: context,
      builder: (context) => RatingDialog(movie: movie),
    );
  }

  @override
  ConsumerState<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<RatingDialog> {
  double _rating = 7.5;
  late DateTime _selectedWatchDate;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.movie.userRating != null) {
      _rating = widget.movie.userRating!;
    } else if (widget.movie.voteAverage != null && widget.movie.voteAverage! > 0) {
      _rating = widget.movie.voteAverage!;
    }
    if (widget.movie.userReview != null) {
      _reviewController.text = widget.movie.userReview!;
    }
    _selectedWatchDate = widget.movie.recommendedAt != null
        ? (DateTime.tryParse(widget.movie.recommendedAt!) ?? DateTime.now())
        : DateTime.now();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filmi Değerlendir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh),
          ),
          const SizedBox(height: 4),
          Text(
            widget.movie.title,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),

            // Score Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 28, color: AppColors.primaryAmber),
                  const SizedBox(width: 8),
                  Text(
                    '${_rating.toStringAsFixed(1)} / 10.0',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryAmber,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 1.0 - 10.0 Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primaryAmber,
                inactiveTrackColor: AppColors.surfaceElevated,
                thumbColor: AppColors.primaryAmber,
                overlayColor: AppColors.primaryAmber.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _rating.clamp(0.0, 10.0),
                min: 0.0,
                max: 10.0,
                divisions: 100, // 0.1 increments
                onChanged: (val) {
                  setState(() {
                    _rating = (val * 10).roundToDouble() / 10.0;
                  });
                },
              ),
            ),

            // Rating quick chips
            Wrap(
              spacing: 6,
              children: [6.0, 7.0, 7.5, 8.0, 8.5, 9.0, 10.0].map((score) {
                final isSelected = (_rating - score).abs() < 0.1;
                return ChoiceChip(
                  label: Text('${score.toStringAsFixed(1)} ⭐'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.black : AppColors.textHigh,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryAmber,
                  backgroundColor: AppColors.surfaceElevated,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _rating = score;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 18),

            // Conversational Evaluation CTA Button (Opens dedicated modal pop-up)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryIndigo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryIndigo.withValues(alpha: 0.35)),
              ),
              child: Column(
                children: [
                  Text(
                    'Puan vermek yerine yapay zeka ile film hakkında detaylı sohbet etmek ister misin?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textAccentBlue),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Directly open the dedicated MovieReviewModal pop-up
                      MovieReviewModal.show(context, widget.movie);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.forum_outlined, size: 16),
                    label: const Text(
                      'Sohbetle Değerlendir 🤖',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Optional text review
            TextField(
              controller: _reviewController,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: AppColors.textHigh),
              decoration: const InputDecoration(
                hintText: 'Kısaca düşüncelerini yazabilirsin (isteğe bağlı)...',
              ),
            ),

            const SizedBox(height: 12),

            // Watch Date Selection Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryAmber),
                  const SizedBox(width: 8),
                  Text('İzlenme Tarihi:', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedWatchDate,
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        helpText: 'İzlenme Tarihini Seçin',
                        cancelText: 'Vazgeç',
                        confirmText: 'Seç',
                        builder: (ctx, child) {
                          return Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: ColorScheme(
                                brightness: Theme.of(ctx).brightness,
                                primary: AppColors.primaryAmber,
                                onPrimary: Colors.white,
                                secondary: AppColors.primaryBlue,
                                onSecondary: Colors.white,
                                surface: AppColors.surface,
                                onSurface: AppColors.textHigh,
                                error: AppColors.accentRose,
                                onError: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedWatchDate = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.edit_calendar_rounded, size: 14, color: AppColors.primaryAmber),
                    label: Text(
                      DateFormatter.formatFriendly(_selectedWatchDate.toIso8601String()),
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryAmber, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Vazgeç', style: TextStyle(color: AppColors.textLow)),
        ),
        ElevatedButton(
          onPressed: () async {
            await ref.read(libraryProvider.notifier).markAsWatched(
              movie: widget.movie,
              rating: _rating,
              review: _reviewController.text.trim().isNotEmpty ? _reviewController.text.trim() : null,
              watchDate: _selectedWatchDate,
            );
            ref.read(settingsProvider.notifier).triggerSync();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
