import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/movie.dart';
import '../../providers/chat_provider.dart';
import '../../providers/library_provider.dart';
import '../../widgets/movie_detail_modal.dart';
import '../../widgets/movie_review_modal.dart';
import '../../widgets/rating_dialog.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? customText]) {
    final text = customText ?? _textController.text;
    if (text.trim().isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage(text);
    if (customText == null) {
      _textController.clear();
      _focusNode.requestFocus();
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final message = chatState.messages[index];
                return _buildMessageItem(message);
              },
            ),
          ),

          // Generating indicator
          if (chatState.isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryAmber),
                  ),
                  Expanded(
                    child: Text(
                      'CineAI zevk profilini analiz ediyor ve düşünüyor...',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium.withValues(alpha: 0.8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Bottom quick suggestions row (from latest assistant message)
          if (chatState.messages.isNotEmpty &&
              chatState.messages.last.options.isNotEmpty &&
              !chatState.isGenerating)
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chatState.messages.last.options.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final option = chatState.messages.last.options[idx];
                  return ActionChip(
                    label: Text(option),
                    labelStyle: TextStyle(fontSize: 12, color: AppColors.textHigh, fontWeight: FontWeight.w600),
                    backgroundColor: AppColors.surfaceElevated,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      final lastMsg = chatState.messages.last;
                      if (option.contains('Sohbetle Değerlendir') && lastMsg.attachedMovie != null) {
                        MovieReviewModal.show(context, lastMsg.attachedMovie!);
                      } else if (option.contains('Puan Ver') && lastMsg.attachedMovie != null) {
                        RatingDialog.show(context, lastMsg.attachedMovie!);
                      } else {
                        _sendMessage(option);
                      }
                    },
                  );
                },
              ),
            ),

          // Message input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    cursorColor: AppColors.primaryAmber,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(fontSize: 14, color: AppColors.textHigh),
                    decoration: InputDecoration(
                      hintText: chatState.isAwaitingInterviewAnswer
                          ? 'Filmin neresini beğendin/beğenmedin yazabilirsin...'
                          : 'Hangi tür film arıyorsun veya nasıl bir moddasın?',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (val) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryAmber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: chatState.isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  onPressed: chatState.isGenerating ? null : () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isUser = message.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.movie_outlined, size: 16, color: AppColors.primaryAmber),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primaryBlue : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isUser ? Colors.transparent : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isUser ? Colors.white : AppColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormatter.formatRelative(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser ? Colors.white70 : AppColors.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Attached movie card (Recommendation or Review prompt)
          if (message.attachedMovie != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _buildInlineRecommendationCard(message.attachedMovie!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineRecommendationCard(Movie movie) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryAmber.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner & info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster thumb
              if (movie.posterUrl.isNotEmpty)
                SizedBox(
                  width: 90,
                  height: 125,
                  child: Image.network(
                    movie.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface,
                      child: Icon(Icons.movie, color: AppColors.textLow),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          DateFormatter.formatYear(movie.releaseDate),
                          if (movie.genres != null) movie.genres,
                        ].where((s) => s != null && s.isNotEmpty).join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppColors.textMedium),
                      ),
                      if (movie.voteAverage != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: AppColors.primaryAmber),
                            const SizedBox(width: 4),
                            Text(
                              movie.voteAverage!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          Divider(height: 1, color: AppColors.border),

          // Actions row
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(libraryProvider.notifier).toggleWatchlist(movie);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${movie.title} izleme listesine eklendi!')),
                    );
                  },
                  icon: const Icon(Icons.bookmark_add_outlined, size: 14, color: AppColors.primaryAmber),
                  label: const Text('Listeye Ekle', style: TextStyle(fontSize: 11, color: AppColors.primaryAmber)),
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => MovieDetailModal.show(context, movie),
                  icon: Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textHigh),
                  label: Text('Detaylar', style: TextStyle(fontSize: 11, color: AppColors.textHigh)),
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => RatingDialog.show(context, movie),
                  icon: const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accentNeon),
                  label: const Text('İzledim', style: TextStyle(fontSize: 11, color: AppColors.accentNeon)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
