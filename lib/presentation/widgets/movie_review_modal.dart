import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/movie.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';

class MovieReviewModal extends ConsumerStatefulWidget {
  final Movie movie;

  const MovieReviewModal({super.key, required this.movie});

  /// Show the dedicated review modal as a responsive dialog on desktop/web or bottom sheet on mobile
  static Future<void> show(BuildContext context, Movie movie) {
    final isWide = MediaQuery.of(context).size.width > 650;
    if (isWide) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: MovieReviewModal(movie: movie),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: MovieReviewModal(movie: movie),
        ),
      );
    }
  }

  @override
  ConsumerState<MovieReviewModal> createState() => _MovieReviewModalState();
}

class _MovieReviewModalState extends ConsumerState<MovieReviewModal> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late double _currentScore;
  final List<String> _likedAspects = [];
  final List<String> _dislikedAspects = [];
  String _summary = '';
  bool _isLoading = false;

  final List<String> _quickSuggestions = [
    'Oyunculuklar şahaneydi 👏',
    'Ters köşe kurgusu harikaydı 🤯',
    'Ortası biraz ağırdı ⏳',
    'Bence puanı 7.5 olmalı ⭐',
    'Görsellik ve müzikler büyüleyiciydi 🎶',
  ];

  @override
  void initState() {
    super.initState();
    final vote = widget.movie.voteAverage;
    _currentScore = widget.movie.userRating ?? 
        ((vote != null && vote > 0) ? vote : 7.5);

    if (widget.movie.likedAspects.isNotEmpty) {
      _likedAspects.addAll(widget.movie.likedAspects);
    }
    if (widget.movie.dislikedAspects.isNotEmpty) {
      _dislikedAspects.addAll(widget.movie.dislikedAspects);
    }

    // Initial warm greeting from CineAI critic
    _messages.add({
      'role': 'assistant',
      'content': '🎬 **${widget.movie.title}** filmini izlemişsin! Harika bir seçim.\n\n'
          'Nasıl buldun? Neler hissettirdi? Oyunculuklar, senaryo, atmosfer ya da kurgu nasıldı? '
          'Seni sıkan bir yer oldu mu yoksa tam bir sinema şöleni miydi?',
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? predefinedText]) async {
    final text = (predefinedText ?? _textController.text).trim();
    if (text.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final aiService = ref.read(backendAiServiceProvider);
      final response = await aiService.chatMovieFeedback(
        movieTitle: widget.movie.title,
        conversationHistory: _messages,
        currentScore: _currentScore,
      );

      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response.reply});
          _currentScore = response.score;
          for (final a in response.likedAspects) {
            if (!_likedAspects.contains(a)) _likedAspects.add(a);
          }
          for (final a in response.dislikedAspects) {
            if (!_dislikedAspects.contains(a)) _dislikedAspects.add(a);
          }
          if (response.summary.isNotEmpty) {
            _summary = response.summary;
          }
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Görüşlerini not aldım! Başka bahsetmek istediğin bir sahne veya detay var mı?',
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _saveAndFinish() async {
    final finalReview = _summary.isNotEmpty 
        ? _summary 
        : _messages.where((m) => m['role'] == 'user').map((m) => m['content']).join(' | ');

    await ref.read(libraryProvider.notifier).saveAiReview(
      movie: widget.movie,
      rating: _currentScore,
      likedAspects: _likedAspects,
      dislikedAspects: _dislikedAspects,
      reviewSummary: finalReview,
    );

    // Trigger background cloud sync to Supabase
    ref.read(settingsProvider.notifier).triggerSync();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 "${widget.movie.title}" (⭐ ${_currentScore.toStringAsFixed(1)}/10) kütüphanene ve zevk profiline kaydedildi!',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width > 650;

    final modalWidth = isWide ? min(screenSize.width * 0.9, 640.0) : double.infinity;
    final modalHeight = isWide ? min(screenSize.height * 0.88, 760.0) : screenSize.height * 0.88;

    return Container(
      width: modalWidth,
      height: modalHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(isWide ? 24 : 0).copyWith(
          topLeft: const Radius.circular(24),
          topRight: const Radius.circular(24),
        ),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle on mobile
          if (!isWide)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLow.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          // 1. Header with Movie info, live score badge, and close button
          _buildHeader(),

          // 2. Aspects / Tags dynamic bar
          _buildAspectsBar(),

          Divider(height: 1, color: AppColors.border),

          // 3. Conversation feed
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildLoadingBubble();
                }
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildMessageBubble(msg['content'] ?? '', isUser);
              },
            ),
          ),

          // 4. Quick suggestions chips
          _buildQuickSuggestions(),

          // 5. Input field + Send button
          _buildInputField(),

          // 6. Footer button: Complete & Save
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // Poster thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 62,
              color: AppColors.surfaceHighlight,
              child: widget.movie.posterUrl.isNotEmpty
                  ? Image.network(
                      widget.movie.posterUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.movie, color: AppColors.textLow),
                    )
                  : Icon(Icons.movie, color: AppColors.textLow),
            ),
          ),
          const SizedBox(width: 14),

          // Title & release info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHigh,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (widget.movie.releaseYear.isNotEmpty) widget.movie.releaseYear,
                    if (widget.movie.genres != null && widget.movie.genres!.isNotEmpty) widget.movie.genres!,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Dynamic Live Score Badge (10-point scale)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryAmber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.primaryAmber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${_currentScore.toStringAsFixed(1)} / 10',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryAmber,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Close button
          IconButton(
            icon: Icon(Icons.close, color: AppColors.textMedium, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Kapat',
          ),
        ],
      ),
    );
  }

  Widget _buildAspectsBar() {
    final hasAspects = _likedAspects.isNotEmpty || _dislikedAspects.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceHighlight,
      child: hasAspects
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Zevk İpuçları: ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textLow),
                  ),
                  ..._likedAspects.map((aspect) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          '✓ $aspect',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6EE7B7)),
                        ),
                      )),
                  ..._dislikedAspects.map((aspect) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          '✕ $aspect',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5)),
                        ),
                      )),
                ],
              ),
            )
          : Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: AppColors.primaryIndigo),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sohbet ettikçe zevk sinyalleri ve tahmini puanın (10 üzerinden) güncellenecek.',
                    style: TextStyle(fontSize: 11, color: AppColors.textLow),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primaryBlue : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(16),
            bottomLeft: !isUser ? const Radius.circular(2) : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser ? Colors.transparent : AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, size: 14, color: AppColors.textAccentBlue),
                  const SizedBox(width: 4),
                  Text(
                    'CineAI Film Danışmanı',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textAccentBlue),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isUser ? Colors.white : AppColors.textHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(2)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 10),
            Text(
              'Yapay zeka filmi değerlendiriyor...',
              style: TextStyle(fontSize: 12, color: AppColors.textMedium),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _quickSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final suggestion = _quickSuggestions[index];
          return ActionChip(
            label: Text(suggestion),
            labelStyle: TextStyle(fontSize: 11, color: AppColors.textAccentBlue),
            backgroundColor: AppColors.surfaceElevated,
            side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () => _sendMessage(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_isLoading,
              style: TextStyle(fontSize: 13, color: AppColors.textHigh),
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Görüşünü yaz veya puan belirt (örn: Bence 7.8 olmalı)...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textLow),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryBlue),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading ? null : () => _sendMessage(),
            icon: Icon(
              Icons.send_rounded,
              color: _isLoading ? AppColors.textLow : AppColors.primaryBlue,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // Slider or manual score adjustment shortcut
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.star_half_rounded, size: 16, color: AppColors.primaryAmber),
                const SizedBox(width: 4),
                Text(
                  'Puan: ${_currentScore.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryAmber),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _currentScore.clamp(0.0, 10.0),
                      min: 0.0,
                      max: 10.0,
                      divisions: 100, // 0.1 increments
                      activeColor: AppColors.primaryAmber,
                      inactiveColor: AppColors.surfaceElevated,
                      onChanged: (val) {
                        setState(() {
                          _currentScore = (val * 10).roundToDouble() / 10.0;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Save & Finish button
          ElevatedButton.icon(
            onPressed: _saveAndFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              'Kaydet & Bitir 💾',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
