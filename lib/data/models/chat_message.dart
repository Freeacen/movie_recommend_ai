import 'dart:convert';
import 'movie.dart';

enum MessageSender {
  user,
  assistant,
  system;

  static MessageSender fromString(String value) {
    switch (value) {
      case 'user':
        return MessageSender.user;
      case 'assistant':
        return MessageSender.assistant;
      case 'system':
      default:
        return MessageSender.system;
    }
  }
}

enum MessageType {
  normal,
  recommendationCard,
  reviewNudge,
  sentimentInterview;

  static MessageType fromString(String? value) {
    switch (value) {
      case 'recommendationCard':
        return MessageType.recommendationCard;
      case 'reviewNudge':
        return MessageType.reviewNudge;
      case 'sentimentInterview':
        return MessageType.sentimentInterview;
      case 'normal':
      default:
        return MessageType.normal;
    }
  }
}

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String content;
  final String timestamp;
  final int? relatedMovieId;
  final MessageType messageType;
  final List<String> options; // Quick actionable response chips
  final Movie? attachedMovie; // In-memory attachment for instant card render

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.relatedMovieId,
    this.messageType = MessageType.normal,
    this.options = const [],
    this.attachedMovie,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender.name,
      'content': content,
      'timestamp': timestamp,
      'related_movie_id': relatedMovieId,
      'message_type': messageType.name,
      'options': jsonEncode(options),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, {Movie? attachedMovie}) {
    List<String> parseOptions(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(value.toString());
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
      return [];
    }

    return ChatMessage(
      id: map['id'] as String,
      sender: MessageSender.fromString(map['sender'] as String),
      content: map['content'] as String,
      timestamp: map['timestamp'] as String,
      relatedMovieId: map['related_movie_id'] as int?,
      messageType: MessageType.fromString(map['message_type'] as String?),
      options: parseOptions(map['options']),
      attachedMovie: attachedMovie,
    );
  }

  ChatMessage copyWith({
    String? id,
    MessageSender? sender,
    String? content,
    String? timestamp,
    int? relatedMovieId,
    MessageType? messageType,
    List<String>? options,
    Movie? attachedMovie,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      relatedMovieId: relatedMovieId ?? this.relatedMovieId,
      messageType: messageType ?? this.messageType,
      options: options ?? this.options,
      attachedMovie: attachedMovie ?? this.attachedMovie,
    );
  }
}
