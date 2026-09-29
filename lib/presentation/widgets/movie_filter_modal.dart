import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/enums/filter_enums.dart';
import '../providers/library_provider.dart';

class MovieFilterModal {
  /// Opens the filter modal for Discover screen
  static Future<void> showDiscoverFilters({
    required BuildContext context,
    required DiscoverSortOption currentSort,
    required String? currentGenre,
    required List<String> availableGenres,
    required double? currentMinRating,
    required YearRangeFilter currentYearRange,
    required void Function({
      required DiscoverSortOption sortOption,
      required String? genre,
      required double? minRating,
      required YearRangeFilter yearRange,
    }) onApply,
    required VoidCallback onReset,
  }) {
    return _show(
      context: context,
      title: 'Keşfet: Filtrele & Sırala',
      sortSection: _DiscoverSortSection(
        initialSort: currentSort,
        onChanged: (val) => currentSort = val,
      ),
      currentGenre: currentGenre,
      availableGenres: availableGenres,
      currentMinRating: currentMinRating,
      currentYearRange: currentYearRange,
      onApply: (genre, rating, year) {
        onApply(
          sortOption: currentSort,
          genre: genre,
          minRating: rating,
          yearRange: year,
        );
      },
      onReset: onReset,
    );
  }

  /// Opens the filter modal for Library screen
  static Future<void> showLibraryFilters({
    required BuildContext context,
    required LibrarySortOption currentSort,
    required String? currentGenre,
    required List<String> availableGenres,
    required double? currentMinRating,
    required YearRangeFilter currentYearRange,
    required void Function({
      required LibrarySortOption sortOption,
      required String? genre,
      required double? minRating,
      required YearRangeFilter yearRange,
    }) onApply,
    required VoidCallback onReset,
  }) {
    return _show(
      context: context,
      title: 'Kütüphane: Filtrele & Sırala',
      sortSection: _LibrarySortSection(
        initialSort: currentSort,
        onChanged: (val) => currentSort = val,
      ),
      currentGenre: currentGenre,
      availableGenres: availableGenres,
      currentMinRating: currentMinRating,
      currentYearRange: currentYearRange,
      onApply: (genre, rating, year) {
        onApply(
          sortOption: currentSort,
          genre: genre,
          minRating: rating,
          yearRange: year,
        );
      },
      onReset: onReset,
    );
  }

  static Future<void> _show({
    required BuildContext context,
    required String title,
    required Widget sortSection,
    required String? currentGenre,
    required List<String> availableGenres,
    required double? currentMinRating,
    required YearRangeFilter currentYearRange,
    required void Function(String? genre, double? rating, YearRangeFilter year) onApply,
    required VoidCallback onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterModalContent(
        title: title,
        sortSection: sortSection,
        initialGenre: currentGenre,
        availableGenres: availableGenres,
        initialMinRating: currentMinRating,
        initialYearRange: currentYearRange,
        onApply: onApply,
        onReset: onReset,
      ),
    );
  }
}

class _FilterModalContent extends StatefulWidget {
  final String title;
  final Widget sortSection;
  final String? initialGenre;
  final List<String> availableGenres;
  final double? initialMinRating;
  final YearRangeFilter initialYearRange;
  final void Function(String? genre, double? rating, YearRangeFilter year) onApply;
  final VoidCallback onReset;

  const _FilterModalContent({
    required this.title,
    required this.sortSection,
    required this.initialGenre,
    required this.availableGenres,
    required this.initialMinRating,
    required this.initialYearRange,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FilterModalContent> createState() => _FilterModalContentState();
}

class _FilterModalContentState extends State<_FilterModalContent> {
  late String? _selectedGenre;
  late double? _minRating;
  late YearRangeFilter _selectedYearRange;

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.initialGenre;
    _minRating = widget.initialMinRating;
    _selectedYearRange = widget.initialYearRange;
  }

  static const List<double?> _ratingOptions = [null, 6.0, 7.0, 8.0, 8.5];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.primaryBlue, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHigh,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textMedium),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Filter Sections
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Sort Section
                      _buildSectionHeader('Sıralama', Icons.swap_vert_rounded),
                      const SizedBox(height: 8),
                      widget.sortSection,

                      const SizedBox(height: 20),

                      // 2. Minimum Rating Section
                      _buildSectionHeader('Minimum Puan', Icons.star_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _ratingOptions.map((rating) {
                          final isSelected = (_minRating == rating) ||
                              (rating == null && (_minRating == null || _minRating == 0.0));
                          final label = rating == null ? 'Tümü' : '⭐ ${rating.toStringAsFixed(1)}+';
                          return _buildChoiceChip(
                            label: label,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _minRating = rating;
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // 3. Release Year Section
                      _buildSectionHeader('Çıkış Yılı / Dönem', Icons.calendar_today_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: YearRangeFilter.values.map((range) {
                          final isSelected = _selectedYearRange == range;
                          return _buildChoiceChip(
                            label: range.label,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedYearRange = range;
                              });
                            },
                          );
                        }).toList(),
                      ),

                      if (widget.availableGenres.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        // 4. Genres Section
                        _buildSectionHeader('Film Türü', Icons.local_movies_rounded),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoiceChip(
                              label: 'Tümü',
                              isSelected: _selectedGenre == null,
                              onTap: () {
                                setState(() {
                                  _selectedGenre = null;
                                });
                              },
                            ),
                            ...widget.availableGenres.map((genre) {
                              final isSelected = _selectedGenre == genre;
                              return _buildChoiceChip(
                                label: genre,
                                isSelected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _selectedGenre = isSelected ? null : genre;
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Bottom Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        widget.onReset();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Sıfırla'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMedium,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        widget.onApply(_selectedGenre, _minRating, _selectedYearRange);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Filtreleri Uygula',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryBlue),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textHigh,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textMedium,
          ),
        ),
      ),
    );
  }
}

class _DiscoverSortSection extends StatefulWidget {
  final DiscoverSortOption initialSort;
  final ValueChanged<DiscoverSortOption> onChanged;

  const _DiscoverSortSection({
    required this.initialSort,
    required this.onChanged,
  });

  @override
  State<_DiscoverSortSection> createState() => _DiscoverSortSectionState();
}

class _DiscoverSortSectionState extends State<_DiscoverSortSection> {
  late DiscoverSortOption _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSort;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DiscoverSortOption.values.map((opt) {
        final isSelected = _selected == opt;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = opt);
            widget.onChanged(opt);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBlue : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primaryBlue : AppColors.border,
              ),
            ),
            child: Text(
              opt.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textMedium,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LibrarySortSection extends StatefulWidget {
  final LibrarySortOption initialSort;
  final ValueChanged<LibrarySortOption> onChanged;

  const _LibrarySortSection({
    required this.initialSort,
    required this.onChanged,
  });

  @override
  State<_LibrarySortSection> createState() => _LibrarySortSectionState();
}

class _LibrarySortSectionState extends State<_LibrarySortSection> {
  late LibrarySortOption _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSort;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: LibrarySortOption.values.map((opt) {
        final isSelected = _selected == opt;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = opt);
            widget.onChanged(opt);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBlue : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primaryBlue : AppColors.border,
              ),
            ),
            child: Text(
              opt.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textMedium,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
