import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/movie.dart';
import '../../../domain/enums/filter_enums.dart';
import '../../providers/library_provider.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/movie_detail_modal.dart';
import '../../widgets/movie_filter_modal.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final selectedTab = libraryState.selectedTabIndex;

    List<Movie> rawList;
    String emptyMessage;
    IconData emptyIcon;

    switch (selectedTab) {
      case 0:
        rawList = libraryState.watchlist;
        emptyMessage = 'İzleme listen henüz boş.\nKeşfet sekmesinden veya AI sohbetinden film ekleyebilirsin.';
        emptyIcon = Icons.bookmark_border_rounded;
        break;
      case 1:
        rawList = libraryState.watched;
        emptyMessage = 'Henüz izlendi olarak işaretlenen film yok.\nFilmleri izledikçe buraya eklenecek.';
        emptyIcon = Icons.check_circle_outline_rounded;
        break;
      case 2:
      default:
        rawList = libraryState.rewatchCandidates;
        emptyMessage = 'Henüz tekrar izleme adayı eski favori bulunmuyor.\nİzlediğin filmler zamanla buraya nostalji adayı olarak gelecek.';
        emptyIcon = Icons.history_rounded;
        break;
    }

    // Extract dynamic genres from the current tab's movies
    final Set<String> distinctGenres = {};
    for (final m in rawList) {
      if (m.genres != null && m.genres!.isNotEmpty) {
        for (final g in m.genres!.split(',')) {
          final trimmed = g.trim();
          if (trimmed.isNotEmpty) {
            distinctGenres.add(trimmed);
          }
        }
      }
    }
    final sortedGenres = distinctGenres.toList()..sort();

    // Filter and sort the list
    final currentList = libraryState.filterAndSort(rawList);
    final isFiltered = libraryState.searchQuery.trim().isNotEmpty ||
        libraryState.selectedGenre != null ||
        libraryState.sortOption != LibrarySortOption.recent;

    return Scaffold(
      body: Column(
        children: [
          // Segmented Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _buildTabButton(
                    label: 'İzleme Listesi (${libraryState.watchlist.length})',
                    isSelected: selectedTab == 0,
                    onTap: () => ref.read(libraryProvider.notifier).setTab(0),
                  ),
                  _buildTabButton(
                    label: 'İzlenenler (${libraryState.watched.length})',
                    isSelected: selectedTab == 1,
                    onTap: () => ref.read(libraryProvider.notifier).setTab(1),
                  ),
                  _buildTabButton(
                    label: 'Tekrar İzle (${libraryState.rewatchCandidates.length})',
                    isSelected: selectedTab == 2,
                    onTap: () => ref.read(libraryProvider.notifier).setTab(2),
                  ),
                ],
              ),
            ),
          ),

          // Search and Sort Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13, color: AppColors.textHigh),
                      decoration: InputDecoration(
                        hintText: 'Kütüphanende ara...',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textLow),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textMedium),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMedium),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(libraryProvider.notifier).setSearchQuery('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (val) {
                        setState(() {});
                        ref.read(libraryProvider.notifier).setSearchQuery(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Combined Filter & Sort Button
                GestureDetector(
                  onTap: () {
                    MovieFilterModal.showLibraryFilters(
                      context: context,
                      currentSort: libraryState.sortOption,
                      currentGenre: libraryState.selectedGenre,
                      availableGenres: sortedGenres,
                      currentMinRating: libraryState.minRating,
                      currentYearRange: libraryState.yearRange,
                      onApply: ({required sortOption, required genre, required minRating, required yearRange}) {
                        ref.read(libraryProvider.notifier).applyFilters(
                          sortOption: sortOption,
                          genre: genre,
                          clearGenre: genre == null,
                          minRating: minRating,
                          clearMinRating: minRating == null,
                          yearRange: yearRange,
                        );
                      },
                      onReset: () {
                        _searchController.clear();
                        ref.read(libraryProvider.notifier).clearFilters();
                      },
                    );
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: libraryState.activeFilterCount > 0
                          ? AppColors.primaryBlue.withValues(alpha: 0.15)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: libraryState.activeFilterCount > 0
                            ? AppColors.primaryBlue
                            : AppColors.border,
                        width: libraryState.activeFilterCount > 0 ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: libraryState.activeFilterCount > 0
                              ? AppColors.primaryBlue
                              : AppColors.textMedium,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filtrele',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: libraryState.activeFilterCount > 0 ? FontWeight.bold : FontWeight.w600,
                            color: libraryState.activeFilterCount > 0
                                ? AppColors.primaryBlue
                                : AppColors.textMedium,
                          ),
                        ),
                        if (libraryState.activeFilterCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${libraryState.activeFilterCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Filter Info & Reset Button
          if (isFiltered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  Text(
                    '${currentList.length} film bulundu',
                    style: TextStyle(fontSize: 12, color: AppColors.textMedium, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      ref.read(libraryProvider.notifier).clearFilters();
                    },
                    child: Row(
                      children: const [
                        Icon(Icons.refresh_rounded, size: 14, color: AppColors.primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          'Filtreleri Temizle',
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
            ),

          const SizedBox(height: 4),

          // Main Grid Content
          Expanded(
            child: libraryState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                : rawList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(emptyIcon, size: 48, color: AppColors.textLow.withValues(alpha: 0.6)),
                              const SizedBox(height: 12),
                              Text(
                                emptyMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      )
                    : currentList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.filter_list_off_rounded, size: 48, color: AppColors.textLow.withValues(alpha: 0.6)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Seçtiğin arama veya filtrelere uygun film bulunamadı.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.5),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(libraryProvider.notifier).clearFilters();
                                    },
                                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                                    label: const Text('Filtreleri Temizle'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryBlue,
                                      side: const BorderSide(color: AppColors.primaryBlue),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 155,
                              mainAxisExtent: 225,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: currentList.length,
                            itemBuilder: (context, index) {
                              final movie = currentList[index];
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

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textMedium,
            ),
          ),
        ),
      ),
    );
  }
}
