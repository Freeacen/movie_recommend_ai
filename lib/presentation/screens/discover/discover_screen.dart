import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/tmdb_service.dart';
import '../../../domain/enums/filter_enums.dart';
import '../../providers/tmdb_provider.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/movie_detail_modal.dart';
import '../../widgets/movie_filter_modal.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 350) {
      ref.read(tmdbProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tmdbState = ref.watch(tmdbProvider);
    final displayedMovies = tmdbState.displayedMovies;

    return Scaffold(
      body: Column(
        children: [
          // Search & Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(fontSize: 14, color: AppColors.textHigh),
                    decoration: InputDecoration(
                      hintText: 'Film adı veya oyuncu ara...',
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
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
                                  icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryBlue, size: 20),
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
                const SizedBox(width: 8),

                // Combined Filter & Sort Button
                _buildFilterButton(
                  activeCount: tmdbState.activeFilterCount,
                  onTap: () {
                    MovieFilterModal.showDiscoverFilters(
                      context: context,
                      currentSort: tmdbState.discoverSort,
                      currentGenre: tmdbState.selectedGenre,
                      availableGenres: TmdbService.genreMap.values.toList()..sort(),
                      currentMinRating: tmdbState.minRating,
                      currentYearRange: tmdbState.yearRange,
                      onApply: ({required sortOption, required genre, required minRating, required yearRange}) {
                        ref.read(tmdbProvider.notifier).applyFilters(
                          sortOption: sortOption,
                          genre: genre,
                          clearGenre: genre == null,
                          minRating: minRating,
                          clearMinRating: minRating == null,
                          yearRange: yearRange,
                        );
                      },
                      onReset: () {
                        ref.read(tmdbProvider.notifier).resetFilters();
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Active Filter Indicators Bar or Category Switcher Chips
          if (tmdbState.isCustomFilterActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_alt_rounded, size: 14, color: AppColors.primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          '${tmdbState.activeFilterCount} Filtre Aktif (${displayedMovies.length} film)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => ref.read(tmdbProvider.notifier).resetFilters(),
                    child: Row(
                      children: const [
                        Icon(Icons.refresh_rounded, size: 14, color: AppColors.primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          'Sıfırla',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (tmdbState.searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: DiscoverCategory.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = DiscoverCategory.values[index];
                    final isSelected = tmdbState.selectedCategory == cat && tmdbState.selectedGenre == null;

                    return ActionChip(
                      label: Text(cat.label),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.black : AppColors.textHigh,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      backgroundColor: isSelected ? AppColors.primaryAmber : AppColors.surfaceElevated,
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryAmber : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () {
                        ref.read(tmdbProvider.notifier).setCategory(cat);
                      },
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 6),

          // 3. Main Responsive Infinite Scroll Grid
          Expanded(
            child: tmdbState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
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
                                    ? '"${tmdbState.searchQuery}" için film bulunamadı.'
                                    : 'Bu kategoride henüz film bulunamadı.',
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
                    : RefreshIndicator(
                        onRefresh: () async {
                          if (tmdbState.searchQuery.isNotEmpty) {
                            await ref.read(tmdbProvider.notifier).search(tmdbState.searchQuery);
                          } else if (tmdbState.selectedGenre != null) {
                            await ref.read(tmdbProvider.notifier).selectGenre(tmdbState.selectedGenre);
                          } else {
                            await ref.read(tmdbProvider.notifier).setCategory(tmdbState.selectedCategory);
                          }
                        },
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 155,
                                  mainAxisExtent: 225,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final movie = displayedMovies[index];
                                    return MovieCard(
                                      movie: movie,
                                      onTap: () => MovieDetailModal.show(context, movie),
                                    );
                                  },
                                  childCount: displayedMovies.length,
                                ),
                              ),
                            ),
                            if (tmdbState.isLoadingMore)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryBlue,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                ),
                              )
                            else if (tmdbState.hasMore)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                                  child: Center(
                                    child: TextButton.icon(
                                      onPressed: () => ref.read(tmdbProvider.notifier).loadMore(),
                                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                                      label: const Text('Daha Fazla Film Yükle', style: TextStyle(fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.textMedium,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 100),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required int activeCount,
    required VoidCallback onTap,
  }) {
    final isActive = activeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryBlue.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primaryBlue : AppColors.border,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 19,
              color: isActive ? AppColors.primaryBlue : AppColors.textMedium,
            ),
            const SizedBox(width: 6),
            Text(
              'Filtrele',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppColors.primaryBlue : AppColors.textMedium,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
