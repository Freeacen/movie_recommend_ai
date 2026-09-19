import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/tmdb_service.dart';
import '../../providers/tmdb_provider.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/movie_detail_modal.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tmdbState = ref.watch(tmdbProvider);
    final displayedMovies = tmdbState.displayedMovies;

    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 14, color: AppColors.textHigh),
              decoration: InputDecoration(
                hintText: 'Film adı veya oyuncu ara...',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, color: AppColors.primaryAmber),
                  onPressed: () {
                    _debounce?.cancel();
                    ref.read(tmdbProvider.notifier).search(_searchController.text);
                  },
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.clear, color: AppColors.textLow, size: 18),
                            onPressed: () {
                              _debounce?.cancel();
                              _searchController.clear();
                              ref.read(tmdbProvider.notifier).search('');
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryAmber, size: 20),
                            tooltip: 'Ara',
                            onPressed: () {
                              _debounce?.cancel();
                              ref.read(tmdbProvider.notifier).search(_searchController.text);
                            },
                          ),
                        ],
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 250), () {
                  ref.read(tmdbProvider.notifier).search(val);
                });
              },
              onSubmitted: (val) {
                _debounce?.cancel();
                ref.read(tmdbProvider.notifier).search(val);
              },
            ),
          ),

          // Genre Filter Chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: TmdbService.genreMap.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final genre = TmdbService.genreMap.values.elementAt(index);
                final isSelected = tmdbState.selectedGenre == genre;

                return FilterChip(
                  label: Text(genre),
                  selected: isSelected,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.black : AppColors.textHigh,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  backgroundColor: AppColors.surfaceElevated,
                  selectedColor: AppColors.primaryAmber,
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryAmber : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (_) {
                    ref.read(tmdbProvider.notifier).selectGenre(genre);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Main Responsive Grid
          Expanded(
            child: tmdbState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAmber))
                : displayedMovies.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: AppColors.textLow.withValues(alpha: 0.6)),
                              const SizedBox(height: 12),
                              Text(
                                tmdbState.searchQuery.isNotEmpty
                                    ? '"${tmdbState.searchQuery}" için TMDB\'de film bulunamadı.'
                                    : 'Aradığınız kriterde film bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMedium, fontSize: 14),
                              ),
                              if (tmdbState.searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    ref.read(tmdbProvider.notifier).searchWithAi(tmdbState.searchQuery);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  label: const Text(
                                    'Yapay Zeka ile Ara 🤖',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisExtent: 310,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: displayedMovies.length,
                        itemBuilder: (context, index) {
                          final movie = displayedMovies[index];
                          return MovieCard(
                            movie: movie,
                            onTap: () => MovieDetailModal.show(context, movie),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
