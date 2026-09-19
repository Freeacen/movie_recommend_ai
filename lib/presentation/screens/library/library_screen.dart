import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/movie.dart';
import '../../providers/library_provider.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/movie_detail_modal.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final selectedTab = libraryState.selectedTabIndex;

    List<Movie> currentList;
    String emptyMessage;
    IconData emptyIcon;

    switch (selectedTab) {
      case 0:
        currentList = libraryState.watchlist;
        emptyMessage = 'İzleme listen henüz boş.\nKeşfet sekmesinden veya AI sohbetinden film ekleyebilirsin.';
        emptyIcon = Icons.bookmark_border_rounded;
        break;
      case 1:
        currentList = libraryState.watched;
        emptyMessage = 'Henüz izlendi olarak işaretlenen film yok.\nFilmleri izledikçe buraya eklenecek.';
        emptyIcon = Icons.check_circle_outline_rounded;
        break;
      case 2:
      default:
        currentList = libraryState.rewatchCandidates;
        emptyMessage = 'Henüz tekrar izleme adayı eski favori bulunmuyor.\nİzlediğin filmler zamanla buraya nostalji adayı olarak gelecek.';
        emptyIcon = Icons.history_rounded;
        break;
    }

    return Scaffold(
      body: Column(
        children: [
          // Taste Profile Insight Banner
          if (libraryState.tasteProfile != null &&
              libraryState.tasteProfile!.likedThemes.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryIndigo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryIndigo.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: AppColors.primaryIndigo, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yapay Zeka Zevk Profilin:',
                          style: TextStyle(fontSize: 11, color: AppColors.textAccentBlue, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sevdiğin Unsurlar: ${libraryState.tasteProfile!.likedThemes.take(3).join(", ")}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppColors.textHigh),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Segmented Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    context: context,
                    label: 'İzleme Listesi (${libraryState.watchlist.length})',
                    isSelected: selectedTab == 0,
                    onTap: () => ref.read(libraryProvider.notifier).setTab(0),
                  ),
                  _buildTabButton(
                    context: context,
                    label: 'İzlenenler (${libraryState.watched.length})',
                    isSelected: selectedTab == 1,
                    onTap: () => ref.read(libraryProvider.notifier).setTab(1),
                  ),
                  _buildTabButton(
                    context: context,
                    label: 'Tekrar İzle (${libraryState.rewatchCandidates.length})',
                    isSelected: selectedTab == 2,
                    onTap: () => ref.read(libraryProvider.notifier).setTab(2),
                  ),
                ],
              ),
            ),
          ),

          // Main Grid Content
          Expanded(
            child: libraryState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAmber))
                : currentList.isEmpty
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
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisExtent: 310,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
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
    required BuildContext context,
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
            color: isSelected ? AppColors.primaryAmber : Colors.transparent,
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
