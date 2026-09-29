import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _sendMessage();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
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

          // Message input bar (Tek parça yukarı genişleyen buzlu cam kapsül)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
                      blurRadius: 16,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [
                                  Colors.white.withValues(alpha: 0.10),
                                  Colors.white.withValues(alpha: 0.03),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.65),
                                  Colors.white.withValues(alpha: 0.35),
                                ],
                        ),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.60),
                          width: 0.75,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Yukarı Doğru Dinamik Genişleyen Metin Alanı
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 10, 6, 10),
                              child: TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                cursorColor: AppColors.primaryBlue,
                                keyboardType: TextInputType.multiline,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.newline,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: AppColors.textHigh,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: chatState.isAwaitingInterviewAnswer
                                      ? 'Filmin neresini beğendin/beğenmedin...'
                                      : 'Hangi tür film arıyorsun veya nasıl bir moddasın?',
                                  hintStyle: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.45)
                                        : Colors.black.withValues(alpha: 0.40),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Kapsül İçi Dinamik Gönderme Butonu (Metin girilince veya AI çalışırken belirir)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: (_hasText || chatState.isGenerating)
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 6, bottom: 1),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF38BDF8),
                                            AppColors.primaryBlue,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryBlue.withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            spreadRadius: -1,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: chatState.isGenerating ? null : () => _sendMessage(),
                                          borderRadius: BorderRadius.circular(19),
                                          child: Center(
                                            child: chatState.isGenerating
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.arrow_upward_rounded,
                                                    size: 20,
                                                    color: Colors.white,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isUser = message.sender == MessageSender.user;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isUser ? 8 : 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primaryBlue),
                ),
              ],
              Flexible(
                child: isUser
                    ? ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (MediaQuery.of(context).size.width * 0.75).clamp(200.0, 560.0),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                              bottomLeft: Radius.circular(18),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildFormattedMessageText(
                                message.content,
                                baseStyle: const TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormatter.formatRelative(message.timestamp),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 2, right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormattedMessageText(
                              message.content,
                              baseStyle: TextStyle(
                                fontSize: 14.5,
                                height: 1.55,
                                color: AppColors.textHigh,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormatter.formatRelative(message.timestamp),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textLow,
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
            const SizedBox(height: 12),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
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
                              const Icon(Icons.star_rounded, size: 14, color: AppColors.tmdbGold),
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

            // Actions row (Responsive & compact)
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
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 14, color: AppColors.primaryBlue),
                    label: const Text(
                      'Listeye Ekle',
                      style: TextStyle(fontSize: 11, color: AppColors.primaryBlue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => MovieDetailModal.show(context, movie),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textHigh),
                    label: Text(
                      'Detaylar',
                      style: TextStyle(fontSize: 11, color: AppColors.textHigh),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => RatingDialog.show(context, movie),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accentNeon),
                    label: const Text(
                      'İzledim',
                      style: TextStyle(fontSize: 11, color: AppColors.accentNeon),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedMessageText(String rawContent, {required TextStyle baseStyle}) {
    // 1. Sanitize HTML tags (<br>, <br/>, <p>, </p>)
    String sanitized = rawContent
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</?p>', caseSensitive: false), '\n\n')
        .trim();

    // 2. If an ASCII table was output (| Col | Col |), convert to clean, beautiful bullet points
    if (sanitized.contains('|')) {
      final lines = sanitized.split('\n');
      final cleanLines = <String>[];
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('|') && trimmedLine.endsWith('|')) {
          if (RegExp(r'^\|[\s\-:|]+\|$').hasMatch(trimmedLine)) continue;
          final cells = trimmedLine
              .split('|')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toList();
          if (cells.isNotEmpty) {
            if (cells.length >= 2) {
              cleanLines.add('• **${cells[0]}:** ${cells.sublist(1).join(' — ')}');
            } else {
              cleanLines.add('• ${cells[0]}');
            }
          }
        } else {
          cleanLines.add(line);
        }
      }
      sanitized = cleanLines.join('\n');
    }

    // 3. Build rich text spans with bold support (**bold text**)
    final spans = <TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int currentIndex = 0;

    for (final match in boldRegex.allMatches(sanitized)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: sanitized.substring(currentIndex, match.start),
          style: baseStyle,
        ));
      }
      final boldText = match.group(1) ?? '';
      spans.add(TextSpan(
        text: boldText,
        style: baseStyle.copyWith(
          fontWeight: FontWeight.bold,
          color: baseStyle.color,
        ),
      ));
      currentIndex = match.end;
    }

    if (currentIndex < sanitized.length) {
      spans.add(TextSpan(
        text: sanitized.substring(currentIndex),
        style: baseStyle,
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}
