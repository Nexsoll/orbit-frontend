// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class StoryReplyModel {
  final String userId;
  final String text;
  final DateTime createdAt;

  const StoryReplyModel({
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory StoryReplyModel.fromMap(Map<String, dynamic> map) {
    return StoryReplyModel(
      userId: map['userId'] as String,
      text: map['text'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'StoryReplyModel{userId: $userId, text: $text, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryReplyModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          text == other.text &&
          createdAt == other.createdAt;

  @override
  int get hashCode => userId.hashCode ^ text.hashCode ^ createdAt.hashCode;
}

class StoryReplyResponse {
  final StoryReplyModel reply;
  final int repliesCount;

  const StoryReplyResponse({
    required this.reply,
    required this.repliesCount,
  });

  factory StoryReplyResponse.fromMap(Map<String, dynamic> map) {
    return StoryReplyResponse(
      reply: StoryReplyModel.fromMap(map['reply'] as Map<String, dynamic>),
      repliesCount: map['repliesCount'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reply': reply.toMap(),
      'repliesCount': repliesCount,
    };
  }

  @override
  String toString() {
    return 'StoryReplyResponse{reply: $reply, repliesCount: $repliesCount}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryReplyResponse &&
          runtimeType == other.runtimeType &&
          reply == other.reply &&
          repliesCount == other.repliesCount;

  @override
  int get hashCode => reply.hashCode ^ repliesCount.hashCode;
}
